# retry-pattern/main.tf
#
# Minimal illustrative sample: a Function App calling into a Storage Queue,
# where the retry behavior lives in configuration (host.json) and the
# Function's own client SDK, not in the infrastructure itself. Terraform's
# job here is just standing up the pieces the retry logic runs on top of.
#
# Not production-ready as-is: no remote state backend, no networking
# hardening, and secrets are referenced via Key Vault in a real deployment
# rather than left as plain app settings. Validate against the current
# azurerm provider docs before applying.

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

resource "azurerm_resource_group" "retry_sample" {
  name     = "rg-retry-pattern-sample"
  location = "East US"
}

resource "azurerm_storage_account" "retry_sample" {
  name                     = "streetrypatternsmpl"
  resource_group_name      = azurerm_resource_group.retry_sample.name
  location                 = azurerm_resource_group.retry_sample.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

resource "azurerm_service_plan" "retry_sample" {
  name                = "asp-retry-pattern-sample"
  resource_group_name = azurerm_resource_group.retry_sample.name
  location            = azurerm_resource_group.retry_sample.location
  os_type             = "Linux"
  sku_name            = "Y1" # Consumption plan — fine for a sample, not for sustained load
}

resource "azurerm_linux_function_app" "retry_sample" {
  name                       = "func-retry-pattern-sample"
  resource_group_name        = azurerm_resource_group.retry_sample.name
  location                   = azurerm_resource_group.retry_sample.location
  service_plan_id            = azurerm_service_plan.retry_sample.id
  storage_account_name       = azurerm_storage_account.retry_sample.name
  storage_account_access_key = azurerm_storage_account.retry_sample.primary_access_key

  site_config {
    application_stack {
      dotnet_version = "8.0"
    }
  }

  app_settings = {
    # The actual retry count and backoff live in host.json for the
    # Functions runtime, or in the Polly/SDK retry policy in code —
    # this setting is just documenting intent for anyone reading the
    # portal, it isn't enforced by Terraform.
    "DOWNSTREAM_RETRY_MAX_ATTEMPTS" = "3"
    "DOWNSTREAM_RETRY_BACKOFF_MS"   = "500"
  }
}
