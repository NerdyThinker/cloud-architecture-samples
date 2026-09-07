# backends-for-frontends-pattern/main.tf
#
# Minimal illustrative sample: three separate, purpose-built App Services
# — one per client type — each free to shape its own responses, caching,
# and payload size independently. All three call into the same shared
# backend services (not shown here, since those are ordinary services
# covered by earlier patterns in this series); what's provisioned here
# is specifically the three thin, client-specific layers in front of them.
#
# Not production-ready as-is: three separate services means three
# separate things to deploy, monitor, and keep reasonably in sync on
# shared concerns like auth — worth that cost specifically when client
# needs have genuinely diverged, not by default for every project with
# more than one client type.

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

resource "azurerm_resource_group" "bff_sample" {
  name     = "rg-bff-sample"
  location = "East US"
}

resource "azurerm_service_plan" "bff_sample" {
  name                = "asp-bff-sample"
  resource_group_name = azurerm_resource_group.bff_sample.name
  location            = azurerm_resource_group.bff_sample.location
  os_type             = "Linux"
  sku_name            = "B1"
}

resource "azurerm_linux_web_app" "mobile_bff" {
  name                = "app-bff-mobile-sample"
  resource_group_name = azurerm_resource_group.bff_sample.name
  location            = azurerm_resource_group.bff_sample.location
  service_plan_id     = azurerm_service_plan.bff_sample.id

  site_config {
    application_stack {
      dotnet_version = "8.0"
    }
  }
}

resource "azurerm_linux_web_app" "web_bff" {
  name                = "app-bff-web-sample"
  resource_group_name = azurerm_resource_group.bff_sample.name
  location            = azurerm_resource_group.bff_sample.location
  service_plan_id     = azurerm_service_plan.bff_sample.id

  site_config {
    application_stack {
      dotnet_version = "8.0"
    }
  }
}

resource "azurerm_linux_web_app" "partner_bff" {
  name                = "app-bff-partner-sample"
  resource_group_name = azurerm_resource_group.bff_sample.name
  location            = azurerm_resource_group.bff_sample.location
  service_plan_id     = azurerm_service_plan.bff_sample.id

  site_config {
    application_stack {
      dotnet_version = "8.0"
    }
  }

  app_settings = {
    # Partner-facing traffic often needs stricter versioning and rate
    # limiting than internal clients — this BFF is the natural place to
    # enforce that without complicating the mobile or web BFFs.
    "API_VERSION_LOCK" = "v1"
  }
}
