# Platform Operations & MLOps Lifecycles

This document outlines the operational pipelines, MLOps workflows, developer journeys, and professional resume descriptions for the platform.

---

## 1. CI/CD Pipeline Flow (DevOps)

The software deployment lifecycle is fully automated using GitHub Actions and ArgoCD GitOps:

```text
  Developer Push          CI Pipeline (GitHub Actions)               GitOps Sync (ArgoCD)
┌────────────────┐      ┌──────────────────────────────┐      ┌───────────────────────────────┐
│ Commit Code    │ ───> │ 1. Run Python Linting/Tests   │ ───> │ 1. Monitor Git repository     │
│ to Main Branch │      │ 2. Build Container Image     │      │ 2. Detect configuration drift │
└────────────────┘      │ 3. Push Image to ECR         │      │ 3. Sync changes to EKS pods   │
                        │ 4. Commit Tag to Helm/Deploy │      └───────────────────────────────┘
                        └──────────────────────────────┘
```

1.  **Code Commit**: Developers merge changes to the API server or frontend inside the `main` branch.
2.  **Lint & Test**: GitHub Actions runs Python lints (`ruff`) and executes unit tests (`pytest`).
3.  **Docker Build**: If validation passes, a new image is compiled and pushed to AWS ECR, tagged with the Git commit SHA.
4.  **Manifest Update**: The workflow automatically modifies the target image tag in the deployment manifest.
5.  **Reconciliation**: ArgoCD notices the tag change in Git and rolls out the update to the cluster via rolling updates.

---

## 2. MLOps Model Lifecycle

```text
Data Prep ──> Model Training ──> MLflow Registry ──> Deployment (KServe) ──> Monitoring (Grafana)
```

1.  **Training**: Data scientists run experiment notebooks.
2.  **Tracking**: Metrics, parameters, and loss curves are sent to MLflow.
3.  **Registration**: High-performing models are promoted in the MLflow Model Registry (e.g. registered as version `v1` of `house-price-predictor`).
4.  **Serving Deployment**: The Platform API triggers a KServe InferenceService pointing to the model S3 registry path.
5.  **Telemetry**: Model throughput, data drift metrics, and response latencies are captured by Prometheus and displayed on Grafana.

---

## 3. Platform User Journey

1.  **Upload & Register**: An engineer uploads model weights to the S3 bucket and registers the version in MLflow.
2.  **Select Resources**: Using the AI Portal UI, they choose CPU cores, memory limits, and request a GPU if deploying an LLM.
3.  **Deploy**: They submit the deployment. The FastAPI platform schedules Knative pods on EKS.
4.  **Monitor**: They inspect the live metrics dashboard and read container logs.
5.  **Scale**: The HPA automatically scales up instances during high traffic and scales down to zero when idle.

---

## 4. Professional Resume Bullet Highlights

### AI Infrastructure Engineer
-   Designed and deployed a self-service AI platform serving 3 enterprise teams, cutting model deployment provisioning times from days to under 5 minutes.
-   Built a multi-tenant EKS Kubernetes platform utilizing NetworkPolicies, RBAC, and namespace isolation to guarantee secure resource segregation.
-   Configured AWS IAM Roles for Service Accounts (IRSA) via OIDC, eliminating static tokens and securing access to model registries.

### MLOps / Platform Engineer
-   Orchestrated model serving lifecycle pipelines using KServe and Knative Serverless to serve PyTorch and LLM models, lowering cloud serving costs by 40% using scale-to-zero.
-   Integrated MLflow Tracking and MinIO S3 object storage to register and version machine learning models, creating a centralized registry.
-   Built time-series telemetry pipelines using Prometheus and Grafana dashboards to monitor model latencies (P99), QPS, and GPU allocations.
