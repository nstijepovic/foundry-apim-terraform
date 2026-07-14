# ---------------------------------------------------------------------------
# Hub APIM reachability (canonical hub-spoke): the APIM private endpoint lives
# in the HUB VNet (created by the hub-apim-openai config). Here we peer the
# spoke VNet to the hub VNet and link the hub's privatelink.azure-api.net zone
# to the spoke VNet, so the agent subnet resolves + reaches APIM privately.
# ---------------------------------------------------------------------------
data "azurerm_virtual_network" "hub" {
  count               = var.enable_apim_private_endpoint ? 1 : 0
  name                = var.hub_vnet_name
  resource_group_name = var.hub_apim_resource_group_name
}

data "azurerm_private_dns_zone" "apim" {
  count               = var.enable_apim_private_endpoint ? 1 : 0
  name                = "privatelink.azure-api.net"
  resource_group_name = var.hub_apim_resource_group_name
}

# Spoke -> Hub peering. depends_on all spoke subnets so the spoke VNet is in a
# Succeeded (not Updating) state before the peering references it.
resource "azurerm_virtual_network_peering" "spoke_to_hub" {
  count                        = var.enable_apim_private_endpoint ? 1 : 0
  name                         = "spoke-to-hub"
  resource_group_name          = azurerm_resource_group.spoke.name
  virtual_network_name         = azurerm_virtual_network.vnet.name
  remote_virtual_network_id    = data.azurerm_virtual_network.hub[0].id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true

  depends_on = [azurerm_subnet.agent, azurerm_subnet.pe, azurerm_subnet.jumpbox, azurerm_subnet.bastion]
}

# Hub -> Spoke peering (created against the hub VNet, which lives in the hub RG).
# Same depends_on: the spoke VNet must be stable before the hub references it.
resource "azurerm_virtual_network_peering" "hub_to_spoke" {
  count                        = var.enable_apim_private_endpoint ? 1 : 0
  name                         = "hub-to-spoke"
  resource_group_name          = var.hub_apim_resource_group_name
  virtual_network_name         = data.azurerm_virtual_network.hub[0].name
  remote_virtual_network_id    = azurerm_virtual_network.vnet.id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true

  depends_on = [azurerm_subnet.agent, azurerm_subnet.pe, azurerm_subnet.jumpbox, azurerm_subnet.bastion]
}

# Link the hub's APIM private DNS zone to the spoke VNet so spoke workloads
# resolve the APIM gateway FQDN to the hub private endpoint IP.
resource "azurerm_private_dns_zone_virtual_network_link" "apim_spoke" {
  count                 = var.enable_apim_private_endpoint ? 1 : 0
  name                  = "apim-spoke-link"
  resource_group_name   = var.hub_apim_resource_group_name
  private_dns_zone_name = data.azurerm_private_dns_zone.apim[0].name
  virtual_network_id    = azurerm_virtual_network.vnet.id
  registration_enabled  = false
}

# ---------------------------------------------------------------------------
# THIS is the APIM "model connection" in the spoke: a Foundry ApiManagement
# connection whose target is the hub APIM gateway (resolved privately via the
# linked DNS zone + peering above). Through it the agent calls the model that
# lives behind the hub APIM (gpt-5.1), instead of the account-local deployment.
#
# Auth note: Foundry sends the key in the `api-key` header. The hub APIM API's
# subscription key header must therefore be `api-key` (set
# subscription_key_parameter_names on the hub API) — see the hub config.
# ---------------------------------------------------------------------------
resource "azapi_resource" "conn_apim_openai" {
  count     = var.enable_apim_model_connection ? 1 : 0
  type      = "Microsoft.CognitiveServices/accounts/projects/connections@2025-04-01-preview"
  name      = var.apim_openai_connection_name
  parent_id = azapi_resource.project.id

  body = {
    properties = {
      # Official Foundry->APIM connection category (see foundry-samples
      # 01-connections/apim/modules/apim-connection-common.bicep). NOT "AzureOpenAI".
      category = "ApiManagement"
      target   = "https://${var.hub_apim_name}.azure-api.net/${var.apim_openai_path}"
      authType = "ApiKey"
      credentials = {
        key = var.apim_subscription_key
      }
      metadata = {
        # deploymentInPath=true => deployment name is in the URL path
        # (/openai/deployments/{name}/chat/completions), matching the hub APIM API.
        deploymentInPath    = "true"
        inferenceAPIVersion = var.apim_inference_api_version
      }
    }
  }
}
