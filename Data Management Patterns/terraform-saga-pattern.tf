# saga-pattern/main.tf
#
# Minimal illustrative sample: a choreography-style saga, where services
# communicate through topic subscriptions rather than a central
# orchestrator. This is the complementary approach to the Compensating
# Transaction sample in the Reliability & Resilience post, which used
# Durable Functions as a single orchestrator directing every step —
# here, each service reacts to events independently, and there's no one
# component that "knows" the whole saga end to end.
#
# Not production-ready as-is: choreography trades orchestration's single
# source of truth for looser coupling — that's a real tradeoff, not a
# strict improvement. Debugging a choreographed saga means tracing events
# across every subscribed service rather than reading one orchestrator's
# execution history, which is worth weighing before choosing this over
# the orchestrated version.

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

resource "azurerm_resource_group" "saga_choreo_sample" {
  name     = "rg-saga-choreography-sample"
  location = "East US"
}

resource "azurerm_servicebus_namespace" "saga_choreo_sample" {
  name                = "sb-saga-choreography-sample"
  resource_group_name = azurerm_resource_group.saga_choreo_sample.name
  location            = azurerm_resource_group.saga_choreo_sample.location
  sku                 = "Standard"
}

resource "azurerm_servicebus_topic" "order_events" {
  name         = "order-events"
  namespace_id = azurerm_servicebus_namespace.saga_choreo_sample.id
}

# Each service gets its own subscription to the shared topic, and
# filters for the specific event types it cares about via a SQL filter
# (not shown) — Inventory reacts to OrderPlaced, Payment reacts to
# StockReserved, Shipping reacts to PaymentCharged, and so on.

resource "azurerm_servicebus_subscription" "inventory_sub" {
  name               = "inventory-service"
  topic_id           = azurerm_servicebus_topic.order_events.id
  max_delivery_count = 5
}

resource "azurerm_servicebus_subscription" "payment_sub" {
  name               = "payment-service"
  topic_id           = azurerm_servicebus_topic.order_events.id
  max_delivery_count = 5
}

resource "azurerm_servicebus_subscription" "shipping_sub" {
  name               = "shipping-service"
  topic_id           = azurerm_servicebus_topic.order_events.id
  max_delivery_count = 5
}
