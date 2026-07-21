# Public Foundry + APIM connection — prod environment.
# Copy/adjust for your subscription. Provide secrets via TF_VAR_* env vars
# (never commit apim_subscription_key).

subscription_id     = "fbfbfbe5-9ee2-43ed-b514-f3266c2193ab"
location            = "eastus2"
resource_group_name = "rg-public-agent-prod"

name_prefix         = "foundry"
project_name_prefix = "proj"

# Foundry -> hub APIM model connection
enable_apim_model_connection = true
hub_apim_name                = "hun-apim-test-007"
apim_openai_connection_name  = "hub-apim-openai"
apim_openai_path             = "openai"
# Agents call chat completions through this connection (not the Responses API
# directly) - use whatever api-version the hub's chat completions endpoint
# requires. The hub imports the 2024-10-21 GA inference spec, so that's the
# value to use here; confirm with the managing team if their setup differs.
apim_inference_api_version = "2024-10-21"

# Azure Document Intelligence (dedicated keyless account + project connection)
enable_document_intelligence = true
document_intelligence_kind   = "FormRecognizer"
document_intelligence_sku    = "S0"
# Optional: object ID of the app identity that processes documents.
# docintel_app_principal_id = "00000000-0000-0000-0000-000000000000"

# Optional: grant a developer/service principal the Foundry User role.
# agent_developer_principal_id = "00000000-0000-0000-0000-000000000000"
