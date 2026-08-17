# throttling-pattern/main.tf
#
# Minimal illustrative sample: an API Management instance fronting a
# backend App Service, with a rate-limit policy applied at the API level.
# APIM enforces the limit before a request ever reaches the backend,
# which is the point — the backend never has to know throttling exists.
#
# Not production-ready as-is: APIM's Developer tier (used here to keep
# the sample cheap to stand up) has no SLA and isn't meant for production
# traffic — move to Basic/Standard/Premium tiers for anything real, and
# tune the rate-limit policy's calls/renewal-period to your actual
# backend's tested capacity, not a guess.

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

resource "azurerm_resource_group" "throttle_sample" {
  name     = "rg-throttling-sample"
  location = "East US"
}

resource "azurerm_service_plan" "throttle_sample" {
  name                = "asp-throttling-sample"
  resource_group_name = azurerm_resource_group.throttle_sample.name
  location            = azurerm_resource_group.throttle_sample.location
  os_type             = "Linux"
  sku_name            = "B1"
}

resource "azurerm_linux_web_app" "backend" {
  name                = "app-throttling-backend-sample"
  resource_group_name = azurerm_resource_group.throttle_sample.name
  location            = azurerm_resource_group.throttle_sample.location
  service_plan_id     = azurerm_service_plan.throttle_sample.id

  site_config {
    application_stack {
      dotnet_version = "8.0"
    }
  }
}

resource "azurerm_api_management" "throttle_sample" {
  name                = "apim-throttling-sample"
  resource_group_name = azurerm_resource_group.throttle_sample.name
  location            = azurerm_resource_group.throttle_sample.location
  publisher_name      = "Sample Publisher"
  publisher_email     = "admin@example.com"
  sku_name            = "Developer_1"
}

resource "azurerm_api_management_api" "backend_api" {
  name                = "backend-api"
  resource_group_name = azurerm_resource_group.throttle_sample.name
  api_management_name = azurerm_api_management.throttle_sample.name
  revision            = "1"
  display_name        = "Backend API"
  path                = "backend"
  protocols           = ["https"]
  service_url         = "https://${azurerm_linux_web_app.backend.default_hostname}"
}

resource "azurerm_api_management_api_policy" "rate_limit" {
  api_name            = azurerm_api_management_api.backend_api.name
  api_management_name = azurerm_api_management.throttle_sample.name
  resource_group_name = azurerm_resource_group.throttle_sample.name

  xml_content = <<XML
<policies>
  <inbound>
    <base />
    <rate-limit-by-key calls="100" renewal-period="60"
      counter-key="@(context.Subscription.Key)" />
  </inbound>
  <backend><base /></backend>
  <outbound><base /></outbound>
  <on-error><base /></on-error>
</policies>
XML
}
