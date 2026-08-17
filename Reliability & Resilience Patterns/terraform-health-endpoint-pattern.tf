# health-endpoint-monitoring-pattern/main.tf
#
# Minimal illustrative sample: an App Service configured with a health
# check path, plus an Application Insights availability test that polls
# it from outside Azure's network — the same way a real user's request
# would arrive. The /health endpoint itself (checking DB connectivity,
# cache reachability, etc.) is implementation code, not infrastructure;
# what's provisioned here is what actually watches that endpoint.
#
# Not production-ready as-is: a single-region availability test is a
# starting point — real deployments run the probe from multiple
# geographies and alert on sustained failures, not a single missed check.

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

resource "azurerm_resource_group" "health_sample" {
  name     = "rg-health-endpoint-sample"
  location = "East US"
}

resource "azurerm_service_plan" "health_sample" {
  name                = "asp-health-endpoint-sample"
  resource_group_name = azurerm_resource_group.health_sample.name
  location            = azurerm_resource_group.health_sample.location
  os_type             = "Linux"
  sku_name            = "B1"
}

resource "azurerm_linux_web_app" "health_sample" {
  name                = "app-health-endpoint-sample"
  resource_group_name = azurerm_resource_group.health_sample.name
  location            = azurerm_resource_group.health_sample.location
  service_plan_id     = azurerm_service_plan.health_sample.id

  site_config {
    health_check_path                = "/health"
    health_check_eviction_time_in_min = 5

    application_stack {
      dotnet_version = "8.0"
    }
  }
}

resource "azurerm_application_insights" "health_sample" {
  name                = "appi-health-endpoint-sample"
  resource_group_name = azurerm_resource_group.health_sample.name
  location            = azurerm_resource_group.health_sample.location
  application_type    = "web"
}

resource "azurerm_application_insights_standard_web_test" "health_probe" {
  name                    = "health-endpoint-probe"
  resource_group_name     = azurerm_resource_group.health_sample.name
  location                = azurerm_resource_group.health_sample.location
  application_insights_id = azurerm_application_insights.health_sample.id
  geo_locations           = ["us-va-ash-azr", "us-ca-sjc-azr"]
  frequency               = 300 # seconds between checks

  request {
    url = "https://${azurerm_linux_web_app.health_sample.default_hostname}/health"
  }

  validation_rules {
    expected_status_code = 200
  }
}
