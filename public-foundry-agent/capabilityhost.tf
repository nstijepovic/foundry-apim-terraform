# ---------------------------------------------------------------------------
# Account capability host (kind = Agents, no connections). Required before the
# project capability host — newer regions (e.g. westus3) reject the project
# caphost with "Foundry Account capabilityHost Not Found" otherwise. Matches
# the official foundry-samples add-project-capability-host.bicep.
# ---------------------------------------------------------------------------
resource "azapi_resource" "account_caphost" {
  type      = "Microsoft.CognitiveServices/accounts/capabilityHosts@2025-04-01-preview"
  name      = var.account_cap_host_name
  parent_id = azapi_resource.account.id

  # The capabilityHosts schema isn't yet in the azapi provider's embedded schema.
  schema_validation_enabled = false

  body = {
    properties = {
      capabilityHostKind = "Agents"
    }
  }

  depends_on = [
    time_sleep.wait_for_rbac,
  ]
}

# ---------------------------------------------------------------------------
# Project capability host (kind = Agents). Wires the three BYO connections and
# triggers provisioning of the agent containers in Cosmos DB and Storage.
# Must be created AFTER the account capability host, the pre-caphost role
# assignments, and the connections.
# ---------------------------------------------------------------------------
resource "azapi_resource" "project_caphost" {
  type      = "Microsoft.CognitiveServices/accounts/projects/capabilityHosts@2025-04-01-preview"
  name      = var.project_cap_host_name
  parent_id = azapi_resource.project.id

  # The capabilityHosts schema isn't yet in the azapi provider's embedded schema.
  schema_validation_enabled = false

  body = {
    properties = {
      capabilityHostKind       = "Agents"
      vectorStoreConnections   = [local.search_conn_name]
      storageConnections       = [local.storage_conn_name]
      threadStorageConnections = [local.cosmos_conn_name]
    }
  }

  depends_on = [
    azapi_resource.account_caphost,
    time_sleep.wait_for_rbac,
  ]
}
