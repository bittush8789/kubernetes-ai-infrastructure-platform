#!/usr/bin/env bash
# monitor.sh - Check the health of EKS nodes, pods, and API endpoints

set -eo pipefail

echo "=========================================================="
echo " Starting Kubernetes AI Infrastructure Health Check"
echo "=========================================================="

# 1. Check cluster connection
if ! kubectl cluster-info &> /dev/null; then
    echo "ERROR: Cannot connect to Kubernetes cluster. Verify kubeconfig context."
    exit 1
fi

# 2. Check Node Status
echo "--> Checking Node Status..."
kubectl get nodes -o wide

# 3. Check Core Namespace Pod status
namespaces=("ml-platform" "kserve" "monitoring" "logging" "team-a" "team-b" "team-c")
echo "--> Checking Pod Status in Core Namespaces..."
for ns in "${namespaces[@]}"; do
    echo "  [Namespace: $ns]"
    unhealthy_pods=$(kubectl get pods -n "$ns" --no-headers | grep -v -E "Running|Completed" || true)
    if [ -n "$unhealthy_pods" ]; then
        echo "    WARNING: Found unhealthy pods:"
        echo "$unhealthy_pods"
    else
        echo "    [✓] All pods healthy"
    fi
done

# 4. Check API Endpoint Response
echo "--> Checking Platform API Gateway response..."
local_api_status=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8000/metrics || true)
if [ "$local_api_status" == "200" ]; then
    echo "  [✓] Local Platform API is operational (200 OK)."
else
    echo "  [i] Local Platform API is not running or not listening on port 8000."
fi

echo "=========================================================="
echo " Health Check Complete"
echo "=========================================================="
