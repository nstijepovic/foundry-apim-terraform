# Hub APIM and the Azure OpenAI account live in the SAME subscription (different resource
# groups), so a single provider configuration is enough.
provider "azurerm" {
  features {}
  subscription_id = var.subscription_id
}

provider "azapi" {
  subscription_id = var.subscription_id
}
