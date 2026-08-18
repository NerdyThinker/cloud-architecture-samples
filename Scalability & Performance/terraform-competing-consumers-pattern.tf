# competing-consumers-pattern/main.tf
#
# Minimal illustrative sample: a Service Bus queue feeding a Function App
# on a Consumption plan. Azure Functions scales the number of instances
# pulling from the queue automatically based on queue depth — that
# autoscaling is what actually produces multiple "competing" consumers.
# Service Bus itself guarantees a given message is delivered to exactly
# one of them, so no coordination code is needed between instances.
#
# Not production-ready as-is: max concurrent calls and the scaling
# ceiling are controlled via host.json (maxConcurrentCalls) and the
# Function App's scale-out settings, not shown here — tune both against
# real load rather than the defaults.

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

resource "azurerm_resource_group" "cc_sample" {
  name     = "rg-competing-consumers-sample"
  location = "East US"
}

resource "azurerm_servicebus_namespace" "cc_sample" {
  name                = "sb-competing-consumers-sample"
  resource_group_name = azurerm_resource_group.cc_sample.name
  location            = azurerm_resource_group.cc_sample.location
  sku                 = "Standard"
}

resource "azurerm_servicebus_queue" "work_queue" {
  name         = "work-items"
  namespace_id = azurerm_servicebus_namespace.cc_sample.id
}

resource "azurerm_storage_account" "cc_sample" {
  name                     = "stcompetingconsmpl"
  resource_group_name      = azurerm_resource_group.cc_sample.name
  location                 = azurerm_resource_group.cc_sample.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

resource "azurerm_service_plan" "cc_sample" {
  name                = "asp-competing-consumers-sample"
  resource_group_name = azurerm_resource_group.cc_sample.name
  location            = azurerm_resource_group.cc_sample.location
  os_type             = "Linux"
  sku_name            = "Y1" # Consumption — instance count scales with queue depth
}

resource "azurerm_linux_function_app" "consumers" {
  name                       = "func-competing-consumers-sample"
  resource_group_name        = azurerm_resource_group.cc_sample.name
  location                   = azurerm_resource_group.cc_sample.location
  service_plan_id            = azurerm_service_plan.cc_sample.id
  storage_account_name       = azurerm_storage_account.cc_sample.name
  storage_account_access_key = azurerm_storage_account.cc_sample.primary_access_key

  site_config {
    application_stack {
      dotnet_version = "8.0"
    }
  }

  app_settings = {
    "ServiceBusConnection__fullyQualifiedNamespace" = "${azurerm_servicebus_namespace.cc_sample.name}.servicebus.windows.net"
    "WORK_QUEUE_NAME"                                = azurerm_servicebus_queue.work_queue.name
  }
}
