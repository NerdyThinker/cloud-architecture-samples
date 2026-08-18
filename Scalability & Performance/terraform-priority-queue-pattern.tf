# priority-queue-pattern/main.tf
#
# Minimal illustrative sample: two separate Service Bus queues — one for
# high-priority work, one for standard-priority work — with a single
# consumer Function App that always drains the high-priority queue first.
# Using two physically separate queues, rather than one queue with a
# priority field, is what actually prevents low-priority messages from
# blocking high-priority ones; the consumer's polling order enforces the
# guarantee, not a sort operation on a mixed queue.
#
# Not production-ready as-is: the consumer's "check high-priority first"
# logic is application code — a common approach is polling the
# high-priority queue with a short timeout before falling back to the
# standard queue, rather than committing to one queue exclusively.

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

resource "azurerm_resource_group" "pq_sample" {
  name     = "rg-priority-queue-sample"
  location = "East US"
}

resource "azurerm_servicebus_namespace" "pq_sample" {
  name                = "sb-priority-queue-sample"
  resource_group_name = azurerm_resource_group.pq_sample.name
  location            = azurerm_resource_group.pq_sample.location
  sku                 = "Standard"
}

resource "azurerm_servicebus_queue" "high_priority" {
  name         = "high-priority"
  namespace_id = azurerm_servicebus_namespace.pq_sample.id
}

resource "azurerm_servicebus_queue" "standard_priority" {
  name         = "standard-priority"
  namespace_id = azurerm_servicebus_namespace.pq_sample.id
}

resource "azurerm_storage_account" "pq_sample" {
  name                     = "stpriorityqueuesmpl"
  resource_group_name      = azurerm_resource_group.pq_sample.name
  location                 = azurerm_resource_group.pq_sample.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

resource "azurerm_service_plan" "pq_sample" {
  name                = "asp-priority-queue-sample"
  resource_group_name = azurerm_resource_group.pq_sample.name
  location            = azurerm_resource_group.pq_sample.location
  os_type             = "Linux"
  sku_name            = "Y1"
}

resource "azurerm_linux_function_app" "consumer" {
  name                       = "func-priority-queue-sample"
  resource_group_name        = azurerm_resource_group.pq_sample.name
  location                   = azurerm_resource_group.pq_sample.location
  service_plan_id            = azurerm_service_plan.pq_sample.id
  storage_account_name       = azurerm_storage_account.pq_sample.name
  storage_account_access_key = azurerm_storage_account.pq_sample.primary_access_key

  site_config {
    application_stack {
      dotnet_version = "8.0"
    }
  }

  app_settings = {
    "HIGH_PRIORITY_QUEUE"     = azurerm_servicebus_queue.high_priority.name
    "STANDARD_PRIORITY_QUEUE" = azurerm_servicebus_queue.standard_priority.name
  }
}
