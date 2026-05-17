# Homepage: Backblaze B2 Metrics + Cloudflare Widget

## Overview

Add two new entries to the Homepage dashboard:

1. **Backblaze B2** — a `prometheus` widget showing Velero bucket size and file count, backed by a new custom Prometheus exporter that queries the B2 API.
2. **Cloudflare** — a native `cloudflare` widget showing zone requests, bandwidth, and threats blocked over the past 24h.

Both entries fit into existing sections without changing column counts for those sections.

---

## B2 Prometheus Exporter

### Architecture

A new `Deployment` in the `monitoring` namespace runs a Python HTTP server that:

- Queries the Backblaze B2 API on startup and then every 30 minutes (internal goroutine/thread)
- Sums `contentLength` across all file versions in the configured bucket via `b2sdk`
- Caches the result in memory
- Serves the cached result immediately on every Prometheus scrape via `/metrics`

This prevents B2 from being hammered on every scrape interval (default 15s).

### Metrics

| Metric | Labels | Description |
|--------|--------|-------------|
| `b2_bucket_bytes_total` | `bucket` | Total bytes stored in the B2 bucket |
| `b2_bucket_file_count_total` | `bucket` | Total number of file versions in the B2 bucket |

### Container Image

- Base image: `python:3.12-slim`
- Dependencies: `b2sdk`, `prometheus_client`
- Script (~50 lines) baked into the image
- Built and pushed to `harbor.vollminlab.com/library/b2-exporter:<tag>`

### Kubernetes Resources

All resources in `monitoring` namespace.

| Resource | Name | Notes |
|----------|------|-------|
| Deployment | `b2-exporter` | Single replica, no PVC |
| SealedSecret | `b2-exporter-credentials` | `B2_APPLICATION_KEY_ID`, `B2_APPLICATION_KEY`, `B2_BUCKET_NAME` |
| Service | `b2-exporter` | Port 8080 (metrics) |
| ServiceMonitor | `b2-exporter` | Labels matching kube-prometheus-stack selector |

Labels on all resources: `app: b2-exporter`, `env: production`, `category: observability`

### Credentials

A B2 Application Key scoped to the Velero bucket with `listFiles`, `readFiles` capabilities. Stored in 1Password as **"B2 Exporter App Key"** (Homelab vault), sealed into `b2-exporter-credentials-sealedsecret.yaml`.

### Flux Wiring

- Add `- b2-exporter/app` to `clusters/vollminlab-cluster/monitoring/kustomization.yaml`
- The existing `monitoring-kustomization.yaml` Flux CR already covers the whole monitoring namespace — no new Flux Kustomization CR needed
- No new HelmRepository needed (plain Kubernetes manifests, not Helm-based)

### Grafana

Once the ServiceMonitor is active, metrics are available in Prometheus immediately. A new panel can be added to the existing Velero Grafana dashboard showing B2 bucket size over time.

---

## Homepage Changes

### Backblaze entry — Infrastructure section

Infrastructure currently has 7 items at 4 columns (row 2 has one empty slot). Adding Backblaze fills it to exactly 2 clean rows of 4 — no column count change needed.

```yaml
- Backblaze:
    description: B2 offsite backup storage
    href: https://secure.backblaze.com/b2_buckets.htm
    icon: backblaze.png
    widget:
      type: prometheus
      url: http://kube-prometheus-stack-prometheus.monitoring.svc.cluster.local:9090
      query: b2_bucket_bytes_total
      format:
        type: bytes
        scale: 1000000000
        suffix: GB
```

No changes to `Infrastructure` column count (stays at 4).

### Cloudflare entry — Networking section

Networking currently has 5 items at 5 columns (1 clean row). Adding Cloudflare makes 6 items. Column count changes from **5 → 3** (2 rows of 3).

```yaml
- Cloudflare:
    description: DNS and CDN
    href: https://dash.cloudflare.com
    icon: cloudflare.png
    widget:
      type: cloudflare
      key: "{{HOMEPAGE_VAR_CLOUDFLARE_API_TOKEN}}"
```

### New env var in SealedSecret

`homepage-env-vars` SealedSecret gains one new key: `CLOUDFLARE_API_TOKEN`.

A new `HOMEPAGE_VAR_CLOUDFLARE_API_TOKEN` env var is added to the `env:` list in `configmap.yaml`.

---

## Secrets Summary

| Secret name | Namespace | Keys | Source in 1Password |
|-------------|-----------|------|---------------------|
| `b2-exporter-credentials` | `monitoring` | `B2_APPLICATION_KEY_ID`, `B2_APPLICATION_KEY`, `B2_BUCKET_NAME` | "B2 Exporter App Key" |
| `homepage-env-vars` (updated) | `homepage` | + `CLOUDFLARE_API_TOKEN` | "Cloudflare Homepage Token" |

---

## Layout Impact Summary

| Section | Before | After | Column change |
|---------|--------|-------|---------------|
| Infrastructure | 7 items, 4 cols | 8 items, 4 cols | None |
| Networking | 5 items, 5 cols | 6 items, 3 cols | 5 → 3 |
