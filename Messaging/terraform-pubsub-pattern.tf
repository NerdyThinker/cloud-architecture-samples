# publish-subscribe-pattern/main.tf
#
# Minimal illustrative sample: a Service Bus topic with three independent
# subscriptions, one per subscriber. The publisher only ever knows about
# the topic — it has no idea how many subscriptions exist, or whether a
# fourth one gets added next month. Each subscription gets its own copy
# of every message published to the topic.
#
# Not production-ready as-is: each subscription can carry its own SQL
# filter (azurerm_servicebus_subscription_rule) to receive only a subset
# of messages on the topic — not shown here for simplicity, but a common
# and useful refinement once subscribers only care about specific event
# types rather than everything published.

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

resource "azurerm_resource_group" "pubsub_sample" {
  name     = "rg-pubsub-sample"
  location = "East US"
}

resource "azurerm_servicebus_namespace" "pubsub_sample" {
  name                = "sb-pubsub-sample"
  resource_group_name = azurerm_resource_group.pubsub_sample.name
  location            = azurerm_resource_group.pubsub_sample.location
  sku                 = "Standard" # topics require Standard tier or above
}

resource "azurerm_servicebus_topic" "order_events" {
  name         = "order-events"
  namespace_id = azurerm_servicebus_namespace.pubsub_sample.id
}

resource "azurerm_servicebus_subscription" "inventory" {
  name               = "inventory-service"
  topic_id           = azurerm_servicebus_topic.order_events.id
  max_delivery_count = 10
}

resource "azurerm_servicebus_subscription" "billing" {
  name               = "billing-service"
  topic_id           = azurerm_servicebus_topic.order_events.id
  max_delivery_count = 10
}

resource "azurerm_servicebus_subscription" "analytics" {
  name               = "analytics-service"
  topic_id           = azurerm_servicebus_topic.order_events.id
  max_delivery_count = 10
}
