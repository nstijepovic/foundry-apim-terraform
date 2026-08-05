# Public Foundry + self-hosted ModelGateway connection — dev environment.
#
# The gateway is BYO. Here it points at our own APIM (hun-apim-test-007), which
# is a known-good OpenAI-compatible gateway — this exercises the ModelGateway
# code path over /chat/completions instead of the Responses API.
#
# The key is the APIM subscription key, supplied out-of-band:
#   $env:TF_VAR_model_gateway_api_key = "<apim-subscription-key>"

subscription_id     = "fbfbfbe5-9ee2-43ed-b514-f3266c2193ab"
location            = "uaenorth"
resource_group_name = "rg-public-agent-mgw"

name_prefix         = "foundry"
project_name_prefix = "proj"
name_suffix         = "mgw"

# ---------------------------------------------------------------------------
# Foundry -> self-hosted model gateway
# ---------------------------------------------------------------------------
enable_model_gateway_connection = true
model_gateway_connection_name   = "model-gateway"

# Full chat completions URL minus /chat/completions (and minus /deployments/{name}).
model_gateway_target = "https://REPLACE-ME.example.com/v1"

# false -> {target}/chat/completions with {"model": "<deployment>"} in the body.
# true  -> {target}/deployments/{deployment}/chat/completions
model_gateway_deployment_in_path = false

# Most non-Azure gateways expect no api-version. Set only if yours requires it.
# model_gateway_inference_api_version  = "2025-03-01"
# model_gateway_deployment_api_version = "2025-03-01"

# --- Discovery: pick EXACTLY ONE of the two blocks below --------------------

# Option 1 (default): static catalogue. `name` is the deployment alias you use
# in the agent model reference, i.e. "model-gateway/gpt-4o".
model_gateway_static_models = [
  {
    name          = "gpt-4o"
    model_name    = "gpt-4o"
    model_version = "2024-11-20"
    model_format  = "OpenAI"
  },
]

# Option 2: dynamic discovery. Set model_gateway_static_models = [] before
# enabling this — the two are mutually exclusive.
# model_gateway_discovery = {
#   list_models_endpoint = "/models"
#   get_model_endpoint   = "/models/{deploymentName}"
#   deployment_provider  = "OpenAI"
# }

# Optional: extra headers on every inference request.
# model_gateway_custom_headers = {
#   "X-Environment" = "dev"
# }

# Optional: override the auth header. Not needed for APIM — its subscription key
# header is `api-key`, which is already the ModelGateway default.
# model_gateway_auth_config = {
#   name   = "Authorization"
#   format = "Bearer {api_key}"
# }

# ---------------------------------------------------------------------------
# Azure Document Intelligence (dedicated keyless account + project connection)
# ---------------------------------------------------------------------------
enable_document_intelligence = true
document_intelligence_kind   = "FormRecognizer"
document_intelligence_sku    = "S0"
# docintel_app_principal_ids = ["00000000-0000-0000-0000-000000000000"]

# Optional: grant object IDs the Foundry User role so they can create agents
# locally. Get your own ID with: az ad signed-in-user show --query id -o tsv
# agent_developer_principal_ids = [
#   "00000000-0000-0000-0000-000000000000",
# ]
