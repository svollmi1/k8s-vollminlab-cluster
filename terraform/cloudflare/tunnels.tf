# ---------------------------------------------------------------------------
# Cloudflare Zero Trust Tunnels (cloudflared)
# All tunnels are pre-existing; tokens are stored in cluster SealedSecrets.
# Do NOT set secret = on any tunnel resource — it would rotate the tunnel token
# and invalidate the credentials sealed in the cluster.
# ---------------------------------------------------------------------------

resource "cloudflare_zero_trust_tunnel_cloudflared" "vollminlab_authentik" {
  account_id = var.cloudflare_account_id
  name       = "vollminlab-Authentik"
  lifecycle { ignore_changes = all }
}

resource "cloudflare_zero_trust_tunnel_cloudflared" "vollminlab_audiobookshelf" {
  account_id = var.cloudflare_account_id
  name       = "vollminlab-Audiobookshelf"
  lifecycle { ignore_changes = all }
}

resource "cloudflare_zero_trust_tunnel_cloudflared" "vollminlab_jellyfin" {
  account_id = var.cloudflare_account_id
  name       = "vollminlab-Jellyfin"
  lifecycle { ignore_changes = all }
}

# ---------------------------------------------------------------------------
# Tunnel ingress configurations
# ---------------------------------------------------------------------------

resource "cloudflare_zero_trust_tunnel_cloudflared_config" "vollminlab_authentik" {
  account_id = var.cloudflare_account_id
  tunnel_id  = cloudflare_zero_trust_tunnel_cloudflared.vollminlab_authentik.id
  lifecycle { ignore_changes = all }

  config = {
    ingress_rule = [
      {
        hostname = "authentik.vollminlab.com"
        service  = "http://authentik-server.authentik.svc.cluster.local:80"
      },
      {
        service = "http_status:404"
      },
    ]
  }
}

resource "cloudflare_zero_trust_tunnel_cloudflared_config" "vollminlab_audiobookshelf" {
  account_id = var.cloudflare_account_id
  tunnel_id  = cloudflare_zero_trust_tunnel_cloudflared.vollminlab_audiobookshelf.id
  lifecycle { ignore_changes = all }

  config = {
    ingress_rule = [
      {
        hostname = "audiobookshelf.vollminlab.com"
        service  = "http://audiobookshelf.mediastack.svc.cluster.local:10223"
      },
      {
        service = "http_status:404"
      },
    ]
  }
}

resource "cloudflare_zero_trust_tunnel_cloudflared_config" "vollminlab_jellyfin" {
  account_id = var.cloudflare_account_id
  tunnel_id  = cloudflare_zero_trust_tunnel_cloudflared.vollminlab_jellyfin.id
  lifecycle { ignore_changes = all }

  config = {
    ingress_rule = [
      {
        hostname = "jellyfin.vollminlab.com"
        service  = "http://jellyfin.mediastack.svc.cluster.local:8096"
      },
      {
        service = "http_status:404"
      },
    ]
  }
}

