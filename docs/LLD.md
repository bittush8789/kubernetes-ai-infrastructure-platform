# Low-Level Design (LLD)

This document details the low-level configurations, code schemas, database models, and manifest shapes for the platform.

---

## 1. Database Schema Design (PostgreSQL)

The database persistence layer is implemented in SQLAlchemy. The schema definitions are structured as follows:

```sql
-- Workspaces Table
CREATE TABLE workspaces (
    id SERIAL PRIMARY KEY,
    name VARCHAR(255) UNIQUE NOT NULL,
    quota_cpu VARCHAR(50) DEFAULT '4',
    quota_memory VARCHAR(50) DEFAULT '16Gi',
    quota_gpu VARCHAR(50) DEFAULT '1',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX idx_workspace_name ON workspaces(name);

-- Models Table
CREATE TABLE models (
    id SERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    version VARCHAR(50) NOT NULL,
    framework VARCHAR(100) NOT NULL,
    artifact_uri VARCHAR(1024) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX idx_model_name ON models(name);

-- Deployments Table
CREATE TABLE deployments (
    id SERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    workspace_id INTEGER REFERENCES workspaces(id) ON DELETE CASCADE,
    model_id INTEGER REFERENCES models(id) ON DELETE RESTRICT,
    cpu VARCHAR(50) DEFAULT '1',
    memory VARCHAR(50) DEFAULT '2Gi',
    gpu VARCHAR(50) DEFAULT '0',
    replicas INTEGER DEFAULT 1,
    status VARCHAR(50) DEFAULT 'Deploying',
    endpoint_url VARCHAR(1024),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX idx_deployment_name ON deployments(name);

-- Audit Logs Table
CREATE TABLE audit_logs (
    id SERIAL PRIMARY KEY,
    "user" VARCHAR(255) NOT NULL,
    action VARCHAR(255) NOT NULL,
    details TEXT,
    timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

---

## 2. API Design & Payloads

The Platform API exposes REST endpoints for self-service operations.

### POST `/deploy-model`
-   **Method**: `POST`
-   **Payload Schema (Pydantic)**:
    ```json
    {
      "name": "sentiment-analysis-v1",
      "workspace": "team-a",
      "model_name": "sentiment-analysis",
      "model_version": "1",
      "framework": "pytorch",
      "artifact_uri": "s3://k8s-ai-platform-model-registry-bucket/models/sentiment-analysis/1/",
      "cpu": "1",
      "memory": "2Gi",
      "gpu": "0",
      "replicas": 1
    }
    ```
-   **Logic**:
    1. Validate Keycloak OIDC bearer token in request header.
    2. Check if the workspace `team-a` exists and has remaining resource quota.
    3. Query or register the model in the database.
    4. Call Kubernetes CustomObject API to apply the KServe `InferenceService` CRD.
    5. Write audit log entry and return deployment state metadata.

### GET `/deployments/{deployment_id}/logs`
-   **Method**: `GET`
-   **Logic**:
    1. Query deployment database record to find workspace name and pod selectors.
    2. Invoke Kubernetes CoreV1 API to retrieve logs from pod matching label: `serving.kserve.io/inferenceservice=<name>`.
    3. Return plain text log stream or JSON payload.

---

## 3. Kubernetes Resource Specifications

### KServe InferenceService CRD Manifest Shape
```yaml
apiVersion: serving.kserve.io/v1beta1
kind: InferenceService
metadata:
  name: sentiment-clf
  namespace: team-a
spec:
  predictor:
    model:
      modelFormat:
        name: pytorch
      storageUri: s3://k8s-ai-platform-model-registry-bucket/models/sentiment-analysis/1/
      resources:
        limits:
          cpu: "1"
          memory: 2Gi
        requests:
          cpu: "500m"
          memory: 1Gi
```

### Team Isolation NetworkPolicy Shape
```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: team-isolation-policy
  namespace: team-a
spec:
  podSelector: {} # Default-deny all pods inside namespace
  policyTypes:
    - Ingress
  ingress:
    - from:
        - podSelector: {} # Whitelist intra-namespace pods
    - from:
        - namespaceSelector:
            matchLabels:
              name: ml-platform # Whitelist Platform API commands
```

---

## 4. Terraform Module Configurations

-   **Root Module**: Calls the VPC, IAM, and EKS sub-modules, provisioning the S3 bucket.
-   **VPC Module**: Deploys public and private subnets across 3 Availability Zones. Annotates public subnets with `kubernetes.io/role/elb=1` and private subnets with `kubernetes.io/role/internal-elb=1`.
-   **EKS Module**: provisions control plane endpoints. Configures CPU node groups (using `t3.xlarge` instances) and GPU node groups (using `g4dn.xlarge` instances with `nvidia.com/gpu=true:NoSchedule` taints).
-   **IAM Module**: Sets up trust policies using the EKS OpenID Connect provider to enable IRSA for S3 access.

---

## 5. GitOps & CI/CD Design

### ArgoCD App-of-Apps structure
The root application at `argocd/root-application.yaml` points to the `argocd/apps` directory, which contains application declarations:
-   `mlflow.yaml`: Configures the MLflow deployment inside namespace `ml-platform`.
-   `minio.yaml`: Configures MinIO StatefulSets and services inside `ml-platform`.
-   `kserve.yaml`: Sets up KServe serving controllers inside `kserve` namespace.
-   `monitoring.yaml`: deploys Prometheus, Grafana dashboards, and Loki logs pipelines.

### CI/CD stages (GitHub Actions)
1.  **Code Check**: Verifies python syntax using `ruff` and executes testing suites using `pytest`.
2.  **Container Compilation**: Compiles the FastAPI backend Docker image and pushes it to Amazon ECR.
3.  **GitOps manifest updates**: Patches the deployment tag in [k8s-deployment.yaml](file:///d:/Ai infra & ai plateform/Kubernetes AI Infrastructure Platform/fastapi-platform-api/k8s-deployment.yaml) and pushes it to GitHub, triggering ArgoCD synchronization.
