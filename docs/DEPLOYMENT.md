# Cloud Platform & GitOps Deployment Guide

This guide details the end-to-end instructions to deploy the AI Platform to AWS EKS and synchronize applications via ArgoCD.

---

## 1. Prerequisites & AWS Configuration

Ensure you have configured your AWS CLI credentials:
```bash
aws configure
# Enter AWS Access Key ID, Secret Access Key, Default Region (e.g., us-west-2), Output Format (json)
```

Verify your active identity:
```bash
aws sts get-caller-identity
```

---

## 2. Infrastructure Deployment (Terraform)

Provision the underlying AWS resources (VPC, IAM policies, Managed EKS node pools, S3 Model Registry):

1.  **Navigate to the Terraform folder**:
    ```bash
    cd terraform
    ```
2.  **Initialize providers**:
    ```bash
    terraform init
    ```
3.  **Validate configurations**:
    ```bash
    terraform validate
    ```
4.  **Review the deployment plan**:
    ```bash
    terraform plan
    ```
5.  **Provision the resources**:
    ```bash
    terraform apply -auto-approve
    ```
    *This command takes 10 to 15 minutes to complete while EKS node groups are created in multiple availability zones.*

---

## 3. Configure Kubernetes Context (Kubeconfig)

Configure your local shell environment to target the newly created EKS cluster:

```bash
aws eks update-kubeconfig --name ai-platform-cluster --region us-west-2
```

Verify cluster access:
```bash
kubectl get nodes
```

---

## 4. Build and Push Container Images (ECR)

Compile the FastAPI platform API and frontend UI, and upload the image to Amazon ECR:

1.  **Retrieve ECR Registry URI**:
    Retrieve the account ID to log in to AWS ECR:
    ```bash
    aws ecr get-login-password --region us-west-2 | docker login --username AWS --password-stdin <aws_account_id>.dkr.ecr.us-west-2.amazonaws.com
    ```
2.  **Build the Docker image**:
    Build the platform image from the root directory:
    ```bash
    docker build -t ai-platform-api:latest -f fastapi-platform-api/Dockerfile fastapi-platform-api/
    ```
3.  **Tag the image for ECR**:
    ```bash
    docker tag ai-platform-api:latest <aws_account_id>.dkr.ecr.us-west-2.amazonaws.com/ai-platform-api:latest
    ```
4.  **Push the image to ECR**:
    ```bash
    docker push <aws_account_id>.dkr.ecr.us-west-2.amazonaws.com/ai-platform-api:latest
    ```

---

## 5. Bootstrap ArgoCD (GitOps)

Reconcile in-cluster deployments automatically based on the App-of-Apps repository pattern.

1.  **Deploy the ArgoCD controller namespaces**:
    ```bash
    kubectl create namespace argocd || true
    kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
    ```
2.  **Apply the Root App-of-Apps Manifest**:
    Configure ArgoCD to track this repository:
    ```bash
    kubectl apply -f argocd/root-application.yaml
    ```
3.  **Access the ArgoCD Web Dashboard**:
    Forward requests to access the Web Console locally:
    ```bash
    kubectl port-forward svc/argocd-server -n argocd 8080:443
    # Navigate to: https://localhost:8080
    ```
4.  **Log in**:
    -   *Username*: `admin`
    -   *Password*: Retrieve using the command:
        ```bash
        kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
        ```

All resources (MLflow, MinIO, KServe serving controllers, Observability monitoring agents, Keycloak databases, and the Platform API) are now automatically synced and deployed inside your EKS cluster!
