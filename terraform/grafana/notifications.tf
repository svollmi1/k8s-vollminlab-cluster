resource "grafana_contact_point" "pushover" {
  name = "Pushover"

  pushover {
    user_key  = var.pushover_user_key
    api_token = var.pushover_api_token
    title     = "Grafana Alert: {{ .CommonLabels.alertname }}"
    message   = "{{ range .Alerts }}{{ .Annotations.summary }}\n{{ end }}"
    priority  = 0
  }
}

resource "grafana_notification_policy" "default" {
  group_by      = ["grafana_folder", "alertname"]
  contact_point = grafana_contact_point.pushover.name

  group_wait      = "30s"
  group_interval  = "5m"
  repeat_interval = "4h"
}
