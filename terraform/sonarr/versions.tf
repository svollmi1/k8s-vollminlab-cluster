terraform {
  required_version = ">= 1.6.0"

  required_providers {
    sonarr = {
      source  = "devopsarr/sonarr"
      version = "~> 3.3"
    }
  }
}
