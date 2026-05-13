resource "harbor_project" "library" {
  name   = "library"
  public = true

  lifecycle {
    prevent_destroy = true
  }
}

resource "harbor_project" "vollminlab" {
  name   = "vollminlab"
  public = true

  lifecycle {
    prevent_destroy = true
  }
}
