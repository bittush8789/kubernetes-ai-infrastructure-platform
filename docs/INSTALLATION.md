# Local Environment Installation Guide

Follow these steps to set up, initialize, and validate the Enterprise AI Platform API and Portal on your local machine.

---

## 1. Local Setup Prerequisites

Ensure you have the following installed:
- **Python 3.10** or higher
- **Git**

---

## 2. Setting Up the Project

### Step 1: Clone the Repository
Open a terminal and run:
```bash
git clone https://github.com/enterprise/kubernetes-ai-infrastructure-platform.git
cd kubernetes-ai-infrastructure-platform
```

### Step 2: Initialize the Environment Script
You can use the automated setup script to check dependencies, create the Python virtual environment, and install libraries:
```bash
# On Linux/macOS:
chmod +x scripts/setup.sh
./scripts/setup.sh

# On Windows:
powershell -ExecutionPolicy Bypass -File scripts/setup.sh
```

### Step 3: Manual Virtual Environment setup (Alternative)
If you prefer setting up manually:
```bash
# Create python virtual environment
python -m venv venv

# Activate virtual environment
# On Linux/macOS:
source venv/bin/activate
# On Windows (cmd):
venv\Scripts\activate
# On Windows (PowerShell):
.\venv\Scripts\Activate.ps1

# Install platform dependencies
pip install --upgrade pip
pip install -r fastapi-platform-api/requirements.txt
```

---

## 3. Running the Platform API & Portal

The platform has a mock mode enabled by default (`MOCK_K8S=true` inside `fastapi-platform-api/app/k8s_client.py`), allowing it to run locally without connecting to an active AWS EKS cluster.

1.  Start the FastAPI application using Uvicorn:
    ```bash
    cd fastapi-platform-api
    python -m uvicorn app.main:app --reload --host 127.0.0.1 --port 8000
    ```
2.  **Access the Portal UI**:
    Open your web browser and navigate to:
    [http://localhost:8000/portal/](http://localhost:8000/portal/)
3.  **Access API Swagger Documentation**:
    Navigate to:
    [http://localhost:8000/docs](http://localhost:8000/docs)

---

## 4. Validating the Local Installation

You can run our automated pytest suite to verify that database tables, schemas, deployment configurations, and mock routing are correct:

1.  Make sure your virtual environment is active.
2.  Run the tests from the root of the repository:
    ```bash
    python -m pytest fastapi-platform-api/app/test_main.py
    ```
3.  You should see output indicating that all test cases have passed successfully:
    `======================== 5 passed, 8 warnings in 5.27s ========================`
