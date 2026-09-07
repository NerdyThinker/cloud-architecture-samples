# ambassador-pattern/main.tf
#
# Minimal illustrative sample: structurally identical to the Sidecar
# sample above — two containers in one Container App, sharing a
# lifecycle — but the second container's job here is specifically
# networking on behalf of the first: outbound calls, retries, TLS, and
# service discovery, rather than a general cross-cutting concern like
# logging. Ambassador is really Sidecar specialized to one job.
#
# Not production-ready as-is: a real ambassador is commonly an Envoy
# proxy or similar, configured with actual retry/circuit-breaking policy
# — the placeholder image here stands in for that configuration, which
# is genuinely the interesting part of a real deployment.

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

resource "azurerm_resource_group" "ambassador_sample" {
  name     = "rg-ambassador-sample"
  location = "East US"
}

resource "azurerm_log_analytics_workspace" "ambassador_sample" {
  name                = "law-ambassador-sample"
  resource_group_name = azurerm_resource_group.ambassador_sample.name
  location            = azurerm_resource_group.ambassador_sample.location
  sku                 = "PerGB2018"
}

resource "azurerm_container_app_environment" "ambassador_sample" {
  name                       = "cae-ambassador-sample"
  resource_group_name        = azurerm_resource_group.ambassador_sample.name
  location                   = azurerm_resource_group.ambassador_sample.location
  log_analytics_workspace_id = azurerm_log_analytics_workspace.ambassador_sample.id
}

resource "azurerm_container_app" "app_with_ambassador" {
  name                         = "ca-ambassador-sample"
  resource_group_name          = azurerm_resource_group.ambassador_sample.name
  container_app_environment_id = azurerm_container_app_environment.ambassador_sample.id
  revision_mode                = "Single"

  template {
    container {
      name   = "main-application"
      image  = "mcr.microsoft.com/azuredocs/containerapps-helloworld:latest"
      cpu    = 0.5
      memory = "1Gi"

      env {
        name  = "DOWNSTREAM_URL"
        value = "http://localhost:8080" # app calls the ambassador on localhost, never the remote service directly
      }
    }

    container {
      name   = "networking-ambassador"
      image  = "mcr.microsoft.com/azuredocs/containerapps-helloworld:latest" # placeholder — swap for an Envoy-style proxy image
      cpu    = 0.25
      memory = "0.5Gi"
    }
  }
}
