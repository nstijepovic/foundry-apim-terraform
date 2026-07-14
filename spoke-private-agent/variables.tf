# ---------------------------------------------------------------------------
# Subscription / location
# ---------------------------------------------------------------------------
variable "subscription_id" {
  description = "Azure subscription ID for the spoke deployment."
  type        = string
  default     = "fbfbfbe5-9ee2-43ed-b514-f3266c2193ab"
}

variable "location" {
  description = "Azure region for the VNet + Foundry account + dependent resources. Must be a Standard Agent supported region."
  type        = string
  default     = "uaenorth"
}

variable "resource_group_name" {
  description = "Resource group to create for the spoke."
  type        = string
  default     = "rg-spoke-agent"
}

# ---------------------------------------------------------------------------
# Naming
# ---------------------------------------------------------------------------
variable "name_prefix" {
  description = "Prefix used for the Foundry account and dependent resource names (lowercase, short)."
  type        = string
  default     = "foundry"
}

variable "project_name_prefix" {
  description = "Prefix for the Foundry project name."
  type        = string
  default     = "proj"
}

variable "project_description" {
  description = "Description of the Foundry project."
  type        = string
  default     = "A project for the AI Foundry account with network secured deployed Agent"
}

variable "project_display_name" {
  description = "Display name of the Foundry project."
  type        = string
  default     = "network secured agent project"
}

variable "project_cap_host_name" {
  description = "Name of the project capability host."
  type        = string
  default     = "caphostproj"
}

# ---------------------------------------------------------------------------
# Network
# ---------------------------------------------------------------------------
variable "vnet_address_space" {
  description = "Address space for the spoke VNet."
  type        = list(string)
  default     = ["10.252.128.0/24"]
}

variable "agent_subnet_prefix" {
  description = "Address prefix for the agent subnet (delegated to Microsoft.App/environments)."
  type        = string
  default     = "10.252.128.0/26"
}

variable "pe_subnet_prefix" {
  description = "Address prefix for the private endpoint subnet."
  type        = string
  default     = "10.252.128.64/26"
}

# ---------------------------------------------------------------------------
# Hub APIM (existing) private endpoint integration
# ---------------------------------------------------------------------------
variable "enable_apim_private_endpoint" {
  description = "When true, adds a private endpoint + privatelink.azure-api.net DNS zone for the existing hub APIM."
  type        = bool
  default     = true
}

variable "hub_apim_name" {
  description = "Name of the existing hub API Management instance to expose privately."
  type        = string
  default     = "hun-apim-test-007"
}

variable "hub_apim_resource_group_name" {
  description = "Resource group of the existing hub APIM."
  type        = string
  default     = "hub-apim-test"
}

variable "hub_vnet_name" {
  description = "Name of the hub VNet (created by the hub-apim-openai config) to peer with and whose APIM private DNS zone to link."
  type        = string
  default     = "hub-vnet"
}

# ---------------------------------------------------------------------------
# Foundry -> hub APIM model connection (consume gpt-5.1 behind the hub APIM)
# ---------------------------------------------------------------------------
variable "enable_apim_model_connection" {
  description = "When true, creates a Foundry ApiManagement connection that targets the hub APIM gateway so the agent can use the model behind APIM."
  type        = bool
  default     = true
}

variable "apim_openai_connection_name" {
  description = "Name of the Foundry ApiManagement connection that points at the hub APIM."
  type        = string
  default     = "hub-apim-openai"
}

variable "apim_openai_path" {
  description = "APIM API path suffix that fronts the Azure OpenAI inference API (matches the hub api_path)."
  type        = string
  default     = "openai"
}

variable "apim_inference_api_version" {
  description = "api-version used for inference calls through APIM (connection metadata.inferenceAPIVersion)."
  type        = string
  default     = "2025-03-01-preview"
}

variable "apim_subscription_key" {
  description = "Hub APIM subscription key used by the Foundry connection to call the model through APIM. Provide via TF_VAR_apim_subscription_key; do not commit."
  type        = string
  sensitive   = true
  default     = null
}

variable "hub_apim_subscription_id" {
  description = "Subscription ID of the existing hub APIM (defaults to the spoke subscription)."
  type        = string
  default     = "fbfbfbe5-9ee2-43ed-b514-f3266c2193ab"
}

# ---------------------------------------------------------------------------
# Jumpbox (Windows VM + Azure Bastion) — for logging in to the VNet to reach
# the private Foundry account/portal and create agents.
# ---------------------------------------------------------------------------
variable "enable_jumpbox" {
  description = "When true, deploys a Windows jumpbox VM + Azure Bastion inside the VNet."
  type        = bool
  default     = true
}

variable "jumpbox_subnet_prefix" {
  description = "Address prefix for the jumpbox subnet."
  type        = string
  default     = "10.252.128.128/26"
}

variable "bastion_subnet_prefix" {
  description = "Address prefix for the AzureBastionSubnet (must be at least /26)."
  type        = string
  default     = "10.252.128.192/26"
}

variable "jumpbox_vm_size" {
  description = "VM size for the jumpbox."
  type        = string
  default     = "Standard_D2s_v5"
}

variable "jumpbox_admin_username" {
  description = "Admin username for the jumpbox VM."
  type        = string
  default     = "azureuser"
}

variable "jumpbox_admin_password" {
  description = "Admin password for the jumpbox VM. Provide via TF_VAR_jumpbox_admin_password or an untracked tfvars file — do not commit."
  type        = string
  sensitive   = true
  default     = null
}
