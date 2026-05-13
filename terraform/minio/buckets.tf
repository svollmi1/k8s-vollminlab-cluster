resource "minio_s3_bucket" "cnpg_backups" {
  bucket = "cnpg-backups"
  acl    = "private"
  lifecycle { prevent_destroy = true }
}

resource "minio_s3_bucket" "loki" {
  bucket = "loki"
  acl    = "private"
  lifecycle { prevent_destroy = true }
}

resource "minio_s3_bucket" "terraform_state" {
  bucket = "terraform-state"
  acl    = "private"
  lifecycle { prevent_destroy = true }
}

resource "minio_s3_bucket" "velero" {
  bucket = "velero"
  acl    = "private"
  lifecycle { prevent_destroy = true }
}
