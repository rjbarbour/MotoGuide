terraform {
  required_version = ">= 1.5.0"

  required_providers {
    fly = {
      source  = "stategraph/fly"
      version = "~> 0.1"
    }
  }
}

provider "fly" {}

resource "fly_app" "fact_proxy" {
  name     = var.fly_app_name
  org_slug = var.fly_org

  lifecycle {
    prevent_destroy = true
  }
}
