import os
import logging
from kubernetes import client, config

logger = logging.getLogger("platform-api")

# Check if we should use mock client for development
MOCK_K8S = os.getenv("MOCK_K8S", "true").lower() == "true"

class K8sClient:
    def __init__(self):
        self.enabled = False
        if not MOCK_K8S:
            try:
                # Try loading in-cluster config first, then kube_config
                try:
                    config.load_incluster_config()
                except config.config_exception.ConfigException:
                    config.load_kube_config()
                self.custom_api = client.CustomObjectsApi()
                self.core_api = client.CoreV1Api()
                self.enabled = True
                logger.info("Kubernetes API client initialized successfully.")
            except Exception as e:
                logger.error(f"Failed to initialize Kubernetes API client: {e}. Falling back to MOCK mode.")
                self.enabled = False
        else:
            logger.info("Initializing Kubernetes client in MOCK mode.")

    def deploy_inference_service(self, name: str, namespace: str, framework: str, storage_uri: str, cpu: str, memory: str, gpu: str):
        if not self.enabled:
            logger.info(f"[MOCK] Deploying InferenceService '{name}' in namespace '{namespace}' (Format: {framework}, URI: {storage_uri})")
            return f"http://{name}.{namespace}.ai-platform.enterprise.internal"

        # Construct the KServe InferenceService CRD payload
        body = {
            "apiVersion": "serving.kserve.io/v1beta1",
            "kind": "InferenceService",
            "metadata": {
                "name": name,
                "namespace": namespace
            },
            "spec": {
                "predictor": {
                    "model": {
                        "modelFormat": {
                            "name": framework
                        },
                        "storageUri": storage_uri,
                        "resources": {
                            "limits": {
                                "cpu": cpu,
                                "memory": memory
                            },
                            "requests": {
                                "cpu": str(max(float(cpu) / 2.0, 0.1)),
                                "memory": str(memory)
                            }
                        }
                    }
                }
            }
        }

        # If GPU is requested, add resources, tolerations, and nodeSelectors
        if gpu and int(gpu) > 0:
            body["spec"]["predictor"]["model"]["resources"]["limits"]["nvidia.com/gpu"] = gpu
            body["spec"]["predictor"]["model"]["resources"]["requests"]["nvidia.com/gpu"] = gpu
            body["spec"]["predictor"]["model"]["tolerations"] = [
                {
                    "key": "nvidia.com/gpu",
                    "operator": "Equal",
                    "value": "true",
                    "effect": "NoSchedule"
                }
            ]
            body["spec"]["predictor"]["model"]["nodeSelector"] = {
                "workload-type": "gpu"
            }

        try:
            self.custom_api.create_namespaced_custom_object(
                group="serving.kserve.io",
                version="v1beta1",
                namespace=namespace,
                plural="inferenceservices",
                body=body
            )
            logger.info(f"Successfully created InferenceService '{name}' in namespace '{namespace}'")
            return f"http://{name}.{namespace}.ai-platform.enterprise.internal"
        except Exception as e:
            logger.error(f"Error deploying InferenceService: {e}")
            raise e

    def delete_inference_service(self, name: str, namespace: str):
        if not self.enabled:
            logger.info(f"[MOCK] Deleting InferenceService '{name}' in namespace '{namespace}'")
            return True

        try:
            self.custom_api.delete_namespaced_custom_object(
                group="serving.kserve.io",
                version="v1beta1",
                namespace=namespace,
                name=name,
                plural="inferenceservices"
            )
            logger.info(f"Successfully deleted InferenceService '{name}' in namespace '{namespace}'")
            return True
        except Exception as e:
            logger.error(f"Error deleting InferenceService: {e}")
            raise e

    def get_deployment_status(self, name: str, namespace: str):
        if not self.enabled:
            return "Ready", f"http://{name}.{namespace}.ai-platform.enterprise.internal"

        try:
            isvc = self.custom_api.get_namespaced_custom_object(
                group="serving.kserve.io",
                version="v1beta1",
                namespace=namespace,
                name=name,
                plural="inferenceservices"
            )
            
            # KServe populates status fields once reconciled
            status = isvc.get("status", {})
            conditions = status.get("conditions", [])
            
            is_ready = False
            for cond in conditions:
                if cond.get("type") == "Ready" and cond.get("status") == "True":
                    is_ready = True
                    break
            
            endpoint_url = status.get("url", f"http://{name}.{namespace}.ai-platform.enterprise.internal")
            status_text = "Ready" if is_ready else "Deploying"
            
            return status_text, endpoint_url
        except Exception as e:
            logger.error(f"Error checking status for '{name}': {e}")
            return "Failed", None

    def get_pod_logs(self, namespace: str, deployment_name: str, tail_lines: int = 100):
        if not self.enabled:
            return f"[MOCK LOGS] Log dump for {deployment_name} in {namespace}:\n[INFO] Inference engine initialized successfully.\n[INFO] Serving Model on port 8080...\n[INFO] 127.0.0.1 - - [13/Jul/2026 03:55:00] \"POST /v1/models/{deployment_name}:predict HTTP/1.1\" 200 OK"

        try:
            # Find the pods associated with this deployment/predictor
            pods = self.core_api.list_namespaced_pod(
                namespace=namespace,
                label_selector=f"serving.kserve.io/inferenceservice={deployment_name}"
            )
            
            if not pods.items:
                return "No pods found for this deployment."
                
            pod_name = pods.items[0].metadata.name
            logs = self.core_api.read_namespaced_pod_log(
                name=pod_name,
                namespace=namespace,
                tail_lines=tail_lines
            )
            return logs
        except Exception as e:
            logger.error(f"Error reading pod logs: {e}")
            return f"Error retrieving logs: {e}"

k8s_client = K8sClient()
