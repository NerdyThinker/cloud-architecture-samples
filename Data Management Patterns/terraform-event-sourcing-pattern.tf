# event-sourcing-pattern/main.tf
#
# Minimal illustrative sample: a Cosmos DB container configured as an
# append-only event store, partitioned by aggregate id (orderId here) so
# that all events for a single aggregate land in the same logical
# partition and can be read back in order cheaply. A Function App
# represents the projection worker that replays events into a queryable
# current-state view — the same relationship the Materialized View
# pattern (Scalability & Performance post) describes between a source
# and a derived read model.
#
# Not production-ready as-is: Cosmos doesn't enforce "append-only" for
# you — that discipline (never issuing an UPDATE or DELETE against this
# container) has to be enforced in application code or through RBAC
# scoped to insert-only operations for the services writing to it.

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

resource "azurerm_resource_group" "es_sample" {
  name     = "rg-event-sourcing-sample"
  location = "East US"
}

resource "azurerm_cosmosdb_account" "es_sample" {
  name                = "cosmos-event-sourcing-sample"
  resource_group_name = azurerm_resource_group.es_sample.name
  location            = azurerm_resource_group.es_sample.location
  offer_type          = "Standard"

  consistency_policy {
    consistency_level = "Strong" # event order matters within an aggregate
  }

  geo_location {
    location          = azurerm_resource_group.es_sample.location
    failover_priority = 0
  }
}

resource "azurerm_cosmosdb_sql_database" "es_sample" {
  name                = "event-store-db"
  resource_group_name = azurerm_resource_group.es_sample.name
  account_name        = azurerm_cosmosdb_account.es_sample.name
}

resource "azurerm_cosmosdb_sql_container" "events" {
  name                = "order-events"
  resource_group_name = azurerm_resource_group.es_sample.name
  account_name        = azurerm_cosmosdb_account.es_sample.name
  database_name       = azurerm_cosmosdb_sql_database.es_sample.name
  partition_key_paths = ["/orderId"]
  # Application code assigns each event a monotonically increasing
  # sequence number within its partition — Cosmos itself doesn't
  # guarantee insertion order beyond what "Strong" consistency provides.
}

resource "azurerm_storage_account" "es_sample" {
  name                     = "steventsourcingsmpl"
  resource_group_name      = azurerm_resource_group.es_sample.name
  location                 = azurerm_resource_group.es_sample.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

resource "azurerm_service_plan" "es_sample" {
  name                = "asp-event-sourcing-sample"
  resource_group_name = azurerm_resource_group.es_sample.name
  location            = azurerm_resource_group.es_sample.location
  os_type             = "Linux"
  sku_name            = "Y1"
}

resource "azurerm_linux_function_app" "projector" {
  name                       = "func-event-sourcing-projector-sample"
  resource_group_name        = azurerm_resource_group.es_sample.name
  location                   = azurerm_resource_group.es_sample.location
  service_plan_id            = azurerm_service_plan.es_sample.id
  storage_account_name       = azurerm_storage_account.es_sample.name
  storage_account_access_key = azurerm_storage_account.es_sample.primary_access_key

  site_config {
    application_stack {
      dotnet_version = "8.0"
    }
  }

  app_settings = {
    "EVENT_CONTAINER_NAME" = azurerm_cosmosdb_sql_container.events.name
  }
}
