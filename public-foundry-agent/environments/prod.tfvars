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
apim_inference_api_version   = "2024-10-21"

# Optional: grant a developer/service principal the Foundry User role.
# agent_developer_principal_id = "00000000-0000-0000-0000-000000000000"
