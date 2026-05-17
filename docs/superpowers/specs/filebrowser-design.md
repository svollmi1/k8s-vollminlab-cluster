# FileBrowser — File Drop Service Design

**Date:** 2026-05-17
**Status:** Approved

## Overview

Deploy FileBrowser in the `mediastack` namespace as a general-purpose file drop service. External users upload files via browser to a dedicated TrueNAS SMB share. Authentication is handled entirely by Authentik (forward-auth via nginx), with FileBrowser running in proxy auth mode — no second login prompt. Files land on the SMB share and are accessible from Windows at `\\smb.vollminlab.com\FileBrowser\`.

## Architecture

```
Friend's browser
      │
      ▼
Cloudflare Tunnel (vollminlab-FileBrowser)
      │  routes to ingress-nginx-controller.ingress-nginx.svc.cluster.local:80
      ▼
nginx ingress (filebrowser.vollminlab.com)
      │  auth-request → Authentik outpost (vollminlab-proxy)
      │  injects X-authentik-username header on success
      ▼
FileBrowser service (mediastack)
      │  reads X-authentik-username, looks up user in its DB
      ▼
pvc-filebrowser → SMB share //192.168.150.2/FileBrowser
      │
      ▼
TrueNAS dataset: FileBrowser
  └── Audiobooks/     ← friend uploads here
  └── (future use cases as subfolders)
```

## Components

### 1. TrueNAS (manual)

- Create ZFS dataset `FileBrowser` on the same pool as `audiobooks`, `movies`, etc.
- Enable SMB share named `FileBrowser`
- Create `Audiobooks/` subfolder inside it
- Permissions: uid=568, gid=568 (matches all other SMB mounts in the cluster)

### 2. Cloudflare Tunnel (tofu — `terraform/cloudflare/tunnels.tf`)

New resources following the existing `vollminlab_audiobookshelf` pattern:

```hcl
resource "cloudflare_zero_trust_tunnel_cloudflared" "vollminlab_filebrowser" {
  account_id = var.cloudflare_account_id
  name       = "vollminlab-FileBrowser"
  lifecycle { ignore_changes = all }
}

resource "cloudflare_zero_trust_tunnel_cloudflared_config" "vollminlab_filebrowser" {
  account_id = var.cloudflare_account_id
  tunnel_id  = cloudflare_zero_trust_tunnel_cloudflared.vollminlab_filebrowser.id
  lifecycle { ignore_changes = all }

  config = {
    ingress_rule = [
      {
        hostname = "filebrowser.vollminlab.com"
        service  = "http://ingress-nginx-controller.ingress-nginx.svc.cluster.local:80"
      },
      {
        service = "http_status:404"
      },
    ]
  }
}
```

**Note:** Unlike audiobookshelf/jellyfin (which use OIDC and route directly to the app service), this tunnel routes through nginx so Authentik forward-auth can inject the `X-authentik-username` header. FileBrowser's proxy auth mode depends on this header being present.

### 3. Kubernetes resources (`clusters/vollminlab-cluster/`)

| File | Location | Purpose |
|---|---|---|
| `pv-filebrowser.yaml` | `clusterwide/` | PV for SMB share `//192.168.150.2/FileBrowser` |
| `pvc-filebrowser.yaml` | `mediastack/pvcs/` | PVC binding to above PV, `ReadWriteMany` |
| `helmrelease.yaml` | `mediastack/filebrowser/app/` | FileBrowser HelmRelease |
| `configmap.yaml` | `mediastack/filebrowser/app/` | Helm values (proxy auth config) |
| `ingress.yaml` | `mediastack/filebrowser/app/` | Ingress with Authentik forward-auth annotations + shlink slug `filebrowser` |
| `cloudflared-filebrowser-tunnel-credentials-sealedsecret.yaml` | `mediastack/cloudflared-filebrowser/app/` | Tunnel token SealedSecret |
| `deployment.yaml` | `mediastack/cloudflared-filebrowser/app/` | cloudflared Deployment (mirrors audiobookshelf pattern) |

Both Flux index files must be updated:
- `flux-system/flux-kustomizations/kustomization.yaml` — add `filebrowser` and `cloudflared-filebrowser` entries
- `flux-system/repositories/kustomization.yaml` — add FileBrowser HelmRepository entry

#### FileBrowser proxy auth configuration

FileBrowser is configured via `settings.json` at startup. Key values:

```json
{
  "authMethod": "proxy",
  "authHeader": "X-authentik-username"
}
```

This is set via Helm values in `configmap.yaml`.

#### Helm chart

Use the `gabe565/filebrowser` chart (`https://charts.gabe565.com`). Confirm latest pinned version before committing.

### 4. Authentik (tofu — `terraform/authentik/`)

**`applications.tf`** — add:
```hcl
resource "authentik_application" "filebrowser" {
  name            = "FileBrowser"
  slug            = "filebrowser"
  meta_launch_url = "https://filebrowser.vollminlab.com"
  open_in_new_tab = false
}
```

**`dns.tf`** — add CNAME record pointing to the tunnel:
```hcl
resource "cloudflare_dns_record" "filebrowser" {
  zone_id = var.cloudflare_zone_id
  name    = "filebrowser.vollminlab.com"
  type    = "CNAME"
  content = "${cloudflare_zero_trust_tunnel_cloudflared.vollminlab_filebrowser.id}.cfargotunnel.com"
  proxied = true
  ttl     = 1
}
```

**`users.tf`** — add the friend's Authentik user (name/email TBD at implementation time, following the `chavelock` pattern with `lifecycle { ignore_changes = [password, groups] }`).

The friend's Authentik user must be granted access to the `filebrowser` application via the existing policy/binding mechanism.

### 5. FileBrowser user bootstrap (one-time, post-deploy)

FileBrowser does not auto-provision users on proxy auth — the username from the header must already exist in FileBrowser's database. After the service is running, create two users via the FileBrowser admin API:

| Username | Role | Scope | Permissions |
|---|---|---|---|
| `vollmin` | Admin | `/` | All |
| `<friend-username>` | User | `/Audiobooks/` | Upload only (no delete/rename) |

Usernames must exactly match the Authentik usernames (what `X-authentik-username` will contain).

## Access model

| Who | Entry point | What they see |
|---|---|---|
| You | `https://filebrowser.vollminlab.com` | Full file manager for all of `FileBrowser/` |
| Friend | `https://filebrowser.vollminlab.com` | Only `Audiobooks/` folder, upload only |
| You (Windows) | `\\smb.vollminlab.com\FileBrowser\` | Direct SMB access, move files anywhere |

## Adding future use cases

To add a new drop folder (e.g. `Photos`):
1. Create the subfolder in TrueNAS under the `FileBrowser` dataset
2. Add a new Authentik user (tofu) for the new sender
3. Bootstrap a FileBrowser user scoped to the new subfolder via the API
4. Share `https://filebrowser.vollminlab.com` — the user sees only their folder

No new Kubernetes resources, no new tunnels, no new ingresses.

## Open questions

- Friend's name, username, and email for the Authentik user entry (needed at implementation time)
