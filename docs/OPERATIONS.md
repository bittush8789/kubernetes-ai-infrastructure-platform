# Platform Operations & Maintenance Guide

This document defines the checklists, procedures, and run intervals for platform maintenance, backups, and upgrades.

---

## 1. Operational Checklists

### Daily Checklists
1.  **Monitor Cluster Resource Capacity**: Check Prometheus alerts for nodes running above 85% CPU or Memory limits.
2.  **Verify Backup Logs**: Ensure the backup archive cron job executed successfully and pushed snapshots to backup locations.
3.  **Inspect ArgoCD Sync Status**: Check for applications marked `OutOfSync` or `Degraded`.
4.  **Audit Logs Review**: Scan Loki logs for high rates of 500 errors in backend API containers or KServe serving logs.

### Weekly Checklists
1.  **Workspaces Quota Review**: Review CPU/RAM consumption per team workspace namespace. Reclaim unused allocated resources.
2.  **Verify Model Registry Storage Limits**: Monitor AWS S3 / MinIO storage capacity. Archive or prune model version checkpoints that are no longer referenced in production.
3.  **Certificate Expiry Auditing**: Confirm cert-manager successfully auto-renewed certificates due within 14 days.

### Monthly Checklists
1.  **IAM Auditing**: Revoke IAM permissions for offboarded engineers. Rotate secrets and access tokens.
2.  **Kubernetes Patch Evaluation**: Check EKS managed node AMI releases. Review pending security patches.
3.  **Simulated Disaster Recovery**: Perform a trial restore of the platform database from a backup file in a temporary namespace to verify data integrity.

---

## 2. Backup & Restore Processes

### Backup Execution
The platform utilizes an automated backup script. It can be triggered manually or via CronJob:
```bash
# Run backup script to dump PostgreSQL database and copy MinIO artifacts
./scripts/backup.sh
```
The output is saved as a compressed archive: `backups/YYYY-MM-DD-HHMMSS.tar.gz`.

### Restore Procedure
In the event of database corruption or data loss:
1.  **Extract the backup archive**:
    ```bash
    tar -xzf backups/YYYY-MM-DD-HHMMSS.tar.gz -C /tmp/restore-platform/
    ```
2.  **Restore PostgreSQL database**:
    Copy the SQL dump file to the database container and run it:
    ```bash
    kubectl cp /tmp/restore-platform/postgres_platform_db.sql ml-platform/postgres-deployment-<pod-id>:/tmp/db.sql
    kubectl exec -n ml-platform postgres-deployment-<pod-id> -- psql -U postgres_user -d platform_db -f /tmp/db.sql
    ```
3.  **Restore SQLite fallback (for local development debugging)**:
    ```bash
    cp /tmp/restore-platform/ai_platform_sqlite.db fastapi-platform-api/ai_platform.db
    ```

---

## 3. Platform Upgrade Process

When upgrading core system components (e.g. updating the FastAPI API server or Keycloak configurations):

1.  **Update Git Configurations**:
    Commit the updated manifest files (e.g. updating container version hash inside [k8s-deployment.yaml](file:///d:/Ai%20infra%20&%20ai%20plateform/Kubernetes%20AI%20Infrastructure%20Platform/fastapi-platform-api/k8s-deployment.yaml)) to Git.
2.  **Trigger ArgoCD Manual Sync** (if auto-sync is off):
    ```bash
    argocd app sync platform-api
    ```
3.  **Monitor Rolling Updates**:
    Kubernetes rolls out pods one by one, verifying the new containers pass health checks before terminating old ones.
    ```bash
    kubectl rollout status deployment/platform-api-deployment -n ml-platform
    ```
