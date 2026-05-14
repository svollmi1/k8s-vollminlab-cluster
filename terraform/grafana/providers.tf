provider "grafana" {
  url  = "https://grafana.vollminlab.com"
  auth = "admin:${var.grafana_admin_password}"
}
