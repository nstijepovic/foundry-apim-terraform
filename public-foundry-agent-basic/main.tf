data "azurerm_client_config" "current" {}

# Unique 4-char suffix (lowercase + numeric), matching the Bicep uniqueSuffix pattern.
resource "random_string" "suffix" {
  length  = 4
  lower   = true
  upper   = false
  numeric = true
  special = false
}

locals {
  suffix = random_string.suffix.result

  account_name = lower("${var.name_prefix}${local.suffix}")
  project_name = lower("${var.project_name_prefix}${local.suffix}")
}

resource "azurerm_resource_group" "main" {
  name     = var.resource_group_name
  location = var.location
}
