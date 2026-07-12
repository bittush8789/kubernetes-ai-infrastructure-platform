from sqlalchemy import Column, Integer, String, Float, ForeignKey, DateTime
from sqlalchemy.orm import relationship
import datetime
from .database import Base

class Workspace(Base):
    __tablename__ = "workspaces"

    id = Column(Integer, primary_key=True, index=True)
    name = Column(String, unique=True, index=True) # team-a, team-b, team-c
    quota_cpu = Column(String, default="4")
    quota_memory = Column(String, default="16Gi")
    quota_gpu = Column(String, default="1")
    created_at = Column(DateTime, default=datetime.datetime.utcnow)

    deployments = relationship("Deployment", back_populates="workspace")

class Model(Base):
    __tablename__ = "models"

    id = Column(Integer, primary_key=True, index=True)
    name = Column(String, index=True) # sentiment-analysis
    version = Column(String) # v1
    framework = Column(String) # pytorch, sklearn, vllm
    artifact_uri = Column(String) # s3://bucket/...
    created_at = Column(DateTime, default=datetime.datetime.utcnow)

class Deployment(Base):
    __tablename__ = "deployments"

    id = Column(Integer, primary_key=True, index=True)
    name = Column(String, index=True) # sentiment-analysis-dev
    workspace_id = Column(Integer, ForeignKey("workspaces.id"))
    model_id = Column(Integer, ForeignKey("models.id"))
    cpu = Column(String, default="1")
    memory = Column(String, default="2Gi")
    gpu = Column(String, default="0")
    replicas = Column(Integer, default=1)
    status = Column(String, default="Deploying") # Deploying, Running, Failed
    endpoint_url = Column(String, nullable=True)
    created_at = Column(DateTime, default=datetime.datetime.utcnow)

    workspace = relationship("Workspace", back_populates="deployments")
    model = relationship("Model")
class AuditLog(Base):
    __tablename__ = "audit_logs"

    id = Column(Integer, primary_key=True, index=True)
    user = Column(String, index=True)
    action = Column(String)
    details = Column(String)
    timestamp = Column(DateTime, default=datetime.datetime.utcnow)
