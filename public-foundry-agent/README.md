# Public Foundry Standard Agent + APIM model connection + Document Intelligence

Public-networking variant of the Standard Agent deployment. Same stack as
[`spoke-private-agent/`](../spoke-private-agent/) — Foundry account + project, BYO
Cosmos/Search/Storage, capability hosts, APIM model connection — but no VNet, private
endpoints, or jumpbox. Includes an optional dedicated Document Intelligence account.

## What it deploys

| Resource | Notes |
| --- | --- |
| Foundry account (kind `AIServices`) | `publicNetworkAccess = Enabled`, Entra ID only |
| Foundry project | System-assigned identity; hosts the agent |
| Cosmos DB, AI Search, Storage | BYO dependencies, public + AAD-only auth |
| Project connections | AAD, one per BYO dependency |
| Capability hosts | Account-level, then project-level (account must exist first) |
| RBAC | Pre-/post-caphost roles on the project identity; optional developer access |
| APIM model connection | `category = ApiManagement`; model reference is `<connection>/<deployment>`, e.g. `hub-apim-openai/gpt-5.1` |
| Document Intelligence (optional, default on) | Dedicated keyless account + project connection + RBAC |

The agent calls Foundry's own Responses API; Foundry in turn calls **chat completions**
on the APIM connection (not `/responses`) — so `apim_inference_api_version` only needs to
be a version your gateway's chat completions endpoint accepts, not a Responses-capable one.

## Prerequisites

- Terraform `>= 1.10.0`, Azure CLI logged in.
- `Contributor` + `User Access Administrator` on the target subscription.
- From the central APIM team: gateway name, published API path, an entity
  Product-scoped subscription key (never the master key), the approved model
  deployment alias, and the inference API version their chat completions endpoint expects.
- Confirm region support for Standard Agent, model capacity, and Document Intelligence.
- Check whether the subscription auto-disables `publicNetworkAccess` on Storage/Cosmos
  (some security baselines do) — get an exemption up front or agent creation fails.

## Deploy

```pwsh
cp environments/prod.tfvars environments/<env>.tfvars
```

1. Edit `environments/<env>.tfvars`: `subscription_id`, `location`, `resource_group_name`,
   naming prefixes, `hub_apim_name`, `apim_openai_path`, `apim_inference_api_version`,
   the Document Intelligence block, and `agent_developer_principal_id` (your object ID,
   via `az ad signed-in-user show --query id -o tsv`).
2. Set the secret for this session only:
   ```pwsh
   $env:TF_VAR_apim_subscription_key = "<entity-product-scoped-apim-key>"
   ```
3. Isolate state, then plan and apply:
   ```pwsh
   terraform init
   terraform workspace new <env>
   terraform plan  -var-file="environments/<env>.tfvars" -out="<env>.tfplan"
   terraform apply "<env>.tfplan"
   ```

## Validate

```pwsh
terraform output   # project_endpoint, docintel_endpoint, ...
```

From [`../agent-samples/`](../agent-samples/) (no jumpbox needed, endpoints are public):

```pwsh
$env:AZURE_AI_PROJECT_ENDPOINT = "<project_endpoint output>"
$env:AZURE_AI_CONNECTION_NAME  = "hub-apim-openai"
$env:AZURE_AI_MODEL_NAME       = "<approved deployment alias>"
uv sync
uv run test_connection.py
uv run create_agent.py
uv run chat_with_agent.py
```

A `403` in the first minutes after apply is RBAC propagation — retry before debugging.

## Document Intelligence

On by default (`enable_document_intelligence = true`). Deploys a dedicated, keyless
Document Intelligence account (`document_intelligence_kind = FormRecognizer`), a Foundry
project connection to it, and Cognitive Services User role assignments for the project
identity, `agent_developer_principal_id`, and `docintel_app_principal_id`.

## Hand over

- Repoint `agent_developer_principal_id` and `docintel_app_principal_id` to the
  customer's identities, then re-apply.
