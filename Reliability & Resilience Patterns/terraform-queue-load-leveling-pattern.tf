# queue-based-load-leveling-pattern/main.tf
#
# Minimal illustrative sample: a Storage Queue sitting between a producer
# and a queue-triggered Function App consumer. The producer writes to the
# queue and moves on immediately; the Function App drains it at whatever
# pace its scaling configuration allows, decoupling arrival rate from
# processing rate entirely.
#
# Not production-ready as-is: for higher-throughput or ordering-sensitive
# scenarios, Service Bus queues (with sessions, dead-lettering, and
# duplicate detection) are usually a better fit than Storage Queues —
# this sample uses Storage Queues because they're the simplest to stand
# up for a demonstration.

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

resource "azurerm_resource_group" "qbll_sample" {
  name     = "rg-queue-load-leveling-sample"
  location = "East US"
}

resource "azurerm_storage_account" "qbll_sample" {
  name                     = "stqbllpatternsmpl"
  resource_group_name      = azurerm_resource_group.qbll_sample.name
  location                 = azurerm_resource_group.qbll_sample.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

resource "azurerm_storage_queue" "work_queue" {
  name                 = "work-items"
  storage_account_name = azurerm_storage_account.qbll_sample.name
}

resource "azurerm_service_plan" "qbll_sample" {
  name                = "asp-queue-load-leveling-sample"
  resource_group_name = azurerm_resource_group.qbll_sample.name
  location            = azurerm_resource_group.qbll_sample.location
  os_type             = "Linux"
  sku_name            = "Y1" # Consumption — scales to zero and up automatically
}

resource "azurerm_linux_function_app" "consumer" {
  name                       = "func-qbll-consumer-sample"
  resource_group_name        = azurerm_resource_group.qbll_sample.name
  location                   = azurerm_resource_group.qbll_sample.location
  service_plan_id            = azurerm_service_plan.qbll_sample.id
  storage_account_name       = azurerm_storage_account.qbll_sample.name
  storage_account_access_key = azurerm_storage_account.qbll_sample.primary_access_key

  site_config {
    application_stack {
      dotnet_version = "8.0"
    }
  }

  app_settings = {
    # The consumer Function is queue-triggered against "work-items" in code
    # (via the QueueTrigger binding) — this setting just documents which
    # queue it's wired to for anyone reading the app settings.
    "WORK_QUEUE_NAME" = azurerm_storage_queue.work_queue.name
  }
}
