# ===========================================================================
# RBAC — assigned to the project's system-assigned managed identity.
# Ordering matters: the pre-caphost roles below must exist before the
# capability host is created; the post-caphost roles (see below) must be
# created after it.
# ===========================================================================

# ---- Pre-capability-host roles ----

# Storage Blob Data Contributor on the storage account.
resource "azurerm_role_assignment" "storage_blob_contributor" {
  scope              = azurerm_storage_account.storage.id
  role_definition_id = "/subscriptions/${var.subscription_id}/providers/Microsoft.Authorization/roleDefinitions/ba92f5b4-2d11-453d-a403-e96b0029c9fe"
  principal_id       = local.project_principal_id
  principal_type     = "ServicePrincipal"
}

# Cosmos DB Operator (control plane) on the Cosmos account.
resource "azurerm_role_assignment" "cosmos_operator" {
  scope              = azurerm_cosmosdb_account.cosmos.id
  role_definition_id = "/subscriptions/${var.subscription_id}/providers/Microsoft.Authorization/roleDefinitions/230815da-be43-4aae-9cb4-875f7bd000aa"
  principal_id       = local.project_principal_id
  principal_type     = "ServicePrincipal"
}

# Search Index Data Contributor on the AI Search service.
resource "azurerm_role_assignment" "search_index_data_contributor" {
  scope              = azurerm_search_service.search.id
  role_definition_id = "/subscriptions/${var.subscription_id}/providers/Microsoft.Authorization/roleDefinitions/8ebe5a00-799e-43f5-93ac-243d3dce84a7"
  principal_id       = local.project_principal_id
  principal_type     = "ServicePrincipal"
}

# Search Service Contributor on the AI Search service.
resource "azurerm_role_assignment" "search_service_contributor" {
  scope              = azurerm_search_service.search.id
  role_definition_id = "/subscriptions/${var.subscription_id}/providers/Microsoft.Authorization/roleDefinitions/7ca78c08-252a-4471-8644-bb5ff32d4ba0"
  principal_id       = local.project_principal_id
  principal_type     = "ServicePrincipal"
}

# Give RBAC + connections time to propagate before creating the capability host.
resource "time_sleep" "wait_for_rbac" {
  create_duration = "60s"

  depends_on = [
    azurerm_role_assignment.storage_blob_contributor,
    azurerm_role_assignment.cosmos_operator,
    azurerm_role_assignment.search_index_data_contributor,
    azurerm_role_assignment.search_service_contributor,
    azapi_resource.conn_cosmos,
    azapi_resource.conn_storage,
    azapi_resource.conn_search,
  ]
}


# ---- Post-capability-host roles ----

# Storage Blob Data Owner, scoped by ABAC condition to the agent's auto-provisioned
# containers ("{workspaceId}...-azureml-agent").
resource "azurerm_role_assignment" "storage_blob_owner_containers" {
  scope              = azurerm_storage_account.storage.id
  role_definition_id = "/subscriptions/${var.subscription_id}/providers/Microsoft.Authorization/roleDefinitions/b7e6dc6d-f1e8-4753-8033-0f276bb0955b"
  principal_id       = local.project_principal_id
  principal_type     = "ServicePrincipal"

  condition_version = "2.0"
  condition         = "((!(ActionMatches{'Microsoft.Storage/storageAccounts/blobServices/containers/blobs/tags/read'})  AND !(ActionMatches{'Microsoft.Storage/storageAccounts/blobServices/containers/blobs/filter/action'}) AND !(ActionMatches{'Microsoft.Storage/storageAccounts/blobServices/containers/blobs/tags/write'}) ) OR (@Resource[Microsoft.Storage/storageAccounts/blobServices/containers:name] StringStartsWithIgnoreCase '${local.project_workspace_guid}' AND @Resource[Microsoft.Storage/storageAccounts/blobServices/containers:name] StringLikeIgnoreCase '*-azureml-agent'))"

  depends_on = [azapi_resource.project_caphost]
}

# Cosmos DB Built-in Data Contributor (data plane) on the enterprise_memory database
# created by the capability host.
resource "azurerm_cosmosdb_sql_role_assignment" "cosmos_data_contributor" {
  resource_group_name = azurerm_resource_group.main.name
  account_name        = azurerm_cosmosdb_account.cosmos.name
  role_definition_id  = "${azurerm_cosmosdb_account.cosmos.id}/sqlRoleDefinitions/00000000-0000-0000-0000-000000000002"
  principal_id        = local.project_principal_id
  scope               = "${azurerm_cosmosdb_account.cosmos.id}/dbs/enterprise_memory"

  depends_on = [azapi_resource.project_caphost]
}

# ---- Document Intelligence access ----

# Cognitive Services User on the Document Intelligence account. With local
# auth disabled, this data-plane role is the only way to call the DI API.

# Project managed identity — lets workloads running as the project call DI.
resource "azurerm_role_assignment" "docintel_project" {
  count              = var.enable_document_intelligence ? 1 : 0
  scope              = azurerm_cognitive_account.docintel[0].id
  role_definition_id = "/subscriptions/${var.subscription_id}/providers/Microsoft.Authorization/roleDefinitions/a97b65f3-24c7-4388-baec-2e87135dc908"
  principal_id       = local.project_principal_id
  principal_type     = "ServicePrincipal"
}

# Optional developer principals (same identities as the agent_developer role).
resource "azurerm_role_assignment" "docintel_developer" {
  for_each           = var.enable_document_intelligence ? toset(var.agent_developer_principal_ids) : toset([])
  scope              = azurerm_cognitive_account.docintel[0].id
  role_definition_id = "/subscriptions/${var.subscription_id}/providers/Microsoft.Authorization/roleDefinitions/a97b65f3-24c7-4388-baec-2e87135dc908"
  principal_id       = each.value
}

# Optional separate application identities that perform document processing.
# setsubtract avoids a duplicate assignment when an ID is also in
# agent_developer_principal_ids (which already grants this same DI role).
resource "azurerm_role_assignment" "docintel_app" {
  for_each           = var.enable_document_intelligence ? toset(setsubtract(var.docintel_app_principal_ids, var.agent_developer_principal_ids)) : toset([])
  scope              = azurerm_cognitive_account.docintel[0].id
  role_definition_id = "/subscriptions/${var.subscription_id}/providers/Microsoft.Authorization/roleDefinitions/a97b65f3-24c7-4388-baec-2e87135dc908"
  principal_id       = each.value
}

# ---- Developer access ----

# Optional: grant developers or service principals the "Foundry User" (formerly
# "Azure AI User") role on the Foundry account so DefaultAzureCredential can create
# and call agents from a local machine over the public endpoint. Set
# var.agent_developer_principal_ids to enable (one role assignment per ID).
resource "azurerm_role_assignment" "agent_developer" {
  for_each           = toset(var.agent_developer_principal_ids)
  scope              = azapi_resource.account.id
  role_definition_id = "/subscriptions/${var.subscription_id}/providers/Microsoft.Authorization/roleDefinitions/53ca6127-db72-4b80-b1b0-d745d6d5456d"
  principal_id       = each.value
}
