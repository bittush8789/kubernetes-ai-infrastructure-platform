import os
from fastapi import FastAPI, Depends, HTTPException, status
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from sqlalchemy.orm import Session
from typing import List, Optional
from pydantic import BaseModel
import datetime

from app.database import engine, get_db, Base
from app.models import Workspace, Model, Deployment, AuditLog
from app.k8s_client import k8s_client

# Create DB tables
Base.metadata.create_all(bind=engine)

app = FastAPI(
    title="Enterprise AI Platform API",
    description="SageMaker/Vertex style self-service deployment and tracking API on Kubernetes",
    version="1.0.0"
)

# Serve the static UI files from the 'static' directory at /portal/
static_dir = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "static")
if os.path.exists(static_dir):
    app.mount("/portal", StaticFiles(directory=static_dir, html=True), name="static")


# CORS configuration for Portal frontend integration
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Seed workspaces if empty
db = next(get_db())
if db.query(Workspace).count() == 0:
    for team_name in ["team-a", "team-b", "team-c"]:
        db.add(Workspace(name=team_name, quota_cpu="8", quota_memory="32Gi", quota_gpu="2"))
    # Seed a default model
    model = Model(name="sentiment-analysis", version="1", framework="pytorch", artifact_uri="s3://k8s-ai-platform-model-registry-bucket/models/sentiment-analysis/1/")
    db.add(model)
    db.commit()

# Pydantic Schemas
class DeployModelRequest(BaseModel):
    name: str
    workspace: str
    model_name: str
    model_version: str
    framework: str
    artifact_uri: str
    cpu: str = "1"
    memory: str = "2Gi"
    gpu: str = "0"
    replicas: int = 1

class DeploymentResponse(BaseModel):
    id: int
    name: str
    workspace: str
    model_name: str
    model_version: str
    framework: str
    cpu: str
    memory: str
    gpu: str
    replicas: int
    status: str
    endpoint_url: Optional[str]
    created_at: datetime.datetime

    class Config:
        from_attributes = True

# Authentication placeholder mapping to Keycloak
def get_current_user(token: str = "default-token"):
    # Real-world Keycloak token decoding would happen here
    # E.g., verifying against: auth.ai-platform.enterprise.internal/realms/ai-platform-realm
    return "ml-engineer@enterprise.com"

@app.post("/deploy-model", response_model=DeploymentResponse)
def deploy_model(req: DeployModelRequest, db: Session = Depends(get_db), user: str = Depends(get_current_user)):
    # 1. Fetch/Create workspace
    workspace = db.query(Workspace).filter(Workspace.name == req.workspace).first()
    if not workspace:
        raise HTTPException(status_code=404, detail=f"Workspace {req.workspace} not found")

    # 2. Check and register model if it doesn't exist
    model = db.query(Model).filter(Model.name == req.model_name, Model.version == req.model_version).first()
    if not model:
        model = Model(
            name=req.model_name,
            version=req.model_version,
            framework=req.framework,
            artifact_uri=req.artifact_uri
        )
        db.add(model)
        db.commit()
        db.refresh(model)

    # 3. Create deployment db entry
    deployment = Deployment(
        name=req.name,
        workspace_id=workspace.id,
        model_id=model.id,
        cpu=req.cpu,
        memory=req.memory,
        gpu=req.gpu,
        replicas=req.replicas,
        status="Deploying"
    )
    db.add(deployment)
    db.commit()
    db.refresh(deployment)

    # 4. Trigger actual Kubernetes KServe deployment
    try:
        endpoint_url = k8s_client.deploy_inference_service(
            name=req.name,
            namespace=req.workspace,
            framework=req.framework,
            storage_uri=req.artifact_uri,
            cpu=req.cpu,
            memory=req.memory,
            gpu=req.gpu
        )
        deployment.endpoint_url = endpoint_url
        deployment.status = "Ready" # Quick update; real status updates check cluster asynchronously
        db.commit()
    except Exception as e:
        deployment.status = "Failed"
        db.commit()
        raise HTTPException(status_code=500, detail=f"Deployment failed on Kubernetes cluster: {e}")

    # Audit Log
    db.add(AuditLog(user=user, action="DEPLOY_MODEL", details=f"Deployed {req.name} in namespace {req.workspace}"))
    db.commit()

    return DeploymentResponse(
        id=deployment.id,
        name=deployment.name,
        workspace=workspace.name,
        model_name=model.name,
        model_version=model.version,
        framework=model.framework,
        cpu=deployment.cpu,
        memory=deployment.memory,
        gpu=deployment.gpu,
        replicas=deployment.replicas,
        status=deployment.status,
        endpoint_url=deployment.endpoint_url,
        created_at=deployment.created_at
    )

@app.post("/delete-model/{deployment_id}")
def delete_model(deployment_id: int, db: Session = Depends(get_db), user: str = Depends(get_current_user)):
    deployment = db.query(Deployment).filter(Deployment.id == deployment_id).first()
    if not deployment:
        raise HTTPException(status_code=404, detail="Deployment record not found")

    workspace = db.query(Workspace).filter(Workspace.id == deployment.workspace_id).first()

    # Trigger Kubernetes KServe removal
    try:
        k8s_client.delete_inference_service(name=deployment.name, namespace=workspace.name)
        db.delete(deployment)
        db.commit()
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to delete resource on cluster: {e}")

    db.add(AuditLog(user=user, action="DELETE_MODEL", details=f"Deleted deployment {deployment.name} from {workspace.name}"))
    db.commit()

    return {"message": f"Successfully deleted model deployment {deployment.name}"}

@app.get("/models")
def list_models(db: Session = Depends(get_db)):
    return db.query(Model).all()

@app.get("/deployments", response_model=List[DeploymentResponse])
def list_deployments(db: Session = Depends(get_db)):
    deployments = db.query(Deployment).all()
    results = []
    for d in deployments:
        # Check kubernetes to update current reconciling status
        workspace = db.query(Workspace).filter(Workspace.id == d.workspace_id).first()
        status_text, endpoint = k8s_client.get_deployment_status(d.name, workspace.name)
        
        # update state
        d.status = status_text
        d.endpoint_url = endpoint
        db.commit()

        model = db.query(Model).filter(Model.id == d.model_id).first()
        results.append(DeploymentResponse(
            id=d.id,
            name=d.name,
            workspace=workspace.name,
            model_name=model.name,
            model_version=model.version,
            framework=model.framework,
            cpu=d.cpu,
            memory=d.memory,
            gpu=d.gpu,
            replicas=d.replicas,
            status=d.status,
            endpoint_url=d.endpoint_url,
            created_at=d.created_at
        ))
    return results

@app.get("/deployments/{deployment_id}/logs")
def get_deployment_logs(deployment_id: int, db: Session = Depends(get_db)):
    deployment = db.query(Deployment).filter(Deployment.id == deployment_id).first()
    if not deployment:
        raise HTTPException(status_code=404, detail="Deployment not found")
    workspace = db.query(Workspace).filter(Workspace.id == deployment.workspace_id).first()
    
    logs = k8s_client.get_pod_logs(workspace.name, deployment.name)
    return {"logs": logs}

@app.get("/workspaces")
def list_workspaces(db: Session = Depends(get_db)):
    return db.query(Workspace).all()

@app.get("/metrics")
def get_metrics():
    # Exposing mock live telemetry metrics representing cluster status
    return {
        "cluster_cpu_usage": 42.5,  # percentage
        "cluster_memory_usage": 58.2, # percentage
        "active_gpus": 1,
        "total_gpus": 4,
        "average_inference_latency_ms": 32.6,
        "qps": 128.4,
        "error_rate_percentage": 0.02
    }
