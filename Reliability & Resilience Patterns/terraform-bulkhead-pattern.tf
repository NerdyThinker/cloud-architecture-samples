# bulkhead-pattern/main.tf
#
# Minimal illustrative sample: two separate App Service Plans — one per
# workload tier — each hosting its own app, so a resource spike in one
# tier physically cannot consume the other tier's compute or connections.
# This is the infrastructure-level version of a bulkhead; a thread-pool
# or connection-pool-level bulkhead would live inside application code
# on top of this.
#
# Not production-ready as-is: SKUs below are small for illustration —
# pick sizes based on real load testing, and consider separate resource
# groups per tier if billing or access boundaries need to be that strict.

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

resource "azurerm_resource_group" "bulkhead_sample" {
  name     = "rg-bulkhead-sample"
  location = "East US"
}

# Pool A — premium tier, isolated capacity
resource "azurerm_service_plan" "pool_a" {
  name                = "asp-bulkhead-pool-a"
  resource_group_name = azurerm_resource_group.bulkhead_sample.name
  location            = azurerm_resource_group.bulkhead_sample.location
  os_type             = "Linux"
  sku_name            = "P1v3"
}

resource "azurerm_linux_web_app" "pool_a_app" {
  name                = "app-bulkhead-pool-a-sample"
  resource_group_name = azurerm_resource_group.bulkhead_sample.name
  location            = azurerm_resource_group.bulkhead_sample.location
  service_plan_id     = azurerm_service_plan.pool_a.id

  site_config {
    application_stack {
      dotnet_version = "8.0"
    }
  }
}

# Pool B — bulk tier, separate capacity entirely
resource "azurerm_service_plan" "pool_b" {
  name                = "asp-bulkhead-pool-b"
  resource_group_name = azurerm_resource_group.bulkhead_sample.name
  location            = azurerm_resource_group.bulkhead_sample.location
  os_type             = "Linux"
  sku_name            = "B1"
}

resource "azurerm_linux_web_app" "pool_b_app" {
  name                = "app-bulkhead-pool-b-sample"
  resource_group_name = azurerm_resource_group.bulkhead_sample.name
  location            = azurerm_resource_group.bulkhead_sample.location
  service_plan_id     = azurerm_service_plan.pool_b.id

  site_config {
    application_stack {
      dotnet_version = "8.0"
    }
  }
}
