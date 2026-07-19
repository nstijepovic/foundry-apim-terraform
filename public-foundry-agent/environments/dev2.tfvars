# Public Foundry + APIM connection — dev2 environment (parallel to dev, new RG).
# Deployed via the "dev2" Terraform workspace so its state is separate from the
# original dev deployment in rg-public-agent-uaen.
# Provide secrets via TF_VAR_* env vars (never commit apim_subscription_key).

subscription_id     = "fbfbfbe5-9ee2-43ed-b514-f3266c2193ab"
# westus3: chosen over uaenorth for model/agent capacity.
location            = "westus3"
resource_group_name = "rg-public-agent-wus3"

name_prefix         = "foundry"
project_name_prefix = "proj"

# Foundry -> hub APIM model connection
enable_apim_model_connection = true
hub_apim_name                = "hun-apim-test-007"
apim_openai_connection_name  = "hub-apim-openai"
apim_openai_path             = "openai"
# Must support the Responses API used by agent runs (matches the hub setup).
apim_inference_api_version = "2025-03-01-preview"

# Azure Document Intelligence (dedicated keyless account + project connection)
enable_document_intelligence = true
document_intelligence_kind   = "FormRecognizer"
document_intelligence_sku    = "S0"
# Optional: object ID of the app identity that processes documents.
# docintel_app_principal_id = "00000000-0000-0000-0000-000000000000"

# Developer access: Foundry User on the account + Cognitive Services User on the
# Document Intelligence account, so agents and DI can be tested from this machine.
agent_developer_principal_id = "719c1b75-9621-4c49-aa8d-b216261e6f00"
