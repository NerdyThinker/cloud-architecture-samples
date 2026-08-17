# circuit-breaker-pattern/main.tf
#
# Minimal illustrative sample: two App Services — a caller and a downstream
# dependency — wired to a shared Application Insights instance, which is
# what the circuit breaker's failure-rate tracking leans on in practice
# (via Polly in .NET, or an equivalent library in your stack of choice).
# The breaker's open/closed state machine lives in application code;
# Terraform's job is standing up the observability the breaker decisions
# get made from.
#
# Not production-ready as-is: no VNet integration between the two apps,
# no private endpoints, and the breaker thresholds shown are illustrative
# app settings, not enforced by any Azure resource.

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

resource "azurerm_resource_group" "cb_sample" {
  name     = "rg-circuit-breaker-sample"
  location = "East US"
}

resource "azurerm_application_insights" "cb_sample" {
  name                = "appi-circuit-breaker-sample"
  resource_group_name = azurerm_resource_group.cb_sample.name
  location            = azurerm_resource_group.cb_sample.location
  application_type    = "web"
}

resource "azurerm_service_plan" "cb_sample" {
  name                = "asp-circuit-breaker-sample"
  resource_group_name = azurerm_resource_group.cb_sample.name
  location            = azurerm_resource_group.cb_sample.location
  os_type             = "Linux"
  sku_name            = "B1"
}

resource "azurerm_linux_web_app" "caller" {
  name                = "app-cb-caller-sample"
  resource_group_name = azurerm_resource_group.cb_sample.name
  location            = azurerm_resource_group.cb_sample.location
  service_plan_id     = azurerm_service_plan.cb_sample.id

  site_config {
    application_stack {
      dotnet_version = "8.0"
    }
  }

  app_settings = {
    "APPLICATIONINSIGHTS_CONNECTION_STRING" = azurerm_application_insights.cb_sample.connection_string
    "DOWNSTREAM_URL"                        = "https://${azurerm_linux_web_app.downstream.default_hostname}"
    "CIRCUIT_BREAKER_FAILURE_THRESHOLD"     = "5"
    "CIRCUIT_BREAKER_OPEN_DURATION_SECONDS" = "30"
  }
}

resource "azurerm_linux_web_app" "downstream" {
  name                = "app-cb-downstream-sample"
  resource_group_name = azurerm_resource_group.cb_sample.name
  location            = azurerm_resource_group.cb_sample.location
  service_plan_id     = azurerm_service_plan.cb_sample.id

  site_config {
    application_stack {
      dotnet_version = "8.0"
    }
  }

  app_settings = {
    "APPLICATIONINSIGHTS_CONNECTION_STRING" = azurerm_application_insights.cb_sample.connection_string
  }
}
