# Agent Samples

Python scripts that create and use a Microsoft Foundry Agent whose model is served
through a hub APIM connection (`<connection>/<deployment>`, e.g. `hub-apim-openai/gpt-5.1`).

Adapted from
[nstijepovic/sample-foundry-apim/03-agent-samples](https://github.com/nstijepovic/sample-foundry-apim/tree/master/03-agent-samples).

## Where to run these from

- **`spoke-private-agent/`** deployments: the Foundry account is
  `publicNetworkAccess=Disabled` — run these scripts from the **jumpbox** (Azure Bastion),
  not your local machine. VM name: `terraform output jumpbox_vm_name`.
- **`public-foundry-agent/`** and **`public-foundry-agent-basic/`** deployments: endpoints
  are public — run these scripts directly from your machine with `az login`.

## Prerequisites

- Python 3.12+ and [uv](https://docs.astral.sh/uv/).
- `DefaultAzureCredential` needs either an `az login` session (local) or the jumpbox VM's
  managed identity (spoke) — both are already granted the **Foundry User** role by
  their respective Terraform.

## Setup

```pwsh
uv sync
cp .env.example .env
```

Fill in `.env` from `terraform output` in the deployment folder:

| Variable | Value |
| --- | --- |
| `AZURE_AI_PROJECT_ENDPOINT` | `https://<foundry_account_name>.services.ai.azure.com/api/projects/<project_name>` |
| `AZURE_AI_CONNECTION_NAME` | the APIM connection name, e.g. `hub-apim-openai` |
| `AZURE_AI_MODEL_NAME` | the model deployment alias exposed behind APIM, e.g. `gpt-5.1` |
| `AZURE_AI_AGENT_NAME` | any name for your agent |

## Scripts

| Script | Purpose |
| --- | --- |
| `test_connection.py` | List connections and verify the model responds through APIM |
| `create_agent.py` | Create a persistent agent (name from `AZURE_AI_AGENT_NAME`) |
| `chat_with_agent.py` | Interactive chat with the agent |

```pwsh
uv run test_connection.py
uv run create_agent.py
uv run chat_with_agent.py   # type 'exit' to quit
```

## Model reference format

```python
model = "hub-apim-openai/gpt-5.1"   # <connection-name>/<deployment-name>
```
