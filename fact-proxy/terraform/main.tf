terraform {
  required_version = ">= 1.5.0"

  required_providers {
    fly = {
      source  = "pi3ch/fly"
      version = "0.0.24"
    }
  }
}

provider "fly" {}

resource "fly_app" "fact_proxy" {
  name = var.fly_app_name
  org  = var.fly_org

  lifecycle {
    prevent_destroy = true
  }
}
