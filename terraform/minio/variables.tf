variable "minio_access_key" {
  description = "MinIO root access key for Terraform provider authentication"
  type        = string
  sensitive   = true
}

variable "minio_secret_key" {
  description = "MinIO root secret key for Terraform provider authentication"
  type        = string
  sensitive   = true
}
