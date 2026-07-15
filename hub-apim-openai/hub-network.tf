########## Optional private APIM connectivity ##########
# Disabled by default. Enable only when the Foundry environment must reach APIM
# through a private endpoint instead of APIM's public gateway.

resource "azurerm_virtual_network" "hub" {
  count               = var.enable_apim_private_endpoint ? 1 : 0
  name                = var.hub_vnet_name
  location            = var.hub_vnet_location
  resource_group_name = var.hub_apim_resource_group_name
  address_space       = var.hub_vnet_address_space
}

# Subnet that hosts the APIM private endpoint NIC.
resource "azurerm_subnet" "hub_pe" {
  count                             = var.enable_apim_private_endpoint ? 1 : 0
  name                              = "pe-subnet"
  resource_group_name               = var.hub_apim_resource_group_name
  virtual_network_name              = azurerm_virtual_network.hub[0].name
  address_prefixes                  = [var.hub_pe_subnet_prefix]
  private_endpoint_network_policies = "Disabled"
}

# Private DNS zone for APIM. Created once in the hub and linked to the hub VNet here;
# the spoke config links this same zone to the spoke VNet.
resource "azurerm_private_dns_zone" "apim" {
  count               = var.enable_apim_private_endpoint ? 1 : 0
  name                = "privatelink.azure-api.net"
  resource_group_name = var.hub_apim_resource_group_name
}

resource "azurerm_private_dns_zone_virtual_network_link" "apim_hub" {
  count                 = var.enable_apim_private_endpoint ? 1 : 0
  name                  = "apim-hub-link"
  resource_group_name   = var.hub_apim_resource_group_name
  private_dns_zone_name = azurerm_private_dns_zone.apim[0].name
  virtual_network_id    = azurerm_virtual_network.hub[0].id
  registration_enabled  = false
}

# APIM Gateway private endpoint (inbound). Basic SKU supports inbound PE as long as the
# instance is not VNet-injected (this one is public/not injected).
resource "azurerm_private_endpoint" "apim" {
  count               = var.enable_apim_private_endpoint ? 1 : 0
  name                = "${var.hub_apim_name}-private-endpoint"
  location            = var.hub_vnet_location
  resource_group_name = var.hub_apim_resource_group_name
  subnet_id           = azurerm_subnet.hub_pe[0].id

  private_service_connection {
    name                           = "${var.hub_apim_name}-private-link-service-connection"
    private_connection_resource_id = data.azurerm_api_management.hub.id
    is_manual_connection           = false
    subresource_names              = ["Gateway"]
  }

  private_dns_zone_group {
    name                 = "apim-dns-group"
    private_dns_zone_ids = [azurerm_private_dns_zone.apim[0].id]
  }
}
