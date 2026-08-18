# cache-aside-pattern/main.tf
#
# Minimal illustrative sample: an App Service alongside an Azure Cache for
# Redis instance. The cache-aside logic itself — check cache, fall back to
# the database on a miss, write the result back to cache with a TTL — is
# application code; Terraform's job is standing up the cache and wiring
# its connection details into the app.
#
# Not production-ready as-is: the Basic Redis SKU used here has no SLA and
# no data persistence — production workloads typically want Standard or
# Premium, and secrets like the Redis access key belong in Key Vault, not
# a plaintext app setting the way this sample shows for brevity.

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

resource "azurerm_resource_group" "cache_sample" {
  name     = "rg-cache-aside-sample"
  location = "East US"
}

resource "azurerm_redis_cache" "cache_sample" {
  name                = "redis-cache-aside-sample"
  resource_group_name = azurerm_resource_group.cache_sample.name
  location            = azurerm_resource_group.cache_sample.location
  capacity            = 0
  family              = "C"
  sku_name            = "Basic"
  non_ssl_port_enabled = false
  minimum_tls_version = "1.2"
}

resource "azurerm_service_plan" "cache_sample" {
  name                = "asp-cache-aside-sample"
  resource_group_name = azurerm_resource_group.cache_sample.name
  location            = azurerm_resource_group.cache_sample.location
  os_type             = "Linux"
  sku_name            = "B1"
}

resource "azurerm_linux_web_app" "cache_sample" {
  name                = "app-cache-aside-sample"
  resource_group_name = azurerm_resource_group.cache_sample.name
  location            = azurerm_resource_group.cache_sample.location
  service_plan_id     = azurerm_service_plan.cache_sample.id

  site_config {
    application_stack {
      dotnet_version = "8.0"
    }
  }

  app_settings = {
    "REDIS_HOST"      = azurerm_redis_cache.cache_sample.hostname
    "REDIS_PORT"      = azurerm_redis_cache.cache_sample.ssl_port
    "REDIS_CACHE_TTL_SECONDS" = "300"
  }
}
