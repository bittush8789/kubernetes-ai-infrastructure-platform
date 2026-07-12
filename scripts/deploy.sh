#!/usr/bin/env bash
# deploy.sh - Production Bootstrap Script for AI Infrastructure Platform

set -eo pipefail

echo "=========================================================="
echo " Starting Full Platform EKS & GitOps Deployment"
echo "=========================================================="

# 1. Provision Infrastructure via Terraform
echo "--> Step 1: Running Terraform Infrastructure Provisioning..."
cd terraform
terraform init
terraform apply -auto-approve
cd ..

# Retrieve outputs
CLUSTER_NAME=$(terraform -chdir=terraform output -raw eks_cluster_name)
AWS_REGION=$(terraform -chdir=terraform output -raw aws_region 2>/dev/null || echo "us-west-2")

echo "--> Provisioned Cluster: $CLUSTER_NAME in $AWS_REGION"

# 2. Setup Kubeconfig
echo "--> Step 2: Configuring Kubeconfig context..."
aws eks update-kubeconfig --name "$CLUSTER_NAME" --region "$AWS_REGION"

# 3. Create Namespaces and Base RBAC
echo "--> Step 3: Applying Core Namespaces and RBAC Roles..."
kubectl apply -f kubernetes/namespaces/namespaces.yaml
kubectl apply -f kubernetes/rbac/roles.yaml

# 4. Bootstrap ArgoCD GitOps
echo "--> Step 4: Installing ArgoCD Controller..."
kubectl create namespace argocd || true
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

echo "--> Waiting for ArgoCD custom resources to reconcile..."
kubectl wait --for=condition=Available deployment/argocd-server -n argocd --timeout=300s

# 5. Apply the GitOps Root App-of-Apps
echo "--> Step 5: Applying Root GitOps Application..."
kubectl apply -f argocd/root-application.yaml

echo "=========================================================="
echo " Bootstrap initiated! ArgoCD is now reconciling all"
echo " resources (MLflow, MinIO, KServe, Keycloak, Observability)"
echo " Check deployment sync status with:"
echo "   kubectl get applications -n argocd"
echo "=========================================================="
