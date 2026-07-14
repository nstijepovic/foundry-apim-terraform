# Private Network Foundry Agent behind Azure API Management

Deploy a **private-network Microsoft Foundry standard agent** (spoke) that consumes an LLM
served through an **existing Azure API Management (APIM) gateway** (hub). All traffic stays on
private networking — the Foundry account has public access disabled, and the agent reaches the
model over VNet peering to the hub APIM private endpoint.

This repo is split into three parts you deploy/run in order:

| # | Folder | What it does |
| - | ------ | ------------ |
| 1 | [`hub-apim-openai/`](hub-apim-openai) | Creates an Azure OpenAI model and wires it behind your existing hub APIM (imports the inference API, sets the subscription-key policy, adds a private endpoint for the gateway). |
| 2 | [`spoke-private-agent/`](spoke-private-agent) | Deploys the private Foundry account + project (BYO Storage/Search/Cosmos), the spoke VNet, VNet peering to the hub, private DNS, an APIM **connection**, and a **jumpbox** VM (reached via Azure Bastion). |
| 3 | [`agent-samples/`](agent-samples) | Python scripts to create and chat with an agent that routes its model calls through the APIM connection. Run these **from the jumpbox**. |

> `code/` is early single-folder scaffolding and is **not** part of the supported flow — ignore it.

## Architecture

```mermaid
flowchart LR
    subgraph Hub["Hub VNet (existing)"]
        APIM["API Management\n(private endpoint)"]
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
    Conn -->|hub-apim-openai/&lt;model&gt;| APIM
    Spoke <-->|VNet peering| Hub
```

The agent references its model as `<connection-name>/<deployment-name>` (e.g.
`hub-apim-openai/gpt-5.1`). Foundry resolves the connection, which points at the APIM gateway
URL, and APIM forwards the request to the backend Azure OpenAI deployment.

## Prerequisites

- **Terraform** ≥ 1.5 ([install](https://developer.hashicorp.com/terraform/install))
- **Azure CLI** logged in: `az login`
- An **existing hub APIM** instance and permission to read its subscription key
- Sufficient quota in your target region for: 1 D-series VM (jumpbox), Cosmos DB, AI Search,
  Storage, and the Azure OpenAI model capacity
- Contributor + User Access Administrator (or Owner) on the target subscription (RBAC role
  assignments are created)

## Step 1 — Deploy the hub (model behind APIM)

```pwsh
cd hub-apim-openai
Copy-Item example.tfvars my.tfvars   # then edit my.tfvars for your environment
```

Edit `my.tfvars`:

| Variable | Set to |
| -------- | ------ |
| `subscription_id` | Your hub subscription ID |
| `location` | Region for the Azure OpenAI account (must offer your model) |
| `hub_apim_name` / `hub_apim_resource_group_name` | Your existing APIM instance |
| `model_name` / `model_version` / `model_sku_name` / `model_capacity` | The model to deploy |
| `api_path` | The APIM API path to expose the model under (e.g. `openai`) |

Deploy:

```pwsh
$env:ARM_SUBSCRIPTION_ID = "<your-hub-subscription-id>"
terraform init
terraform apply -var-file="my.tfvars"
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

```pwsh
Copy-Item example.tfvars my.tfvars   # then edit my.tfvars
```

Edit `my.tfvars` — key values:

| Variable | Set to |
| -------- | ------ |
| `subscription_id` / `location` / `resource_group_name` | Your spoke subscription, region, RG |
| `vnet_address_space` and the four `*_subnet_prefix` values | A range that does **not** overlap your hub VNet |
| `hub_apim_name` / `hub_apim_resource_group_name` / `hub_apim_subscription_id` | Your hub APIM |
| `apim_openai_connection_name` | Name for the Foundry connection (e.g. `hub-apim-openai`) |
| `apim_openai_path` | Must match the hub `api_path` from Step 1 |
| `apim_inference_api_version` | Inference API version (e.g. `2024-10-21`) |

Deploy:

```pwsh
terraform init
terraform apply -var-file="my.tfvars"
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
3. On the VM, install prerequisites and sign in: [Python 3.12+](https://www.python.org/downloads/),
   [uv](https://docs.astral.sh/uv/), then `az login`.

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

The signed-in identity needs the **Azure AI User** role on the Foundry project to create/use
agents.

## Clean up

Destroy in reverse order (spoke first, then hub). Secrets must be present for `destroy` too:

```pwsh
cd spoke-private-agent
. .\set-secrets.ps1
terraform destroy -var-file="my.tfvars"

cd ..\hub-apim-openai
terraform destroy -var-file="my.tfvars"
```

> **Note:** Foundry standard-agent teardown can leave an orphaned *service-association-link* on
> the agent subnet, which blocks deleting the subnet/VNet/RG until Azure releases it. If a
> destroy stalls on the network, wait and retry, or delete the resource group later.

## Troubleshooting

| Symptom | Cause / fix |
| ------- | ----------- |
| `SkuNotAvailable` / Cosmos `ServiceUnavailable` on apply | The region lacks capacity for the VM or Cosmos AZ. Choose another region (reset state: delete `terraform.tfstate` before re-applying to a new region/RG). |
| Storage `403 KeyBasedAuthenticationNotPermitted` | Ensure the provider uses `storage_use_azuread = true` (already set in `providers.tf`). |
| Jumpbox `PlatformImageNotFound` | The Windows image SKU isn't offered in your region — pick an available SKU in `jumpbox.tf`. |
| Peering `ReferencedResourceNotProvisioned` | Transient ordering; re-run `apply`. |
| Agent scripts fail with network/DNS errors | You're not on the jumpbox. The Foundry account is private — run from inside the VNet. |

## References

- [Configure private link for Microsoft Foundry](https://learn.microsoft.com/en-us/azure/ai-foundry/how-to/configure-private-link)
- [Azure API Management with virtual networks](https://learn.microsoft.com/en-us/azure/api-management/api-management-using-with-vnet)
- [AzAPI Provider](https://registry.terraform.io/providers/azure/azapi/latest/docs)

`Tags: Private Network, APIM, Standard Agent, Foundry, Terraform`
