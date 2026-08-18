# autoscaling-pattern/main.tf
#
# Minimal illustrative sample: an App Service Plan with an Azure Monitor
# autoscale setting attached, scaling instance count out when average CPU
# crosses 70% and back in when it drops below 25%, bounded between a
# floor and a ceiling. This is genuinely infrastructure-native — unlike
# most patterns in this series, the scaling logic itself lives entirely
# in the azurerm_monitor_autoscale_setting resource, not in application code.
#
# Not production-ready as-is: CPU is a simple, illustrative metric —
# real workloads often scale on queue depth, request latency, or a
# custom metric that better reflects actual user-facing load, and the
# thresholds and cooldown windows below need tuning against real traffic
# patterns, not left at these starting values.

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

resource "azurerm_resource_group" "autoscale_sample" {
  name     = "rg-autoscaling-sample"
  location = "East US"
}

resource "azurerm_service_plan" "autoscale_sample" {
  name                = "asp-autoscaling-sample"
  resource_group_name = azurerm_resource_group.autoscale_sample.name
  location            = azurerm_resource_group.autoscale_sample.location
  os_type             = "Linux"
  sku_name            = "P1v3" # autoscale requires a non-free/shared tier
}

resource "azurerm_linux_web_app" "autoscale_sample" {
  name                = "app-autoscaling-sample"
  resource_group_name = azurerm_resource_group.autoscale_sample.name
  location            = azurerm_resource_group.autoscale_sample.location
  service_plan_id     = azurerm_service_plan.autoscale_sample.id

  site_config {
    application_stack {
      dotnet_version = "8.0"
    }
  }
}

resource "azurerm_monitor_autoscale_setting" "autoscale_sample" {
  name                = "autoscale-app-plan"
  resource_group_name = azurerm_resource_group.autoscale_sample.name
  location            = azurerm_resource_group.autoscale_sample.location
  target_resource_id  = azurerm_service_plan.autoscale_sample.id

  profile {
    name = "default"

    capacity {
      default = 2
      minimum = 2
      maximum = 10
    }

    rule {
      metric_trigger {
        metric_name        = "CpuPercentage"
        metric_resource_id = azurerm_service_plan.autoscale_sample.id
        time_grain         = "PT1M"
        statistic          = "Average"
        time_window        = "PT5M"
        time_aggregation   = "Average"
        operator           = "GreaterThan"
        threshold          = 70
      }
      scale_action {
        direction = "Increase"
        type      = "ChangeCount"
        value     = "1"
        cooldown  = "PT5M"
      }
    }

    rule {
      metric_trigger {
        metric_name        = "CpuPercentage"
        metric_resource_id = azurerm_service_plan.autoscale_sample.id
        time_grain         = "PT1M"
        statistic          = "Average"
        time_window        = "PT5M"
        time_aggregation   = "Average"
        operator           = "LessThan"
        threshold          = 25
      }
      scale_action {
        direction = "Decrease"
        type      = "ChangeCount"
        value     = "1"
        cooldown  = "PT5M"
      }
    }
  }
}
