# Public Foundry Standard Agent + APIM model connection

A **public-networking** variant of the Standard Agent deployment. It provisions the
same Azure AI Foundry Standard Agent stack as [`spoke-private-agent/`](../spoke-private-agent/)
but **without** any VNet, private endpoints, private DNS, VNet peering, or jumpbox —
the Foundry account, project, and dependent resources are reachable over their
public endpoints.

Use this when the customer wants the agent and its endpoints publicly accessible
instead of network-isolated.

## What it deploys

- **Foundry account** (`Microsoft.CognitiveServices/accounts`, kind `AIServices`) with
  `publicNetworkAccess = Enabled`, `disableLocalAuth = true` (Entra ID only).
- **Foundry project** with a system-assigned managed identity.
- **BYO dependencies** (required by the Standard Agent), all public + AAD auth:
  - Cosmos DB (SQL API) — thread storage
  - Azure AI Search — vector store
  - Storage account (StorageV2, AAD-only) — file/blob storage
- **Project connections** (AAD) to the three dependencies.
- **Capability host** (`kind = Agents`) wiring the connections.
- **RBAC** on the project managed identity (pre- and post-capability-host roles).
- **APIM model connection** (`category = ApiManagement`) targeting the hub APIM public
  gateway so the agent consumes the model behind APIM.

## Differences vs. `spoke-private-agent/`

| Concern | spoke-private-agent | public-foundry-agent |
| --- | --- | --- |
| Foundry account | `publicNetworkAccess = Disabled` + `networkInjections` | `publicNetworkAccess = Enabled`, no injection |
| Cosmos / Search / Storage | public access disabled + private endpoints | public access enabled, no private endpoints |
| VNet / subnets / private DNS | created | none |
| VNet peering to hub | optional (`enable_apim_private_endpoint`) | none |
| Jumpbox VM + Bastion | optional (`enable_jumpbox`) | none |
| Reaching the account/portal | via jumpbox inside the VNet | directly from your machine |

## Prerequisites

- Terraform `>= 1.10.0`, `azurerm` `~> 4.37`, `azapi` `~> 2.5`.
- An existing hub APIM instance exposing the model (default `hun-apim-test-007`), with
  its subscription-key header set to `api-key`.
- Permission to create resources and assign roles in the target subscription.

## Deploy

Provide the APIM subscription key as an environment variable (never commit it):

```powershell
$env:TF_VAR_apim_subscription_key = "<hub-apim-subscription-key>"

terraform init
terraform plan  -var-file="environments/dev.tfvars"
terraform apply -var-file="environments/dev.tfvars"
```

To let your own identity create agents from your machine, set
`agent_developer_principal_id` in the tfvars (see the commented line) to your object ID:

```powershell
az ad signed-in-user show --query id -o tsv
```

## Using the agent from a local machine

Because the endpoints are public, the [`agent-samples/`](../agent-samples/) scripts run
from your machine with `DefaultAzureCredential` — no jumpbox needed. Use the
`project_endpoint` output as the SDK endpoint and the model reference
`hub-apim-openai/<deployment-name>`.

## Remote state

This folder has no backend block; `terraform init` uses local state by default. For CI/CD,
generate a `backend.tf` (git-ignored) pointing at the shared state storage account, matching
the pattern used by the workflows for the private folder.
