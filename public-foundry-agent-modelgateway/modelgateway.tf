# ---------------------------------------------------------------------------
# Foundry ModelGateway connection (self-hosted / third-party gateway, no APIM).
#
# Unlike the ApiManagement connection, a ModelGateway connection drives the
# agent through the gateway's OpenAI-compatible /chat/completions endpoint.
# The gateway is BYO: this module never provisions it, it only points at it.
#
# Spec: category must be "ModelGateway"; every complex metadata value (objects
# and arrays) must be serialised as a JSON *string* — simple scalars such as
# "true"/"false" and api-versions stay plain strings.
# ---------------------------------------------------------------------------

locals {
  # Static catalogue: ModelInfo entries keyed by deployment name.
  mg_models = [
    for m in var.model_gateway_static_models : {
      name = m.name
      properties = {
        model = {
          name    = m.model_name
          version = m.model_version
          format  = m.model_format
        }
      }
    }
  ]

  mg_metadata = merge(
    {
      deploymentInPath = var.model_gateway_deployment_in_path ? "true" : "false"
    },
    var.model_gateway_inference_api_version != "" ? {
      inferenceAPIVersion = var.model_gateway_inference_api_version
    } : {},
    var.model_gateway_deployment_api_version != "" ? {
      deploymentAPIVersion = var.model_gateway_deployment_api_version
    } : {},

    # Static discovery.
    length(var.model_gateway_static_models) > 0 ? {
      models = jsonencode(local.mg_models)
    } : {},

    # Dynamic discovery.
    var.model_gateway_discovery != null ? {
      modelDiscovery = jsonencode({
        listModelsEndpoint = var.model_gateway_discovery.list_models_endpoint
        getModelEndpoint   = var.model_gateway_discovery.get_model_endpoint
        deploymentProvider = var.model_gateway_discovery.deployment_provider
      })
    } : {},

    length(var.model_gateway_custom_headers) > 0 ? {
      customHeaders = jsonencode(var.model_gateway_custom_headers)
    } : {},

    var.model_gateway_auth_config != null ? {
      authConfig = jsonencode({
        type   = "api_key"
        name   = var.model_gateway_auth_config.name
        format = var.model_gateway_auth_config.format
      })
    } : {}
  )
}

resource "azapi_resource" "conn_model_gateway" {
  count     = var.enable_model_gateway_connection ? 1 : 0
  type      = "Microsoft.CognitiveServices/accounts/projects/connections@2025-04-01-preview"
  name      = var.model_gateway_connection_name
  parent_id = azapi_resource.project.id

  body = {
    properties = {
      category      = "ModelGateway"
      target        = var.model_gateway_target
      authType      = "ApiKey"
      isSharedToAll = true
      credentials   = { key = var.model_gateway_api_key }
      metadata      = local.mg_metadata
    }
  }

  lifecycle {
    precondition {
      condition = (
        (length(var.model_gateway_static_models) > 0 && var.model_gateway_discovery == null) ||
        (length(var.model_gateway_static_models) == 0 && var.model_gateway_discovery != null)
      )
      error_message = "Set exactly one discovery mode: either model_gateway_static_models (static catalogue) or model_gateway_discovery (dynamic endpoints), not both and not neither."
    }

    precondition {
      condition     = var.model_gateway_api_key != null && var.model_gateway_api_key != ""
      error_message = "model_gateway_api_key is required. Supply it out-of-band, e.g. $env:TF_VAR_model_gateway_api_key = \"<key>\"."
    }
  }
}
