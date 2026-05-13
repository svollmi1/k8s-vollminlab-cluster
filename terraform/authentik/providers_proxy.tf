resource "authentik_provider_proxy" "vollminlab_forward_auth" {
  name               = "vollminlab-forward-auth"
  external_host      = "https://authentik.vollminlab.com"
  authorization_flow = data.authentik_flow.default_authorization_implicit.id
  mode               = "forward_domain"
  cookie_domain      = "vollminlab.com"

  lifecycle {
    ignore_changes = [client_secret]
  }
}
