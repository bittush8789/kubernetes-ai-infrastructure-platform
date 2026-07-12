import sys
import os

# Add the fastapi-platform-api folder (parent of app) to sys.path
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from fastapi.testclient import TestClient
from app.main import app

client = TestClient(app)

def test_read_models():
    response = client.get("/models")
    assert response.status_code == 200
    assert isinstance(response.json(), list)

def test_read_workspaces():
    response = client.get("/workspaces")
    assert response.status_code == 200
    workspaces = response.json()
    assert len(workspaces) > 0
    names = [w["name"] for w in workspaces]
    assert "team-a" in names

def test_deploy_model_mock():
    # Deploy a mock model
    payload = {
        "name": "test-model-serving",
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
    response = client.post("/deploy-model", json=payload)
    assert response.status_code == 200
    data = response.json()
    assert data["name"] == "test-model-serving"
    assert data["status"] in ["Ready", "Deploying"]
    assert data["endpoint_url"] is not None

def test_read_deployments():
    response = client.get("/deployments")
    assert response.status_code == 200
    deployments = response.json()
    assert len(deployments) > 0

def test_get_metrics():
    response = client.get("/metrics")
    assert response.status_code == 200
    data = response.json()
    assert "cluster_cpu_usage" in data
    assert "qps" in data
