# strangler-fig-pattern/main.tf
#
# Minimal illustrative sample: an Azure Front Door profile acting as the
# routing facade, sending some paths to a legacy backend and others to a
# new service, based on path-pattern rules. Migrating another route means
# adding another routing rule pointing at the new service instead of the
# legacy one — nothing about the client, or the routes not yet migrated,
# has to change.
#
# Not production-ready as-is: only two illustrative routes are shown
# here (/api/orders/* migrated, everything else still legacy) — a real
# migration tracks many such rules over time, and needs a clear plan for
# what happens to data the legacy system still owns while routes are
# transitioning.

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

resource "azurerm_resource_group" "strangler_sample" {
  name     = "rg-strangler-fig-sample"
  location = "East US"
}

resource "azurerm_service_plan" "strangler_sample" {
  name                = "asp-strangler-fig-sample"
  resource_group_name = azurerm_resource_group.strangler_sample.name
  location            = azurerm_resource_group.strangler_sample.location
  os_type             = "Linux"
  sku_name            = "B1"
}

resource "azurerm_linux_web_app" "legacy_monolith" {
  name                = "app-strangler-legacy-sample"
  resource_group_name = azurerm_resource_group.strangler_sample.name
  location            = azurerm_resource_group.strangler_sample.location
  service_plan_id     = azurerm_service_plan.strangler_sample.id
  site_config {
    application_stack {
      dotnet_version = "8.0"
    }
  }
}

resource "azurerm_linux_web_app" "new_orders_service" {
  name                = "app-strangler-new-orders-sample"
  resource_group_name = azurerm_resource_group.strangler_sample.name
  location            = azurerm_resource_group.strangler_sample.location
  service_plan_id     = azurerm_service_plan.strangler_sample.id
  site_config {
    application_stack {
      dotnet_version = "8.0"
    }
  }
}

resource "azurerm_cdn_frontdoor_profile" "strangler_sample" {
  name                = "fd-strangler-fig-sample"
  resource_group_name = azurerm_resource_group.strangler_sample.name
  sku_name            = "Standard_AzureFrontDoor"
}

# In a full deployment, azurerm_cdn_frontdoor_route resources would map
# /api/orders/* to new_orders_service and everything else (/*) to
# legacy_monolith — the routing table IS the migration plan, and updating
# it is how each subsequent route gets "strangled" away from the legacy system.
