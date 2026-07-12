# Platform Architecture Specifications

This document defines the roles, best practices, business value, and comparative alternatives for every component in the Enterprise Kubernetes AI Infrastructure Platform.

---

## 1. Cloud Infrastructure Layer

### AWS (Amazon Web Services)
- **What is it?** A secure, cloud hosting environment.
- **Business Problem**: On-premise infrastructure requires significant capital expense (CapEx), lacks scaling speed, and requires dedicated hardware teams. AWS enables operational expense models (OpEx) with near-instant scalability.
- **Real-World Use Cases**: Netflix, Airbnb, and Expedia run core workloads on AWS.
- **Architecture Role**: Provides hosting for EKS clusters, block devices, OIDC federation, and model bucket storage.
- **Alternatives**: Google Cloud Platform (GCP), Microsoft Azure.
- **Best Practices**: Use Multi-AZ deployments, enable AWS Organizations with strict IAM permissions, and apply AWS Cost Explorer alerts.

### AWS VPC (Virtual Private Cloud)
- **What is it?** A logically isolated virtual network.
- **Business Problem**: Exposing cluster databases or internal model endpoints to the public internet presents high security risks. VPC secures internal assets.
- **Real-World Use Cases**: Financial applications hosting transaction nodes in private subnets.
- **Architecture Role**: Segregates public-facing resources (ALB/Ingress) from private EKS worker nodes and PostgreSQL databases.
- **Alternatives**: VPCs in other clouds, on-premise VLANs.
- **Best Practices**: Keep subnets split strictly between Public (Ingress and NAT) and Private (App Pods, Node pools). Use separate route tables.

### AWS IAM (Identity and Access Management)
- **What is it?** Authentication and authorization control service.
- **Business Problem**: Distributing long-lived AWS Access Keys to Kubernetes pods introduces credential leakage risks.
- **Real-World Use Cases**: Large enterprises mapping application accounts dynamically to prevent static token use.
- **Architecture Role**: Maps AWS permissions to EKS ServiceAccounts using OpenID Connect (IRSA).
- **Alternatives**: HashiCorp Vault AWS secrets engine.
- **Best Practices**: Enforce Least Privilege. Never issue admin access to application roles. Use IAM Roles for Service Accounts (IRSA) exclusively.

### AWS EKS (Elastic Kubernetes Service)
- **What is it?** Managed Kubernetes control plane service.
- **Business Problem**: Bootstrapping, scaling, and backing up a Kubernetes control plane (etcd, scheduler, API server) is complex and error-prone.
- **Real-World Use Cases**: Adidas, Intel, and GoDaddy deploy containerized applications on EKS.
- **Architecture Role**: Manages the life cycle of worker nodes, schedules pods, and handles cluster administration.
- **Alternatives**: Self-managed Kubernetes (kubeadm), Red Hat OpenShift.
- **Best Practices**: Enable control plane logging, use EKS Managed Node Groups, and use Private Endpoint access for the Kubernetes API.

---

## 2. Kubernetes Layer

### Namespaces
- **What is it?** Logical partition within a single cluster.
- **Business Problem**: Running separate teams on dedicated clusters leads to resource fragmentation, high costs, and operational overhead.
- **Real-World Use Cases**: Multi-tenant developer clusters hosting different microservices in dedicated developer spaces.
- **Architecture Role**: Partitions the cluster to isolate tenant teams (`team-a`, `team-b`) and core platform services (`ml-platform`, `kserve`, `monitoring`).
- **Alternatives**: Separate Kubernetes clusters per team (expensive).
- **Best Practices**: Always set ResourceQuotas and LimitRanges on every team namespace to prevent resource exhaustion.

### Network Policies
- **What is it?** IP-table based firewalls for pod-to-pod network traffic.
- **Business Problem**: By default, pods in Kubernetes can communicate with any other pod across any namespace. This violates security compliance.
- **Real-World Use Cases**: Payment processing pods blocked from communicating with non-PCI compliant logging nodes.
- **Architecture Role**: Enforces network-level isolation between tenant teams (e.g. blocking team-a from pinging team-b).
- **Alternatives**: Service Mesh authorization policies (e.g., Istio AuthorizationPolicy).
- **Best Practices**: Enforce a default-deny ingress policy and explicitly whitelist ingress routes (like Prometheus scraping).

### HPA (Horizontal Pod Autoscaler)
- **What is it?** Dynamic pod scaling controller.
- **Business Problem**: Models experience variable query traffic (QPS). Oversizing replica sets leads to high idle costs; undersizing leads to downtime during traffic spikes.
- **Real-World Use Cases**: E-commerce platforms scaling checkout API endpoints during promotional sales.
- **Architecture Role**: Scales inference service pods dynamically based on CPU, Memory, or request concurrency metrics.
- **Alternatives**: KEDA (Kubernetes Event-driven Autoscaling).
- **Best Practices**: Define fallback scaling boundaries (min/max replicas) and use custom metrics (like Knative concurrency) for faster response times.

---

## 3. Observability Layer

### Prometheus & Grafana
- **What is it?** Time-series metrics collection system and dashboard visualizer.
- **Business Problem**: Black-box microservices fail without alerting developers about high CPU, memory leaks, or climbing latency.
- **Real-World Use Cases**: Site Reliability Engineering (SRE) centers tracking platform SLOs and SLA curves.
- **Architecture Role**: Scraping model latency, throughput, and error rates from KServe and EKS cluster nodes.
- **Alternatives**: Datadog, Dynatrace, New Relic.
- **Best Practices**: Apply remote storage configurations for long-term retention. Implement strict Alertmanager routing rules to prevent alerting fatigue.

### Loki & Promtail
- **What is it?** Log aggregation and shipping system.
- **Business Problem**: Searching logs across distributed microservices by running `kubectl logs` on individual pods is slow and limits historical tracking.
- **Real-World Use Cases**: Compliance auditing checking application audit trails after a security incident.
- **Architecture Role**: Scrapes container log directories and indexes labels, enabling real-time log querying via Grafana.
- **Alternatives**: Elasticsearch-Logstash-Kibana (ELK/EFK) stack.
- **Best Practices**: Configure log retention limits to save disk space, and format log outputs in JSON for easy parsing.
