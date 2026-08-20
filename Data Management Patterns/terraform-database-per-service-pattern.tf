# database-per-service-pattern/main.tf
#
# Minimal illustrative sample: three services, each with its own
# dedicated database using whichever engine actually fits its access
# pattern — SQL for Orders (relational, transactional), Cosmos DB for
# Inventory (flexible schema, high write throughput), Table Storage for
# Shipping (simple key-based lookups, cheapest option). Nothing in this
# file gives any service's identity access to another service's
# database — that boundary is enforced by simply never granting it,
# not by a network rule alone.
#
# Not production-ready as-is: for a real deployment, each service's
# managed identity (see the Managed Identities post) would be granted
# access to only its own database via RBAC role assignments, which
# aren't shown here for brevity but are exactly the mechanism that
# makes "no direct cross-service DB access" actually enforceable rather
# than just a convention everyone agrees to follow.

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

resource "azurerm_resource_group" "dbps_sample" {
  name     = "rg-database-per-service-sample"
  location = "East US"
}

# Order Service — SQL
resource "azurerm_mssql_server" "orders" {
  name                         = "sql-orders-service-sample"
  resource_group_name          = azurerm_resource_group.dbps_sample.name
  location                     = azurerm_resource_group.dbps_sample.location
  version                      = "12.0"
  administrator_login          = "ordersadmin"
  administrator_login_password = "ReplaceWithKeyVaultSecret!123"
}

resource "azurerm_mssql_database" "orders" {
  name      = "orders-db"
  server_id = azurerm_mssql_server.orders.id
  sku_name  = "S0"
}

# Inventory Service — Cosmos DB
resource "azurerm_cosmosdb_account" "inventory" {
  name                = "cosmos-inventory-service-sample"
  resource_group_name = azurerm_resource_group.dbps_sample.name
  location            = azurerm_resource_group.dbps_sample.location
  offer_type          = "Standard"

  consistency_policy {
    consistency_level = "Session"
  }

  geo_location {
    location          = azurerm_resource_group.dbps_sample.location
    failover_priority = 0
  }
}

# Shipping Service — Table Storage
resource "azurerm_storage_account" "shipping" {
  name                     = "stshippingservicesmpl"
  resource_group_name      = azurerm_resource_group.dbps_sample.name
  location                 = azurerm_resource_group.dbps_sample.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

resource "azurerm_storage_table" "shipping" {
  name                 = "shipments"
  storage_account_name = azurerm_storage_account.shipping.name
}
