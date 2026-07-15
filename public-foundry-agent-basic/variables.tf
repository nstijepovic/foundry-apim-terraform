# ---------------------------------------------------------------------------
# Subscription / location
# ---------------------------------------------------------------------------
variable "subscription_id" {
  description = "Azure subscription ID for the deployment."
  type        = string
  default     = "fbfbfbe5-9ee2-43ed-b514-f3266c2193ab"
}

variable "location" {
  description = "Azure region for the Foundry account + project."
  type        = string
  default     = "eastus2"
}

variable "resource_group_name" {
  description = "Resource group to create for the basic deployment."
  type        = string
  default     = "rg-public-agent-basic"
}

# ---------------------------------------------------------------------------
# Naming
# ---------------------------------------------------------------------------
variable "name_prefix" {
  description = "Prefix used for the Foundry account name (lowercase, short)."
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
  default     = "A project for the AI Foundry account with a publicly deployed basic Agent"
}

variable "project_display_name" {
  description = "Display name of the Foundry project."
  type        = string
  default     = "public basic agent project"
}

# ---------------------------------------------------------------------------
# Foundry -> hub APIM model connection (consume the model behind the hub APIM)
# ---------------------------------------------------------------------------
variable "enable_apim_model_connection" {
  description = "When true, creates a Foundry ApiManagement connection that targets the hub APIM gateway so the agent can use the model behind APIM."
  type        = bool
  default     = true
}

variable "hub_apim_name" {
  description = "Name of the existing hub API Management instance used by the Foundry connection."
  type        = string
  default     = "hun-apim-test-007"
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

# ---------------------------------------------------------------------------
# Developer access
# ---------------------------------------------------------------------------
variable "agent_developer_principal_id" {
  description = "Optional Entra object ID (user or service principal) to grant the Azure AI User role on the Foundry account, so it can create/call agents from a local machine. Leave null to skip."
  type        = string
  default     = null
}
