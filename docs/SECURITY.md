# Platform Security Architecture

This document details the security layers, policies, and authorization flows implemented in the platform.

---

## 1. Network Security (Namespace Isolation)

By default, Kubernetes has a flat network design where any pod can communicate with any other pod in the cluster. This platform enforces **strict namespace isolation** using Kubernetes `NetworkPolicy` objects.

-   **Team Isolation**: Tenant namespaces (`team-a`, `team-b`, `team-c`) have a default-deny ingress policy applied. 
-   **Whitelisted Services**: Ingress is permitted only from:
    1.  The pod's own namespace.
    2.  The `ingress-nginx` ingress controller namespace (for external HTTP routing).
    3.  The `ml-platform` namespace (where the Platform API triggers commands and checks models).
    4.  The `monitoring` namespace (restricting Prometheus metric scraping to port `9080` for KServe workloads).

Refer to [team-isolation.yaml](file:///d:/Ai%20infra%20&%20ai%20plateform/Kubernetes%20AI%20Infrastructure%20Platform/kubernetes/network-policies/team-isolation.yaml) for complete rules.

---

## 2. Authentication & Authorization (Keycloak SSO)

We integrate **Keycloak** as the Identity Provider (IdP) for OAuth2 and OpenID Connect (OIDC) protocols.

-   **Single Sign-On (SSO)**: The AI Portal Web UI and FastAPI endpoints are registered as OIDC clients in the `ai-platform-realm`.
-   **RBAC Groups**: Users are grouped into distinct roles mapping to RBAC:
    -   `admin`: Full access to configure cluster nodes, create namespaces, and manage database migrations.
    -   `ml-engineer`: Can upload model weights, register models in MLflow, and schedule model deployments in team workspaces.
    -   `viewer`: Read-only access to view active deployments, read logs, and trace telemetry dashboards.

---

## 3. Kubernetes Secrets & AWS IRSA

To protect credentials, we avoid distributing static AWS Access Keys in pod specifications.

-   **IAM Roles for Service Accounts (IRSA)**: The EKS cluster utilizes an OpenID Connect (OIDC) provider federation. Pods needing access to the model registry S3 bucket run under a specific ServiceAccount (`mlflow-sa`, `kserve-sa`) annotated with the AWS IAM Role ARN:
    ```yaml
    apiVersion: v1
    kind: ServiceAccount
    metadata:
      name: mlflow-sa
      namespace: ml-platform
      annotations:
        eks.amazonaws.com/role-arn: arn:aws:iam::<ACCOUNT_ID>:role/ai-platform-s3-access-role
    ```
-   **Secrets Encryption**: Secrets at rest inside Kubernetes (such as Keycloak DB passwords or registry access tokens) are encrypted in the etcd database using AWS Key Management Service (KMS) keys configured during EKS provisioning.

---

## 4. In-Transit Encryption (TLS/SSL)

All external traffic entering the cluster is encrypted in transit using TLS certificates.

-   **Cert-Manager Integration**: The NGINX Ingress Controller is integrated with **cert-manager** and Let's Encrypt (configured via ClusterIssuer annotations).
-   **Automatic Renewals**: Certificates for hostnames (e.g. `api.ai-platform.enterprise.internal`) are automatically provisioned, validated, and rotated before expiration.
