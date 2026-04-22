# Velero Rules

## Current configuration

- **Schedules:** `daily-full` (2am → MinIO BSL), `daily-b2` (4am → Backblaze B2 BSL)
- **FSB:** `defaultVolumesToFsBackup: true` on both schedules
- **Excluded from both:** `minio` namespace (see below)
- **Resource policy:** `velero-skip-smb-policy` — skips `smb` StorageClass volumes (NAS shares)
- **Node-agents:** deployed as DaemonSet with DMZ toleration; healthy on all 6 nodes
- **BackupRepository CRs:** recreated automatically on first backup after any wipe

## Hard rule: measure before you act

Before diagnosing any backup issue or taking any corrective action, run the storage breakdown first:

```bash
# Bucket breakdown — answers "what is actually consuming space" in one command
kubectl exec -n minio $(kubectl get pods -n minio -l app=minio -o jsonpath='{.items[0].metadata.name}') \
  -- mc du --depth 2 velero-access/velero/

# PVC free space
kubectl exec -n minio $(kubectl get pods -n minio -l app=minio -o jsonpath='{.items[0].metadata.name}') \
  -- df -h /export
```

Never trigger a backup or write operation when storage is < 5% free. Check headroom first.

## Circular backup check

`defaultVolumesToFsBackup: true` backs up **every** pod's volumes by default.  
The namespace that hosts the backup object store (MinIO) **must** be in `excludedNamespaces` on every schedule that uses that BSL — otherwise Velero backs up the backup store into itself.

**On this cluster:** `minio` is excluded from both schedules. Do not remove it.  
If adding a new schedule or BSL, verify: does the BSL's storage namespace appear in `excludedNamespaces`?

## Velero kopia GC timing

Quick maintenance runs hourly (index compaction only). Full maintenance runs ~every 24h and is what actually deletes orphaned content blocks. If you delete backup objects and need space back immediately:

```bash
# Force-purge all versions from a kopia prefix (versioned bucket — delete markers alone don't reclaim space)
kubectl exec -n minio <minio-pod> -- sh -c \
  "mc alias set root http://localhost:9000 root '<rootPassword>' && \
   mc rm --recursive --force --versions root/velero/kopia/<namespace>/"

# Then delete the stale BackupRepository CR so Velero reinitializes clean
kubectl delete backuprepository.velero.io <namespace>-minio-kopia -n velero
```

## Checking backup status

```bash
# All schedules and last backup time
kubectl get schedules.velero.io -n velero

# Recent backup phase (Completed / PartiallyFailed / Failed)
kubectl get backups.velero.io -n velero -l velero.io/schedule-name=velero-daily-full \
  --sort-by=.metadata.creationTimestamp -o custom-columns='NAME:.metadata.name,PHASE:.status.phase,ERRORS:.status.errors'

# BackupRepository health
kubectl get backuprepositories.velero.io -n velero

# Kopia maintenance log for a namespace repo
kubectl logs -n velero $(kubectl get pods -n velero --sort-by=.metadata.creationTimestamp \
  | grep "<namespace>-minio-kopia-maintain" | tail -1 | awk '{print $1}')
```

## Gate for Cilium migration (Phase 8)

Do not start the Cilium CNI migration until a `daily-full` backup shows `Completed` status and a test restore has been validated. First expected clean backup: **2026-04-23 at 2am UTC** (after circular backup fix in PR #410).
