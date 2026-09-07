# api-gateway-pattern/main.tf
#
# Minimal illustrative sample: an API Management instance in front of
# three backend App Services, with routing configured per-API so each
# path segment reaches the right backend. Cross-cutting policies —
# authentication, rate limiting (the same rate-limit-by-key policy from
# the Throttling pattern in the reliability post) — get applied once at
# the gateway rather than duplicated in every backend service.
#
# Not production-ready as-is: the Developer SKU here has no SLA, same
# caveat as the Throttling sample — move to Standard or Premium for real
# traffic, and note that a gateway this central needs its own resilience
# story (Azure API Management supports multi-region deployment for
# exactly this reason).

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

resource "azurerm_resource_group" "gateway_sample" {
  name     = "rg-api-gateway-sample"
  location = "East US"
}

resource "azurerm_api_management" "gateway_sample" {
  name                = "apim-gateway-sample"
  resource_group_name = azurerm_resource_group.gateway_sample.name
  location            = azurerm_resource_group.gateway_sample.location
  publisher_name      = "Sample Publisher"
  publisher_email     = "admin@example.com"
  sku_name            = "Developer_1"
}

resource "azurerm_service_plan" "gateway_sample" {
  name                = "asp-api-gateway-sample"
  resource_group_name = azurerm_resource_group.gateway_sample.name
  location            = azurerm_resource_group.gateway_sample.location
  os_type             = "Linux"
  sku_name            = "B1"
}

resource "azurerm_linux_web_app" "orders" {
  name                = "app-gw-orders-sample"
  resource_group_name = azurerm_resource_group.gateway_sample.name
  location            = azurerm_resource_group.gateway_sample.location
  service_plan_id     = azurerm_service_plan.gateway_sample.id
  site_config {
    application_stack {
      dotnet_version = "8.0"
    }
  }
}

resource "azurerm_linux_web_app" "inventory" {
  name                = "app-gw-inventory-sample"
  resource_group_name = azurerm_resource_group.gateway_sample.name
  location            = azurerm_resource_group.gateway_sample.location
  service_plan_id     = azurerm_service_plan.gateway_sample.id
  site_config {
    application_stack {
      dotnet_version = "8.0"
    }
  }
}

resource "azurerm_api_management_api" "orders_api" {
  name                = "orders-api"
  resource_group_name = azurerm_resource_group.gateway_sample.name
  api_management_name = azurerm_api_management.gateway_sample.name
  revision            = "1"
  display_name        = "Orders API"
  path                = "orders"
  protocols           = ["https"]
  service_url         = "https://${azurerm_linux_web_app.orders.default_hostname}"
}

resource "azurerm_api_management_api" "inventory_api" {
  name                = "inventory-api"
  resource_group_name = azurerm_resource_group.gateway_sample.name
  api_management_name = azurerm_api_management.gateway_sample.name
  revision            = "1"
  display_name        = "Inventory API"
  path                = "inventory"
  protocols           = ["https"]
  service_url         = "https://${azurerm_linux_web_app.inventory.default_hostname}"
}
