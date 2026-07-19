output "resource_group_name" {
  description = "The resource group holding the public deployment."
  value       = azurerm_resource_group.main.name
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
  description = "The Foundry account endpoint (public)."
  value       = azapi_resource.account.output.properties.endpoint
}

output "project_name" {
  description = "The Foundry project name."
  value       = local.project_name
}

output "project_endpoint" {
  description = "The Foundry project endpoint for the Azure AI Projects SDK."
  value       = "https://${local.account_name}.services.ai.azure.com/api/projects/${local.project_name}"
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

output "docintel_account_name" {
  description = "Document Intelligence account name (null when disabled)."
  value       = var.enable_document_intelligence ? azurerm_cognitive_account.docintel[0].name : null
}

output "docintel_account_id" {
  description = "Document Intelligence account resource ID (null when disabled)."
  value       = var.enable_document_intelligence ? azurerm_cognitive_account.docintel[0].id : null
}

output "docintel_endpoint" {
  description = "Document Intelligence endpoint for application code (null when disabled)."
  value       = var.enable_document_intelligence ? azurerm_cognitive_account.docintel[0].endpoint : null
}

output "docintel_connection_name" {
  description = "Foundry project connection name for Document Intelligence (null when disabled)."
  value       = var.enable_document_intelligence ? local.docintel_conn_name : null
}

output "apim_gateway_url" {
  description = "Hub APIM gateway URL used by the Foundry connection."
  value       = "https://${var.hub_apim_name}.azure-api.net"
}
