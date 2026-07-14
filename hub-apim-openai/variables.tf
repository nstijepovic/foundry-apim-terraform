variable "subscription_id" {
  description = "Subscription ID that hosts the hub APIM and the new Azure OpenAI account"
  type        = string
  default     = "fbfbfbe5-9ee2-43ed-b514-f3266c2193ab"
}

variable "location" {
  description = "Azure region for the Azure OpenAI account and model deployment"
  type        = string
  default     = "eastus2"
}

########## Hub-side Azure OpenAI ##########

variable "openai_resource_group_name" {
  description = "Name of the NEW resource group (in the hub subscription) to create for the Azure OpenAI account"
  type        = string
  default     = "rg-openai-hub"
}

variable "openai_name_prefix" {
  description = "Prefix for the Azure OpenAI (Cognitive Services) account name; a random suffix is appended"
  type        = string
  default     = "aoai"
}

variable "model_name" {
  description = "Model to deploy (also used as the deployment name)"
  type        = string
  default     = "gpt-5.1"
}

variable "model_version" {
  description = "Exact model version string. Leave empty (\"\") to let Azure pick the default version for the model."
  type        = string
  default     = "2025-11-13"
}

variable "model_sku_name" {
  description = "Deployment SKU (GlobalStandard, Standard, DataZoneStandard, etc.)"
  type        = string
  default     = "GlobalStandard"
}

variable "model_capacity" {
  description = "Deployment capacity (thousands of tokens per minute)"
  type        = number
  default     = 40
}

########## Hub (existing API Management) ##########

variable "hub_apim_name" {
  description = "Name of the EXISTING API Management instance in the hub resource group"
  type        = string
  default     = "hun-apim-test-007"
}

variable "hub_apim_resource_group_name" {
  description = "Resource group that contains the existing API Management instance"
  type        = string
  default     = "hub-apim-test"
}

variable "api_path" {
  description = "URL path suffix for the Azure OpenAI API exposed by APIM (e.g. {gateway}/openai/...)"
  type        = string
  default     = "openai"
}

variable "openai_spec_url" {
  description = "OpenAPI (Swagger) link for the Azure OpenAI inference data-plane API imported into APIM"
  type        = string
  default     = "https://raw.githubusercontent.com/Azure/azure-rest-api-specs/main/specification/cognitiveservices/data-plane/AzureOpenAI/inference/stable/2024-10-21/inference.json"
}

########## Hub networking (APIM private endpoint + VNet for spoke peering) ##########

variable "enable_apim_private_endpoint" {
  description = "When true, creates the hub VNet + APIM Gateway private endpoint + private DNS zone for spoke peering."
  type        = bool
  default     = true
}

variable "hub_vnet_name" {
  description = "Name of the hub VNet that hosts the APIM private endpoint."
  type        = string
  default     = "hub-vnet"
}

variable "hub_vnet_location" {
  description = "Region for the hub VNet + APIM private endpoint. Must match the region used by the spoke's private DNS resolution (and typically the APIM region)."
  type        = string
  default     = "uaenorth"
}

variable "hub_vnet_address_space" {
  description = "Address space for the hub VNet. Must NOT overlap the spoke VNet (192.168.0.0/16)."
  type        = list(string)
  default     = ["10.0.0.0/16"]
}

variable "hub_pe_subnet_prefix" {
  description = "Address prefix for the hub private endpoint subnet."
  type        = string
  default     = "10.0.1.0/24"
}
