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
#
# Basic setup: no BYO Storage/Search/Cosmos and no capability host. Agents in
# this project automatically use Microsoft-managed, multitenant storage and
# search for files, threads, and vector stores.
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

  response_export_values = ["identity.principalId"]
}

locals {
  project_principal_id = azapi_resource.project.output.identity.principalId
}
