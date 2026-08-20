# index-table-pattern/main.tf
#
# Minimal illustrative sample: two Cosmos DB containers over the same
# logical dataset — a primary container partitioned by orderId (the
# natural key for "get this specific order fast") and an index container
# partitioned by customerEmail (for "find every order for this customer"
# — a query the primary container's partitioning makes expensive, since
# it would require a cross-partition scan).
#
# Not production-ready as-is: keeping the index container in sync with
# the primary container is application code's job — typically a change
# feed-triggered Function, the same mechanism used in the Materialized
# View sample, applied here to maintain a lightweight pointer rather
# than a full denormalized copy of the record.

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

resource "azurerm_resource_group" "index_sample" {
  name     = "rg-index-table-sample"
  location = "East US"
}

resource "azurerm_cosmosdb_account" "index_sample" {
  name                = "cosmos-index-table-sample"
  resource_group_name = azurerm_resource_group.index_sample.name
  location            = azurerm_resource_group.index_sample.location
  offer_type          = "Standard"

  consistency_policy {
    consistency_level = "Session"
  }

  geo_location {
    location          = azurerm_resource_group.index_sample.location
    failover_priority = 0
  }
}

resource "azurerm_cosmosdb_sql_database" "index_sample" {
  name                = "orders-app"
  resource_group_name = azurerm_resource_group.index_sample.name
  account_name        = azurerm_cosmosdb_account.index_sample.name
}

resource "azurerm_cosmosdb_sql_container" "primary" {
  name                = "orders-primary"
  resource_group_name = azurerm_resource_group.index_sample.name
  account_name        = azurerm_cosmosdb_account.index_sample.name
  database_name       = azurerm_cosmosdb_sql_database.index_sample.name
  partition_key_paths = ["/orderId"]
}

resource "azurerm_cosmosdb_sql_container" "email_index" {
  name                = "orders-by-email-index"
  resource_group_name = azurerm_resource_group.index_sample.name
  account_name        = azurerm_cosmosdb_account.index_sample.name
  database_name       = azurerm_cosmosdb_sql_database.index_sample.name
  partition_key_paths = ["/customerEmail"]
  # Holds { customerEmail, orderId } pointers only — the caller fetches
  # the full record from the primary container after resolving the id.
}

resource "azurerm_storage_account" "index_sample" {
  name                     = "stindextablesmpl"
  resource_group_name      = azurerm_resource_group.index_sample.name
  location                 = azurerm_resource_group.index_sample.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

resource "azurerm_service_plan" "index_sample" {
  name                = "asp-index-table-sample"
  resource_group_name = azurerm_resource_group.index_sample.name
  location            = azurerm_resource_group.index_sample.location
  os_type             = "Linux"
  sku_name            = "Y1"
}

resource "azurerm_linux_function_app" "index_maintainer" {
  name                       = "func-index-table-sample"
  resource_group_name        = azurerm_resource_group.index_sample.name
  location                   = azurerm_resource_group.index_sample.location
  service_plan_id            = azurerm_service_plan.index_sample.id
  storage_account_name       = azurerm_storage_account.index_sample.name
  storage_account_access_key = azurerm_storage_account.index_sample.primary_access_key

  site_config {
    application_stack {
      dotnet_version = "8.0"
    }
  }

  app_settings = {
    "PRIMARY_CONTAINER" = azurerm_cosmosdb_sql_container.primary.name
    "INDEX_CONTAINER"   = azurerm_cosmosdb_sql_container.email_index.name
  }
}
