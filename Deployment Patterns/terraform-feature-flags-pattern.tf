# feature-flags-pattern/main.tf
#
# Minimal illustrative sample: Azure App Configuration's built-in feature
# management, which stores feature flags centrally and lets an
# application check a flag's state at runtime via the App Configuration
# SDK — no redeployment required to turn a feature on or off. The App
# Service reads its App Configuration connection string from an app
# setting, and the actual flag-checking logic lives in application code.
#
# Not production-ready as-is: production feature flag setups commonly
# add per-user or percentage-based targeting (the App Configuration
# feature filters support this) rather than a single global on/off state
# — worth designing in from the start once a flag needs to target beta
# users specifically rather than everyone at once.

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

resource "azurerm_resource_group" "flags_sample" {
  name     = "rg-feature-flags-sample"
  location = "East US"
}

resource "azurerm_app_configuration" "flags_sample" {
  name                = "appconfig-feature-flags-sample"
  resource_group_name = azurerm_resource_group.flags_sample.name
  location            = azurerm_resource_group.flags_sample.location
  sku                 = "standard" # feature flags require Standard tier
}

resource "azurerm_app_configuration_feature" "new_checkout_flow" {
  configuration_store_id = azurerm_app_configuration.flags_sample.id
  name                    = "new-checkout-flow"
  label                   = "production"
  enabled                 = false # ships OFF — turned on independently of any deploy
}

resource "azurerm_service_plan" "flags_sample" {
  name                = "asp-feature-flags-sample"
  resource_group_name = azurerm_resource_group.flags_sample.name
  location            = azurerm_resource_group.flags_sample.location
  os_type             = "Linux"
  sku_name            = "B1"
}

resource "azurerm_linux_web_app" "flags_sample" {
  name                = "app-feature-flags-sample"
  resource_group_name = azurerm_resource_group.flags_sample.name
  location            = azurerm_resource_group.flags_sample.location
  service_plan_id     = azurerm_service_plan.flags_sample.id

  site_config {
    application_stack {
      dotnet_version = "8.0"
    }
  }

  app_settings = {
    "APP_CONFIGURATION_ENDPOINT" = azurerm_app_configuration.flags_sample.endpoint
  }
}
