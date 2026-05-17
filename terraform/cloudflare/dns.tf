# ---------------------------------------------------------------------------
# DNS CNAME records for Cloudflare tunnel-backed hostnames (vollminlab.com)
# All records are proxied through Cloudflare (proxied = true, ttl = 1 = auto)
# ---------------------------------------------------------------------------

resource "cloudflare_dns_record" "authentik" {
  zone_id = var.cloudflare_zone_id
  name    = "authentik.vollminlab.com"
  type    = "CNAME"
  content = "${cloudflare_zero_trust_tunnel_cloudflared.vollminlab_authentik.id}.cfargotunnel.com"
  proxied = true
  ttl     = 1
}

resource "cloudflare_dns_record" "audiobookshelf" {
  zone_id = var.cloudflare_zone_id
  name    = "audiobookshelf.vollminlab.com"
  type    = "CNAME"
  content = "${cloudflare_zero_trust_tunnel_cloudflared.vollminlab_audiobookshelf.id}.cfargotunnel.com"
  proxied = true
  ttl     = 1
}

resource "cloudflare_dns_record" "filebrowser" {
  zone_id = var.cloudflare_zone_id
  name    = "filebrowser.vollminlab.com"
  type    = "CNAME"
  content = "${cloudflare_zero_trust_tunnel_cloudflared.vollminlab_filebrowser.id}.cfargotunnel.com"
  proxied = true
  ttl     = 1
}

resource "cloudflare_dns_record" "jellyfin" {
  zone_id = var.cloudflare_zone_id
  name    = "jellyfin.vollminlab.com"
  type    = "CNAME"
  content = "${cloudflare_zero_trust_tunnel_cloudflared.vollminlab_jellyfin.id}.cfargotunnel.com"
  proxied = true
  ttl     = 1
}

