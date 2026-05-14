terraform {
  required_version = ">= 1.6.0"

  required_providers {
    harbor = {
      source  = "goharbor/harbor"
      version = "~> 3.10"
    }
  }
}
