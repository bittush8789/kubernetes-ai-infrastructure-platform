# Platform Operational Runbook & DR Procedures

This runbook describes recovery procedures for platform failures.

---

## 1. Recovery Procedure: Pod Failures (`CrashLoopBackOff` / `Pending`)

*   **Symptoms**: A core pod or model deployment container continuously crashes, showing `CrashLoopBackOff` status.
*   **Resolution Steps**:
    1.  **Retrieve Pod description**: Check constraints, volume attachments, or event logs:
        ```bash
        kubectl describe pod <POD_NAME> -n <NAMESPACE>
        ```
    2.  **Inspect container logs**: Look at stderr outputs:
        ```bash
        kubectl logs <POD_NAME> -n <NAMESPACE> --tail=100
        ```
    3.  **Check for OOM (Out of Memory) kills**:
        If events show `OOMKilled`, increase the memory limits inside the deployment manifest or re-submit the deployment with higher requests.

---

## 2. Recovery Procedure: EKS Node Failures

*   **Symptoms**: Nodes transition to `NotReady` status, causing pods to get stuck in `Terminating` or rescheduled states.
*   **Resolution Steps**:
    1.  **Evacuate Node**: Drain workloads from the degraded node:
        ```bash
        kubectl drain <NODE_NAME> --ignore-daemonsets --delete-emptydir-data --force
        ```
    2.  **Terminate Instance**: Terminate the corresponding EC2 instance. The AWS Auto Scaling Group (ASG) will spin up a healthy node replacement automatically.
    3.  **Monitor New Node Lifecycle**:
        ```bash
        kubectl get nodes -w
        ```

---

## 3. Recovery Procedure: KServe Controller Failure

*   **Symptoms**: Inference service creation hangs; `kubectl get inferenceservices` shows reconciliation state as `Unknown` or empty.
*   **Resolution Steps**:
    1.  **Check KServe controller pods status**:
        ```bash
        kubectl get pods -n kserve
        ```
    2.  **Restart the KServe controller manager**:
        ```bash
        kubectl rollout restart deployment/kserve-controller-manager -n kserve
        ```
    3.  **Inspect Knative serving gateway**:
        Verify Istio/Knative sidecars are not experiencing certificate mismatch issues. Check cert-manager logs.

---

## 4. Recovery Procedure: MLflow Connection / UI Failures

*   **Symptoms**: The MLflow Web UI page times out; code fails to upload experiment metadata or log artifact models.
*   **Resolution Steps**:
    1.  **Check MinIO availability**: Verify MinIO object store is responsive:
        ```bash
        kubectl get pods -n ml-platform -l app=minio
        ```
    2.  **Verify PostgreSQL connectivity**:
        Run a ping command inside the MLflow pod to ensure PostgreSQL port 5432 is accessible:
        ```bash
        kubectl exec -it deployment/mlflow-deployment -n ml-platform -- nc -zv postgres-service 5432
        ```
    3.  **Restart MLflow deployment**:
        ```bash
        kubectl rollout restart deployment/mlflow-deployment -n ml-platform
        ```

---

## 5. Recovery Procedure: ArgoCD Sync Loops

*   **Symptoms**: ArgoCD application gets stuck in an infinite `Reconciling` loop, continuously changing resources back and forth.
*   **Resolution Steps**:
    1.  **Identify drifting manifests**: Check the ArgoCD UI diff page to find the conflicting resource attribute.
    2.  **Disable Auto-Heal temporarily** to freeze updates:
        ```bash
        kubectl patch app <APP_NAME> -n argocd --type merge -p '{"spec":{"syncPolicy":{"automated":{"selfHeal":false}}}}'
        ```
    3.  **Resolve definition conflicts**: Align the Git source manifests with the Kubernetes controller overrides (like mutating Webhook changes).

---

## 6. Recovery Procedure: Database Connection Outages

*   **Symptoms**: Platform API backend returns `500 Database Connection Error` for all endpoints.
*   **Resolution Steps**:
    1.  **Check PostgreSQL Pod status**:
        ```bash
        kubectl get pods -n ml-platform -l app=postgres
        ```
    2.  **Verify PV/PVC storage space**: Check if the database storage volume is full:
        ```bash
        kubectl get pvc -n ml-platform
        ```
    3.  **Recover from corruption (if needed)**: Restore from the latest snapshot using [docs/OPERATIONS.md](file:///d:/Ai%20infra%20&%20ai%20plateform/Kubernetes%20AI%20Infrastructure%20Platform/docs/OPERATIONS.md#restore-procedure) guidelines.
