# deployment-stamps-pattern/main.tf
#
# Minimal illustrative sample: two independent regional "stamps," each
# with its own App Service, tied together by an Azure Front Door profile
# that routes traffic to whichever stamp is healthy and closest. Adding a
# third stamp for a new region means adding a new entry to the `regions`
# map below — nothing else in this file changes, which is the point of
# the pattern: the stamp is the unit of both scale and deployment.
#
# Not production-ready as-is: each stamp here has just an App Service for
# clarity — a real stamp typically also includes its own regional database
# and storage, per the diagram, and Front Door's routing/health-probe
# configuration needs real tuning for genuine failover behavior.

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

locals {
  regions = {
    eastus       = "East US"
    westeurope   = "West Europe"
  }
}

resource "azurerm_resource_group" "stamp" {
  for_each = local.regions
  name     = "rg-stamp-${each.key}"
  location = each.value
}

resource "azurerm_service_plan" "stamp" {
  for_each            = local.regions
  name                = "asp-stamp-${each.key}"
  resource_group_name = azurerm_resource_group.stamp[each.key].name
  location            = azurerm_resource_group.stamp[each.key].location
  os_type             = "Linux"
  sku_name            = "B1"
}

resource "azurerm_linux_web_app" "stamp" {
  for_each            = local.regions
  name                = "app-stamp-${each.key}-sample"
  resource_group_name = azurerm_resource_group.stamp[each.key].name
  location            = azurerm_resource_group.stamp[each.key].location
  service_plan_id     = azurerm_service_plan.stamp[each.key].id

  site_config {
    application_stack {
      dotnet_version = "8.0"
    }
  }
}

resource "azurerm_cdn_frontdoor_profile" "stamps" {
  name                = "fd-deployment-stamps-sample"
  resource_group_name = azurerm_resource_group.stamp["eastus"].name
  sku_name            = "Standard_AzureFrontDoor"
}

# In a full sample, each stamp's App Service would be registered as an
# azurerm_cdn_frontdoor_origin under a shared origin group, with Front
# Door's health probe path pointed at each stamp's own /health endpoint —
# tying this pattern directly back to Health Endpoint Monitoring above.
