variable "token" {
  description = "Authentik API token for Terraform provider authentication"
  type        = string
  sensitive   = true
}

variable "grafana_client_secret" {
  description = "OAuth2 client secret for the Grafana application in Authentik"
  type        = string
  sensitive   = true
}

variable "headlamp_client_secret" {
  description = "OAuth2 client secret for the Headlamp application in Authentik"
  type        = string
  sensitive   = true
}

variable "minio_client_secret" {
  description = "OAuth2 client secret for the MinIO application in Authentik"
  type        = string
  sensitive   = true
}

variable "jellyfin_client_secret" {
  description = "OAuth2 client secret for the Jellyfin application in Authentik"
  type        = string
  sensitive   = true
}

variable "harbor_client_secret" {
  description = "OAuth2 client secret for the Harbor application in Authentik"
  type        = string
  sensitive   = true
}

variable "portainer_client_secret" {
  description = "OAuth2 client secret for the Portainer application in Authentik"
  type        = string
  sensitive   = true
}

variable "audiobookshelf_client_secret" {
  description = "OAuth2 client secret for the Audiobookshelf application in Authentik"
  type        = string
  sensitive   = true
}

variable "portainer_password" {
  description = "Portainer admin password for Terraform provider authentication"
  type        = string
  sensitive   = true
}
