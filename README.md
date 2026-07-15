# Microsoft Foundry Agent behind a Central API Management Gateway

Deploy a **private-network Microsoft Foundry standard agent** (spoke) that consumes an LLM
served through an **existing Azure API Management (APIM) gateway**. By default, Foundry calls
APIM's published public HTTPS endpoint; the APIM instance, Azure OpenAI resources, PTU
deployments, and backend network remain inaccessible to the customer. The Foundry account can
still use its own private network for agents and customer-owned resources.

This repo is split into three parts you deploy/run in order:

| # | Folder | What it does |
| - | ------ | ------------ |
| 1 | [`hub-apim-openai/`](hub-apim-openai) | Creates an Azure OpenAI model and wires it behind your existing hub APIM (imports inference and discovery operations and configures managed-identity backend access). |
| 2 | [`spoke-private-agent/`](spoke-private-agent) | Deploys the private Foundry account + project (BYO Storage/Search/Cosmos), its own VNet, an APIM **connection**, and a **jumpbox** VM (reached via Azure Bastion). |
| 3 | [`agent-samples/`](agent-samples) | Python scripts to create and chat with an agent that routes its model calls through the APIM connection. Run these **from the jumpbox**. |

> `code/` is early single-folder scaffolding and is **not** part of the supported flow — ignore it.

## Architecture

```mermaid
flowchart LR
  subgraph Platform["Central AI platform"]
    APIM["API Management\n(public gateway endpoint)"]
        AOAI["Azure OpenAI\n(gpt model)"]
        APIM --> AOAI
    end
    subgraph Spoke["Spoke VNet (private)"]
        Foundry["Foundry account + project\n(public access disabled)"]
        Conn["APIM connection\n(ApiManagement)"]
        JB["Jumpbox VM\n(via Bastion)"]
        Foundry --- Conn
    end
    JB -->|create/chat agent| Foundry
    Conn -->|HTTPS + customer APIM key| APIM
```

The agent references its model as `<connection-name>/<deployment-name>` (e.g.
`hub-apim-openai/gpt-5.1`). Foundry resolves the connection, which points at the APIM gateway
URL, and APIM forwards the request to the backend Azure OpenAI deployment.

### How the Foundry APIM connection works

The spoke creates a project connection with `category = "ApiManagement"`. Its target is the
hub gateway URL (`https://<apim-name>.azure-api.net/<api-path>`), and its model reference is
`<connection-name>/<deployment-name>`. This follows the Microsoft Foundry
[AI gateway connection pattern](https://learn.microsoft.com/en-us/azure/foundry/agents/how-to/ai-gateway).

The request path has two separate authentication hops:

1. **Foundry to APIM:** Foundry reads the APIM subscription key from the connection credential
  and sends it in the `api-key` header. The APIM API is configured to accept that header as its
  subscription-key header.
2. **APIM to Azure OpenAI:** APIM discards the need for an Azure OpenAI key and obtains a token
  with its system-assigned identity. The API policy requests the
  `https://cognitiveservices.azure.com` audience, and Terraform grants the APIM identity the
  **Cognitive Services OpenAI User** role on the account. See the official
  [`authentication-managed-identity` policy](https://learn.microsoft.com/en-us/azure/api-management/authentication-managed-identity-policy).

This deployment uses **dynamic model discovery**, so the connection does not contain a static
`models` list. Foundry uses the standard APIM discovery conventions:

```text
GET <target>/deployments
GET <target>/deployments/{deploymentName}
```

The hub Terraform creates both operations. Their operation-level policies authenticate to
Azure Resource Manager as the APIM identity and return the Azure OpenAI deployment objects that
Foundry expects. These routes and response formats follow the official
[APIM connection schema](https://github.com/microsoft-foundry/foundry-samples/blob/main/infrastructure/infrastructure-setup-bicep/01-connections/apim/APIM-Connection-Objects.md)
and [APIM setup guide for Foundry Agents](https://github.com/microsoft-foundry/foundry-samples/blob/main/infrastructure/infrastructure-setup-bicep/01-connections/apim/apim-setup-guide-for-agents.md).

#### Static versus dynamic model discovery

Foundry APIM connections support either mode. The agent model reference remains
`<connection-name>/<deployment-name>` in both cases; only the source of the deployment catalog
changes.

| Mode | Connection metadata | Required APIM operations | Best fit |
| ---- | ------------------- | ------------------------ | -------- |
| **Dynamic (used here)** | Omit `models`; optionally configure `modelDiscovery` for nonstandard paths | Inference operations plus `GET /deployments` and `GET /deployments/{deploymentName}` | Deployments change regularly and APIM should remain the source of truth |
| **Static** | Include a serialized `models` catalog | Inference operations only; Foundry does not call discovery routes | An explicit, controlled allowlist that changes infrequently |

A static connection would use metadata equivalent to:

```json
{
  "deploymentInPath": "true",
  "inferenceAPIVersion": "2025-03-01-preview",
  "models": [
    {
      "name": "gpt-5.1",
      "properties": {
        "model": {
          "name": "gpt-5.1",
          "version": "2025-11-13",
          "format": "OpenAI"
        }
      }
    }
  ]
}
```

For the ARM/Bicep/Terraform connection resource, `models` is stored as a JSON-serialized string,
not as a native nested array. Static discovery removes only the two deployment-discovery calls;
APIM must still expose the inference operation used by Agent Service, including `POST /responses`
for these samples. When a static deployment is added, renamed, upgraded, or removed, update and
redeploy the connection metadata to keep the catalog synchronized with APIM and Azure OpenAI.

Agent execution uses the Responses API. The hub API therefore also exposes `POST /responses`
and the related get, delete, and input-items operations. The connection sets
`inferenceAPIVersion = "2025-03-01-preview"`, which Foundry appends to inference requests. The
base Azure OpenAI API is imported from Microsoft's APIM-compatible stable OpenAPI document, as
described in [Import an Azure OpenAI API as a REST API](https://learn.microsoft.com/en-us/azure/api-management/azure-openai-api-from-specification);
the Responses operations are managed explicitly because the published preview OpenAPI document
currently contains a schema construct that APIM rejects during import.

### Optional private APIM connectivity

No APIM private endpoint, VNet peering, private DNS zone, or customer-side IP allocation is
required when the APIM gateway is publicly reachable. This is the default and matches a
centralized multi-tenant gateway where customer isolation is enforced with APIM Products,
Subscriptions, model allowlists, quotas, and policies.

For a customer that requires private connectivity to APIM, set
`enable_apim_private_endpoint = true` in both the hub and spoke deployments. That optional mode
creates the hub VNet and APIM Gateway private endpoint, links `privatelink.azure-api.net`, and
peers the Foundry spoke VNet to the hub. It changes only how the same APIM target hostname is
resolved and reached; the Foundry connection metadata does not change.

## Prerequisites

- **Terraform** ≥ 1.10 ([install](https://developer.hashicorp.com/terraform/install))
- **Azure CLI** logged in: `az login`
- An **existing hub APIM** instance and permission to read its subscription key
- Sufficient quota in your target region for: 1 D-series VM (jumpbox), Cosmos DB, AI Search,
  Storage, and the Azure OpenAI model capacity
- Contributor + User Access Administrator (or Owner) on the target subscription (RBAC role
  assignments are created)

## Step 1 — Deploy the hub (model behind APIM)

```pwsh
cd hub-apim-openai
```

Non-secret config lives in per-environment files under `environments/`. Edit
`environments/dev.tfvars` (or copy `environments/prod.tfvars` for another environment):

| Variable | Set to |
| -------- | ------ |
| `subscription_id` | Your hub subscription ID |
| `location` | Region for the Azure OpenAI account (must offer your model) |
| `hub_apim_name` / `hub_apim_resource_group_name` | Your existing APIM instance |
| `model_name` / `model_version` / `model_sku_name` / `model_capacity` | The model to deploy |
| `api_path` | The APIM API path to expose the model under (e.g. `openai`) |
| `enable_apim_private_endpoint` | `false` for the public APIM gateway (default); `true` only for optional private APIM connectivity |

The hub apply also enables APIM's system-assigned identity, grants its Azure OpenAI role, imports
the inference API, and creates the Responses and dynamic-discovery operations. The identity must
be allowed to request both Cognitive Services data-plane and Azure Resource Manager tokens;
the included role assignment supplies the required deployment read permissions.

Deploy:

```pwsh
$env:ARM_SUBSCRIPTION_ID = "<your-hub-subscription-id>"
terraform init
terraform apply -var-file="environments/dev.tfvars"
```

## Step 2 — Set spoke secrets (never commit these)

The spoke needs two secrets that must **not** live in a tfvars file: the hub APIM subscription
key and the jumpbox admin password. Provide them as environment variables.

A ready-to-edit helper is included:
[`spoke-private-agent/set-secrets.example.ps1`](spoke-private-agent/set-secrets.example.ps1).
Copy it, fill in your hub APIM details, then dot-source it:

```pwsh
cd spoke-private-agent
Copy-Item set-secrets.example.ps1 set-secrets.ps1   # set-secrets.ps1 is git-ignored
# edit set-secrets.ps1: subscription id + APIM resource group/name
. .\set-secrets.ps1                                 # note the leading dot — dot-source it
```

This fetches the APIM subscription key, generates a compliant jumpbox password (printed once —
**save it** for Bastion login), and exports `TF_VAR_apim_subscription_key`,
`TF_VAR_jumpbox_admin_password`, and `ARM_SUBSCRIPTION_ID` into your shell.

Prefer to do it manually instead? Set these three before `apply`:

```pwsh
$env:ARM_SUBSCRIPTION_ID           = "<subscription-id>"
$env:TF_VAR_apim_subscription_key  = "<hub-apim-subscription-key>"
$env:TF_VAR_jumpbox_admin_password = "<strong-password>"
```

## Step 3 — Deploy the spoke (private agent)

Edit the non-secret config in `environments/dev.tfvars` — key values:

| Variable | Set to |
| -------- | ------ |
| `subscription_id` / `location` / `resource_group_name` | Your spoke subscription, region, RG |
| `vnet_address_space` and the four `*_subnet_prefix` values | A range that does **not** overlap your hub VNet |
| `hub_apim_name` / `hub_apim_resource_group_name` / `hub_apim_subscription_id` | Your hub APIM |
| `enable_apim_private_endpoint` | Keep `false` for a published APIM gateway; set `true` only with the matching hub private endpoint |
| `apim_openai_connection_name` | Name for the Foundry connection (e.g. `hub-apim-openai`) |
| `apim_openai_path` | Must match the hub `api_path` from Step 1 |
| `apim_inference_api_version` | Inference API version used by Agent Service (`2025-03-01-preview`) |

Do not add a static model list for this setup. The connection intentionally relies on the hub
APIM's `/deployments` operations. If you replace those standard paths with custom paths, add
serialized `modelDiscovery` metadata as documented in the official APIM connection schema.

Deploy:

```pwsh
terraform init
terraform apply -var-file="environments/dev.tfvars"
```

Capture the outputs you'll need next:

```pwsh
terraform output foundry_account_name   # -> used to build the project endpoint
terraform output project_name
terraform output jumpbox_vm_name
```

## Step 4 — Connect to the jumpbox

The Foundry account has `publicNetworkAccess=Disabled`, so agents can only be created/used from
**inside the spoke VNet**. Use Azure Bastion to reach the jumpbox:

1. Azure portal → the jumpbox VM (`terraform output jumpbox_vm_name`) → **Connect → Bastion**.
2. User: `azureuser` (or your `jumpbox_admin_username`); Password: the one printed in Step 2.
3. On the VM, install [Python 3.12+](https://www.python.org/downloads/) and
   [uv](https://docs.astral.sh/uv/). The VM's managed identity is already authorized by the
   spoke Terraform, so no `az login` is required.

## Step 5 — Create and use the agent

Copy the [`agent-samples/`](agent-samples) folder onto the jumpbox (or `git clone` this repo
there), then follow [`agent-samples/README.md`](agent-samples/README.md):

```pwsh
cd agent-samples
Copy-Item .env.example .env   # set endpoint/connection/model from your terraform outputs
uv sync
uv run test_connection.py     # verifies the model responds through APIM
uv run create_agent.py        # creates a persistent agent
uv run chat_with_agent.py     # interactive chat
```

The spoke Terraform grants the jumpbox VM's managed identity the **Foundry User** role
(formerly **Azure AI User**) on the Foundry account, so `DefaultAzureCredential` can create and
use agents out of the box.

## Terraform state — where it lives

| How you run | State location | When to use |
| ----------- | -------------- | ----------- |
| **Local** (the steps above) | `spoke-private-agent/terraform.tfstate` on your machine (git-ignored) | Single operator, quick tests. |
| **GitHub Actions / teams** | **Azure Storage** blob via the `azurerm` backend (state locking + versioning) | Shared/automated deployments. |

> ⚠️ **State contains every secret in plaintext** (APIM key, jumpbox password, connection
> secrets). Never commit it, and lock down the Storage account like a vault.

There is **no committed `backend.tf`**, so local runs stay backendless (local state). The deploy
workflow generates a `backend.tf` at runtime and points it at your Storage account — so the same
code works both ways.

### Bootstrap the state Storage account (run once)

```pwsh
$rg="rg-tfstate"; $sa="sttfstate$(Get-Random -Maximum 99999)"; $loc="eastus2"
az group create -n $rg -l $loc
# AAD-only (no storage keys), TLS1.2, no public blob access
az storage account create -n $sa -g $rg -l $loc --sku Standard_LRS --kind StorageV2 `
  --min-tls-version TLS1_2 --allow-blob-public-access false --allow-shared-key-access false
az storage container create --name tfstate --account-name $sa --auth-mode login
# Versioning + soft delete (recover a bad state)
az storage account blob-service-properties update -n $sa -g $rg `
  --enable-versioning true --enable-delete-retention true --delete-retention-days 7
# Give the deploy identity (and yourself) data-plane access
az role assignment create --assignee "<ci-or-your-objectId>" `
  --role "Storage Blob Data Contributor" `
  --scope $(az storage account show -n $sa -g $rg --query id -o tsv)
```

Use the resulting `$rg`, `$sa`, and container name as the GitHub `TFSTATE_*` variables below.
The workflow stores one blob per environment: `spoke-private-agent-<env>.tfstate`.

To adopt remote state for **local** runs too, create a `backend.tf` (it's git-ignored) and run
`terraform init -migrate-state -backend-config=...` with the same values.

## Deploy the spoke via GitHub Actions (optional)

The pipeline covers the **spoke** only. The hub (`hub-apim-openai`) is deployed manually — it
mostly exists to expose the model connection for testing — so deploy it once locally (Step 1)
before running the spoke pipeline.

Two workflows are included under [`.github/workflows/`](.github/workflows):

- **`terraform-validate.yml`** — runs `fmt -check` + `validate` on every PR/push that touches
  `spoke-private-agent/` (no cloud access needed).
- **`terraform-deploy.yml`** — manual (`workflow_dispatch`) `plan` / `apply` / `destroy` of the
  spoke for a chosen **environment** (`dev`/`prod`). It authenticates with **OIDC** (no stored
  cloud credentials) and stores state in Azure Storage.

### One-time setup

1. **Create the state Storage account** (once) and a container, e.g. `tfstate`. Lock it down
   (RBAC/AAD auth, versioning, soft delete). State holds secrets in plaintext — treat it like a
   vault.
2. **Create an OIDC identity** — an Entra app registration (or user-assigned managed identity)
   with a **federated credential** for this repo/environment, and grant it `Contributor` +
   `User Access Administrator` on the target subscription (RBAC assignments are created), plus
   `Storage Blob Data Contributor` on the state account.
3. **Configure GitHub** (repo → Settings). Create Environments `dev` and `prod` (add required
   reviewers on `prod`), then set:

   | Type | Name | Purpose |
   | ---- | ---- | ------- |
   | Variable | `TFSTATE_RESOURCE_GROUP` | State storage RG |
   | Variable | `TFSTATE_STORAGE_ACCOUNT` | State storage account name |
   | Variable | `TFSTATE_CONTAINER` | State container (e.g. `tfstate`) |
   | Secret | `AZURE_CLIENT_ID` / `AZURE_TENANT_ID` / `AZURE_SUBSCRIPTION_ID` | OIDC identity |
   | Secret | `TF_VAR_APIM_SUBSCRIPTION_KEY` | Hub APIM subscription key |
   | Secret | `TF_VAR_JUMPBOX_ADMIN_PASSWORD` | Jumpbox admin password |

   Non-secret config stays in `spoke-private-agent/environments/<env>.tfvars`; secrets stay in
   Environment secrets — the workflow maps them to `TF_VAR_*` automatically.

4. **Run it:** Actions → *Deploy Spoke (Private Agent)* → *Run workflow* → pick environment and
   `plan`/`apply`/`destroy`.

> **Private networking caveat:** GitHub-hosted runners provision fine over the Azure control
> plane, but they are **not** inside your VNet. Creating/using agents (data plane) still requires
> the jumpbox. If apply ever needs private data-plane access, use a **self-hosted runner** in the
> spoke VNet.

## Clean up

Destroy in reverse order (spoke first, then hub). Secrets must be present for `destroy` too:

```pwsh
cd spoke-private-agent
. .\set-secrets.ps1
terraform destroy -var-file="environments/dev.tfvars"

cd ..\hub-apim-openai
terraform destroy -var-file="environments/dev.tfvars"
```

> If `destroy` stalls on network resources, a service-association-link on the agent subnet may
> still be releasing. Wait a few minutes and retry.

## Troubleshooting

| Symptom | Cause / fix |
| ------- | ----------- |
| `SkuNotAvailable` / Cosmos `ServiceUnavailable` on apply | The region lacks capacity for the VM size or Cosmos. Choose a region that offers them. |
| Storage `403 KeyBasedAuthenticationNotPermitted` | The provider must use AAD auth (`storage_use_azuread = true`, already set in `providers.tf`). |
| `PlatformImageNotFound` on the jumpbox | The Windows image SKU isn't offered in your region — pick an available SKU in `jumpbox.tf`. |
| Agent scripts fail with network/DNS errors | Not running on the jumpbox. The Foundry account is private — run from inside the spoke VNet. |
| Agent reports `model not found` | Use `<connection-name>/<deployment-name>` and confirm both APIM discovery operations return the deployment. Do not use the underlying model name if it differs from the deployment name. |
| APIM returns `404 Not Found` for agent responses | Confirm `POST /responses` exists and `apim_inference_api_version` is `2025-03-01-preview`. The stable `2024-10-21` import alone does not expose Responses operations. |
| Discovery returns `401` or `403` | Confirm APIM has a system-assigned identity and **Cognitive Services OpenAI User** on the Azure OpenAI account. The discovery policy requests an ARM token for `https://management.azure.com/`. |

## References

- [Bring your own model to Foundry Agent Service through an AI gateway](https://learn.microsoft.com/en-us/azure/foundry/agents/how-to/ai-gateway)
- [Official Foundry APIM connection schema and examples](https://github.com/microsoft-foundry/foundry-samples/blob/main/infrastructure/infrastructure-setup-bicep/01-connections/apim/APIM-Connection-Objects.md)
- [Official APIM setup guide for Foundry Agents](https://github.com/microsoft-foundry/foundry-samples/blob/main/infrastructure/infrastructure-setup-bicep/01-connections/apim/apim-setup-guide-for-agents.md)
- [Import Azure OpenAI into API Management](https://learn.microsoft.com/en-us/azure/api-management/azure-openai-api-from-specification)
- [API Management managed-identity authentication policy](https://learn.microsoft.com/en-us/azure/api-management/authentication-managed-identity-policy)
- [Configure private link for Microsoft Foundry](https://learn.microsoft.com/en-us/azure/ai-foundry/how-to/configure-private-link)
- [Azure API Management with virtual networks](https://learn.microsoft.com/en-us/azure/api-management/api-management-using-with-vnet)
- [AzAPI Provider](https://registry.terraform.io/providers/azure/azapi/latest/docs)

`Tags: Private Network, APIM, Standard Agent, Foundry, Terraform`
