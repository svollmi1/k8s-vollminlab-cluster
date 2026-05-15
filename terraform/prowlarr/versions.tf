terraform {
  required_version = ">= 1.6.0"

  required_providers {
    prowlarr = {
      source  = "devopsarr/prowlarr"
      version = "~> 3.2"
    }
  }
}
