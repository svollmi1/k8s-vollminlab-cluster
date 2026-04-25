# Jellyfin Deployment Design

**Created:** 2026-04-25
**Status:** Approved — ready for implementation

## Goal

Deploy Jellyfin alongside Plex in the `mediastack` namespace, accessible externally through Cloudflare Tunnel, usable from native apps for the owner and friends, with no router port forwarding and no publicly open NodePort/LoadBalancer.

Plex remains untouched. Both media servers share the existing `pvc-movies` and `pvc-tv` SMB RWX PVCs.

## Helm chart

- **Source:** Official Jellyfin chart, `https://jellyfin.github.io/jellyfin-helm/`
- **Chart version:** 3.2.0
- **App version:** 10.11.8 (Jellyfin)
- **Source kind:** `HelmRepository` (HTTP, not OCI)
- **Source name:** `jellyfin-repo`

## Architecture

```text
External (friends) ──► Cloudflare Edge ──► cloudflared-jellyfin (Deployment)
                                                     │
                                                     ▼
LAN ─────────────────► nginx ingress ──► jellyfin Service (ClusterIP :8096)
                                                     │
                                                     ▼
                                            Jellyfin Pod (UID/GID 568)
                                              /config  → pvc-jellyfin-config (Longhorn 20Gi RWO)
                                              /movies  → pvc-movies (SMB RWX)
                                              /tv      → pvc-tv (SMB RWX)
```

## Security model

- No Cloudflare Access policy on `jellyfin.vollminlab.com`. Cloudflare Access email-gate does not work with native Jellyfin apps (Android, iOS, Apple TV, Roku, etc.) — those apps make HTTP requests that cannot complete a browser-based auth challenge.
- Cloudflare Tunnel provides connectivity only; Jellyfin's built-in authentication is the gate.
- Public signup disabled in Jellyfin settings on first launch.
- Admin account created on first launch with a strong password; user accounts added manually.
- No NodePort, no LoadBalancer, no router port forwarding.

## Tunnel architecture

**Separate tunnel** (Option B). Jellyfin gets its own Cloudflare Tunnel, its own `cloudflared` Deployment, and its own SealedSecret. This gives independent blast-radius isolation: the Plex tunnel and Jellyfin tunnel can be individually revoked or rotated without affecting the other. This matters because Jellyfin is shared with external users.

- Existing `cloudflared` Deployment (for Plex) is unchanged.
- New `cloudflared-jellyfin` Deployment reads from `cloudflared-jellyfin-tunnel-credentials` SealedSecret.

## Storage

| PVC | Type | Size | StorageClass | Access | Mount |
| --- | --- | --- | --- | --- | --- |
| `pvc-jellyfin-config` | Longhorn (default) | 20Gi | (default) | RWO | `/config` |
| `pvc-movies` | SMB (existing) | — | smb | RWX | `/movies` |
| `pvc-tv` | SMB (existing) | — | smb | RWX | `/tv` |

The Jellyfin chart's built-in `persistence.media` PVC is disabled. `pvc-movies` and `pvc-tv` are mounted via the chart's `volumes[]` / `volumeMounts[]` extra-volume mechanism.

## Helm values (configmap.yaml)

```yaml
persistence:
  config:
    existingClaim: pvc-jellyfin-config
  media:
    enabled: false

volumes:
  - name: movies
    persistentVolumeClaim:
      claimName: pvc-movies
  - name: tv
    persistentVolumeClaim:
      claimName: pvc-tv

volumeMounts:
  - name: movies
    mountPath: /movies
  - name: tv
    mountPath: /tv

securityContext:
  runAsUser: 568
  runAsGroup: 568

podSecurityContext:
  fsGroup: 568
  fsGroupChangePolicy: OnRootMismatch

podLabels:
  app: jellyfin
  env: production
  category: media

resources:
  requests:
    cpu: 500m
    memory: 512Mi
  limits:
    cpu: 2000m
    memory: 2Gi
```

CPU transcoding only for initial deployment. Hardware transcoding deferred (requires hostPath or device mount — Kyverno audit-mode violation; must be evaluated separately).

## Ingress

- `ingressClassName: nginx`
- Host: `jellyfin.vollminlab.com`
- TLS: `wildcard-tls`
- `nginx.ingress.kubernetes.io/ssl-redirect: "true"`
- `shlink.vollminlab.com/slug: jellyfin` (auto-creates `vollm.in/jellyfin`)

Cloudflare Tunnel targets the Service directly at `http://jellyfin.mediastack.svc.cluster.local:8096`. The ingress serves LAN/split-DNS access.

## Files to create (9)

```text
flux-system/repositories/jellyfin-helmrepository.yaml
mediastack/jellyfin/app/helmrelease.yaml
mediastack/jellyfin/app/configmap.yaml
mediastack/jellyfin/app/ingress.yaml
mediastack/jellyfin/app/pvc-jellyfin-config.yaml
mediastack/jellyfin/app/kustomization.yaml
mediastack/cloudflared-jellyfin/app/deployment.yaml
mediastack/cloudflared-jellyfin/app/cloudflared-jellyfin-tunnel-sealedsecret.yaml
mediastack/cloudflared-jellyfin/app/kustomization.yaml
```

## Files to modify (4)

```text
flux-system/repositories/kustomization.yaml      — add jellyfin-helmrepository.yaml (alphabetical)
mediastack/kustomization.yaml                    — add ./jellyfin/app and ./cloudflared-jellyfin/app
docs/cluster-reference.md                        — add Jellyfin section
docs/roadmap.md                                  — add Jellyfin entry
```

## Manual Cloudflare dashboard steps (post-merge)

1. Zero Trust → Networks → Tunnels → Create a tunnel → name `jellyfin`
2. Copy the tunnel token
3. Seal the token:

   ```bash
   kubeseal --fetch-cert --controller-namespace sealed-secrets \
     --controller-name sealed-secrets-controller > pub-cert.pem
   kubectl create secret generic cloudflared-jellyfin-tunnel-credentials \
     -n mediastack --from-literal=tunnel-token=<TOKEN> \
     --dry-run=client -o yaml | \
     kubeseal --cert pub-cert.pem --format yaml \
     > clusters/vollminlab-cluster/mediastack/cloudflared-jellyfin/app/cloudflared-jellyfin-tunnel-sealedsecret.yaml
   rm pub-cert.pem
   ```

4. Push the sealed secret to the branch; Flux will reconcile
5. In the tunnel's Public Hostnames tab: add `jellyfin.vollminlab.com` → `http://jellyfin.mediastack.svc.cluster.local:8096`

## Post-deployment first-launch checklist

1. Navigate to `jellyfin.vollminlab.com` (or LAN URL) to complete setup wizard
2. Create admin account with strong password
3. Add media libraries: Movies → `/movies`, TV Shows → `/tv`
4. Settings → Dashboard → Disable "Allow remote connections without authentication" if present
5. Settings → Users → Disable "Allow users to join this server" (no public signup)
6. Create user accounts for friends manually

## Deferred: hardware transcoding

Requires a device mount (e.g. `/dev/dri`) via hostPath or device plugin. `hostPath` is a Kyverno audit-mode violation in this cluster. Evaluate separately; document the policy impact before enabling.

## Deferred: Cloudflare Access for browser access

If a browser-only admin UI behind email-gate is desired in future, a separate subdomain (e.g. `jellyfin-admin.vollminlab.com`) with Cloudflare Access could be added without breaking native app support on the main hostname.
