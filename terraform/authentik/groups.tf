resource "authentik_group" "audiobookshelf_admins" {
  name  = "Audiobookshelf Admins"
  users = [data.authentik_user.vollmin.id]
}

resource "authentik_group" "audiobookshelf_users" {
  name  = "Audiobookshelf Users"
  users = [data.authentik_user.jvollmin.id]
}

resource "authentik_group" "grafana_admins" {
  name  = "Grafana Admins"
  users = [data.authentik_user.vollmin.id]
}

resource "authentik_group" "harbor_admins" {
  name  = "Harbor Admins"
  users = [data.authentik_user.vollmin.id]
}

resource "authentik_group" "headlamp_admins" {
  name  = "Headlamp Admins"
  users = [data.authentik_user.vollmin.id]
}

resource "authentik_group" "jellyfin_admins" {
  name  = "Jellyfin Admins"
  users = [data.authentik_user.vollmin.id]
}

resource "authentik_group" "jellyfin_users" {
  name  = "Jellyfin Users"
  users = toset([data.authentik_user.jvollmin.id, data.authentik_user.vollmin.id])
}

resource "authentik_group" "minio_admins" {
  name  = "MinIO Admins"
  users = [data.authentik_user.vollmin.id]
}

resource "authentik_group" "portainer_admins" {
  name  = "Portainer Admins"
  users = [data.authentik_user.vollmin.id]
}
