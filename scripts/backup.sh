#!/usr/bin/env bash
# backup.sh - Backup script for MLflow registry, MinIO, and PostgreSQL metadata

set -eo pipefail

BACKUP_DIR="./backups/$(date +%Y-%m-%d-%H%M%S)"
mkdir -p "$BACKUP_DIR"

echo "=========================================================="
echo " Starting Platform Data Backup"
echo " Target Directory: $BACKUP_DIR"
echo "=========================================================="

# 1. Backup PostgreSQL Metadata Database
echo "--> 1. Backing up PostgreSQL Metadata Database..."
if command -v pg_dump &> /dev/null; then
    # Local SQLite fallback check
    if [ -f "fastapi-platform-api/ai_platform.db" ]; then
        cp fastapi-platform-api/ai_platform.db "$BACKUP_DIR/ai_platform_sqlite.db"
        echo "  [✓] Backed up SQLite database."
    fi
    
    # Try Kubernetes Postgres backup
    kubectl exec -n ml-platform deployment/postgres-deployment -- pg_dump -U postgres_user platform_db > "$BACKUP_DIR/postgres_platform_db.sql" 2>/dev/null || echo "  [i] In-cluster PostgreSQL was not running or reachable. Skipping dump."
else
    # Fallback copy
    if [ -f "fastapi-platform-api/ai_platform.db" ]; then
        cp fastapi-platform-api/ai_platform.db "$BACKUP_DIR/ai_platform_sqlite.db"
        echo "  [✓] Backed up local SQLite DB."
    fi
fi

# 2. Backup MinIO Model Storage Buckets
echo "--> 2. Backing up Model Artifacts from MinIO..."
if command -v aws &> /dev/null; then
    # Pull model artifacts from local MinIO console pod
    # Using aws cli or kubectl cp
    kubectl cp ml-platform/minio-0:/data/ "$BACKUP_DIR/minio-artifacts/" 2>/dev/null || echo "  [i] In-cluster MinIO pod unreachable. Skipping artifact file backup."
else
    echo "  [!] AWS CLI not found. Skipping S3 sync backups."
fi

# Compress the backup
tar -czf "${BACKUP_DIR}.tar.gz" "$BACKUP_DIR"
rm -rf "$BACKUP_DIR"

echo "=========================================================="
echo " Backup complete: ${BACKUP_DIR}.tar.gz"
echo "=========================================================="
