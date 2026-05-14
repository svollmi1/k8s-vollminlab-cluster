resource "b2_bucket" "velero" {
  bucket_name = "vollminlab-k8s-backups"
  bucket_type = "allPrivate"
}

