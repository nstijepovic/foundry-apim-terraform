# ---------------------------------------------------------------------------
# Storage account (StorageV2, AAD-only, private) + blob private endpoint
# ---------------------------------------------------------------------------
locals {
  # Some regions don't support Standard ZRS; fall back to GRS (matches the Bicep noZRSRegions list).
  no_zrs_regions           = ["southindia", "westus"]
  storage_replication_type = contains(local.no_zrs_regions, var.location) ? "GRS" : "ZRS"
}

resource "azurerm_storage_account" "storage" {
  name                     = local.storage_name
  resource_group_name      = azurerm_resource_group.spoke.name
  location                 = var.location
  account_kind             = "StorageV2"
  account_tier             = "Standard"
  account_replication_type = local.storage_replication_type

  min_tls_version                 = "TLS1_2"
  shared_access_key_enabled       = false
  allow_nested_items_to_be_public = false
  public_network_access_enabled   = false

  network_rules {
    default_action = "Deny"
    bypass         = ["AzureServices"]
  }
}

resource "azurerm_private_endpoint" "storage" {
  name                = "${local.storage_name}-private-endpoint"
  location            = var.location
  resource_group_name = azurerm_resource_group.spoke.name
  subnet_id           = azurerm_subnet.pe.id

  private_service_connection {
    name                           = "${local.storage_name}-private-link-service-connection"
    private_connection_resource_id = azurerm_storage_account.storage.id
    is_manual_connection           = false
    subresource_names              = ["blob"]
  }

  private_dns_zone_group {
    name                 = "storage-dns-group"
    private_dns_zone_ids = [azurerm_private_dns_zone.zones["blob"].id]
  }
}

# ---------------------------------------------------------------------------
# AI Search (standard, AAD auth, private) + private endpoint
# ---------------------------------------------------------------------------
resource "azurerm_search_service" "search" {
  name                = local.search_name
  resource_group_name = azurerm_resource_group.spoke.name
  location            = var.location
  sku                 = "standard"

  replica_count   = 1
  partition_count = 1

  local_authentication_enabled  = true
  authentication_failure_mode   = "http401WithBearerChallenge"
  public_network_access_enabled = false
  semantic_search_sku           = "free"

  identity {
    type = "SystemAssigned"
  }
}

resource "azurerm_private_endpoint" "search" {
  name                = "${local.search_name}-private-endpoint"
  location            = var.location
  resource_group_name = azurerm_resource_group.spoke.name
  subnet_id           = azurerm_subnet.pe.id

  private_service_connection {
    name                           = "${local.search_name}-private-link-service-connection"
    private_connection_resource_id = azurerm_search_service.search.id
    is_manual_connection           = false
    subresource_names              = ["searchService"]
  }

  private_dns_zone_group {
    name                 = "search-dns-group"
    private_dns_zone_ids = [azurerm_private_dns_zone.zones["search"].id]
  }
}

# ---------------------------------------------------------------------------
# Cosmos DB (SQL API, AAD-only, private) + private endpoint
# ---------------------------------------------------------------------------
resource "azurerm_cosmosdb_account" "cosmos" {
  name                = local.cosmos_name
  location            = var.location
  resource_group_name = azurerm_resource_group.spoke.name
  offer_type          = "Standard"
  kind                = "GlobalDocumentDB"

  local_authentication_enabled     = false
  public_network_access_enabled    = false
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

resource "azurerm_private_endpoint" "cosmos" {
  name                = "${local.cosmos_name}-private-endpoint"
  location            = var.location
  resource_group_name = azurerm_resource_group.spoke.name
  subnet_id           = azurerm_subnet.pe.id

  private_service_connection {
    name                           = "${local.cosmos_name}-private-link-service-connection"
    private_connection_resource_id = azurerm_cosmosdb_account.cosmos.id
    is_manual_connection           = false
    subresource_names              = ["Sql"]
  }

  private_dns_zone_group {
    name                 = "cosmos-dns-group"
    private_dns_zone_ids = [azurerm_private_dns_zone.zones["cosmos"].id]
  }
}
