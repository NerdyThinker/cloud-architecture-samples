# outbox-pattern/main.tf
#
# Minimal illustrative sample: an Azure SQL database holding both the
# business table (orders) and an outbox table in the same schema, so a
# single local transaction can write to both atomically. A timer-triggered
# Function App polls the outbox table for unprocessed rows, publishes
# each one to Service Bus, and marks it processed — the relay described
# in the diagram.
#
# Not production-ready as-is: polling on a timer works for a demo but
# introduces latency between the write and the publish; a production
# setup often uses Change Data Capture or Cosmos DB's change feed
# instead of polling, to relay new outbox rows closer to real time.
# The relay also needs idempotent publishing — a crash between "publish"
# and "mark processed" must not result in a duplicate downstream event
# being treated as two separate ones.

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

resource "azurerm_resource_group" "outbox_sample" {
  name     = "rg-outbox-sample"
  location = "East US"
}

resource "azurerm_mssql_server" "outbox_sample" {
  name                         = "sql-outbox-sample"
  resource_group_name         = azurerm_resource_group.outbox_sample.name
  location                     = azurerm_resource_group.outbox_sample.location
  version                      = "12.0"
  administrator_login          = "outboxadmin"
  administrator_login_password = "ReplaceWithKeyVaultSecret!123"
}

resource "azurerm_mssql_database" "outbox_sample" {
  name      = "outbox-sample-db"
  server_id = azurerm_mssql_server.outbox_sample.id
  sku_name  = "S0"
  # The `orders` table and the `outbox` table both live in this single
  # database — that's what makes the atomic write possible. Table DDL
  # itself is applied via a migration tool, not Terraform.
}

resource "azurerm_servicebus_namespace" "outbox_sample" {
  name                = "sb-outbox-sample"
  resource_group_name = azurerm_resource_group.outbox_sample.name
  location            = azurerm_resource_group.outbox_sample.location
  sku                 = "Standard"
}

resource "azurerm_servicebus_topic" "domain_events" {
  name         = "domain-events"
  namespace_id = azurerm_servicebus_namespace.outbox_sample.id
}

resource "azurerm_storage_account" "outbox_sample" {
  name                     = "stoutboxpatternsmpl"
  resource_group_name      = azurerm_resource_group.outbox_sample.name
  location                 = azurerm_resource_group.outbox_sample.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

resource "azurerm_service_plan" "outbox_sample" {
  name                = "asp-outbox-sample"
  resource_group_name = azurerm_resource_group.outbox_sample.name
  location            = azurerm_resource_group.outbox_sample.location
  os_type             = "Linux"
  sku_name            = "Y1"
}

resource "azurerm_linux_function_app" "relay" {
  name                       = "func-outbox-relay-sample"
  resource_group_name        = azurerm_resource_group.outbox_sample.name
  location                   = azurerm_resource_group.outbox_sample.location
  service_plan_id            = azurerm_service_plan.outbox_sample.id
  storage_account_name       = azurerm_storage_account.outbox_sample.name
  storage_account_access_key = azurerm_storage_account.outbox_sample.primary_access_key

  site_config {
    application_stack {
      dotnet_version = "8.0"
    }
  }

  app_settings = {
    # A TimerTrigger function in code polls the outbox table on this
    # schedule — every 10 seconds, illustrative only.
    "OUTBOX_POLL_SCHEDULE" = "*/10 * * * * *"
  }
}
