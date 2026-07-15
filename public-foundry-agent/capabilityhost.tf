# ---------------------------------------------------------------------------
# Project capability host (kind = Agents). Wires the three BYO connections and
# triggers provisioning of the agent containers in Cosmos DB and Storage.
# Must be created AFTER the pre-caphost role assignments and connections.
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
    time_sleep.wait_for_rbac,
  ]
}
