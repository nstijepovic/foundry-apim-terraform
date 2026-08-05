# Public Foundry + APIM connection — prod environment.
# Copy/adjust for your subscription. Provide secrets via TF_VAR_* env vars
# (never commit apim_subscription_key).

subscription_id     = "fbfbfbe5-9ee2-43ed-b514-f3266c2193ab"
location            = "eastus2"
resource_group_name = "rg-public-agent-prod"

name_prefix         = "foundry"
project_name_prefix = "proj"

# Deterministic suffix appended to generated resource names — see dev.tfvars.
# Must be globally unique for the Foundry account, Storage, Search and Cosmos
# names. Changing it after deployment forces destroy + recreate.
name_suffix = "prod01"

# Foundry -> hub APIM model connection
enable_apim_model_connection = true
hub_apim_name                = "hun-apim-test-007"
apim_openai_connection_name  = "hub-apim-openai"
apim_openai_path             = "openai"
apim_inference_api_version   = "2024-10-21"

# Azure Document Intelligence (dedicated keyless account + project connection)
enable_document_intelligence = true
document_intelligence_kind   = "FormRecognizer"
document_intelligence_sku    = "S0"
# Optional: object IDs of app identities that process documents.
# docintel_app_principal_ids = ["00000000-0000-0000-0000-000000000000"]

# Optional: grant one or more developers/service principals the Foundry User role.
# agent_developer_principal_ids = [
#   "00000000-0000-0000-0000-000000000000",
#   "11111111-1111-1111-1111-111111111111",
# ]
