# ---------------------------------------------------------------------------
# Import blocks for pre-existing Cloudflare resources
#
# Tunnel + tunnel config import ID format: <account_id>/<tunnel_uuid>
# DNS record import ID format:             <zone_id>/<record_id>
#
# Account ID:          9013108406ddceed8abc1a3e2e21907d
# Zone ID (vollminlab.com): 30033aeb9194c2b67af71e7d0869da02
# ---------------------------------------------------------------------------

# Tunnel resources
import {
  to = cloudflare_zero_trust_tunnel_cloudflared.vollminlab_authentik
  id = "9013108406ddceed8abc1a3e2e21907d/d5a68ca0-0460-47f0-b17b-a4043f9fe69c"
}

import {
  to = cloudflare_zero_trust_tunnel_cloudflared.vollminlab_audiobookshelf
  id = "9013108406ddceed8abc1a3e2e21907d/01ca47d0-b545-4ee4-9fb0-2ae1f74c0e9c"
}

import {
  to = cloudflare_zero_trust_tunnel_cloudflared.vollminlab_jellyfin
  id = "9013108406ddceed8abc1a3e2e21907d/51eeb142-e2fe-4153-8ed2-585d3c5ac018"
}

# DNS CNAME records
import {
  to = cloudflare_dns_record.authentik
  id = "30033aeb9194c2b67af71e7d0869da02/c71fa309423d523e718940f184d3fea0"
}

import {
  to = cloudflare_dns_record.audiobookshelf
  id = "30033aeb9194c2b67af71e7d0869da02/e2a8dca4a841cb6d674568525db72c37"
}

import {
  to = cloudflare_dns_record.jellyfin
  id = "30033aeb9194c2b67af71e7d0869da02/e1f3d0c051364c8f8c686af7bf167d60"
}
