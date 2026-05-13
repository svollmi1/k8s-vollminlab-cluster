provider "harbor" {
  url      = "https://harbor.vollminlab.com"
  username = "admin"
  password = var.harbor_admin_password
  insecure = false
}
