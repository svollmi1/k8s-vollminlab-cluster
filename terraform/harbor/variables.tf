variable "harbor_admin_password" {
  description = "Harbor admin password for Terraform provider authentication"
  type        = string
  sensitive   = true
}

variable "harbor_oidc_client_secret" {
  description = "OAuth2 client secret for the Harbor application in Authentik"
  type        = string
  sensitive   = true
}
