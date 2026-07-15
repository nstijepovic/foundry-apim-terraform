# Public Foundry Basic Agent + APIM model connection

A **public-networking**, **basic-setup** variant of the Foundry Agent deployment.
Unlike the Standard Agent stack in [`public-foundry-agent/`](../public-foundry-agent/),
the basic setup uses **Microsoft-managed, multitenant storage** for agent files,
threads, and vector stores — so there are **no BYO Cosmos DB, Azure AI Search, or
Storage account**, and **no capability host**.

Use this when you want the simplest agent setup and don't need data to stay in your
own Azure resources (no data-sovereignty / single-tenant isolation requirement).

## What it deploys

- **Foundry account** (`Microsoft.CognitiveServices/accounts`, kind `AIServices`) with
  `publicNetworkAccess = Enabled`, `disableLocalAuth = true` (Entra ID only).
- **Foundry project** with a system-assigned managed identity.
- **APIM model connection** (`category = ApiManagement`) targeting the hub APIM public
  gateway so the agent consumes the model behind APIM.
- Optional **developer RBAC** (Foundry User, formerly Azure AI User) on the account.

That's it — no dependencies, no connections to BYO storage, no capability host, no
pre/post-caphost role assignments.

## Basic vs. Standard (`public-foundry-agent/`)

| Concern | public-foundry-agent (standard) | public-foundry-agent-basic |
| --- | --- | --- |
| Agent state storage | **BYO** Cosmos + Search + Storage (your tenant) | **Microsoft-managed** multitenant |
| Capability host | project caphost wiring the 3 connections | none |
| BYO dependencies | Cosmos DB, AI Search, Storage account | none |
| RBAC on project MI | pre/post-caphost roles on the 3 resources | none |
| Data sovereignty / isolation | full (single-tenant) | not applicable |
| APIM model connection | yes | yes |

Both variants are public-networking (no VNet, private endpoints, or jumpbox) and both
consume the model through the hub APIM gateway.

## Prerequisites

- Terraform `>= 1.10.0`, `azurerm` `~> 4.37`, `azapi` `~> 2.5`.
- An existing hub APIM instance exposing the model (default `hun-apim-test-007`), with
  its subscription-key header set to `api-key`.
- Permission to create resources (and assign roles, if using `agent_developer_principal_id`).

## Deploy

Provide the APIM subscription key as an environment variable (never commit it):

```powershell
$env:TF_VAR_apim_subscription_key = "<hub-apim-subscription-key>"

terraform init
terraform plan  -var-file="environments/dev.tfvars"
terraform apply -var-file="environments/dev.tfvars"
```

To let your own identity create agents from your machine, set
`agent_developer_principal_id` in the tfvars to your object ID:

```powershell
az ad signed-in-user show --query id -o tsv
```

## Using the agent from a local machine

Because the endpoints are public, agent scripts run from your machine with
`DefaultAzureCredential`. Use the `project_endpoint` output as the SDK endpoint and the
model reference `hub-apim-openai/<deployment-name>`.

## Remote state

This folder has no backend block; `terraform init` uses local state by default.
