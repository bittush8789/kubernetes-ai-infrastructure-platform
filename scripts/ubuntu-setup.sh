#!/usr/bin/env bash
# ubuntu-setup.sh - Full development environment bootstrap for Ubuntu systems
# Must be run with sudo or root permissions to install packages.

set -eo pipefail

echo "=========================================================="
echo " Starting Platform Dependency Installer for Ubuntu"
echo "=========================================================="

if [ "$EUID" -ne 0 ]; then
  echo "ERROR: Please run this script with sudo or as root:"
  echo "  sudo ./scripts/ubuntu-setup.sh"
  exit 1
fi

export DEBIAN_FRONTEND=noninteractive

# 1. System updates & basic tools
echo "--> Step 1: Updating packages and installing utility core tools..."
apt-get update -y
apt-get install -y apt-transport-https ca-certificates curl gnupg lsb-release unzip software-properties-common python3 python3-pip python3-venv git

# 2. Install Docker
echo "--> Step 2: Installing Docker Engine..."
if ! command -v docker &> /dev/null; then
    curl -fsSL https://get.docker.com -o get-docker.sh
    sh get-docker.sh
    rm get-docker.sh
    echo "  [✓] Docker installed successfully."
else
    echo "  [✓] Docker already installed."
fi

# 3. Install AWS CLI
echo "--> Step 3: Installing AWS CLI v2..."
if ! command -v aws &> /dev/null; then
    curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
    unzip -q awscliv2.zip
    ./aws/install
    rm -rf aws awscliv2.zip
    echo "  [✓] AWS CLI installed successfully."
else
    echo "  [✓] AWS CLI already installed."
fi

# 4. Install Kubectl
echo "--> Step 4: Installing Kubectl..."
if ! command -v kubectl &> /dev/null; then
    K8S_VERSION=$(curl -L -s https://dl.k8s.io/release/stable.txt)
    curl -LO "https://dl.k8s.io/release/${K8S_VERSION}/bin/linux/amd64/kubectl"
    chmod +x kubectl
    mv kubectl /usr/local/bin/
    echo "  [✓] Kubectl installed successfully."
else
    echo "  [✓] Kubectl already installed."
fi

# 5. Install Terraform
echo "--> Step 5: Installing Terraform CLI..."
if ! command -v terraform &> /dev/null; then
    curl -fsSL https://apt.releases.hashicorp.com/gpg | gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
    echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | tee /etc/apt/sources.list.d/hashicorp.list
    apt-get update -y && apt-get install -y terraform
    echo "  [✓] Terraform installed successfully."
else
    echo "  [✓] Terraform already installed."
fi

# 6. Install Helm
echo "--> Step 6: Installing Helm..."
if ! command -v helm &> /dev/null; then
    curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3
    chmod 700 get_helm.sh
    ./get_helm.sh
    rm get_helm.sh
    echo "  [✓] Helm installed successfully."
else
    echo "  [✓] Helm already installed."
fi

echo "=========================================================="
echo " System Dependency Installation Complete!"
echo "=========================================================="
echo " Next Steps for non-root users:"
echo " 1. Add your user to the docker group so you don't need 'sudo docker':"
echo "    sudo usermod -aG docker \$USER"
echo "    (You will need to log out and log back in to apply this change)"
echo ""
echo " 2. Run the platform setup script to initialize virtualenv and db:"
echo "    ./scripts/setup.sh"
echo "=========================================================="
