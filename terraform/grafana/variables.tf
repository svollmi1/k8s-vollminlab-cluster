variable "grafana_admin_password" {
  description = "Grafana admin password for Terraform provider authentication"
  type        = string
  sensitive   = true
}

variable "grafana_client_secret" {
  description = "Authentik OAuth2 client secret for the Grafana application"
  type        = string
  sensitive   = true
}

variable "pushover_user_key" {
  description = "Pushover user key for Grafana alert contact point"
  type        = string
  sensitive   = true
}

variable "pushover_api_token" {
  description = "Pushover API token for Grafana alert contact point"
  type        = string
  sensitive   = true
}
