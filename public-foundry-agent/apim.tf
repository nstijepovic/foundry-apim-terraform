# ---------------------------------------------------------------------------
# Foundry ApiManagement connection whose target is the hub APIM gateway.
# The account and project are publicly reachable and call the model through
# APIM's public gateway URL — no VNet peering or private DNS required.
# ---------------------------------------------------------------------------
resource "azapi_resource" "conn_apim_openai" {
  count     = var.enable_apim_model_connection ? 1 : 0
  type      = "Microsoft.CognitiveServices/accounts/projects/connections@2025-04-01-preview"
  name      = var.apim_openai_connection_name
  parent_id = azapi_resource.project.id

  body = {
    properties = {
      # Official Foundry->APIM connection category (see foundry-samples
      # 01-connections/apim/modules/apim-connection-common.bicep). NOT "AzureOpenAI".
      category      = "ApiManagement"
      target        = "https://${var.hub_apim_name}.azure-api.net/${var.apim_openai_path}"
      authType      = "ApiKey"
      isSharedToAll = true
      credentials = {
        key = var.apim_subscription_key
      }
      metadata = merge(
        {
          # deploymentInPath=true => deployment name is in the URL path
          # (/openai/deployments/{name}/chat/completions), matching the hub APIM API.
          deploymentInPath    = "true"
          inferenceAPIVersion = var.apim_inference_api_version
        },
        # Optional static model catalog. When set, Foundry uses this list instead
        # of calling the gateway's /deployments discovery routes. Leave the
        # apim_static_models variable empty for dynamic discovery (the default).
        length(var.apim_static_models) > 0 ? {
          models = jsonencode([
            for m in var.apim_static_models : {
              name = m.name
              properties = {
                model = {
                  name    = m.model_name
                  version = m.model_version
                  format  = m.model_format
                }
              }
            }
          ])
        } : {}
      )
    }
  }
}
