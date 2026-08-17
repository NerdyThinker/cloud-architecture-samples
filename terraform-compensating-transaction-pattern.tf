# compensating-transaction-pattern/main.tf
#
# Minimal illustrative sample: infrastructure for a Durable Functions app,
# which is Azure's native fit for orchestrating a multi-step process and
# running compensation logic when a step fails partway through. The
# orchestrator function, the activity functions (BookFlight, BookHotel,
# ChargePayment), and the compensation activities (CancelFlight,
# CancelHotel) are all application code deployed to this Function App —
# Terraform just provisions the durable-task storage and hosting plan.
#
# Not production-ready as-is: Durable Functions needs a storage account
# for its task hub state, shown below, and a real deployment should pin
# the task hub name explicitly rather than rely on the default, to avoid
# collisions if you ever run two versions of this orchestration side by side.

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

resource "azurerm_resource_group" "saga_sample" {
  name     = "rg-compensating-transaction-sample"
  location = "East US"
}

resource "azurerm_storage_account" "saga_sample" {
  name                     = "stsagapatternsmpl"
  resource_group_name      = azurerm_resource_group.saga_sample.name
  location                 = azurerm_resource_group.saga_sample.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

resource "azurerm_service_plan" "saga_sample" {
  name                = "asp-compensating-transaction-sample"
  resource_group_name = azurerm_resource_group.saga_sample.name
  location            = azurerm_resource_group.saga_sample.location
  os_type             = "Linux"
  sku_name            = "Y1"
}

resource "azurerm_linux_function_app" "orchestrator" {
  name                       = "func-saga-orchestrator-sample"
  resource_group_name        = azurerm_resource_group.saga_sample.name
  location                   = azurerm_resource_group.saga_sample.location
  service_plan_id            = azurerm_service_plan.saga_sample.id
  storage_account_name       = azurerm_storage_account.saga_sample.name
  storage_account_access_key = azurerm_storage_account.saga_sample.primary_access_key

  site_config {
    application_stack {
      dotnet_version = "8.0"
    }
  }

  app_settings = {
    "AzureFunctionsJobHost__extensions__durableTask__hubName" = "BookingSagaHub"
  }
}
