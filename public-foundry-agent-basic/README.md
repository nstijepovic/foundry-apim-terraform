# Public Foundry Basic Agent + APIM model connection

Minimal public-networking variant. Unlike [`public-foundry-agent/`](../public-foundry-agent/),
this uses **Microsoft-managed, multitenant storage** for agent files, threads, and vector
stores — no BYO Cosmos/Search/Storage, no capability host.

Use this when you don't need data-sovereignty / single-tenant isolation.

## What it deploys

- Foundry account (kind `AIServices`), `publicNetworkAccess = Enabled`, Entra ID only.
- Foundry project with a system-assigned identity.
- APIM model connection (`category = ApiManagement`) targeting the hub APIM gateway.
- Optional developer RBAC (`agent_developer_principal_id` → Foundry User role).

No BYO dependencies, no capability host, no pre/post-caphost RBAC.

## Prerequisites

- Terraform `>= 1.10.0`, Azure CLI logged in.
- An existing hub APIM instance exposing the model, subscription-key header set to `api-key`.
- Permission to create resources (and assign roles, if using `agent_developer_principal_id`).

## Deploy

```pwsh
$env:TF_VAR_apim_subscription_key = "<hub-apim-subscription-key>"

terraform init
terraform plan  -var-file="environments/dev.tfvars"
terraform apply -var-file="environments/dev.tfvars"
```

To create agents from your machine, set `agent_developer_principal_id` in the tfvars to
your object ID (`az ad signed-in-user show --query id -o tsv`).

## Use it

Endpoints are public — run [`../agent-samples/`](../agent-samples/) directly from your
machine. Use the `project_endpoint` output and model reference `hub-apim-openai/<deployment-name>`.

No backend block is committed; `terraform init` uses local state by default.
