# ---------------------------------------------------------------------------
# Foundry ApiManagement connection whose target is the hub APIM gateway.
# The account and project are publicly reachable and call the model through
# APIM's public gateway URL — no VNet peering or private DNS required.
#
# Auth note: Foundry sends the key in the `api-key` header. The hub APIM API's
# subscription key header must therefore be `api-key` (set
# subscription_key_parameter_names on the hub API) — see the hub config.
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
      metadata = {
        # deploymentInPath=true => deployment name is in the URL path
        # (/openai/deployments/{name}/chat/completions), matching the hub APIM API.
        deploymentInPath    = "true"
        inferenceAPIVersion = var.apim_inference_api_version
      }
    }
  }
}
