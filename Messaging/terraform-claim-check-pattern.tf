# claim-check-pattern/main.tf
#
# Minimal illustrative sample: a Blob Storage container for large
# payloads, alongside a Service Bus queue that carries only a reference
# to the blob — not the blob itself. The sender uploads the large file
# first, then sends a small message containing the blob's URL; the
# receiver reads the URL and fetches the file directly from storage,
# never routing the large payload through the message broker at all.
#
# Not production-ready as-is: consider a short-lived SAS token or a
# managed-identity-based access policy for the blob reference rather than
# a raw URL, so the "claim check" itself doesn't grant indefinite access
# to whoever intercepts the message.

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
  name     = "rg-claim-check-sample"
  location = "East US"
}

resource "azurerm_storage_account" "payloads" {
  name                     = "stclaimchecksmpl"
  resource_group_name      = azurerm_resource_group.cc_sample.name
  location                 = azurerm_resource_group.cc_sample.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

resource "azurerm_storage_container" "large_payloads" {
  name                  = "large-payloads"
  storage_account_name  = azurerm_storage_account.payloads.name
  container_access_type = "private"
}

resource "azurerm_servicebus_namespace" "cc_sample" {
  name                = "sb-claim-check-sample"
  resource_group_name = azurerm_resource_group.cc_sample.name
  location            = azurerm_resource_group.cc_sample.location
  sku                 = "Standard"
}

resource "azurerm_servicebus_queue" "claim_checks" {
  name         = "claim-check-references"
  namespace_id = azurerm_servicebus_namespace.cc_sample.id
}
