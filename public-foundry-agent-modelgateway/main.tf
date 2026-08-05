data "azurerm_client_config" "current" {}

locals {
  # Explicit, deterministic suffix. Set var.name_suffix to "" for no suffix at all.
  # Names below must still be globally unique where Azure requires it.
  suffix = lower(var.name_suffix)

  account_name  = lower("${var.name_prefix}${local.suffix}")
  project_name  = lower("${var.project_name_prefix}${local.suffix}")
  cosmos_name   = lower("${var.name_prefix}${local.suffix}cosmosdb")
  search_name   = lower("${var.name_prefix}${local.suffix}search")
  storage_name  = lower("${var.name_prefix}${local.suffix}storage")
  docintel_name = lower("${var.name_prefix}${local.suffix}docintel")

  # Connection names (also referenced by the capability host).
  cosmos_conn_name   = local.cosmos_name
  storage_conn_name  = local.storage_name
  search_conn_name   = local.search_name
  docintel_conn_name = local.docintel_name
}

resource "azurerm_resource_group" "main" {
  name     = var.resource_group_name
  location = var.location
}
