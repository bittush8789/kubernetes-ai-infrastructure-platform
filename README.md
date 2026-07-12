# Enterprise Kubernetes AI Infrastructure Platform

[![Build Status](https://img.shields.io/badge/build-passing-brightgreen.svg)](#)
[![License](https://img.shields.io/badge/license-MIT-blue.svg)](#)
[![Kubernetes](https://img.shields.io/badge/kubernetes-v1.28%2B-blue.svg?logo=kubernetes)](#)
[![Terraform](https://img.shields.io/badge/terraform-v1.5%2B-purple.svg?logo=terraform)](#)
[![AWS](https://img.shields.io/badge/AWS-EKS-orange.svg?logo=amazon-aws)](#)
[![Python](https://img.shields.io/badge/python-3.10%2B-blue.svg?logo=python)](#)
[![Docker](https://img.shields.io/badge/docker-ready-blue.svg?logo=docker)](#)

A production-grade, self-service AI Model Deployment and Inference Serving platform built on Kubernetes. The platform resembles AWS SageMaker, Vertex AI, Databricks Model Serving, and internal OpenAI platforms.

---

## 📖 Complete Documentation Index

To explore detailed engineering configurations, designs, and runbooks:
1.  **High-Level Design**: Learn about architecture topologies and component layouts in [docs/HLD.md](file:///d:/Ai%20infra%20&%20ai%20plateform/Kubernetes%20AI%20Infrastructure%20Platform/docs/HLD.md).
2.  **Low-Level Design**: Examine directory trees, API definitions, and DB schemas in [docs/LLD.md](file:///d:/Ai%20infra%20&%20ai%20plateform/Kubernetes%20AI%20Infrastructure%20Platform/docs/LLD.md).
3.  **Detailed Architecture Specs**: Learn the role, alternatives, and best practices of each tool in [docs/ARCHITECTURE.md](file:///d:/Ai%20infra%20&%20ai%20plateform/Kubernetes%20AI%20Infrastructure%20Platform/docs/ARCHITECTURE.md).
4.  **Local Installation Guide**: Set up virtual environments, database seeding, and tests locally in [docs/INSTALLATION.md](file:///d:/Ai%20infra%20&%20ai%20plateform/Kubernetes%20AI%20Infrastructure%20Platform/docs/INSTALLATION.md).
5.  **Cloud & GitOps Deployment**: Configure AWS, build Docker containers, and sync with ArgoCD in [docs/DEPLOYMENT.md](file:///d:/Ai%20infra%20&%20ai%20plateform/Kubernetes%20AI%20Infrastructure%20Platform/docs/DEPLOYMENT.md).
6.  **Troubleshooting Playbooks**: Diagnose common EKS, Terraform, and KServe failures in [docs/TROUBLESHOOTING.md](file:///d:/Ai%20infra%20&%20ai%20plateform/Kubernetes%20AI%20Infrastructure%20Platform/docs/TROUBLESHOOTING.md).
7.  **Security Architecture Specs**: Understand Network Policies, Keycloak SSO, and AWS IRSA in [docs/SECURITY.md](file:///d:/Ai%20infra%20&%20ai%20plateform/Kubernetes%20AI%20Infrastructure%20Platform/docs/SECURITY.md).
8.  **Platform Lifecycles**: Learn about DevOps CI/CD pipelines, MLOps, and developer journeys in [docs/OPERATIONS.md](file:///d:/Ai%20infra%20&%20ai%20plateform/Kubernetes%20AI%20Infrastructure%20Platform/docs/OPERATIONS.md).
9.  **Operator Runbook**: onboarding teams, port-forwarding to metrics, and node pool scaling in [docs/RUNBOOK.md](file:///d:/Ai%20infra%20&%20ai%20plateform/Kubernetes%20AI%20Infrastructure%20Platform/docs/RUNBOOK.md).

---

## 🖥️ System Architecture

```text
Users / ML Engineers
       │
       ▼
   AI Portal  (Web UI Dashboard)
       │
       ▼
 FastAPI Platform API ─── Authentication (Keycloak OIDC)
       │
       ├── [Deploy] ──> KServe Inference Services (Knative & Istio)
       ├── [Register] ─> MLflow Registry (MinIO / S3 Store)
       └── [Monitor] ──> Prometheus & Loki Logs
```

---

## ⚡ Core Features

-   **Self-Service Serving Portal**: A premium, glassmorphic dark-theme Web UI featuring latency graphs, live logs streaming, resource requests, and termination triggers.
-   **Serverless Inference Serving**: Implemented via KServe/Knative, enabling scale-to-zero, autoscaling, and GPU acceleration.
-   **Multi-Tenancy Workspace Isolation**: ResourceQuotas, limits, and ingress-filtering Network Policies separating team workspaces.
-   **Continuous GitOps Delivery**: Automated image packaging and deployment updates managed by GitHub Actions and ArgoCD.
-   **Full-Stack Observability**: Custom Grafana Dashboards tracking average response time (ms), total QPS, Success Rate, and GPU capacity.

---

## 🛠️ Technology Stack

-   **Cloud Infrastructure**: AWS EKS, AWS VPC, AWS IAM, AWS S3, AWS EBS.
-   **Kubernetes Stack**: Helm, NGINX Ingress Controller, Cert-manager, HPA, RBAC, NetworkPolicies.
-   **GitOps**: GitHub, GitHub Actions, ArgoCD (App-of-Apps).
-   **MLOps Core**: MLflow Tracking Server, MinIO Object Storage, KServe.
-   **Observability**: Prometheus Operator, Grafana, Loki, Promtail.
-   **Database & SSO**: Keycloak, PostgreSQL.
-   **Platform API**: FastAPI, SQLAlchemy, SQLite (local development).

---

## 🚀 Quick Start (Local Setup)

Run the platform API and Portal UI locally using the built-in mock configurations:

1.  **Clone and initialize**:
    ```bash
    git clone https://github.com/enterprise/kubernetes-ai-infrastructure-platform.git
    cd kubernetes-ai-infrastructure-platform
    ```
2.  **Run setup script**:
    ```bash
    # On Windows:
    powershell -ExecutionPolicy Bypass -File scripts/setup.sh
    # On Linux/macOS:
    ./scripts/setup.sh
    ```
3.  **Start FastAPI Server**:
    ```bash
    cd fastapi-platform-api
    python -m uvicorn app.main:app --reload
    ```
4.  **Access the Dashboard**: Open your browser at [http://localhost:8000/portal/](http://localhost:8000/portal/)

---

## 🗺️ Project Roadmap & Enhancements

### Phase 1: Core Serving & GitOps (Completed)
-   Terraform cloud provisioning modules.
-   ArgoCD GitOps deployment manifests.
-   FastAPI core endpoints and React/Vite portal UI.

### Phase 2: Security & Governance (In Progress)
-   Integrate keycloak SSO authorization into the Portal frontend.
-   Configure AWS KMS secret envelope encryption for EKS etcd databases.

### Phase 3: Advanced MLOps & LLM Tuning (Roadmap)
-   Deploy KServe explainability endpoints using Alibi Explainer engines.
-   Implement HuggingFace Hub pipelines for automatic model syncing and weights loading.
-   Add custom HPA metric scaling based on Kafka message queue depths.

---

## 🤝 Contributing
Contributions are welcome! Please submit a Pull Request or open an issue on GitHub to discuss design proposals.

## 📄 License
This project is licensed under the MIT License - see the LICENSE file for details.
