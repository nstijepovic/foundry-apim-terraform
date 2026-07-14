########## Hub-side Azure OpenAI model, fronted by the existing hub API Management ##########

data "azurerm_client_config" "current" {}

## Reference the EXISTING hub API Management instance (not managed by this config)
data "azurerm_api_management" "hub" {
  name                = var.hub_apim_name
  resource_group_name = var.hub_apim_resource_group_name
}

## Random suffix for a globally-unique Cognitive Services account / custom subdomain
resource "random_string" "unique" {
  length      = 4
  min_numeric = 4
  numeric     = true
  special     = false
  lower       = true
  upper       = false
}

locals {
  account_name = lower("${var.openai_name_prefix}${random_string.unique.result}")
  # Azure OpenAI data-plane endpoint (custom subdomain == account name)
  openai_endpoint = "https://${local.account_name}.openai.azure.com"
}

## ---------------------------------------------------------------------------
## Azure OpenAI account + model deployment (hub subscription)
## ---------------------------------------------------------------------------

resource "azurerm_resource_group" "openai" {
  name     = var.openai_resource_group_name
  location = var.location
}

## Azure OpenAI account (AIServices kind). Public network access is ENABLED because the
## hub APIM is not network-restricted; local (key) auth is DISABLED so only Entra ID
## (APIM's managed identity) can call it.
resource "azapi_resource" "openai" {
  type      = "Microsoft.CognitiveServices/accounts@2025-04-01-preview"
  name      = local.account_name
  location  = var.location
  parent_id = azurerm_resource_group.openai.id

  body = {
    kind = "AIServices"
    sku = {
      name = "S0"
    }
    properties = {
      customSubDomainName = local.account_name
      publicNetworkAccess = "Enabled"
      disableLocalAuth    = true
      networkAcls = {
        defaultAction = "Allow"
      }
    }
  }

  response_export_values = ["properties.endpoint"]
}

## Model deployment (e.g. gpt-5.1). If var.model_version is empty, Azure selects the
## default version for the model.
resource "azapi_resource" "model_deployment" {
  type      = "Microsoft.CognitiveServices/accounts/deployments@2025-04-01-preview"
  name      = var.model_name
  parent_id = azapi_resource.openai.id

  body = {
    sku = {
      name     = var.model_sku_name
      capacity = var.model_capacity
    }
    properties = {
      model = var.model_version == "" ? {
        name   = var.model_name
        format = "OpenAI"
        } : {
        name    = var.model_name
        format  = "OpenAI"
        version = var.model_version
      }
    }
  }
}

## ---------------------------------------------------------------------------
## HUB: ensure APIM has a system-assigned identity, grant it access, wire up API
## ---------------------------------------------------------------------------

## Non-destructive PATCH to guarantee the existing APIM has a system-assigned identity.
resource "azapi_update_resource" "apim_identity" {
  type        = "Microsoft.ApiManagement/service@2024-05-01"
  resource_id = data.azurerm_api_management.hub.id

  body = {
    identity = {
      type = "SystemAssigned"
    }
  }

  response_export_values = ["identity.principalId"]
}

## Grant the APIM managed identity permission to call the Azure OpenAI account (keyless).
resource "azurerm_role_assignment" "apim_openai_user" {
  scope                = azapi_resource.openai.id
  role_definition_name = "Cognitive Services OpenAI User"
  principal_id         = azapi_update_resource.apim_identity.output.identity.principalId
}

## Allow the RBAC assignment to propagate before traffic flows through the gateway.
resource "time_sleep" "wait_for_rbac" {
  depends_on      = [azurerm_role_assignment.apim_openai_user]
  create_duration = "60s"
}

## Backend pointing at the Azure OpenAI endpoint.
resource "azurerm_api_management_backend" "openai" {
  name                = "openai-backend"
  resource_group_name = var.hub_apim_resource_group_name
  api_management_name = data.azurerm_api_management.hub.name
  protocol            = "https"
  url                 = "${local.openai_endpoint}/openai"
}

## Import the Azure OpenAI inference API into APIM.
resource "azurerm_api_management_api" "openai" {
  name                  = "azure-openai-api"
  resource_group_name   = var.hub_apim_resource_group_name
  api_management_name   = data.azurerm_api_management.hub.name
  revision              = "1"
  display_name          = "Azure OpenAI API"
  path                  = var.api_path
  protocols             = ["https"]
  service_url           = "${local.openai_endpoint}/openai"
  subscription_required = true

  # Accept the subscription key in the `api-key` header/query, matching what the
  # Azure OpenAI SDK (and Foundry AzureOpenAI connections) send, instead of the
  # default Ocp-Apim-Subscription-Key.
  subscription_key_parameter_names {
    header = "api-key"
    query  = "api-key"
  }

  import {
    content_format = "openapi-link"
    content_value  = var.openai_spec_url
  }
}

## API-level policy: route to the backend and authenticate with APIM's managed identity.
resource "azurerm_api_management_api_policy" "openai" {
  api_name            = azurerm_api_management_api.openai.name
  api_management_name = data.azurerm_api_management.hub.name
  resource_group_name = var.hub_apim_resource_group_name

  xml_content = <<XML
<policies>
  <inbound>
    <base />
    <set-backend-service backend-id="${azurerm_api_management_backend.openai.name}" />
    <authentication-managed-identity resource="https://cognitiveservices.azure.com" />
  </inbound>
  <backend>
    <base />
  </backend>
  <outbound>
    <base />
  </outbound>
  <on-error>
    <base />
  </on-error>
</policies>
XML

  depends_on = [time_sleep.wait_for_rbac]
}
