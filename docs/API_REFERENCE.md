# Platform REST API Reference

The Platform API operates on port `8000`. This document details the endpoints, query parameters, request schemas, and responses.

---

## 1. Authentication Header
All endpoints require a valid OIDC bearer token issued by Keycloak:
```http
Authorization: Bearer <token_value>
```

---

## 2. API Endpoints

### Deploy Model (`POST /deploy-model`)
Triggers a new model deployment or updates resource specs on an existing one.

-   **Path**: `/deploy-model`
-   **Method**: `POST`
-   **Request Headers**:
    -   `Content-Type: application/json`
-   **Request Body**:
    ```json
    {
      "name": "sentiment-clf",
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
-   **Response (200 OK)**:
    ```json
    {
      "id": 1,
      "name": "sentiment-clf",
      "workspace": "team-a",
      "model_name": "sentiment-analysis",
      "model_version": "1",
      "framework": "pytorch",
      "cpu": "1",
      "memory": "2Gi",
      "gpu": "0",
      "replicas": 1,
      "status": "Ready",
      "endpoint_url": "http://sentiment-clf.team-a.ai-platform.enterprise.internal",
      "created_at": "2026-07-13T04:00:00.000Z"
    }
    ```

---

### Terminate Model (`POST /delete-model/{deployment_id}`)
Deletes the associated KServe resource from the EKS cluster and removes the database record.

-   **Path**: `/delete-model/{deployment_id}`
-   **Method**: `POST`
-   **Parameters**:
    -   `deployment_id` (integer, path parameter)
-   **Response (200 OK)**:
    ```json
    {
      "message": "Successfully deleted model deployment sentiment-clf"
    }
    ```

---

### List Active Deployments (`GET /deployments`)
Returns status lists of active cluster inference runtimes.

-   **Path**: `/deployments`
-   **Method**: `GET`
-   **Response (200 OK)**:
    ```json
    [
      {
        "id": 1,
        "name": "sentiment-clf",
        "workspace": "team-a",
        "model_name": "sentiment-analysis",
        "model_version": "1",
        "framework": "pytorch",
        "cpu": "1",
        "memory": "2Gi",
        "gpu": "0",
        "replicas": 1,
        "status": "Ready",
        "endpoint_url": "http://sentiment-clf.team-a.ai-platform.enterprise.internal",
        "created_at": "2026-07-13T04:00:00"
      }
    ]
    ```

---

### Read Container Logs (`GET /deployments/{deployment_id}/logs`)
Streams standard output (stdout) from the model's predictor pod.

-   **Path**: `/deployments/{deployment_id}/logs`
-   **Method**: `GET`
-   **Parameters**:
    -   `deployment_id` (integer, path parameter)
-   **Response (200 OK)**:
    ```json
    {
      "logs": "[INFO] Uvicorn running on http://0.0.0.0:8080\n[INFO] Loaded model from S3 path."
    }
    ```

---

### Get Telemetry Metrics (`GET /metrics`)
Scrapes current load statistics from the platform control layer.

-   **Path**: `/metrics`
-   **Method**: `GET`
-   **Response (200 OK)**:
    ```json
    {
      "cluster_cpu_usage": 42.5,
      "cluster_memory_usage": 58.2,
      "active_gpus": 1,
      "total_gpus": 4,
      "average_inference_latency_ms": 32.6,
      "qps": 128.4,
      "error_rate_percentage": 0.02
    }
    ```
