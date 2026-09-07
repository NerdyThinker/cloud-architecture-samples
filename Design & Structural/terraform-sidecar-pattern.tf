# sidecar-pattern/main.tf
#
# Minimal illustrative sample: an Azure Container App with two containers
# defined in the same container app resource — a main application
# container and a sidecar handling a cross-cutting concern (in this
# example, log shipping). Both containers share the same pod-equivalent
# lifecycle in Container Apps: deployed together, scaled together, and
# able to talk to each other over localhost, exactly as the pattern
# requires.
#
# Not production-ready as-is: the sidecar here is a placeholder image —
# a real deployment would run something like a Fluent Bit or Dapr sidecar
# doing genuine cross-cutting work, and resource limits per container
# need tuning based on what the sidecar actually does.

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

resource "azurerm_resource_group" "sidecar_sample" {
  name     = "rg-sidecar-sample"
  location = "East US"
}

resource "azurerm_log_analytics_workspace" "sidecar_sample" {
  name                = "law-sidecar-sample"
  resource_group_name = azurerm_resource_group.sidecar_sample.name
  location            = azurerm_resource_group.sidecar_sample.location
  sku                 = "PerGB2018"
}

resource "azurerm_container_app_environment" "sidecar_sample" {
  name                       = "cae-sidecar-sample"
  resource_group_name        = azurerm_resource_group.sidecar_sample.name
  location                   = azurerm_resource_group.sidecar_sample.location
  log_analytics_workspace_id = azurerm_log_analytics_workspace.sidecar_sample.id
}

resource "azurerm_container_app" "app_with_sidecar" {
  name                         = "ca-sidecar-sample"
  resource_group_name          = azurerm_resource_group.sidecar_sample.name
  container_app_environment_id = azurerm_container_app_environment.sidecar_sample.id
  revision_mode                = "Single"

  template {
    container {
      name   = "main-application"
      image  = "mcr.microsoft.com/azuredocs/containerapps-helloworld:latest"
      cpu    = 0.5
      memory = "1Gi"
    }

    container {
      name   = "logging-sidecar"
      image  = "mcr.microsoft.com/azuredocs/containerapps-helloworld:latest" # placeholder — swap for a real log-shipping image
      cpu    = 0.25
      memory = "0.5Gi"
    }
  }
}
