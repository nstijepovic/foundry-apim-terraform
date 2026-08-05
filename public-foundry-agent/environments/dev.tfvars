# Public Foundry + APIM connection — TEMPLATE / dev environment.
#
# Copy this file and adjust for your own subscription:
#   cp environments/dev.tfvars environments/<env>.tfvars
#
# Secrets are never stored here — provide them per session:
#   $env:TF_VAR_apim_subscription_key = "<product-scoped-apim-key>"

subscription_id     = "fbfbfbe5-9ee2-43ed-b514-f3266c2193ab"
location            = "uaenorth" # confirm Standard Agent support in the target region
resource_group_name = "rg-public-agent-uaen"

name_prefix         = "foundry"
project_name_prefix = "proj"

# Deterministic suffix appended to generated resource names.
# The Foundry account, Storage, Search and Cosmos names must be GLOBALLY unique,
# so change this to something of your own before the first apply. Setting it to
# "" removes the suffix entirely and will usually collide with existing names.
# Changing it after deployment RENAMES resources, which means destroy + recreate.
name_suffix = "e3hd"

# ---------------------------------------------------------------------------
# Foundry -> hub APIM model connection
# ---------------------------------------------------------------------------
enable_apim_model_connection = true
hub_apim_name                = "hun-apim-test-007"
apim_openai_connection_name  = "hub-apim-openai"
apim_openai_path             = "openai"
apim_inference_api_version   = "2024-10-21"

# --- Model discovery -------------------------------------------------------
# Default (empty list) = dynamic discovery: Foundry calls the gateway's
# /deployments routes to learn which models exist.
#
# If the gateway does not expose those routes — or they return errors — declare
# a static catalogue instead, one entry per approved deployment alias. Foundry
# then skips discovery entirely.
#
# apim_static_models = [
#   {
#     name       = "gpt-4o-deployment" # deployment alias behind the gateway
#     model_name = "gpt-4o"            # underlying model family
#     # model_version = ""             # optional (default "")
#     # model_format  = "OpenAI"       # optional (default "OpenAI")
#   },
# ]

# ---------------------------------------------------------------------------
# Azure Document Intelligence (dedicated keyless account + project connection)
# ---------------------------------------------------------------------------
enable_document_intelligence = true
document_intelligence_kind   = "FormRecognizer"
document_intelligence_sku    = "S0"
# Optional: object IDs of app identities that process documents.
# docintel_app_principal_ids = ["00000000-0000-0000-0000-000000000000"]

# Optional: grant one or more object IDs the Foundry User role so they can create
# agents from their local machine (and Cognitive Services User on DI). Get your own
# ID with: az ad signed-in-user show --query id -o tsv
# agent_developer_principal_ids = [
#   "00000000-0000-0000-0000-000000000000",
#   "11111111-1111-1111-1111-111111111111",
# ]
