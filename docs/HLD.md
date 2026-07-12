# High-Level Design (HLD)

This document provides the high-level design of the Enterprise Kubernetes AI Infrastructure Platform.

---

## 1. System Diagrams

### High-Level Architecture (HLD)

```mermaid
graph TD
    User([Platform Users]) -->|HTTP/HTTPS| Ingress[NGINX Ingress Controller]
    
    subgraph K8s [Kubernetes Cluster]
        Ingress -->|Route: /portal| UI[AI Portal React Frontend]
        Ingress -->|Route: /api| API[FastAPI Platform API]
        Ingress -->|Route: /mlflow| MLflow[MLflow Tracking Server]
        Ingress -->|Route: /console| MinIO[MinIO Console]
        Ingress -->|Route: /grafana| Grafana[Grafana Dashboard]
        
        API -->|Deploy Models| KServe[KServe Controller]
        API -->|Audit Logs / State| Postgres[(PostgreSQL DB)]
        
        KServe -->|Deploy Model Pods| Knative[Knative Serving]
        Knative -->|Fetch Artifacts| MinIO
        MLflow -->|Metadata Store| Postgres
        MLflow -->|Artifact Store| MinIO
        
        Prometheus[Prometheus Operator] -->|Scrape Metrics| Knative
        Prometheus -->|Scrape Metrics| API
        Prometheus -->|Scrape Metrics| Postgres
        
        Loki[Loki Log Aggregator] -->|Aggregate Logs| Promtail[Promtail Agent]
    end
    
    MinIO -->|S3 Sync / Cloud storage| S3[(AWS S3 Bucket)]
    Postgres -->|RDS Failover| AWS_RDS[(AWS RDS Postgres)]
```

### Component Diagram

```mermaid
classDiagram
    class UserInterface {
        +DeployModelForm()
        +ViewActiveDeployments()
        +TelemetryCharts()
    }
    class FastAPI_API {
        +deploy_model()
        +delete_model()
        +list_deployments()
        +get_metrics()
    }
    class K8sClient {
        +deploy_inference_service()
        +delete_inference_service()
        +get_pod_logs()
    }
    class KServe_InferenceService {
        +PredictorContainer
        +Autoscaler
        +StorageInitializer
    }
    class MLflow_Registry {
        +RegisterModel()
        +TrackExperiments()
        +ArtifactStorage
    }
    class Database {
        +WorkspacesTable
        +DeploymentsTable
        +AuditLogTable
    }

    UserInterface --> FastAPI_API : HTTP Requests
    FastAPI_API --> K8sClient : Python SDK Calls
    FastAPI_API --> Database : ORM Queries
    K8sClient --> KServe_InferenceService : Apply CRD YAML
    KServe_InferenceService --> MLflow_Registry : Load weights from registry
```

### Data Flow Diagram (Model Deployment & Serving)

```mermaid
sequenceDiagram
    autonumber
    actor User as ML Engineer
    participant Portal as AI Portal UI
    participant API as FastAPI Platform API
    participant DB as PostgreSQL DB
    participant K8s as Kubernetes API
    participant KS as KServe Controller
    participant Registry as MLflow / S3 Registry
    participant Model as Inference Pod (vLLM)

    User->>Portal: Configures model & clicks Deploy
    Portal->>API: POST /deploy-model (JSON payload)
    API->>DB: Write deployment record (Status: "Deploying")
    API->>K8s: Submit InferenceService Custom Resource (CRD)
    K8s->>KS: Reconcile InferenceService CRD
    KS->>Registry: Fetch model weights (S3/MinIO URI)
    Registry-->>KS: Download weights (Storage Initializer)
    KS->>Model: Spin up container with weights attached
    Model-->>K8s: Pod running health checks pass
    K8s->>API: Status: Ready, Endpoint URL generated
    API->>DB: Update deployment record (Status: "Ready")
    API-->>Portal: Return deployment state & Endpoint
    Portal-->>User: Display deployment online
```

### Deployment Diagram (AWS EKS Topology)

```mermaid
graph TD
    subgraph AWS [AWS Cloud]
        subgraph VPC [VPC - 10.0.0.0/16]
            subgraph PublicSubnets [Public Subnets]
                IGW[Internet Gateway]
                ALB[Application Load Balancer]
            end
            subgraph PrivateSubnets [Private Subnets]
                NAT[NAT Gateway]
                subgraph EKS [AWS EKS Cluster]
                    subgraph CPNode [EKS Control Plane]
                        K8sAPI[Kubernetes API Server]
                    end
                    subgraph CPUPool [CPU Node Group]
                        PodAPI[Platform API Pods]
                        PodML[MLflow Pods]
                        PodMon[Prometheus/Grafana Pods]
                    end
                    subgraph GPUPool [GPU Node Group]
                        PodLLM[vLLM Inference Pods]
                    end
                end
            end
            subgraph Storage [Storage Layer]
                S3[(AWS S3 Bucket)]
                EBS[(EBS PersistentVolumes)]
            end
        end
    end
    
    ALB --> PodAPI
    ALB --> PodML
    PodAPI --> K8sAPI
    PodLLM --> GPUPool
    PodLLM --> S3
    PodML --> S3
```

---

## 2. Platform Component Business Analysis

| Tool | Business Problem Solved |
|:---|:---|
| **Terraform** | Automates multi-environment AWS infrastructure deployment, eliminating drift and configuration errors. |
| **AWS VPC** | Secures network infrastructure by isolating internal pods from public interfaces. |
| **AWS IAM / IRSA** | Prevents credential leaks by mapping EKS ServiceAccounts directly to AWS IAM roles. |
| **AWS EKS** | Replaces complex Kubernetes control plane operations with a managed, SLA-backed container service. |
| **AWS S3** | Supplies high-durability, cost-efficient storage for terabyte-scale ML models and checkpoints. |
| **AWS EBS** | Provides dynamic, high-IOPS block storage for databases and persistent tools. |
| **Kubernetes** | Handles container orchestration, high-availability, rolling rollouts, and scheduling. |
| **Pods / Deployments** | Packs software applications into immutable, isolated runtimes. |
| **Services & Ingress** | Exposes cluster pods internally and externally via load-balancing and domain-based routing. |
| **HPA** | Scales serving resources dynamically during spikes to protect availability and reduce idle costs. |
| **Namespaces** | Partitions the cluster into logic environments for multi-tenancy workspace isolation. |
| **RBAC** | Restricts human and machine access based on least-privilege principles. |
| **Network Policies** | Prevents lateral network movement between tenant workloads (Security Isolation). |
| **GitHub Actions** | Drives CI pipelines (automated linting, image building, testing). |
| **ArgoCD** | Automates GitOps, syncing resource manifests directly from Git to prevent manual drift. |
| **MLflow** | Unifies experiment runs and coordinates model promotions from dev to production. |
| **KServe** | Automates serverless inference, scaling-to-zero, GPU allocations, and metrics exposure. |
| **MinIO** | Implements local S3-compatible endpoints for development, testing, and latency reduction. |
| **FastAPI** | Serves as the self-service abstraction API layer for platform users. |
| **PostgreSQL** | Stores platform state metadata, audit history, and user workspace definitions. |
| **Prometheus** | Performs scraping and storage of time-series metric data. |
| **Grafana** | Visualizes cluster resource utilization and model performance metrics. |
| **Loki & Promtail** | Aggregates and searches cluster logs without expensive index overhead. |
| **Keycloak** | Implements standard OAuth2/OIDC Single-Sign-On (SSO) and client authentication. |

---

## 3. Alternative Solutions Analysis

### MLflow Alternatives
- **Weights & Biases (W&B)**: Enterprise SaaS with rich visualization. Chosen MLflow because it is fully open-source, easily self-hosted in-cluster, and supports direct S3-compatible backend storage without third-party cloud lock-in.
- **Comet ML**: Commercial option focusing on team sharing. Not used due to pricing models and lack of deep integration with Knative/KServe ecosystems.

### KServe Alternatives
- **Seldon Core**: Advanced inference framework. Chosen KServe because it is the CNCF standard, has native support for Knative Serverless scale-to-zero, and aligns closely with Kubeflow.
- **Triton Server**: High-performance engine. Triton is actually used *inside* KServe as a predictor runtime rather than an alternative.

### Prometheus Alternatives
- **Datadog**: High-cost commercial agent. Not used because Prometheus is standard on Kubernetes, free to scale, and integrates out of the box with EKS metrics collectors.
