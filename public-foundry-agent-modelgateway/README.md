# Public Foundry Standard Agent + self-hosted ModelGateway connection + Document Intelligence

Public-networking Standard Agent deployment that consumes models through a
**self-hosted or third-party model gateway** instead of Azure API Management.
Same stack as [`../public-foundry-agent/`](../public-foundry-agent/) — Foundry
account + project, BYO Cosmos/Search/Storage, capability hosts, optional
Document Intelligence — with `apim.tf` replaced by
[modelgateway.tf](public-foundry-agent-modelgateway/modelgateway.tf).

## Why this differs from the APIM variant

The two connection categories drive the agent down **different API routes**:

| | `ApiManagement` connection | `ModelGateway` connection (this folder) |
| --- | --- | --- |
| Route the agent uses | Responses API (`/responses`) | OpenAI-compatible `/chat/completions` |
| Gateway must expose | Azure OpenAI inference + `/deployments` discovery | `/chat/completions` with tool calling |
| Auth header | APIM subscription key | `api-key`, or any header via `authConfig` |

That makes this variant the right choice when the gateway is not APIM, or when
the gateway's Responses API route is unavailable or misbehaving.

## Scope: the gateway is BYO

This module **does not provision a gateway**. It only creates the Foundry
connection that points at one. The gateway must already:

- expose an OpenAI-compatible `POST /chat/completions` **with tool/function calling**,
- accept API-key authentication,
- be reachable from Azure over the public internet,
- and either publish a discovery API or have its models declared statically here.

## Working out `model_gateway_target`

Take the full chat completions URL and strip the `/chat/completions` suffix, plus
any `/deployments/{name}` segment:

| Full chat completions URL | `model_gateway_target` | `model_gateway_deployment_in_path` |
| --- | --- | --- |
| `https://gw.example.com/chat/completions` | `https://gw.example.com` | `false` |
| `https://gw.example.com/v1/custom/chat/completions` | `https://gw.example.com/v1/custom` | `false` |
| `https://gw.example.com/deployments/gpt-4o/chat/completions` | `https://gw.example.com` | `true` |

With `deployment_in_path = false`, Foundry passes the deployment via
`{"model": "<deployment>"}` in the request body instead of in the URL.

## Model discovery — pick exactly one

A precondition fails the plan if you set both or neither.

**Static catalogue** (default; no discovery routes needed on the gateway):

```hcl
model_gateway_static_models = [
  {
    name          = "gpt-4o"       # deployment alias used in the agent model reference
    model_name    = "gpt-4o"       # underlying model family
    model_version = "2024-11-20"   # optional (default "")
    model_format  = "OpenAI"       # optional (default "OpenAI")
  },
]
```

**Dynamic discovery** (set `model_gateway_static_models = []` first):

```hcl
model_gateway_discovery = {
  list_models_endpoint = "/models"
  get_model_endpoint   = "/models/{deploymentName}"  # placeholder is required
  deployment_provider  = "OpenAI"                    # or "AzureOpenAI" — only these two
}
```

`deployment_provider` selects the response parser: `OpenAI` expects a `data[]`
array of `{id, object, ...}`; `AzureOpenAI` expects a `value[]` array of ARM-shaped
`{name, properties.model{name, version, format}}` objects.

## Optional gateway tuning

```hcl
# Extra headers on every inference request (gateway policy routing, etc.)
model_gateway_custom_headers = { "X-Environment" = "prod" }

# Override the auth header — defaults to `api-key` when unset
model_gateway_auth_config = { name = "Authorization", format = "Bearer {api_key}" }

# api-version query params — most non-Azure gateways need neither
model_gateway_inference_api_version  = "2025-03-01"  # inference calls only
model_gateway_deployment_api_version = "2025-03-01"  # discovery calls only
```

## Prerequisites

- Terraform `>= 1.10.0`, Azure CLI logged in.
- `Contributor` + `User Access Administrator` on the target subscription.
- From the gateway owner: base URL, an API key, the auth header shape, the
  approved deployment aliases, and whether discovery endpoints exist.
- Confirm region support for Standard Agent and Document Intelligence.
- Check whether the subscription auto-disables `publicNetworkAccess` on
  Storage/Cosmos — get an exemption up front or agent creation fails.

## Deploy

1. Edit `environments/dev.tfvars`: `subscription_id`, `location`,
   `resource_group_name`, `name_suffix`, the `model_gateway_*` block, the
   Document Intelligence block, and `agent_developer_principal_ids` (get your own
   object ID with `az ad signed-in-user show --query id -o tsv`).
2. Set the gateway key for this session only — it is never committed:
   ```pwsh
   $env:TF_VAR_model_gateway_api_key = "<gateway-api-key>"
   ```
3. Isolate state, then plan and apply:
   ```pwsh
   terraform init
   terraform workspace new <env>
   terraform plan  -var-file="environments/<env>.tfvars" -out="<env>.tfplan"
   terraform apply "<env>.tfplan"
   ```

> Terraform stores `credentials.key` in state in **plaintext**. Keep state out of
> source control (it already is) and use a remote backend with restricted access
> for anything shared.

## Validate

Test the gateway itself **before** creating the connection — a bad gateway
surfaces from Foundry only as an opaque upstream error:

```pwsh
curl -X POST "<target>/chat/completions" -H "api-key: $env:TF_VAR_model_gateway_api_key" -H "Content-Type: application/json" -d '{\"model\":\"gpt-4o\",\"messages\":[{\"role\":\"user\",\"content\":\"hi\"}]}'
```

Then, after apply, from [`../agent-samples/`](../agent-samples/):

```pwsh
terraform output   # project_endpoint, agent_model_references, ...

$env:AZURE_AI_PROJECT_ENDPOINT = "<project_endpoint output>"
$env:AZURE_AI_CONNECTION_NAME  = "model-gateway"
$env:AZURE_AI_MODEL_NAME       = "<deployment alias>"
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
identity, `agent_developer_principal_ids`, and `docintel_app_principal_ids`.

## Hand over

- Repoint `agent_developer_principal_ids` and `docintel_app_principal_ids` to the
  customer's identities, then re-apply.
