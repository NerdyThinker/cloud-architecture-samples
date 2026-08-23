# message-queue-pattern/main.tf
#
# Minimal illustrative sample: a single Service Bus queue between one
# sender and one receiver. Unlike the topic used in the Publish-Subscribe
# sample, a queue delivers each message to exactly one consumer — this is
# the point-to-point counterpart to that broadcast pattern, useful when
# a message represents work to be done once, not an event several
# independent parties all care about.
#
# Not production-ready as-is: dead-lettering is enabled by default on
# Service Bus queues after max_delivery_count is exceeded, but a real
# deployment should explicitly monitor that dead-letter queue rather than
# letting failed messages accumulate silently.

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

resource "azurerm_resource_group" "mq_sample" {
  name     = "rg-message-queue-sample"
  location = "East US"
}

resource "azurerm_servicebus_namespace" "mq_sample" {
  name                = "sb-message-queue-sample"
  resource_group_name = azurerm_resource_group.mq_sample.name
  location            = azurerm_resource_group.mq_sample.location
  sku                 = "Standard"
}

resource "azurerm_servicebus_queue" "requests" {
  name                    = "processing-requests"
  namespace_id            = azurerm_servicebus_namespace.mq_sample.id
  max_delivery_count      = 10
  default_message_ttl     = "P14D" # messages expire after 14 days unclaimed
  dead_lettering_on_message_expiration = true
}
