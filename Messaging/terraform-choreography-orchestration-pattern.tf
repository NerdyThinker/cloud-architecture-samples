# choreography-orchestration-pattern/main.tf
#
# Minimal illustrative sample covering BOTH styles side by side, since the
# choice between them is the whole point of this pattern:
#
#   - Orchestration: a Durable Functions app acts as the coordinator,
#     calling each service in sequence and handling branching/retries
#     centrally. (Infrastructure-wise, near-identical to the Compensating
#     Transaction sample in the reliability post — orchestration is the
#     coordination shape Sagas commonly use.)
#
#   - Choreography: a Service Bus topic that every participating service
#     both publishes to and subscribes from, with no central coordinator
#     at all — compare this to the Publish-Subscribe sample above, since
#     choreography is really pub-sub applied to a business process.
#
# Not production-ready as-is: pick one style for a given process rather
# than mixing both, and see the Publish-Subscribe and Compensating
# Transaction samples for the pieces this one intentionally keeps thin.

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

resource "azurerm_resource_group" "coord_sample" {
  name     = "rg-choreography-orchestration-sample"
  location = "East US"
}

# --- Orchestration option ---
resource "azurerm_storage_account" "orchestrator_storage" {
  name                     = "stcoordorchestrsmpl"
  resource_group_name      = azurerm_resource_group.coord_sample.name
  location                 = azurerm_resource_group.coord_sample.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

resource "azurerm_service_plan" "orchestrator_plan" {
  name                = "asp-orchestrator-sample"
  resource_group_name = azurerm_resource_group.coord_sample.name
  location            = azurerm_resource_group.coord_sample.location
  os_type             = "Linux"
  sku_name            = "Y1"
}

resource "azurerm_linux_function_app" "orchestrator" {
  name                       = "func-orchestrator-sample"
  resource_group_name        = azurerm_resource_group.coord_sample.name
  location                   = azurerm_resource_group.coord_sample.location
  service_plan_id            = azurerm_service_plan.orchestrator_plan.id
  storage_account_name       = azurerm_storage_account.orchestrator_storage.name
  storage_account_access_key = azurerm_storage_account.orchestrator_storage.primary_access_key

  site_config {
    application_stack {
      dotnet_version = "8.0"
    }
  }
}

# --- Choreography option ---
resource "azurerm_servicebus_namespace" "choreography_sample" {
  name                = "sb-choreography-sample"
  resource_group_name = azurerm_resource_group.coord_sample.name
  location            = azurerm_resource_group.coord_sample.location
  sku                 = "Standard"
}

resource "azurerm_servicebus_topic" "process_events" {
  name         = "order-fulfillment-events"
  namespace_id = azurerm_servicebus_namespace.choreography_sample.id
}
