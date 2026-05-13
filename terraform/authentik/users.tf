resource "authentik_user" "vollmin" {
  username  = "vollmin"
  name      = "Scott Vollmin"
  email     = "scottvollmin@gmail.com"
  is_active = true

  lifecycle {
    ignore_changes = [password]
  }
}

resource "authentik_user" "jvollmin" {
  username  = "jvollmin"
  name      = "Justin Vollmin"
  email     = "vollmi91@gmail.com"
  is_active = true

  lifecycle {
    ignore_changes = [password]
  }
}

resource "authentik_user" "gkroner" {
  username  = "gkroner"
  name      = "Garrett Kroner"
  email     = "gkroner@gmail.com"
  is_active = true

  lifecycle {
    ignore_changes = [password]
  }
}
