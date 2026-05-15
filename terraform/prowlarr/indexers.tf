# Indexers imported from Prowlarr API
# Retrieved 2026-05-15 via kubectl exec prowlarr /api/v1/indexer
# Both are Newznab usenet indexers; sensitive fields use ignore_changes
# to prevent perpetual drift from Prowlarr's masked API responses.

resource "prowlarr_indexer" "nzbgeek" {
  name            = "NZBgeek"
  enable          = true
  priority        = 25
  protocol        = "usenet"
  implementation  = "Newznab"
  config_contract = "NewznabSettings"
  app_profile_id  = 1

  lifecycle { ignore_changes = [fields] }

  fields = [
    { name = "baseUrl", text_value = "https://api.nzbgeek.info" },
    { name = "apiPath", text_value = "/api" },
    { name = "apiKey", sensitive_value = var.nzbgeek_api_key },
  ]
}

resource "prowlarr_indexer" "nzbplanet" {
  name            = "NzbPlanet"
  enable          = true
  priority        = 25
  protocol        = "usenet"
  implementation  = "Newznab"
  config_contract = "NewznabSettings"
  app_profile_id  = 1

  lifecycle { ignore_changes = [fields] }

  fields = [
    { name = "baseUrl", text_value = "https://api.nzbplanet.net" },
    { name = "apiPath", text_value = "/api" },
    { name = "apiKey", sensitive_value = var.nzbplanet_api_key },
  ]
}
