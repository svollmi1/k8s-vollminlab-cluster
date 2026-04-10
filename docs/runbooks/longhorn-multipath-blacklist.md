# Runbook: Longhorn iSCSI Multipath Blacklist

## Why this is required

Longhorn uses iSCSI internally to expose block devices to pods. Ubuntu 24.04 ships with `multipathd` enabled by default. When multipath is active, it intercepts the same SCSI devices Longhorn manages and creates `/dev/mapper/mpathX` entries alongside Longhorn's `/dev/longhorn/<pvc>` symlinks. This causes the kernel to report the device as "already mounted or mount point busy" when Longhorn tries to mount it, producing:

```
MountVolume.MountDevice failed: exit status 32
/dev/longhorn/pvc-xxx already mounted or mount point busy
```

These stale mount errors were the root cause of recurring pod failures on k8sworker01 (and intermittently other workers) in April 2026. The fix is to blacklist all SCSI block devices from multipath so that multipathd ignores Longhorn's iSCSI volumes entirely.

**This must be applied to every worker node in the cluster, including DMZ workers, and to any new worker nodes added in the future.**

---

## Nodes to apply this to

| Node | Role | IP |
|------|------|----|
| k8sworker01 | worker | 192.168.152.11 |
| k8sworker02 | worker | 192.168.152.12 |
| k8sworker03 | worker | 192.168.152.13 |
| k8sworker04 | worker | 192.168.152.14 |
| k8sworker05 | dmz, worker | 192.168.152.15 |
| k8sworker06 | dmz, worker | 192.168.152.16 |

Control plane nodes (k8scp01–03) do not run Longhorn workloads and do not require this change.

---

## Procedure (per node)

Perform one node at a time. There is no need to cordon or drain — `multipathd` restart is non-disruptive to running pods that are already mounted.

### 1. SSH into the node

```bash
ssh k8sworker0X
```

### 2. Check current multipath state

```bash
sudo multipath -ll
# If output is empty or shows no devices, multipath is already not managing any volumes.
# If it shows mpathX entries, those are the devices causing conflicts.
```

### 3. Create or update `/etc/multipath.conf`

Check if the file exists:

```bash
sudo cat /etc/multipath.conf 2>/dev/null || echo "file does not exist"
```

**If the file does not exist**, create it:

```bash
sudo tee /etc/multipath.conf <<'EOF'
defaults {
    user_friendly_names yes
}

blacklist {
    devnode "^sd[a-z0-9]+"
}
EOF
```

**If the file already exists**, add the blacklist section. Ensure it contains at minimum:

```
blacklist {
    devnode "^sd[a-z0-9]+"
}
```

Do not remove any existing content — just append or merge the blacklist block.

### 4. Restart multipathd

```bash
sudo systemctl restart multipathd.service
```

### 5. Verify

```bash
# Should return empty or show no sd* devices being managed
sudo multipath -ll

# Confirm the blacklist is active
sudo multipath -t | grep -A5 blacklist
```

### 6. Confirm no new stale mount events

After completing all nodes, check Longhorn-related pod events for any residual errors:

```bash
kubectl get events -A --sort-by=.lastTimestamp | grep -i "exit status 32\|already mounted\|mount point busy" | tail -20
# Expected: no new events after the restart
```

---

## For new worker nodes

When provisioning a new worker node, apply this configuration **before** joining it to the cluster or before any Longhorn volumes are scheduled to it. Add it to the node provisioning checklist in `homelab-infrastructure`.

Steps are identical to the procedure above. The node does not need to be in the cluster yet — SSH in and apply it as part of OS baseline configuration.

---

## Reverting

If for any reason you need to revert (not recommended):

```bash
sudo rm /etc/multipath.conf
sudo systemctl restart multipathd.service
```

Do not revert while Longhorn volumes are active on the node — it will immediately cause stale mount conflicts.

---

## References

- [Longhorn KB: Troubleshooting MountVolume.SetUp failed due to multipathd](https://longhorn.io/kb/troubleshooting-volume-with-multipath/)
- Incident: `docs/incidents/` — April 2026 stale mount cascade
