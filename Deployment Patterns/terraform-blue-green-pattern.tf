# blue-green-deployment-pattern/main.tf
#
# Minimal illustrative sample: an App Service with a single deployment
# slot named "green" alongside the default production slot ("blue" in
# this metaphor). Both slots run full, independent copies of the app;
# a slot swap moves 100% of traffic from one to the other, and swapping
# back is the rollback mechanism — no redeployment needed under pressure.
#
# Not production-ready as-is: real slot swaps typically include a
# warm-up step (App Service's auto-swap or an explicit health check
# against the target slot) before completing the swap, so traffic never
# hits a cold-started instance mid-cutover.

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

resource "azurerm_resource_group" "bg_sample" {
  name     = "rg-blue-green-sample"
  location = "East US"
}

resource "azurerm_service_plan" "bg_sample" {
  name                = "asp-blue-green-sample"
  resource_group_name = azurerm_resource_group.bg_sample.name
  location            = azurerm_resource_group.bg_sample.location
  os_type             = "Linux"
  sku_name            = "P1v3" # deployment slots require Standard tier or above
}

resource "azurerm_linux_web_app" "production" {
  name                = "app-blue-green-sample"
  resource_group_name = azurerm_resource_group.bg_sample.name
  location            = azurerm_resource_group.bg_sample.location
  service_plan_id     = azurerm_service_plan.bg_sample.id

  site_config {
    application_stack {
      dotnet_version = "8.0"
    }
  }
}

resource "azurerm_linux_web_app_slot" "green" {
  name           = "green"
  app_service_id = azurerm_linux_web_app.production.id

  site_config {
    application_stack {
      dotnet_version = "8.0"
    }
  }
}

# The swap itself is an operation, not a static resource — performed via
# `az webapp deployment slot swap` or the equivalent Azure DevOps/GitHub
# Actions task once the green slot has been validated.
