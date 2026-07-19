# ---------------------------------------------------------------------------
# Azure Document Intelligence — dedicated Cognitive Services account, keyless
# (Entra ID only), publicly reachable like the rest of this variant.
#
# kind "FormRecognizer" is the current single-service Document Intelligence
# kind (the service was renamed in 2023 but the ARM kind string was not).
# Switch var.document_intelligence_kind to "AIServices" for the multi-service
# umbrella (adds Speech/Vision/Language/Content Understanding on the same
# endpoint); the account is recreated and its endpoint hostname changes.
# ---------------------------------------------------------------------------
resource "azurerm_cognitive_account" "docintel" {
  count               = var.enable_document_intelligence ? 1 : 0
  name                = local.docintel_name
  resource_group_name = azurerm_resource_group.main.name
  location            = var.location
  kind                = var.document_intelligence_kind
  sku_name            = var.document_intelligence_sku

  # Required for Entra ID (token) authentication.
  custom_subdomain_name = local.docintel_name

  local_auth_enabled            = false
  public_network_access_enabled = true

  identity {
    type = "SystemAssigned"
  }
}

# ---------------------------------------------------------------------------
# Foundry project connection for Document Intelligence (AAD — no secret
# stored). Discovery/portal visibility only: agents have no built-in tool for
# CognitiveService connections, so application code performs the DI calls.
# ---------------------------------------------------------------------------
resource "azapi_resource" "conn_docintel" {
  count     = var.enable_document_intelligence ? 1 : 0
  type      = "Microsoft.CognitiveServices/accounts/projects/connections@2025-04-01-preview"
  name      = local.docintel_conn_name
  parent_id = azapi_resource.project.id

  body = {
    properties = {
      # Single-service accounts use category "CognitiveService" (with the kind
      # in metadata); multi-service accounts use category "AIServices".
      category      = var.document_intelligence_kind == "AIServices" ? "AIServices" : "CognitiveService"
      target        = azurerm_cognitive_account.docintel[0].endpoint
      authType      = "AAD"
      isSharedToAll = true
      metadata = {
        ApiType    = "Azure"
        ResourceId = azurerm_cognitive_account.docintel[0].id
        location   = var.location
        Kind       = var.document_intelligence_kind
      }
    }
  }
}
