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

variable "name_suffix" {
  description = "Deterministic suffix appended to generated resource names. Set to \"\" for no suffix. Must be lowercase alphanumeric; you are responsible for global uniqueness of the Foundry account, storage, search and Cosmos names."
  type        = string
  default     = ""

  validation {
    condition     = can(regex("^[a-z0-9]*$", var.name_suffix))
    error_message = "name_suffix must contain only lowercase letters and digits (or be empty)."
  }
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
# Foundry -> self-hosted model gateway connection (category = ModelGateway)
#
# The gateway itself is BYO: this module never provisions it. It must expose an
# OpenAI-compatible /chat/completions endpoint (with tool/function calling),
# accept API-key auth, and be reachable from Azure.
# ---------------------------------------------------------------------------
variable "enable_model_gateway_connection" {
  description = "When true, creates a Foundry ModelGateway connection that targets a self-hosted or third-party gateway so the agent can consume models behind it."
  type        = bool
  default     = true
}

variable "model_gateway_connection_name" {
  description = "Name of the Foundry ModelGateway connection. This is the prefix of the agent model reference, i.e. <connection>/<deployment>."
  type        = string
  default     = "model-gateway"
}

variable "model_gateway_target" {
  description = <<-EOT
    Base URL of the gateway: take the full chat completions URL and strip the
    trailing /chat/completions, plus any /deployments/{name} segment.
      https://gw.example.com/chat/completions                      -> https://gw.example.com                 (deployment_in_path = false)
      https://gw.example.com/v1/custom/chat/completions            -> https://gw.example.com/v1/custom       (deployment_in_path = false)
      https://gw.example.com/deployments/gpt-4o/chat/completions   -> https://gw.example.com                 (deployment_in_path = true)
  EOT
  type        = string

  validation {
    condition     = can(regex("^https://", var.model_gateway_target))
    error_message = "model_gateway_target must be an absolute https:// URL."
  }

  validation {
    condition     = !can(regex("/chat/completions/?$", var.model_gateway_target))
    error_message = "model_gateway_target must not include the /chat/completions suffix; Foundry appends it."
  }

  validation {
    condition     = !can(regex("/$", var.model_gateway_target))
    error_message = "model_gateway_target must not end with a trailing slash."
  }
}

variable "model_gateway_api_key" {
  description = "API key the Foundry connection presents to the gateway. Provide via TF_VAR_model_gateway_api_key; do not commit. Note: Terraform stores this in state in plaintext."
  type        = string
  sensitive   = true
  default     = null
}

variable "model_gateway_deployment_in_path" {
  description = "true  -> Foundry calls {target}/deployments/{deployment}/chat/completions. false -> Foundry calls {target}/chat/completions and passes {\"model\": \"<deployment>\"} in the body."
  type        = bool
  default     = false
}

variable "model_gateway_inference_api_version" {
  description = "Optional api-version query parameter appended to inference (chat completion) calls. Leave empty to omit — most non-Azure gateways do not expect it."
  type        = string
  default     = ""
}

variable "model_gateway_deployment_api_version" {
  description = "Optional api-version query parameter appended to dynamic model-discovery calls only. Leave empty to omit."
  type        = string
  default     = ""
}

variable "model_gateway_static_models" {
  description = "Static model catalogue (one entry per deployment the gateway exposes). Mutually exclusive with model_gateway_discovery. `name` is the deployment alias used in the agent model reference."
  type = list(object({
    name          = string
    model_name    = string
    model_version = optional(string, "")
    model_format  = optional(string, "OpenAI")
  }))
  default = []
}

variable "model_gateway_discovery" {
  description = "Dynamic model discovery endpoints, relative to model_gateway_target. Mutually exclusive with model_gateway_static_models. deployment_provider selects the response parser and must be OpenAI or AzureOpenAI."
  type = object({
    list_models_endpoint = string
    get_model_endpoint   = string
    deployment_provider  = optional(string, "OpenAI")
  })
  default = null

  validation {
    condition = alltrue([
      for d in(var.model_gateway_discovery == null ? [] : [var.model_gateway_discovery]) :
      contains(["OpenAI", "AzureOpenAI"], d.deployment_provider)
    ])
    error_message = "model_gateway_discovery.deployment_provider must be either OpenAI or AzureOpenAI."
  }

  validation {
    condition = alltrue([
      for d in(var.model_gateway_discovery == null ? [] : [var.model_gateway_discovery]) :
      can(regex("\\{deploymentName\\}", d.get_model_endpoint))
    ])
    error_message = "model_gateway_discovery.get_model_endpoint must contain the {deploymentName} placeholder."
  }
}

variable "model_gateway_custom_headers" {
  description = "Optional extra headers added to every inference request, e.g. for gateway policy routing. Leave empty to omit."
  type        = map(string)
  default     = {}
}

variable "model_gateway_auth_config" {
  description = "Optional override of the auth header shape. Defaults to the `api-key` header when unset. `format` is a template containing the {api_key} placeholder, e.g. name = \"Authorization\", format = \"Bearer {api_key}\"."
  type = object({
    name   = string
    format = optional(string, "{api_key}")
  })
  default = null

  validation {
    condition = alltrue([
      for a in(var.model_gateway_auth_config == null ? [] : [var.model_gateway_auth_config]) :
      can(regex("\\{api_key\\}", a.format))
    ])
    error_message = "model_gateway_auth_config.format must contain the {api_key} placeholder."
  }
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
    error_message = "The document_intelligence_kind value must be either FormRecognizer or AIServices."
  }
}

variable "document_intelligence_sku" {
  description = "SKU of the Document Intelligence account. S0 = standard pay-per-page (no base fee). F0 = free tier for trials only: analyzes just the first 2 pages of each document."
  type        = string
  default     = "S0"

  validation {
    condition     = contains(["F0", "S0"], var.document_intelligence_sku)
    error_message = "The document_intelligence_sku value must be either F0 or S0."
  }
}

variable "docintel_app_principal_ids" {
  description = "Optional Entra object IDs of application identities that perform document processing, each granted Cognitive Services User on the Document Intelligence account. Leave empty to skip."
  type        = list(string)
  default     = []
}

# ---------------------------------------------------------------------------
# Developer access
# ---------------------------------------------------------------------------
variable "agent_developer_principal_ids" {
  description = "Optional Entra object IDs (users or service principals) to grant the Foundry User role (formerly Azure AI User) on the Foundry account — and Cognitive Services User on the Document Intelligence account — so they can create/call agents and use DI. Leave empty to skip."
  type        = list(string)
  default     = []
}
