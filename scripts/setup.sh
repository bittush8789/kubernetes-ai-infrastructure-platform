#!/usr/bin/env bash
# setup.sh - Set up local development environment and verify tools

set -eo pipefail

echo "=========================================================="
echo " Starting Kubernetes AI Infrastructure Platform Setup"
echo "=========================================================="

# 1. Dependency checks
echo "--> Checking CLI prerequisites..."
prereqs=(python3 docker kubectl terraform helm argocd)
for cmd in "${prereqs[@]}"; do
    if ! command -v "$cmd" &> /dev/null; then
        echo "WARNING: '$cmd' is not installed or not in PATH. Please install it for full operations."
    else
        echo "  [✓] Found $cmd"
    fi
done

# 2. Virtual environment setup
echo "--> Initializing Python Virtual Environment..."
if [ ! -d "venv" ]; then
    python3 -m venv venv
    echo "  Virtual environment created."
else
    echo "  Virtual environment already exists."
fi

# Activate venv and install dependencies
source venv/bin/activate || source venv/Scripts/activate
echo "--> Installing Python platform dependencies..."
pip install --upgrade pip
pip install -r fastapi-platform-api/requirements.txt
pip install pytest httpx

# 3. Create local dotenv config
echo "--> Creating local platform configuration..."
if [ ! -f "fastapi-platform-api/.env" ]; then
    cat <<EOF > fastapi-platform-api/.env
DATABASE_URL=sqlite:///./ai_platform.db
MOCK_K8S=true
LOG_LEVEL=INFO
KEYCLOAK_URL=http://localhost:8080
EOF
    echo "  Created default fastapi-platform-api/.env config."
else
    echo "  fastapi-platform-api/.env already exists. Skipping."
fi

echo "=========================================================="
echo " Setup complete! To start the FastAPI server locally:"
echo " 1. Activate the environment: source venv/bin/activate"
echo " 2. Run the server: uvicorn fastapi-platform-api.app.main:app --reload"
echo "=========================================================="
