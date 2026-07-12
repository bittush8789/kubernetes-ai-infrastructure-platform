# Platform CLI Installation Guide (From Scratch)

This guide walks you through installing all required CLI tools from scratch. It covers macOS, Linux (Ubuntu), and Windows (PowerShell/Choco).

---

## 1. AWS Command Line Interface (AWS CLI v2)
Used to configure credentials and manage EKS cluster contexts.

-   **macOS**:
    ```bash
    curl "https://awscli.amazonaws.com/AWSCLIV2.pkg" -o "AWSCLIV2.pkg"
    sudo installer -pkg AWSCLIV2.pkg -target /
    ```
-   **Linux (Ubuntu)**:
    ```bash
    curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
    unzip awscliv2.zip
    sudo ./aws/install
    ```
-   **Windows (PowerShell)**:
    ```powershell
    msiexec.exe /i https://awscli.amazonaws.com/AWSCLIV2.msi /qn
    ```

Verify: `aws --version`

---

## 2. Kubernetes Command Line Tool (kubectl)
Used to interact with the EKS cluster API.

-   **macOS**:
    ```bash
    brew install kubectl
    ```
-   **Linux (Ubuntu)**:
    ```bash
    sudo apt-get update && sudo apt-get install -y apt-transport-https ca-certificates curl
    sudo curl -fsSLo /usr/share/keyrings/kubernetes-archive-keyring.gpg https://packages.cloud.google.com/apt/doc/gpg.key
    echo "deb [signed-by=/usr/share/keyrings/kubernetes-archive-keyring.gpg] https://apt.kubernetes.io/ kubernetes-xenial main" | sudo tee /etc/apt/sources.list.d/kubernetes.list
    sudo apt-get update && sudo apt-get install -y kubectl
    ```
-   **Windows (PowerShell)**:
    ```powershell
    curl.exe -LO "https://dl.k8s.io/release/v1.28.0/bin/windows/amd64/kubectl.exe"
    # Move kubectl.exe to a folder in your System PATH
    ```

Verify: `kubectl version --client`

---

## 3. Terraform (HashiCorp)
Used to provision the AWS VPC, IAM policies, and EKS clusters.

-   **macOS**:
    ```bash
    brew tap hashicorp/tap
    brew install hashicorp/tap/terraform
    ```
-   **Linux (Ubuntu)**:
    ```bash
    wget -O- https://apt.releases.hashicorp.com/gpg | gpg --dearmor | sudo tee /usr/share/keyrings/hashicorp-archive-keyring.gpg
    echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
    sudo apt-get update && sudo apt-get install terraform
    ```
-   **Windows**:
    ```powershell
    choco install terraform
    ```

Verify: `terraform --version`

---

## 4. Docker Engine
Used to build container images for the Platform API.

-   **macOS / Windows**: Install [Docker Desktop](https://www.docker.com/products/docker-desktop/).
-   **Linux (Ubuntu)**:
    ```bash
    curl -fsSL https://get.docker.com -o get-docker.sh
    sudo sh get-docker.sh
    sudo usermod -aG docker $USER
    ```

Verify: `docker --version`

---

## 5. Python 3.10 & Pip
Used to run the local FastAPI API server.

-   **macOS**:
    ```bash
    brew install python@3.10
    ```
-   **Linux (Ubuntu)**:
    ```bash
    sudo apt-get update && sudo apt-get install -y python3 python3-pip python3-venv
    ```
-   **Windows**: Download installer from [python.org](https://www.python.org/downloads/).

Verify: `python3 --version`

---

## 6. Helm (Kubernetes Package Manager)
Used to deploy Prometheus, Grafana, Loki, and Cert-manager.

-   **macOS**:
    ```bash
    brew install helm
    ```
-   **Linux (Ubuntu)**:
    ```bash
    curl https://baltocdn.com/helm/signing.asc | gpg --dearmor | sudo tee /usr/share/keyrings/helm.gpg > /dev/null
    echo "deb [arch=amd64 signed-by=/usr/share/keyrings/helm.gpg] https://baltocdn.com/helm/stable/debian/ all main" | sudo tee /etc/apt/sources.list.d/helm-stable-debian.list
    sudo apt-get update && sudo apt-get install helm
    ```
-   **Windows**:
    ```powershell
    choco install kubernetes-helm
    ```

Verify: `helm version`

---

## 7. ArgoCD Command Line Interface (ArgoCD CLI)
Used to manage application synchronizations from the command line.

-   **macOS**:
    ```bash
    brew install argocd
    ```
-   **Linux (Ubuntu)**:
    ```bash
    curl -sSL -o argocd-linux-amd64 https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
    sudo install -m 555 argocd-linux-amd64 /usr/local/bin/argocd
    rm argocd-linux-amd64
    ```
-   **Windows (PowerShell)**:
    ```powershell
    choco install argocd-cli
    ```

Verify: `argocd version --client`
