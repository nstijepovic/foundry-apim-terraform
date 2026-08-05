provider "azurerm" {
  features {}
  subscription_id = var.subscription_id
  # Storage accounts have shared-key auth disabled; use Entra ID for data-plane
  # calls so the provider does not attempt (and fail) key-based blob polling.
  storage_use_azuread = true
}

provider "azapi" {
  subscription_id = var.subscription_id
}
