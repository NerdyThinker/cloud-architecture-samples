# scatter-gather-pattern/main.tf
#
# Minimal illustrative sample: an aggregator Function App that fans a
# single incoming request out to multiple downstream calls in parallel,
# then waits for responses up to a bounded timeout before returning
# whatever arrived. The three downstream "providers" are represented as
# app settings holding their URLs, standing in for services that would
# realistically live outside this Terraform's scope entirely (third-party
# APIs, in this pattern's classic use case).
#
# Not production-ready as-is: the fan-out and timeout-bounded gathering
# logic is application code — issuing the parallel calls, applying a
# per-call timeout, and assembling whatever responses arrived in time —
# not something Terraform or Azure infrastructure enforces on its own.

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

resource "azurerm_resource_group" "sg_sample" {
  name     = "rg-scatter-gather-sample"
  location = "East US"
}

resource "azurerm_storage_account" "sg_sample" {
  name                     = "stscattergathersmpl"
  resource_group_name      = azurerm_resource_group.sg_sample.name
  location                 = azurerm_resource_group.sg_sample.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

resource "azurerm_service_plan" "sg_sample" {
  name                = "asp-scatter-gather-sample"
  resource_group_name = azurerm_resource_group.sg_sample.name
  location            = azurerm_resource_group.sg_sample.location
  os_type             = "Linux"
  sku_name            = "Y1"
}

resource "azurerm_linux_function_app" "aggregator" {
  name                       = "func-scatter-gather-sample"
  resource_group_name        = azurerm_resource_group.sg_sample.name
  location                   = azurerm_resource_group.sg_sample.location
  service_plan_id            = azurerm_service_plan.sg_sample.id
  storage_account_name       = azurerm_storage_account.sg_sample.name
  storage_account_access_key = azurerm_storage_account.sg_sample.primary_access_key

  site_config {
    application_stack {
      dotnet_version = "8.0"
    }
  }

  app_settings = {
    "PROVIDER_A_URL"           = "https://provider-a.example.com/quote"
    "PROVIDER_B_URL"           = "https://provider-b.example.com/quote"
    "PROVIDER_C_URL"           = "https://provider-c.example.com/quote"
    "GATHER_TIMEOUT_MS"        = "2000"
    "MIN_RESPONSES_TO_PROCEED" = "2"
  }
}
