# ---------------------------------------------------------------------------
# hub-apim-openai — DEV environment (non-secret config, safe to commit).
# Apply with:  terraform apply -var-file="environments/dev.tfvars"
# Secrets are NOT set here — this component currently has none.
# ---------------------------------------------------------------------------

# Hub subscription hosts the existing APIM and the new Azure OpenAI account
subscription_id = "fbfbfbe5-9ee2-43ed-b514-f3266c2193ab"
location        = "eastus2"

# Azure OpenAI (created in the hub subscription)
openai_resource_group_name = "rg-openai-hub"
openai_name_prefix         = "aoai"

# Model deployment
model_name     = "gpt-5.1"
model_version  = "2025-11-13" # confirmed available in eastus2 (GlobalStandard)
model_sku_name = "GlobalStandard"
model_capacity = 40

# Existing hub API Management
hub_apim_name                = "hun-apim-test-007"
hub_apim_resource_group_name = "hub-apim-test"
api_path                     = "openai"
