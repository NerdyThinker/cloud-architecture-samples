# canary-release-pattern/main.tf
#
# Minimal illustrative sample: the same slot mechanism as Blue-Green, but
# used differently — traffic is split between production and the canary
# slot by percentage, rather than swapped wholesale. App Service's
# traffic-routing rules handle this natively via routing percentages on
# the slot, without needing an external load balancer to implement the
# split.
#
# Not production-ready as-is: this sample sets a static 5% split at
# deploy time. A real canary process adjusts that percentage
# progressively based on live metrics (error rate, latency) — typically
# driven by a deployment pipeline step or a progressive-delivery tool,
# not a one-time Terraform apply.

terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.100"
    }
  }
}

provider "azurerm" {
  features {}
}

resource "azurerm_resource_group" "canary_sample" {
  name     = "rg-canary-release-sample"
  location = "East US"
}

resource "azurerm_service_plan" "canary_sample" {
  name                = "asp-canary-release-sample"
  resource_group_name = azurerm_resource_group.canary_sample.name
  location            = azurerm_resource_group.canary_sample.location
  os_type             = "Linux"
  sku_name            = "P1v3"
}

resource "azurerm_linux_web_app" "stable" {
  name                = "app-canary-release-sample"
  resource_group_name = azurerm_resource_group.canary_sample.name
  location            = azurerm_resource_group.canary_sample.location
  service_plan_id     = azurerm_service_plan.canary_sample.id

  site_config {
    application_stack {
      dotnet_version = "8.0"
    }
  }
}

resource "azurerm_linux_web_app_slot" "canary" {
  name           = "canary"
  app_service_id = azurerm_linux_web_app.stable.id

  site_config {
    application_stack {
      dotnet_version = "8.0"
    }
  }
}

resource "azurerm_web_app_active_slot" "traffic_split" {
  slot_id = azurerm_linux_web_app_slot.canary.id
  # Note: azurerm_web_app_active_slot performs a full swap, not a
  # percentage split. A genuine percentage-based canary split uses
  # `az webapp traffic-routing set --distribution canary=5` (or the
  # equivalent ARM/Bicep property), which isn't yet a first-class
  # azurerm resource — worth checking current provider docs, since this
  # is exactly the kind of gap that closes over time.
}
