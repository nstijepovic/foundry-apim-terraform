# ---------------------------------------------------------------------------
# spoke-private-agent — DEV environment (non-secret config, safe to commit).
# Apply with:  terraform apply -var-file="environments/dev.tfvars"
#
# Secrets are NOT set here. Provide them via env vars before apply
# (see set-secrets.example.ps1):
#   $env:TF_VAR_jumpbox_admin_password = "<strong-password>"
#   $env:TF_VAR_apim_subscription_key  = "<hub-apim-subscription-key>"
#   $env:ARM_SUBSCRIPTION_ID           = "<subscription-id>"
# ---------------------------------------------------------------------------

subscription_id     = "fbfbfbe5-9ee2-43ed-b514-f3266c2193ab"
location            = "westus3"
resource_group_name = "rg-spoke-agent-wus3"

name_prefix         = "foundry"
project_name_prefix = "proj"

project_description   = "Private network standard agent project."
project_display_name  = "Private Agent Project"
project_cap_host_name = "caphostproj"

vnet_address_space  = ["10.252.128.0/24"]
agent_subnet_prefix = "10.252.128.0/26"
pe_subnet_prefix    = "10.252.128.64/26"

enable_apim_private_endpoint = true
hub_apim_name                = "hun-apim-test-007"
hub_apim_resource_group_name = "hub-apim-test"
hub_apim_subscription_id     = "fbfbfbe5-9ee2-43ed-b514-f3266c2193ab"

# Jumpbox (login via Bastion to reach the private Foundry account and create agents).
enable_jumpbox         = true
jumpbox_subnet_prefix  = "10.252.128.128/26"
bastion_subnet_prefix  = "10.252.128.192/26"
jumpbox_vm_size        = "Standard_D2s_v5"
jumpbox_admin_username = "azureuser"

# APIM model connection (agent consumes the model behind the hub APIM).
enable_apim_model_connection = true
apim_openai_connection_name  = "hub-apim-openai"
apim_openai_path             = "openai"
apim_inference_api_version   = "2024-10-21"
