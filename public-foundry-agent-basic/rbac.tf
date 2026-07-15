# ===========================================================================
# RBAC
# ===========================================================================
# Basic setup uses Microsoft-managed storage, so no project-managed-identity
# role assignments on BYO Storage/Search/Cosmos are required. The only optional
# assignment is developer access on the Foundry account.

# Optional: grant a developer or service principal the "Azure AI User" (formerly
# "Foundry User") role on the Foundry account so DefaultAzureCredential can create
# and call agents from a local machine over the public endpoint. Set
# var.agent_developer_principal_id to enable.
resource "azurerm_role_assignment" "agent_developer" {
  count              = var.agent_developer_principal_id == null ? 0 : 1
  scope              = azapi_resource.account.id
  role_definition_id = "/subscriptions/${var.subscription_id}/providers/Microsoft.Authorization/roleDefinitions/53ca6127-db72-4b80-b1b0-d745d6d5456d"
  principal_id       = var.agent_developer_principal_id
}
