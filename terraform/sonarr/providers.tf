provider "sonarr" {
  url     = "http://sonarr.mediastack.svc.cluster.local:8989"
  api_key = var.sonarr_api_key
}
