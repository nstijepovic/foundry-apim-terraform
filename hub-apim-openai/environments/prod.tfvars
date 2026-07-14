# ---------------------------------------------------------------------------
# hub-apim-openai — PROD environment TEMPLATE.
# Copy the real values in, then:  terraform apply -var-file="environments/prod.tfvars"
# These are non-secret; commit this file once filled in.
# ---------------------------------------------------------------------------

subscription_id = "<prod-subscription-id>"
location        = "<region>" # region offering your model, e.g. eastus2

openai_resource_group_name = "rg-openai-hub"
openai_name_prefix         = "aoai"

model_name     = "gpt-5.1"
model_version  = "2025-11-13"
model_sku_name = "GlobalStandard"
model_capacity = 40

hub_apim_name                = "<prod-apim-name>"
hub_apim_resource_group_name = "<prod-apim-resource-group>"
api_path                     = "openai"
