variable "sonarr_api_key" {
  description = "Sonarr API key for provider authentication"
  type        = string
  sensitive   = true
}

variable "sabnzbd_api_key" {
  description = "SABnzbd API key for download client configuration"
  type        = string
  sensitive   = true
}
