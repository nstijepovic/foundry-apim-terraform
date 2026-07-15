# ---------------------------------------------------------------------------
# Foundry (Cognitive Services AIServices) account — publicly reachable.
# ---------------------------------------------------------------------------
resource "azapi_resource" "account" {
  type      = "Microsoft.CognitiveServices/accounts@2025-04-01-preview"
  name      = local.account_name
  location  = var.location
  parent_id = azurerm_resource_group.main.id

  identity {
    type = "SystemAssigned"
  }

  body = {
    kind = "AIServices"
    sku = {
      name = "S0"
    }
    properties = {
      allowProjectManagement = true
      customSubDomainName    = local.account_name
      publicNetworkAccess    = "Enabled"
      disableLocalAuth       = true
      networkAcls = {
        defaultAction       = "Allow"
        virtualNetworkRules = []
        ipRules             = []
        bypass              = "AzureServices"
      }
    }
  }

  response_export_values = ["properties.endpoint"]
}

# ---------------------------------------------------------------------------
# Foundry project (sub-resource of the account) with a system-assigned identity.
# ---------------------------------------------------------------------------
resource "azapi_resource" "project" {
  type      = "Microsoft.CognitiveServices/accounts/projects@2025-04-01-preview"
  name      = local.project_name
  location  = var.location
  parent_id = azapi_resource.account.id

  identity {
    type = "SystemAssigned"
  }

  body = {
    properties = {
      description = var.project_description
      displayName = var.project_display_name
    }
  }

  response_export_values = ["identity.principalId", "properties.internalId"]
}

locals {
  project_principal_id = azapi_resource.project.output.identity.principalId
  project_internal_id  = azapi_resource.project.output.properties.internalId

  # Format the 32-char internalId as a GUID (8-4-4-4-12), matching format-project-workspace-id.bicep.
  project_workspace_guid = format(
    "%s-%s-%s-%s-%s",
    substr(local.project_internal_id, 0, 8),
    substr(local.project_internal_id, 8, 4),
    substr(local.project_internal_id, 12, 4),
    substr(local.project_internal_id, 16, 4),
    substr(local.project_internal_id, 20, 12),
  )
}

# ---------------------------------------------------------------------------
# Project connections (all AAD): Cosmos DB, Storage, AI Search.
# ---------------------------------------------------------------------------
resource "azapi_resource" "conn_cosmos" {
  type      = "Microsoft.CognitiveServices/accounts/projects/connections@2025-04-01-preview"
  name      = local.cosmos_conn_name
  parent_id = azapi_resource.project.id

  body = {
    properties = {
      category = "CosmosDB"
      target   = azurerm_cosmosdb_account.cosmos.endpoint
      authType = "AAD"
      metadata = {
        ApiType    = "Azure"
        ResourceId = azurerm_cosmosdb_account.cosmos.id
        location   = var.location
      }
    }
  }
}

resource "azapi_resource" "conn_storage" {
  type      = "Microsoft.CognitiveServices/accounts/projects/connections@2025-04-01-preview"
  name      = local.storage_conn_name
  parent_id = azapi_resource.project.id

  body = {
    properties = {
      category = "AzureStorageAccount"
      target   = azurerm_storage_account.storage.primary_blob_endpoint
      authType = "AAD"
      metadata = {
        ApiType    = "Azure"
        ResourceId = azurerm_storage_account.storage.id
        location   = var.location
      }
    }
  }
}

resource "azapi_resource" "conn_search" {
  type      = "Microsoft.CognitiveServices/accounts/projects/connections@2025-04-01-preview"
  name      = local.search_conn_name
  parent_id = azapi_resource.project.id

  body = {
    properties = {
      category = "CognitiveSearch"
      target   = "https://${local.search_name}.search.windows.net"
      authType = "AAD"
      metadata = {
        ApiType    = "Azure"
        ResourceId = azurerm_search_service.search.id
        location   = var.location
      }
    }
  }
}
