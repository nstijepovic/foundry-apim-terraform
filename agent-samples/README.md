# Agent Samples

Sample Python scripts for creating and using a **Microsoft Foundry Agent** whose
model is served through a **hub APIM** connection (`<connection>` →
`<model deployment>` behind Azure API Management).

Adapted from
[nstijepovic/sample-foundry-apim/03-agent-samples](https://github.com/nstijepovic/sample-foundry-apim/tree/master/03-agent-samples).

## ⚠️ Run these from inside the spoke VNet (the jumpbox)

The Foundry account is deployed with `publicNetworkAccess=Disabled`. Its
data-plane endpoint only resolves and is only reachable **from inside the spoke
VNet**. Running these scripts from your local machine will fail with a
network/DNS error.

Connect to the jumpbox via **Azure Bastion** and run the samples there
(portal → the jumpbox VM → **Connect → Bastion**). Get the VM name and login
from the spoke deployment:

- VM name: `terraform output jumpbox_vm_name` (in `../spoke-private-agent`)
- Username: your `jumpbox_admin_username` (default `azureuser`)
- Password: printed by `set-secrets.ps1` during the spoke deploy — **save it**

## Prerequisites (on the jumpbox)

- Python 3.12+
- [uv](https://docs.astral.sh/uv/) package manager

`DefaultAzureCredential` authenticates as the jumpbox VM's managed identity, which
the spoke Terraform grants the **Foundry User** role (formerly **Azure AI User**)
on the Foundry account, so no `az login` is required.

## Setup

1. Copy this `agent-samples` folder onto the jumpbox (or `git clone` your repo).
2. Install dependencies:

   ```pwsh
   uv sync
   ```

3. Copy `.env.example` to `.env` and fill in your values:

   ```pwsh
   cp .env.example .env
   ```

   Values come from `terraform output` in `../spoke-private-agent`:

   | Variable | Where it comes from | Example |
   | --- | --- | --- |
   | `AZURE_AI_PROJECT_ENDPOINT` | `https://<foundry_account_name>.services.ai.azure.com/api/projects/<project_name>` | `https://foundryabcd.services.ai.azure.com/api/projects/projabcd` |
   | `AZURE_AI_CONNECTION_NAME` | `var.apim_openai_connection_name` | `hub-apim-openai` |
   | `AZURE_AI_MODEL_NAME` | the model deployment exposed behind the hub APIM | `gpt-5.1` |
   | `AZURE_AI_AGENT_NAME` | any name for your agent | `apim-agent` |

## Scripts

| Script | Purpose |
| --- | --- |
| `test_connection.py` | List connections and verify the model responds through APIM |
| `create_agent.py` | Create a persistent agent (name from `AZURE_AI_AGENT_NAME`) |
| `chat_with_agent.py` | Interactive chat with the agent |

## Usage

```pwsh
# 1. Verify the APIM connection + model round-trip
uv run test_connection.py

# 2. Create the persistent agent
uv run create_agent.py

# 3. Chat with it (type 'exit' to quit)
uv run chat_with_agent.py
```

## How it routes through APIM

When an agent references its model as `<connection>/<model>` (e.g.
`hub-apim-openai/gpt-5.1`), Foundry resolves the connection (category
`ApiManagement`, target = the APIM gateway URL). Because this connection has no
static `models` metadata, Foundry first uses APIM's standard dynamic-discovery
operations:

```text
GET https://<apim-gateway>/<api-path>/deployments
GET https://<apim-gateway>/<api-path>/deployments/<model>
```

The sample then uses Foundry's Responses client. Agent Service sends inference
through `POST /responses?api-version=2025-03-01-preview`; APIM authenticates the
incoming call with its `api-key` subscription header and calls Azure OpenAI with
APIM's managed identity. Chat-completions clients can also use the Azure OpenAI
path selected by `deploymentInPath=true`:

```text
POST https://<apim-gateway>/<api-path>/deployments/<model>/chat/completions?api-version=<version>
```

All traffic stays private: spoke -> VNet peering -> hub APIM private endpoint.
See Microsoft's [AI gateway guide](https://learn.microsoft.com/en-us/azure/foundry/agents/how-to/ai-gateway)
and [APIM connection schema](https://github.com/microsoft-foundry/foundry-samples/blob/main/infrastructure/infrastructure-setup-bicep/01-connections/apim/APIM-Connection-Objects.md).

## Model reference format

```python
model = "hub-apim-openai/gpt-5.1"   # <connection-name>/<deployment-name>
```
