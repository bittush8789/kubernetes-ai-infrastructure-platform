#!/usr/bin/env bash
# destroy.sh - Safe teardown script for AWS infrastructure and EKS workloads

set -eo pipefail

echo "=========================================================="
echo " Starting Safe Platform Destruction"
echo " WARNING: This will delete EKS, VPC, and S3 resources!"
echo "=========================================================="

read -p "Are you absolutely sure you want to destroy the entire platform? (y/N) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]
then
    echo "Destruction cancelled."
    exit 1
fi

# 1. Clean up Kubernetes services to prevent stuck ELBs
echo "--> Cleaning up GitOps Root Application..."
kubectl delete -f argocd/root-application.yaml --ignore-not-found=true || true

echo "--> Deleting namespaces and active load balancers..."
kubectl delete ns ml-platform kserve monitoring logging team-a team-b team-c --ignore-not-found=true || true

# Wait for deletion
echo "--> Waiting for namespaces to delete..."
sleep 30

# 2. Run Terraform destroy
echo "--> Step 2: Running Terraform Destroy..."
cd terraform
terraform destroy -auto-approve
cd ..

echo "=========================================================="
echo " Destruction completed successfully."
echo "=========================================================="
