resource "grafana_sso_settings" "authentik" {
  provider_name = "generic_oauth"

  oauth2_settings {
    name                 = "Authentik"
    client_id            = "rArLch2402M3G4HWq4eqmyt0B2EThCIyX5M6CHFG" # gitleaks:allow
    client_secret        = var.grafana_client_secret
    auth_url             = "https://authentik.vollminlab.com/application/o/authorize/"
    token_url            = "https://authentik.vollminlab.com/application/o/token/"
    api_url              = "https://authentik.vollminlab.com/application/o/userinfo/"
    scopes               = "openid profile email groups"
    role_attribute_path  = "contains(groups, 'Grafana Admins') && 'Admin' || 'Viewer'"
    signout_redirect_url = "https://authentik.vollminlab.com/application/o/grafana/end-session/"
    allow_sign_up        = true
    use_pkce             = true
    enabled              = true
  }
}
