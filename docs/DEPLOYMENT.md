# Cloud & GitOps Deployment Guide

This document describes how to deploy the platform to AWS EKS using Terraform, build the Docker images, and sync the workloads via ArgoCD GitOps.

---

## 1. Cloud Provisioning (Terraform)

### Step 1: Initialize Terraform
Navigate to the terraform directory and initialize providers (AWS, TLS, etc.):
```bash
cd terraform
terraform init
```

### Step 2: Validate the Plan
Create an execution plan to verify what AWS resources (VPC, subnets, node pools, S3 bucket, IAM roles) will be created:
```bash
terraform plan
```

### Step 3: Apply the Plan
Apply the configurations to deploy resources to AWS:
```bash
terraform apply -auto-approve
```
*Note: This provisioning step takes approximately 10-15 minutes to spin up the VPC and EKS node groups.*

---

## 2. Docker Image Compilation

Build and upload the Platform API & UI Portal image to Amazon Elastic Container Registry (ECR):

1.  **Retrieve ECR login credentials**:
    ```bash
    aws ecr get-login-password --region us-west-2 | docker login --username AWS --password-stdin <aws_account_id>.dkr.ecr.us-west-2.amazonaws.com
    ```
2.  **Build the Docker image**:
    Navigate to the root directory and run:
    ```bash
    docker build -t ai-platform-api:latest -f fastapi-platform-api/Dockerfile fastapi-platform-api/
    ```
3.  **Tag and Push to ECR**:
    ```bash
    docker tag ai-platform-api:latest <aws_account_id>.dkr.ecr.us-west-2.amazonaws.com/ai-platform-api:latest
    docker push <aws_account_id>.dkr.ecr.us-west-2.amazonaws.com/ai-platform-api:latest
    ```

---

## 3. GitOps Bootstrap (ArgoCD)

Once EKS is up and your kubeconfig context is updated, you can bootstrap ArgoCD to deploy all services (MLflow, MinIO, KServe, etc.).

### Step 1: Connect to EKS Cluster
Update your local kubeconfig to point to your new EKS cluster:
```bash
aws eks update-kubeconfig --name ai-platform-cluster --region us-west-2
```

### Step 2: Install ArgoCD
Deploy the ArgoCD control controller inside the cluster:
```bash
kubectl create namespace argocd || true
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
```

### Step 3: Apply the Root GitOps App
Apply the root App-of-Apps manifest. ArgoCD will read [argocd/apps/](file:///d:/Ai%20infra%20&%20ai%20plateform/Kubernetes%20AI%20Infrastructure%20Platform/argocd/apps/) and deploy all modules automatically:
```bash
kubectl apply -f argocd/root-application.yaml
```

### Step 4: Verify Deployment Synced
Check if all applications are in a synced and healthy state:
```bash
kubectl get applications -n argocd
```
You can port-forward to access the ArgoCD console locally:
```bash
kubectl port-forward svc/argocd-server -n argocd 8080:443
```
Now log in at `https://localhost:8080` using the username `admin` and retrieve the password with:
```bash
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
```
