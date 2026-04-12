# external-dns Runbook

## HARD CONSTRAINT — policy: sync is forbidden with Pi-hole

**Never set `policy: sync` in the external-dns Helm values.** Always use `policy: upsert-only`.

Pi-hole is a **shared** DNS backend holding both external-dns-managed records (ingress hostnames) and manually-managed records (infrastructure hosts: vCenter, ESXi, k8s nodes, TrueNAS, haproxy VIPs, etc.). external-dns has no awareness of manually-managed records.

With `policy: sync`, external-dns treats itself as authoritative for the entire `vollminlab.com` zone and deletes any record it didn't create. **This wiped all infrastructure DNS records on 2026-04-05.**

With `policy: upsert-only`, external-dns only adds or updates records it manages — never deletes records it didn't create.

**Why registry/ownership can't fix this:** The Pi-hole provider uses `--registry=noop` because Pi-hole's API v6 does not support TXT ownership records. There is no mechanism to distinguish managed from unmanaged records. `policy: sync` with `registry: noop` is unconditionally destructive on a shared backend.

## Current config

- Provider: `pihole`
- Policy: `upsert-only` (in `external-dns-values` ConfigMap, `external-dns` namespace)
- Registry: `noop`
- Domain filter: `vollminlab.com`
- Pi-hole primary: `http://192.168.100.2` (pihole1)
- API version: `6`

## DNS record backup and restore

Authoritative infrastructure record list: `c:/git/homelab-infrastructure/hosts/pihole1/configs/pihole/pihole.toml`, `dns.hosts` array (~lines 102–158).

To restore all records to both Pi-holes:
```bash
TOKEN=$(op read "op://Homelab/Recordimporter/credential")

# For each "IP HOSTNAME" entry in dns.hosts:
curl -s -X POST http://192.168.100.2:5001/add-a-record \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"domain":"vcenter.vollminlab.com","ip":"192.168.151.5"}'
# Repeat for 192.168.100.3 (pihole2)
# HTTP 200/201/409 are all success (409 = already exists)
```

## Verifying external-dns is safe after restart or upgrade

```bash
# Must show Policy:upsert-only — never Policy:sync
kubectl logs -n external-dns deployment/external-dns --tail=20 | grep "Policy:"

# Must show no DELETE lines
kubectl logs -n external-dns deployment/external-dns --tail=50 | grep -i DELETE
# Expected output: (empty)
```
