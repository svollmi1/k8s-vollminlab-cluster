variable "cloudflare_api_token" {
  description = "Cloudflare API token with Zero Trust and DNS edit permissions"
  type        = string
  sensitive   = true
}

variable "cloudflare_account_id" {
  description = "Cloudflare account ID"
  type        = string
}

variable "cloudflare_zone_id" {
  description = "Cloudflare zone ID for vollminlab.com"
  type        = string
}
