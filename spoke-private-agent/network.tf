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
  cosmos_name  = lower("${var.name_prefix}${local.suffix}cosmosdb")
  search_name  = lower("${var.name_prefix}${local.suffix}search")
  storage_name = lower("${var.name_prefix}${local.suffix}storage")

  # Connection names (also referenced by the capability host).
  cosmos_conn_name  = local.cosmos_name
  storage_conn_name = local.storage_name
  search_conn_name  = local.search_name
}

resource "azurerm_resource_group" "spoke" {
  name     = var.resource_group_name
  location = var.location
}

# ---------------------------------------------------------------------------
# Virtual network + subnets
# ---------------------------------------------------------------------------
resource "azurerm_virtual_network" "vnet" {
  name                = "agent-vnet-${local.suffix}"
  location            = var.location
  resource_group_name = azurerm_resource_group.spoke.name
  address_space       = var.vnet_address_space
}

# Agent subnet: delegated to Microsoft.App/environments (required for the Standard Agent).
resource "azurerm_subnet" "agent" {
  name                 = "agent-subnet"
  resource_group_name  = azurerm_resource_group.spoke.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = [var.agent_subnet_prefix]

  delegation {
    name = "Microsoft.App/environments"
    service_delegation {
      name    = "Microsoft.App/environments"
      actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
    }
  }
}

# Private endpoint subnet.
resource "azurerm_subnet" "pe" {
  name                              = "pe-subnet"
  resource_group_name               = azurerm_resource_group.spoke.name
  virtual_network_name              = azurerm_virtual_network.vnet.name
  address_prefixes                  = [var.pe_subnet_prefix]
  private_endpoint_network_policies = "Disabled"
}

# ---------------------------------------------------------------------------
# Private DNS zones + VNet links
# ---------------------------------------------------------------------------
locals {
  dns_zones = {
    services_ai       = "privatelink.services.ai.azure.com"
    openai            = "privatelink.openai.azure.com"
    cognitiveservices = "privatelink.cognitiveservices.azure.com"
    search            = "privatelink.search.windows.net"
    blob              = "privatelink.blob.core.windows.net"
    cosmos            = "privatelink.documents.azure.com"
  }
}

resource "azurerm_private_dns_zone" "zones" {
  for_each            = local.dns_zones
  name                = each.value
  resource_group_name = azurerm_resource_group.spoke.name
}

resource "azurerm_private_dns_zone_virtual_network_link" "links" {
  for_each              = local.dns_zones
  name                  = "${each.key}-link"
  resource_group_name   = azurerm_resource_group.spoke.name
  private_dns_zone_name = azurerm_private_dns_zone.zones[each.key].name
  virtual_network_id    = azurerm_virtual_network.vnet.id
  registration_enabled  = false
}
