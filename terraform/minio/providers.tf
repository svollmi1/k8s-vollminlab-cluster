provider "minio" {
  minio_server   = "minio.minio.svc.cluster.local:9000"
  minio_user     = var.minio_access_key
  minio_password = var.minio_secret_key
  minio_ssl      = false
}
