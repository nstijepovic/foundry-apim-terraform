# ---------------------------------------------------------------------------
# Subscription / location
# ---------------------------------------------------------------------------
variable "subscription_id" {
  description = "Azure subscription ID for the deployment. No default on purpose: set it in the environment tfvars so a forgotten value can never target the wrong subscription."
  type        = string
}

variable "location" {
  description = "Azure region for the Foundry account + dependent resources. Must be a Standard Agent supported region."
  type        = string
  default     = "eastus2"
}

variable "resource_group_name" {
  description = "Resource group to create for the public deployment."
  type        = string
  default     = "rg-public-agent"
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
  default     = "A project for the AI Foundry account with a publicly deployed Agent"
}

variable "project_display_name" {
  description = "Display name of the Foundry project."
  type        = string
  default     = "public agent project"
}

variable "project_cap_host_name" {
  description = "Name of the project capability host."
  type        = string
  default     = "caphostproj"
}

variable "account_cap_host_name" {
  description = "Name of the account capability host (required before the project capability host in newer regions)."
  type        = string
  default     = "caphostacc"
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
  description = "Name of the existing hub API Management instance used by the Foundry connection. No default on purpose: supplied by the managing team via tfvars."
  type        = string
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
# Azure Document Intelligence
# ---------------------------------------------------------------------------
variable "enable_document_intelligence" {
  description = "When true, deploys a dedicated Document Intelligence account (keyless), a Foundry project connection to it, and the related role assignments."
  type        = bool
  default     = true
}

variable "document_intelligence_kind" {
  description = "Kind of the Document Intelligence Cognitive Services account. FormRecognizer = single-service Document Intelligence (narrowest RBAC surface); AIServices = multi-service account that also serves Speech/Vision/Language/Content Understanding. Changing this recreates the account and changes its endpoint hostname."
  type        = string
  default     = "FormRecognizer"

  validation {
    condition     = contains(["FormRecognizer", "AIServices"], var.document_intelligence_kind)
    error_message = "document_intelligence_kind must be FormRecognizer or AIServices."
  }
}

variable "document_intelligence_sku" {
  description = "SKU of the Document Intelligence account. S0 = standard pay-per-page (no base fee). F0 = free tier for trials only: analyzes just the first 2 pages of each document."
  type        = string
  default     = "S0"

  validation {
    condition     = contains(["F0", "S0"], var.document_intelligence_sku)
    error_message = "document_intelligence_sku must be F0 or S0."
  }
}

variable "docintel_app_principal_id" {
  description = "Optional Entra object ID of an application identity that performs document processing, granted Cognitive Services User on the Document Intelligence account. Leave null to skip."
  type        = string
  default     = null
}

# ---------------------------------------------------------------------------
# Developer access
# ---------------------------------------------------------------------------
variable "agent_developer_principal_id" {
  description = "Optional Entra object ID (user or service principal) to grant the Foundry User role (formerly Azure AI User) on the Foundry account, so it can create/call agents from a local machine. Leave null to skip."
  type        = string
  default     = null
}
