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
- **Azure Document Intelligence** (optional, on by default): a dedicated keyless
  Cognitive Services account, a Foundry project connection to it, and the related
  role assignments. See [Azure Document Intelligence](#azure-document-intelligence).

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

## Azure Document Intelligence

When `enable_document_intelligence = true` (the default), the deployment adds:

- A **dedicated Document Intelligence account** (`azurerm_cognitive_account`,
  `kind = FormRecognizer`, sku `S0`), keyless (`local_auth_enabled = false`) with a
  custom subdomain — callers authenticate with Entra ID only.
- A **Foundry project connection** (`category = CognitiveService`, `authType = AAD`,
  no secret stored) so the endpoint is visible under the project's connected
  resources and discoverable via the SDK.
- **Cognitive Services User** role assignments on the account for the project's
  managed identity, the optional `agent_developer_principal_id`, and the optional
  `docintel_app_principal_id` (an application identity that processes documents).

Configuration knobs (tfvars):

| Variable | Default | Notes |
| --- | --- | --- |
| `enable_document_intelligence` | `true` | Set `false` to skip everything above. |
| `document_intelligence_kind` | `FormRecognizer` | `FormRecognizer` = Document Intelligence only (narrowest RBAC). `AIServices` = multi-service account (adds Speech/Vision/Language/Content Understanding); changing recreates the account and its endpoint hostname. |
| `document_intelligence_sku` | `S0` | `S0` is pay-per-page with no base fee. `F0` (free) analyzes **only the first 2 pages** of each document — trials only. |
| `docintel_app_principal_id` | `null` | Optional object ID of the customer app identity that calls DI. |

> **How it's consumed:** Document Intelligence is **not** a built-in agent tool —
> the agent does not call it automatically. Application code performs the DI calls
> (use API version `2024-11-30`, the v4.0 GA) and passes the extracted content to
> the agent. The project connection provides endpoint discovery:
>
> ```python
> from azure.identity import DefaultAzureCredential
> from azure.ai.projects import AIProjectClient
> from azure.ai.documentintelligence import DocumentIntelligenceClient
>
> project = AIProjectClient(endpoint=PROJECT_ENDPOINT, credential=DefaultAzureCredential())
> conn = project.connections.get("<docintel_connection_name output>")
> di = DocumentIntelligenceClient(endpoint=conn.target, credential=DefaultAzureCredential())
> with open("sample.pdf", "rb") as f:
>     result = di.begin_analyze_document("prebuilt-read", f).result()
> ```
>
> Alternatively skip the lookup and configure the `docintel_endpoint` output directly.

Notes:

- Role assignments can take a few minutes to propagate; a `403` immediately after
  `apply` usually resolves on retry.
- Deleted Cognitive Services accounts are soft-deleted for 48 hours; recreating with
  the same name requires a purge (the random suffix normally avoids collisions).
- Custom-model training (requires a training storage container + CORS), diagnostics,
  and private networking are out of scope here, consistent with the rest of this
  variant.

## Using the agent from a local machine

Because the endpoints are public, the [`agent-samples/`](../agent-samples/) scripts run
from your machine with `DefaultAzureCredential` — no jumpbox needed. Use the
`project_endpoint` output as the SDK endpoint and the model reference
`hub-apim-openai/<deployment-name>`.

## Remote state

This folder has no backend block; `terraform init` uses local state by default. For CI/CD,
generate a `backend.tf` (git-ignored) pointing at the shared state storage account, matching
the pattern used by the workflows for the private folder.
