# ---------------------------------------------------------------------------
# Storage account (StorageV2, AAD-only, publicly reachable).
# ---------------------------------------------------------------------------
locals {
  # Some regions don't support Standard ZRS; fall back to GRS (matches the Bicep noZRSRegions list).
  no_zrs_regions           = ["southindia", "westus"]
  storage_replication_type = contains(local.no_zrs_regions, var.location) ? "GRS" : "ZRS"
}

resource "azurerm_storage_account" "storage" {
  name                     = local.storage_name
  resource_group_name      = azurerm_resource_group.main.name
  location                 = var.location
  account_kind             = "StorageV2"
  account_tier             = "Standard"
  account_replication_type = local.storage_replication_type

  min_tls_version                 = "TLS1_2"
  shared_access_key_enabled       = false
  allow_nested_items_to_be_public = false
  public_network_access_enabled   = true
}

# ---------------------------------------------------------------------------
# AI Search (standard, AAD auth, publicly reachable).
# ---------------------------------------------------------------------------
resource "azurerm_search_service" "search" {
  name                = local.search_name
  resource_group_name = azurerm_resource_group.main.name
  location            = var.location
  sku                 = "standard"

  replica_count   = 1
  partition_count = 1

  local_authentication_enabled  = true
  authentication_failure_mode   = "http401WithBearerChallenge"
  public_network_access_enabled = true
  semantic_search_sku           = "free"

  identity {
    type = "SystemAssigned"
  }
}

# ---------------------------------------------------------------------------
# Cosmos DB (SQL API, AAD-only, publicly reachable).
# ---------------------------------------------------------------------------
resource "azurerm_cosmosdb_account" "cosmos" {
  name                = local.cosmos_name
  location            = var.location
  resource_group_name = azurerm_resource_group.main.name
  offer_type          = "Standard"
  kind                = "GlobalDocumentDB"

  local_authentication_enabled     = false
  public_network_access_enabled    = true
  automatic_failover_enabled       = false
  multiple_write_locations_enabled = false
  free_tier_enabled                = false

  consistency_policy {
    consistency_level = "Session"
  }

  geo_location {
    location          = var.location
    failover_priority = 0
    zone_redundant    = false
  }
}
