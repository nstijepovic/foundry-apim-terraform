# Public Foundry Standard Agent + APIM model connection + Document Intelligence

A **public-networking** variant of the Standard Agent deployment. It provisions the
same Azure AI Foundry Standard Agent stack as [`spoke-private-agent/`](../spoke-private-agent/)
but **without** any VNet, private endpoints, private DNS, VNet peering, or jumpbox —
the Foundry account, project, and dependent resources are reachable over their
public endpoints. The agent consumes its model through an existing **hub APIM
gateway**, and an optional **Azure Document Intelligence** account provides document
extraction for application code.

Use this when the customer wants the agent and its endpoints publicly accessible
instead of network-isolated.

## What it deploys

| # | Resource | Purpose |
| - | -------- | ------- |
| 1 | **Foundry account** (`Microsoft.CognitiveServices/accounts`, kind `AIServices`) | `publicNetworkAccess = Enabled`, `disableLocalAuth = true` (Entra ID only) |
| 2 | **Foundry project** | System-assigned managed identity; hosts the agent |
| 3 | **BYO dependencies** (required by the Standard Agent) | Cosmos DB (thread storage), AI Search (vector store), Storage account (files/blobs) — all public + AAD-only auth |
| 4 | **Project connections** (AAD) | One per BYO dependency |
| 5 | **Capability hosts** | **Account-level** caphost first, then the **project-level** caphost wiring the three connections. Newer regions (e.g. `westus3`) reject the project caphost if the account caphost doesn't exist |
| 6 | **RBAC** | Pre-/post-caphost roles for the project managed identity; optional developer access |
| 7 | **APIM model connection** (`category = ApiManagement`, `authType = ApiKey`) | Targets the hub APIM public gateway; the agent references its model as `<connection>/<deployment>` (e.g. `hub-apim-openai/gpt-5.1`) |
| 8 | **Document Intelligence** (optional, on by default) | Dedicated keyless account + project connection + RBAC — see [Azure Document Intelligence](#azure-document-intelligence) |

### How the model path works

Agent runs execute via the **Responses API**: your client calls the Foundry project
endpoint, the agent runtime resolves the `hub-apim-openai` connection, and calls
`<apim-gateway>/<path>/responses?api-version=<inferenceAPIVersion>` with the APIM
subscription key in the `api-key` header. APIM then authenticates to the Azure
OpenAI backend with its managed identity.

> **`apim_inference_api_version` must be `2025-03-01-preview` or a later
> Responses-capable version.** The last dated GA (`2024-10-21`) has no `/responses`
> routes: connection listing and plain chat completions will work, but agent runs
> will fail. (Responses is GA only in the new `v1` URL surface, which the APIM
> connection convention does not use.)

## Differences vs. `spoke-private-agent/`

| Concern | spoke-private-agent | public-foundry-agent |
| --- | --- | --- |
| Foundry account | `publicNetworkAccess = Disabled` + `networkInjections` | `publicNetworkAccess = Enabled`, no injection |
| Cosmos / Search / Storage | public access disabled + private endpoints | public access enabled, no private endpoints |
| VNet / subnets / private DNS | created | none |
| VNet peering to hub | optional (`enable_apim_private_endpoint`) | none |
| Jumpbox VM + Bastion | optional (`enable_jumpbox`) | none |
| Reaching the account/portal | via jumpbox inside the VNet | directly from your machine |
| Document Intelligence | not included | optional dedicated account + connection |

## Prerequisites

- Terraform `>= 1.10.0`, `azurerm` `~> 4.37`, `azapi` `~> 2.5`; Azure CLI logged in.
- `Contributor` + `User Access Administrator` on the target subscription (role
  assignments are created).
- From the central APIM team: gateway name, published API path, an **entity
  Product-scoped subscription key** (never the master key), the approved model
  deployment alias, and a Responses-capable inference API version. The APIM API
  must expose the inference, `/responses*`, and `/deployments*` operations and
  accept the key in the **`api-key` header**.
- Region check: Standard Agent support, model capacity, and Document Intelligence
  availability in the target region.
- Ask whether the subscription runs policies/automation that disable
  `publicNetworkAccess` on Storage/Cosmos (security baselines do this silently);
  get an exemption for the resource group up front, or agent creation will fail
  with a Cosmos 403.

## Deploy — step by step

### 1. Configure an environment tfvars

Copy `environments/prod.tfvars` to `environments/<env>.tfvars` and set:

| Variable | Notes |
| --- | --- |
| `subscription_id` | **Required, no default** — refuses to run without it |
| `location` / `resource_group_name` | Verified region + new RG |
| `name_prefix` / `project_name_prefix` | Short, lowercase; a random 4-char suffix is appended |
| `hub_apim_name` | **Required, no default** — from the managing team |
| `apim_openai_path` / `apim_openai_connection_name` | Published API path; connection name used in the agent model reference |
| `apim_inference_api_version` | `2025-03-01-preview` or later (see above) |
| `enable_document_intelligence` / `document_intelligence_kind` / `document_intelligence_sku` | See the DI section |
| `agent_developer_principal_id` | Your object ID (`az ad signed-in-user show --query id -o tsv`) so you can create agents and call DI while testing |
| `docintel_app_principal_id` | Optional: the app identity that will call DI |

### 2. Set the secret (session only, never a file)

```powershell
$env:TF_VAR_apim_subscription_key = "<entity-product-scoped-apim-key>"
```

### 3. Isolate state per environment

```powershell
terraform init
terraform workspace new <env>     # separate state per environment
```

For team/CI use, configure an `azurerm` remote state backend instead (a
git-ignored `backend.tf`), one state key per environment.

### 4. Plan and apply

```powershell
terraform plan  -var-file="environments/<env>.tfvars" -out="<env>.tfplan"
terraform show  "<env>.tfplan"    # expect ~25 adds, 0 changes, 0 destroys
terraform apply "<env>.tfplan"    # ~20 minutes; Cosmos is the slow part
```

### 5. Validate

```powershell
terraform output                  # project_endpoint, docintel_endpoint, ...

# Document Intelligence account: kind FormRecognizer, keyless
az cognitiveservices account show -n <docintel_account_name> -g <rg> `
  --query "{kind:kind, disableLocalAuth:properties.disableLocalAuth}"

# All 5 project connections present (ApiManagement, CognitiveService, + 3 BYO)
az rest --method get --uri "https://management.azure.com/<foundry_account_id>/projects/<project_name>/connections?api-version=2025-06-01" `
  --query "value[].{name:name, category:properties.category}" -o table
```

Then run the end-to-end tests from [`../agent-samples/`](../agent-samples/) — no
jumpbox needed, the endpoints are public:

```powershell
$env:AZURE_AI_PROJECT_ENDPOINT = "<project_endpoint output>"
$env:AZURE_AI_CONNECTION_NAME  = "hub-apim-openai"
$env:AZURE_AI_MODEL_NAME       = "<approved deployment alias>"
uv sync
uv run test_connection.py         # agent responds through APIM
uv run create_agent.py            # persistent agent
```

A `403` in the first minutes after apply is RBAC propagation — retry before
debugging.

### 6. Hand over

- Remove or repoint `agent_developer_principal_id`; set `docintel_app_principal_id`
  to the customer's app identity; re-apply.
- APIM key rotation: update the env var and re-apply (the key lives in the
  connection credential and in state — protect state accordingly).

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

## Remote state

This folder has no backend block; `terraform init` uses local state by default. For CI/CD,
generate a `backend.tf` (git-ignored) pointing at the shared state storage account, matching
the pattern used by the workflows for the private folder.

> ⚠️ State contains the APIM subscription key in plaintext. Never commit it, and
> lock down any remote state storage accordingly.
