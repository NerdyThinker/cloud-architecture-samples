# sharding-pattern/main.tf
#
# Minimal illustrative sample: a Cosmos DB container with an explicit
# partition key, which is Azure's native mechanism for horizontal
# sharding — Cosmos automatically distributes data and throughput across
# physical partitions based on the partition key's value, without you
# provisioning separate "shard" resources by hand the way you might with
# self-managed sharded SQL.
#
# Not production-ready as-is: partition key choice is the single most
# consequential decision in this pattern and is genuinely workload-
# specific — customerId works well here because it distributes evenly
# and matches the dominant query pattern, but that won't be true for
# every dataset. Get this wrong and you get a "hot partition" that
# defeats the entire point of sharding.

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

resource "azurerm_resource_group" "shard_sample" {
  name     = "rg-sharding-sample"
  location = "East US"
}

resource "azurerm_cosmosdb_account" "shard_sample" {
  name                = "cosmos-sharding-sample"
  resource_group_name = azurerm_resource_group.shard_sample.name
  location            = azurerm_resource_group.shard_sample.location
  offer_type          = "Standard"

  consistency_policy {
    consistency_level = "Session"
  }

  geo_location {
    location          = azurerm_resource_group.shard_sample.location
    failover_priority = 0
  }
}

resource "azurerm_cosmosdb_sql_database" "shard_sample" {
  name                = "orders"
  resource_group_name = azurerm_resource_group.shard_sample.name
  account_name        = azurerm_cosmosdb_account.shard_sample.name
}

resource "azurerm_cosmosdb_sql_container" "shard_sample" {
  name                  = "orders-container"
  resource_group_name   = azurerm_resource_group.shard_sample.name
  account_name          = azurerm_cosmosdb_account.shard_sample.name
  database_name         = azurerm_cosmosdb_sql_database.shard_sample.name
  partition_key_paths   = ["/customerId"]
  partition_key_version = 2
  throughput            = 4000 # shared across logical partitions of /customerId
}
