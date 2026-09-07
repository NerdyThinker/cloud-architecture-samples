# anti-corruption-layer-pattern/main.tf
#
# Minimal illustrative sample: a standalone App Service whose entire job
# is translation — accepting requests in the new service's clean domain
# model and translating them into whatever shape the legacy system
# actually expects, then translating its response back. The new service
# never calls the legacy system directly; it only ever talks to this
# layer.
#
# Not production-ready as-is: the translation logic itself (mapping
# Customer/Order/LineItem to CUST_REC/ORD_HDR/ORD_LN, or whatever the
# real legacy schema looks like) is entirely application code — this
# infrastructure just provisions the service boundary the translation
# runs inside.

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

resource "azurerm_resource_group" "acl_sample" {
  name     = "rg-anti-corruption-layer-sample"
  location = "East US"
}

resource "azurerm_service_plan" "acl_sample" {
  name                = "asp-anti-corruption-layer-sample"
  resource_group_name = azurerm_resource_group.acl_sample.name
  location            = azurerm_resource_group.acl_sample.location
  os_type             = "Linux"
  sku_name            = "B1"
}

resource "azurerm_linux_web_app" "acl_sample" {
  name                = "app-anti-corruption-layer-sample"
  resource_group_name = azurerm_resource_group.acl_sample.name
  location            = azurerm_resource_group.acl_sample.location
  service_plan_id     = azurerm_service_plan.acl_sample.id

  site_config {
    application_stack {
      dotnet_version = "8.0"
    }
  }

  app_settings = {
    # The legacy system's connection details live here, isolated to this
    # layer — the new service's code has no knowledge this even exists.
    "LEGACY_SYSTEM_ENDPOINT" = "https://legacy-mainframe.internal.example.com"
  }
}
