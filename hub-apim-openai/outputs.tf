output "openai_resource_group_name" {
  description = "Resource group created for the Azure OpenAI account"
  value       = azurerm_resource_group.openai.name
}

output "openai_account_name" {
  description = "Name of the Azure OpenAI (AIServices) account"
  value       = azapi_resource.openai.name
}

output "openai_endpoint" {
  description = "Data-plane endpoint of the Azure OpenAI account"
  value       = azapi_resource.openai.output.properties.endpoint
}

output "model_deployment_name" {
  description = "Deployment name to use in the request path"
  value       = azapi_resource.model_deployment.name
}

output "apim_principal_id" {
  description = "System-assigned managed identity principal ID of the hub APIM"
  value       = azapi_update_resource.apim_identity.output.identity.principalId
}

output "apim_gateway_url" {
  description = "Gateway URL of the hub API Management instance"
  value       = data.azurerm_api_management.hub.gateway_url
}

output "example_request_url" {
  description = "Example chat completions URL through the gateway (requires an APIM subscription key header: Ocp-Apim-Subscription-Key)"
  value       = "${data.azurerm_api_management.hub.gateway_url}/${var.api_path}/deployments/${var.model_name}/chat/completions?api-version=2025-03-01-preview"
}

output "hub_vnet_id" {
  description = "Resource ID of the hub VNet (for spoke peering)."
  value       = var.enable_apim_private_endpoint ? azurerm_virtual_network.hub[0].id : null
}

output "hub_vnet_name" {
  description = "Name of the hub VNet."
  value       = var.enable_apim_private_endpoint ? azurerm_virtual_network.hub[0].name : null
}

output "apim_private_dns_zone_name" {
  description = "Name of the APIM private DNS zone (link this to the spoke VNet)."
  value       = var.enable_apim_private_endpoint ? azurerm_private_dns_zone.apim[0].name : null
}

output "apim_private_endpoint_ip" {
  description = "Private IP of the hub APIM private endpoint."
  value       = var.enable_apim_private_endpoint ? azurerm_private_endpoint.apim[0].private_service_connection[0].private_ip_address : null
}
