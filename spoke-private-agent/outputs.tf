output "resource_group_name" {
  description = "The spoke resource group."
  value       = azurerm_resource_group.spoke.name
}

output "vnet_id" {
  description = "The spoke virtual network ID."
  value       = azurerm_virtual_network.vnet.id
}

output "agent_subnet_id" {
  description = "The delegated agent subnet ID."
  value       = azurerm_subnet.agent.id
}

output "foundry_account_name" {
  description = "The Foundry account name."
  value       = local.account_name
}

output "foundry_account_id" {
  description = "The Foundry account resource ID."
  value       = azapi_resource.account.id
}

output "foundry_account_endpoint" {
  description = "The Foundry account endpoint (private)."
  value       = azapi_resource.account.output.properties.endpoint
}

output "project_name" {
  description = "The Foundry project name."
  value       = local.project_name
}

output "project_principal_id" {
  description = "The project system-assigned identity principal ID."
  value       = local.project_principal_id
}

output "project_workspace_guid" {
  description = "The project workspace GUID (formatted internalId)."
  value       = local.project_workspace_guid
}

output "capability_host_name" {
  description = "The project capability host name."
  value       = azapi_resource.project_caphost.name
}

output "cosmos_account_name" {
  description = "Cosmos DB account name."
  value       = local.cosmos_name
}

output "search_service_name" {
  description = "AI Search service name."
  value       = local.search_name
}

output "storage_account_name" {
  description = "Storage account name."
  value       = local.storage_name
}

output "apim_private_dns_zone_id" {
  description = "The hub APIM private DNS zone linked to the spoke VNet (PE itself is managed in the hub-apim-openai config)."
  value       = var.enable_apim_private_endpoint ? data.azurerm_private_dns_zone.apim[0].id : null
}

output "apim_gateway_url" {
  description = "Hub APIM gateway URL (reachable privately from the VNet)."
  value       = var.enable_apim_private_endpoint ? "https://${var.hub_apim_name}.azure-api.net" : null
}

output "jumpbox_vm_name" {
  description = "Jumpbox VM name (connect via Azure Bastion)."
  value       = var.enable_jumpbox ? azurerm_windows_virtual_machine.jumpbox[0].name : null
}

output "jumpbox_private_ip" {
  description = "Jumpbox private IP."
  value       = var.enable_jumpbox ? azurerm_network_interface.jumpbox[0].private_ip_address : null
}
