provider "authentik" {
  url   = "https://authentik.vollminlab.com"
  token = var.token
}

provider "portainer" {
  endpoint = "https://portainer.vollminlab.com/api"
  username = "vollmin"
  password = var.portainer_password
}
