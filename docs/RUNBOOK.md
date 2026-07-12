# Platform Operations Runbook

This runbook guides operators through common administrative tasks for the AI Infrastructure.

---

## 1. Onboarding a New Workspace (Team Namespace)

To onboard a new tenant (e.g. `team-d`):

1.  **Create Namespace and labels**:
    Add the team block to `kubernetes/namespaces/namespaces.yaml` or run:
    ```bash
    kubectl create namespace team-d
    kubectl label namespace team-d tenant=team-d istio-injection=enabled
    ```
2.  **Apply Resource Quotas**:
    Restrict maximum memory and CPU consumption to prevent cluster resource starvation:
    ```bash
    kubectl apply -f - <<EOF
    apiVersion: v1
    kind: ResourceQuota
    metadata:
      name: team-d-quota
      namespace: team-d
    spec:
      hard:
        requests.cpu: "4"
        requests.memory: 8Gi
        limits.cpu: "8"
        limits.memory: 16Gi
        requests.nvidia.com/gpu: "1"
    EOF
    ```
3.  **Apply Team isolation NetworkPolicy**:
    Apply the default-deny and whitelist rules:
    ```bash
    kubectl apply -f kubernetes/network-policies/team-isolation.yaml
    ```

---

## 2. Port-Forwarding to Internal Services

For security, dashboard consoles are not exposed to the public internet. Use these port-forward commands to access them locally:

-   **Grafana Dashboards**:
    ```bash
    kubectl port-forward svc/prometheus-grafana -n monitoring 3000:80
    # Access at http://localhost:3000 (Retrieve password from secret)
    ```
-   **MLflow Tracking Console**:
    ```bash
    kubectl port-forward svc/mlflow-service -n ml-platform 5000:5000
    # Access at http://localhost:5000
    ```
-   **MinIO Console (S3 Browser)**:
    ```bash
    kubectl port-forward svc/minio-service -n ml-platform 9001:9001
    # Access at http://localhost:9001
    ```

---

## 3. Scaling EKS Node Pools

If GPU queues grow or CPU limits are hit:

1.  **Scale CPU Node Pool**:
    Modify the EKS node scale settings:
    ```bash
    aws eks update-nodegroup-config \
      --cluster-name ai-platform-cluster \
      --nodegroup-name ai-platform-cluster-cpu-nodegroup \
      --scaling-config minSize=2,maxSize=10,desiredSize=5 \
      --region us-west-2
    ```
2.  **Verify New Nodes Joining**:
    ```bash
    kubectl get nodes -w
    ```
