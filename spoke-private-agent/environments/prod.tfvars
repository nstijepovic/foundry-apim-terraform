# ---------------------------------------------------------------------------
# spoke-private-agent — PROD environment TEMPLATE.
# Copy the real values in, then:  terraform apply -var-file="environments/prod.tfvars"
# Non-secret config only — commit this file once filled in.
#
# Secrets go via env vars (see set-secrets.example.ps1):
#   $env:TF_VAR_jumpbox_admin_password, $env:TF_VAR_apim_subscription_key
# ---------------------------------------------------------------------------

subscription_id     = "<prod-subscription-id>"
location            = "<region>"
resource_group_name = "<prod-spoke-resource-group>"

name_prefix         = "foundry"
project_name_prefix = "proj"

project_description   = "Private network standard agent project."
project_display_name  = "Private Agent Project"
project_cap_host_name = "caphostproj"

# Must not overlap the hub VNet address space.
vnet_address_space  = ["<10.x.x.0/24>"]
agent_subnet_prefix = "<10.x.x.0/26>"
pe_subnet_prefix    = "<10.x.x.64/26>"

enable_apim_private_endpoint = true
hub_apim_name                = "<prod-apim-name>"
hub_apim_resource_group_name = "<prod-apim-resource-group>"
hub_apim_subscription_id     = "<prod-subscription-id>"

enable_jumpbox         = true
jumpbox_subnet_prefix  = "<10.x.x.128/26>"
bastion_subnet_prefix  = "<10.x.x.192/26>"
jumpbox_vm_size        = "Standard_D2s_v5"
jumpbox_admin_username = "azureuser"

enable_apim_model_connection = true
apim_openai_connection_name  = "hub-apim-openai"
apim_openai_path             = "openai"
apim_inference_api_version   = "2025-03-01-preview"
