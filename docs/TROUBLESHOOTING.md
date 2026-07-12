# Platform Troubleshooting Guide

This guide covers common issues encountered during the lifecycle of the AI Infrastructure Platform and how to resolve them.

---

## 1. Cloud Infrastructure & Terraform Errors

### Error: State Lock (Error Acquiring Lock)
*   **Cause**: A previous Terraform run was interrupted or crashed, leaving the DynamoDB lock or local state lock active.
*   **Resolution**:
    1.  Verify no other teammate is running terraform.
    2.  Unlock the state using the lock ID provided in the error message:
        ```bash
        terraform force-unlock <LOCK_ID>
        ```

### Error: IAM IRSA role fails to assume (403 Access Denied)
*   **Cause**: The trust relationship configuration in EKS OIDC provider doesn't match the namespace or service account name.
*   **Resolution**:
    1.  Inspect the IAM trust policy on the role.
    2.  Check the OIDC provider url matches exactly.
    3.  Verify the service account name (`mlflow-sa`) and namespace (`ml-platform`) match the policy string:
        `system:serviceaccount:ml-platform:mlflow-sa`

---

## 2. Kubernetes & KServe Workload Errors

### Error: Pod stuck in `ImagePullBackOff`
*   **Cause**: Kubernetes nodes cannot authenticate to ECR, or the specified container tag is missing in the registry.
*   **Resolution**:
    1.  Describe the failing pod to identify the image path:
        ```bash
        kubectl describe pod <POD_NAME> -n <NAMESPACE>
        ```
    2.  Verify EKS Worker node IAM role has `AmazonEC2ContainerRegistryReadOnly` policy attached.
    3.  Manually inspect ECR repository to verify the image tag exists.

### Error: KServe model deployment fails with `StorageInitializer` timeout
*   **Cause**: The initContainer responsible for downloading model weights from S3/MinIO cannot reach the storage URL or has bad S3 credentials.
*   **Resolution**:
    1.  Check KServe initContainer logs:
        ```bash
        kubectl logs <POD_NAME> -c storage-initializer -n <NAMESPACE>
        ```
    2.  Validate S3 credentials secret is correct and reachable by KServe in that namespace.
    3.  Ensure the endpoint URI is resolvable inside the cluster.

---

## 3. GitOps & ArgoCD Sync Issues

### Error: Application status is `Degraded` or stuck in `Progressing`
*   **Cause**: Manifests have invalid specifications, or resource limits exceed the namespace quotas.
*   **Resolution**:
    1.  Retrieve detailed status from ArgoCD:
        ```bash
        argocd app get <APP_NAME>
        ```
    2.  Check for namespace quota violations:
        ```bash
        kubectl describe resourcequotas -n <NAMESPACE>
        ```
    3.  Manually run dry-run validation on the manifest:
        ```bash
        kubectl apply -f <MANIFEST_FILE> --dry-run=client
        ```
