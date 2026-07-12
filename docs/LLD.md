# Low-Level Design (LLD)

This document details the low-level configurations, schemas, and specifications for the platform.

---

## 1. Repository Directory Structure

```text
kubernetes-ai-infrastructure-platform/
├── .github/
│   └── workflows/
│       └── ci-cd.yaml             # GitHub Actions CI/CD Pipeline
├── terraform/
│   ├── main.tf                    # Root Terraform orchestration
│   ├── variables.tf               # Terraform global variables
│   ├── outputs.tf                 # Terraform output values
│   └── modules/
│       ├── vpc/
│       │   └── main.tf            # VPC resources, subnets, route tables
│       ├── eks/
│       │   └── main.tf            # EKS Cluster, node groups, OIDC
│       └── iam/
│           └── main.tf            # EKS roles, node roles, IRSA S3 policy
├── kubernetes/
│   ├── namespaces/
│   │   └── namespaces.yaml        # Isolated tenant namespaces
│   ├── rbac/
│   │   └── roles.yaml             # ML Engineer roles & Platform API SA bindings
│   ├── ingress/
│   │   └── nginx-ingress.yaml     # Hostname ingress mapping routing
│   ├── hpa/
│   │   └── hpa-template.yaml      # Horizontal Pod Autoscalers
│   └── network-policies/
│       └── team-isolation.yaml    # Tenant network namespace block policies
├── argocd/
│   ├── root-application.yaml      # ArgoCD App-of-Apps setup
│   └── apps/
│       ├── fastapi-platform-api.yaml
│       ├── mlflow.yaml
│       ├── minio.yaml
│       ├── kserve.yaml
│       ├── monitoring.yaml
│       └── keycloak.yaml
├── mlflow/
│   ├── mlflow-deployment.yaml     # MLflow container, init-containers
│   └── mlflow-service.yaml        # Service definition
├── minio/
│   └── minio-deployment.yaml      # StatefulSet, Service and PVC
├── kserve/
│   ├── kserve-config.yaml         # KServe cluster configs
│   └── samples/
│       ├── sentiment-analysis.yaml # PyTorch deployment
│       ├── house-price.yaml        # Sklearn deployment
│       └── llama3-vllm.yaml        # LLM GPU deployment
├── monitoring/
│   ├── prometheus/
│   │   └── prometheus-values.yaml # Scrape configurations
│   ├── grafana/
│   │   ├── datasources.yaml       # Datasources setup
│   │   └── dashboards/
│   │       └── model-serving.json # JSON Dashboard configuration
│   └── loki/
│       └── loki-values.yaml       # Log aggregator & promtail pipelines
├── keycloak/
│   ├── keycloak-deployment.yaml   # Deployment & Service
│   └── realm-config.json          # SSO Client configurations
├── fastapi-platform-api/
│   ├── app/
│   │   ├── main.py                # REST endpoints
│   │   ├── models.py              # DB Models schema
│   │   ├── database.py            # Engine, session, SQLite fallback
│   │   ├── k8s_client.py          # EKS client logic & KServe API bindings
│   │   └── test_main.py           # Pytest test suite
│   ├── static/
│   │   └── index.html             # Glassmorphic Portal UI HTML/CSS/JS
│   ├── requirements.txt
│   └── Dockerfile
├── scripts/
│   ├── setup.sh                   # Dev environment setup
│   ├── deploy.sh                  # Bootstrap Kubernetes & ArgoCD
│   ├── destroy.sh                 # Tear down EKS & AWS infrastructure
│   ├── backup.sh                  # Platform backup pipeline
│   └── monitor.sh                 # Cluster health assessment
└── README.md                      # General user guide
```

---

## 2. Database Schema Design (PostgreSQL)

The platform metadata is managed via PostgreSQL. Here are the schemas and constraints:

### Workspaces Table (`workspaces`)
Represents namespaces assigned to teams (e.g. `team-a`).
- `id` (INTEGER, Primary Key, Auto-increment)
- `name` (VARCHAR, Unique, Indexed, Not Null) - matches Kubernetes namespace name.
- `quota_cpu` (VARCHAR, Default "4")
- `quota_memory` (VARCHAR, Default "16Gi")
- `quota_gpu` (VARCHAR, Default "1")
- `created_at` (TIMESTAMP, Default UTC Now)

### Models Table (`models`)
Represents models registered in the registry.
- `id` (INTEGER, Primary Key, Auto-increment)
- `name` (VARCHAR, Indexed, Not Null) - e.g., "sentiment-analysis"
- `version` (VARCHAR, Not Null) - e.g., "v1"
- `framework` (VARCHAR, Not Null) - e.g., "pytorch", "sklearn", "vllm"
- `artifact_uri` (VARCHAR, Not Null) - e.g., "s3://registry-bucket/models/sentiment/1/"
- `created_at` (TIMESTAMP, Default UTC Now)

### Deployments Table (`deployments`)
Represents active serving instances on the cluster.
- `id` (INTEGER, Primary Key, Auto-increment)
- `name` (VARCHAR, Indexed, Not Null) - Deployment name.
- `workspace_id` (INTEGER, Foreign Key referencing `workspaces.id`, Not Null)
- `model_id` (INTEGER, Foreign Key referencing `models.id`, Not Null)
- `cpu` (VARCHAR, Default "1")
- `memory` (VARCHAR, Default "2Gi")
- `gpu` (VARCHAR, Default "0")
- `replicas` (INTEGER, Default 1)
- `status` (VARCHAR, Default "Deploying") - Options: `Deploying`, `Ready`, `Failed`
- `endpoint_url` (VARCHAR, Nullable) - HTTP URL of the Knative predictor.
- `created_at` (TIMESTAMP, Default UTC Now)

---

## 3. Platform API Design

### POST `/deploy-model`
Deploys a new model or updates an existing one.
- **Request Body (JSON)**:
  ```json
  {
    "name": "sentiment-classifier-dev",
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
- **Response (JSON - Status 200)**:
  ```json
  {
    "id": 1,
    "name": "sentiment-classifier-dev",
    "workspace": "team-a",
    "model_name": "sentiment-analysis",
    "model_version": "1",
    "framework": "pytorch",
    "cpu": "1",
    "memory": "2Gi",
    "gpu": "0",
    "replicas": 1,
    "status": "Ready",
    "endpoint_url": "http://sentiment-classifier-dev.team-a.ai-platform.enterprise.internal",
    "created_at": "2026-07-13T03:55:00.000Z"
  }
  ```

### POST `/delete-model/{deployment_id}`
Tears down model pods and deletes the KServe custom object.
- **Response (JSON - Status 200)**:
  ```json
  {
    "message": "Successfully deleted model deployment sentiment-classifier-dev"
  }
  ```

### GET `/deployments`
Retrieves status of all deployments on the cluster.
- **Response (JSON - Status 200)**:
  ```json
  [
    {
      "id": 1,
      "name": "sentiment-classifier-dev",
      "workspace": "team-a",
      "model_name": "sentiment-analysis",
      "model_version": "1",
      "framework": "pytorch",
      "cpu": "1",
      "memory": "2Gi",
      "gpu": "0",
      "replicas": 1,
      "status": "Ready",
      "endpoint_url": "http://sentiment-classifier-dev.team-a.ai-platform.enterprise.internal",
      "created_at": "2026-07-13T03:55:00"
    }
  ]
  ```

### GET `/deployments/{deployment_id}/logs`
Streams the logs from the active inference pod.
- **Response (JSON - Status 200)**:
  ```json
  {
    "logs": "[INFO] Starting model serving engine...\n[INFO] Inference engine initialized successfully."
  }
  ```
