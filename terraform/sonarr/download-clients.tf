resource "sonarr_download_client_sabnzbd" "sabnzbd" {
  name                       = "SABnzbd"
  enable                     = true
  priority                   = 1
  host                       = "sabnzbd"
  port                       = 10097
  api_key                    = var.sabnzbd_api_key
  use_ssl                    = false
  tv_category                = "tv"
  recent_tv_priority         = -100
  older_tv_priority          = -100
  remove_completed_downloads = true
  remove_failed_downloads    = true
}
