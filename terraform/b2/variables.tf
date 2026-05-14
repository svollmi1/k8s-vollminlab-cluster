variable "b2_master_application_key_id" {
  description = "Backblaze B2 application key ID for provider authentication"
  type        = string
  sensitive   = true
}

variable "b2_master_application_key" {
  description = "Backblaze B2 application key secret"
  type        = string
  sensitive   = true
}
