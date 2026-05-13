provider "authentik" {
  url   = "https://authentik.vollminlab.com"
  token = var.token
}

provider "portainer" {
  endpoint     = "https://portainer.vollminlab.com/api"
  api_user     = "vollmin"
  api_password = var.portainer_password
}
