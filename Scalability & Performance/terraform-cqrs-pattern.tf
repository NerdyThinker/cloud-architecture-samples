# cqrs-pattern/main.tf
#
# Minimal illustrative sample: separate write and read APIs backed by
# separate data stores — an Azure SQL database for the normalized,
# transactional write side, and a Cosmos DB container for the
# denormalized, query-optimized read side. A Service Bus topic stands in
# for the sync mechanism that propagates writes into the read store;
# the actual projection logic (turning a write event into an updated
# read-model document) is application code, typically a small Function
# subscribed to the topic.
#
# Not production-ready as-is: the SQL admin credentials below are for
# illustration only — use Azure AD authentication or Key Vault-sourced
# secrets in a real deployment, never a hardcoded password.

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

resource "azurerm_resource_group" "cqrs_sample" {
  name     = "rg-cqrs-sample"
  location = "East US"
}

# Write side
resource "azurerm_mssql_server" "write_store" {
  name                         = "sql-cqrs-write-sample"
  resource_group_name          = azurerm_resource_group.cqrs_sample.name
  location                     = azurerm_resource_group.cqrs_sample.location
  version                      = "12.0"
  administrator_login          = "cqrsadmin"
  administrator_login_password = "ReplaceWithKeyVaultSecret!123"
}

resource "azurerm_mssql_database" "write_store" {
  name      = "cqrs-write-db"
  server_id = azurerm_mssql_server.write_store.id
  sku_name  = "S0"
}

# Read side
resource "azurerm_cosmosdb_account" "read_store" {
  name                = "cosmos-cqrs-read-sample"
  resource_group_name = azurerm_resource_group.cqrs_sample.name
  location            = azurerm_resource_group.cqrs_sample.location
  offer_type          = "Standard"

  consistency_policy {
    consistency_level = "Session"
  }

  geo_location {
    location          = azurerm_resource_group.cqrs_sample.location
    failover_priority = 0
  }
}

# Sync mechanism between write and read sides
resource "azurerm_servicebus_namespace" "cqrs_sample" {
  name                = "sb-cqrs-sample"
  resource_group_name = azurerm_resource_group.cqrs_sample.name
  location            = azurerm_resource_group.cqrs_sample.location
  sku                 = "Standard"
}

resource "azurerm_servicebus_topic" "write_events" {
  name         = "write-events"
  namespace_id = azurerm_servicebus_namespace.cqrs_sample.id
}
