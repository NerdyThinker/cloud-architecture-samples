# materialized-view-pattern/main.tf
#
# Minimal illustrative sample: a source Cosmos DB container with change
# feed enabled (on by default for Cosmos SQL API containers), a Function
# App wired to that change feed, and a second Cosmos container holding
# the precomputed, denormalized view. Every write to the source container
# triggers the Function, which recomputes and writes the affected part of
# the materialized view — the view stays eventually consistent with the
# source, not instantly consistent.
#
# Not production-ready as-is: the projection logic (how a source write
# turns into a view update) is application code inside the Function;
# what's provisioned here is just the two containers and the Function App
# wired to the change feed trigger.

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

resource "azurerm_resource_group" "mv_sample" {
  name     = "rg-materialized-view-sample"
  location = "East US"
}

resource "azurerm_cosmosdb_account" "mv_sample" {
  name                = "cosmos-materialized-view-sample"
  resource_group_name = azurerm_resource_group.mv_sample.name
  location            = azurerm_resource_group.mv_sample.location
  offer_type          = "Standard"

  consistency_policy {
    consistency_level = "Session"
  }

  geo_location {
    location          = azurerm_resource_group.mv_sample.location
    failover_priority = 0
  }
}

resource "azurerm_cosmosdb_sql_database" "mv_sample" {
  name                = "orders-app"
  resource_group_name = azurerm_resource_group.mv_sample.name
  account_name        = azurerm_cosmosdb_account.mv_sample.name
}

resource "azurerm_cosmosdb_sql_container" "source" {
  name                = "orders-source"
  resource_group_name = azurerm_resource_group.mv_sample.name
  account_name        = azurerm_cosmosdb_account.mv_sample.name
  database_name       = azurerm_cosmosdb_sql_database.mv_sample.name
  partition_key_paths = ["/orderId"]
}

resource "azurerm_cosmosdb_sql_container" "materialized_view" {
  name                = "customer-order-summary-view"
  resource_group_name = azurerm_resource_group.mv_sample.name
  account_name        = azurerm_cosmosdb_account.mv_sample.name
  database_name       = azurerm_cosmosdb_sql_database.mv_sample.name
  partition_key_paths = ["/customerId"]
}

resource "azurerm_storage_account" "mv_sample" {
  name                     = "stmaterializedvwsmpl"
  resource_group_name      = azurerm_resource_group.mv_sample.name
  location                 = azurerm_resource_group.mv_sample.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

resource "azurerm_service_plan" "mv_sample" {
  name                = "asp-materialized-view-sample"
  resource_group_name = azurerm_resource_group.mv_sample.name
  location            = azurerm_resource_group.mv_sample.location
  os_type             = "Linux"
  sku_name            = "Y1"
}

resource "azurerm_linux_function_app" "view_builder" {
  name                       = "func-materialized-view-sample"
  resource_group_name        = azurerm_resource_group.mv_sample.name
  location                   = azurerm_resource_group.mv_sample.location
  service_plan_id            = azurerm_service_plan.mv_sample.id
  storage_account_name       = azurerm_storage_account.mv_sample.name
  storage_account_access_key = azurerm_storage_account.mv_sample.primary_access_key

  site_config {
    application_stack {
      dotnet_version = "8.0"
    }
  }

  app_settings = {
    "COSMOS_SOURCE_CONTAINER" = azurerm_cosmosdb_sql_container.source.name
    "COSMOS_VIEW_CONTAINER"   = azurerm_cosmosdb_sql_container.materialized_view.name
  }
}
