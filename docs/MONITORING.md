# Platform Monitoring & Observability Specifications

This document details the configuration for Prometheus, Grafana, Loki, and Alertmanager to manage the platform's health.

---

## 1. Metrics Collection (Prometheus Operator)

Prometheus scrapes metrics from cluster nodes and services at regular intervals (default: `15s`):

-   **Kubernetes Node Metrics**: Collected via `node-exporter` (CPU load, disk IO, memory saturation, network bandwidth).
-   **Kubernetes Pod Metrics**: Collected via `kube-state-metrics` (pod readiness status, container restart counts).
-   **KServe Model Metrics**: Scraped from the sidecar queue proxy at port `9080`:
    -   `kserve_inference_request_duration_seconds_bucket`: Latency histogram.
    -   `kserve_inference_request_duration_seconds_count`: Total query counts.
-   **FastAPI API Metrics**: Scraped via custom `/metrics` Prometheus middleware target.

Scrape configuration rules are detailed in [prometheus-values.yaml](file:///d:/Ai%20infra%20&%20ai%20plateform/Kubernetes%20AI%20Infrastructure%20Platform/monitoring/prometheus/prometheus-values.yaml).

---

## 2. Visualization (Grafana Panels)

Grafana is linked to Prometheus and Loki datasources. The default model serving dashboard displays:

### Panel 1: Throughput (Queries Per Second)
-   **Query**: `sum(rate(kserve_inference_request_duration_seconds_count[5m])) by (inferenceservice)`
-   **Visualization**: Time-series line chart.

### Panel 2: Latency (P99 / P95 / P50)
-   **Query (P99)**: `histogram_quantile(0.99, sum(rate(kserve_inference_request_duration_seconds_bucket[5m])) by (le, inferenceservice)) * 1000`
-   **Visualization**: Time-series area chart in milliseconds.

### Panel 3: Error Rate & Success Percentage
-   **Query**: `sum(rate(kserve_inference_request_duration_seconds_count{status!="200"}[5m])) / sum(rate(kserve_inference_request_duration_seconds_count[5m])) * 100`
-   **Visualization**: Gauge indicator (red thresholds at >2%).

---

## 3. Alertmanager Configurations

Critical system alerts are configured to route notifications to SRE channels (e.g. Slack, PagerDuty):

### Alert: ModelLatencyClimbing (Severity: Warning)
-   **Trigger Condition**: P95 latency exceeds 500ms for more than 5 consecutive minutes.
-   **Expression**: `histogram_quantile(0.95, sum(rate(kserve_inference_request_duration_seconds_bucket[2m])) by (le, inferenceservice)) > 0.5`

### Alert: PodRestartLooping (Severity: Critical)
-   **Trigger Condition**: A model serving or core API container restarts more than 3 times in a 10-minute window.
-   **Expression**: `rate(kube_pod_container_status_restarts_total[10m]) * 600 > 3`

### Alert: GPUOutOfMemory (Severity: Critical)
-   **Trigger Condition**: GPU memory utilization reaches 95% of allocation limits.
-   **Expression**: `sum(container_memory_working_set_bytes{container="vllm-container"}) by (pod) / sum(kube_pod_container_resource_limits{resource="nvidia.com/gpu"}) > 0.95`
