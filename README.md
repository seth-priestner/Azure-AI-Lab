# Azure AI Red-Team Range (Terraform)

Spin up a contained Azure “range” for red-team exercises against AI apps.  
What you get:

- **Private** Azure OpenAI endpoint (Public Network Access = **Off**) behind **Private Link**
- **APIM gateway** with **managed identity** → RBAC to call Azure OpenAI (no API keys)
- **Per-operator throttling** & attribution via `X-Operator-ID`
- **Log Analytics** diagnostics (Audit + optional RequestResponse) for hunting
- Clean **Terraform modules** for network, OpenAI, logging, and APIM

> ⚠️ **Reality check:** This costs real money while it’s running. APIM, Log Analytics, and model usage add up. Use dev SKUs, keep retention tight, and **destroy** the env when you’re done.

---

## TL;DR (Cloud Shell one-liner)

Open Azure Cloud Shell, select **Bash**, then:

```bash
# Prereqs: Owner on the target subscription and Azure OpenAI access enabled for the tenant/subscription.
SUB=$(az account show --query id -o tsv)
az account set --subscription "$SUB"
for NS in Microsoft.CognitiveServices Microsoft.Network Microsoft.ApiManagement; do az provider register --namespace $NS --wait; done

# Fork/clone your repo, then:
git clone <REPO_URL> azure-ai-redteam
cd azure-ai-redteam/envs/dev
terraform init
terraform apply -auto-approve

# Smoke test (replace <dep> and <api-version>):
APIM=$(terraform output -raw apim_api_base)
curl -sS -D- -X POST   "$APIM/openai/deployments/<dep>/chat/completions?api-version=<api-version>"   -H "Content-Type: application/json"   -H "X-Operator-ID: alice"   -d '{"messages":[{"role":"user","content":"hello"}],"temperature":0}'
```

To clean up:

```bash
terraform destroy -auto-approve
```

---

## Architecture

```
+--------------------------+        +-----------------------+
|     Client (curl/app)    |        |  Log Analytics (LAW)  |
|  -> APIM (External VNet) +------->+  AzureDiagnostics     |
|     MSI -> Bearer token  |        +-----------------------+
|  Rate limit per operator |
+------------+-------------+
             |  HTTPS (VNet egress)
             v
+------------+-------------+        +-------------------------------+
|   VNet (apps/apim/pep)   |        |   Private DNS Zone            |
|  subnets: apps, apim,    |        |   privatelink.openai.azure.com|
|  priv-endpoints          |        +-------------------------------+
+------------+-------------+
             | Private Link
             v
+--------------------------+
| Azure OpenAI (PNA = Off)|
| custom subdomain + PEP   |
+--------------------------+
```

---

## Repo layout

```
azure-ai-redteam/
├─ modules/
│  ├─ network/   # VNet, subnets, Private DNS
│  ├─ openai/    # AOAI account, private endpoint, deployments
│  ├─ logging/   # Log Analytics + diagnostics
│  └─ apim/      # APIM, MSI → AOAI RBAC, wildcard proxy policy
└─ envs/
   └─ dev/       # Composed stack (edit tfvars here)
```

---

## Prerequisites

- **Role:** Owner (or Contributor + User Access Admin) on the target subscription.
- **Azure OpenAI access:** Your tenant/subscription must be enabled for Azure OpenAI. If not, deployment will succeed for the account but model calls may fail or quotas will block you.
- **Providers registered:** `Microsoft.CognitiveServices`, `Microsoft.Network`, `Microsoft.ApiManagement`.
- **Terraform:** v1.6+ and `azurerm` provider v3.116+ (Cloud Shell already has Terraform).

---

## Quickstart

1. **Clone & choose an environment**
   ```bash
   git clone <REPO_URL> azure-ai-redteam
   cd azure-ai-redteam/envs/dev
   ```

2. **(Optional) Edit variables**
   - `variables.tf` and/or `terraform.tfvars` to pick:
     - `location` (must support Azure OpenAI in your tenant)
     - `aoai_deployments` (model name/version)
     - `enable_request_response_logs` (if your tenant exposes this category)

   Example `terraform.tfvars`:
   ```hcl
   prefix   = "rtai"
   location = "eastus"

   enable_request_response_logs = false

   aoai_deployments = {
     gpt-4o-mini = {
       model_name    = "gpt-4o-mini"
       model_version = "2024-07-18"  # adjust to an allowed version in your region
     }
   }
   ```

3. **Deploy**
   ```bash
   terraform init
   terraform apply -auto-approve
   ```

4. **Outputs you’ll use**
   ```bash
   terraform output
   # apim_api_base, apim_gateway, openai_endpoint, openai_deployments, etc.
   ```

---

## How it works

- **Network module** creates a VNet with `apps`, `apim`, and `priv-endpoints` subnets, plus `privatelink.openai.azure.com` and a VNet link.
- **OpenAI module** creates `kind=OpenAI` account with a **custom subdomain**, **Public Network Access: Disabled**, a **Private Endpoint** bound to the VNet, and **model deployments** you define.
- **APIM module** deploys APIM in **External** VNet mode on the `apim` subnet, grants its **managed identity** the **Cognitive Services OpenAI User** role on the AOAI account, and publishes a **catch-all proxy** at `/aoai/*`.
- **Logging module** stands up a Log Analytics workspace and attaches diagnostics (Audit and optional RequestResponse).

---

## Test the range

### 1) Chat completions via APIM (preferred path)

```bash
APIM=$(terraform output -raw apim_api_base)
# Option A: pick a deployment manually from the output
terraform output openai_deployments

# Option B (Cloud Shell includes jq): take the first deployment automatically
DEP=$(terraform output -json openai_deployments | jq -r '.[0]')

API_VERSION="<your-aoai-api-version>"  # e.g., 2024-xx-xx per AOAI docs

curl -sS -D- -X POST   "$APIM/openai/deployments/$DEP/chat/completions?api-version=$API_VERSION"   -H "Content-Type: application/json"   -H "X-Operator-ID: alice"   -d '{"messages":[{"role":"user","content":"You are live. Say hi in one word."}],"temperature":0}'
```

**What should happen**
- APIM enforces `X-Operator-ID`, rate-limits by that value, and fetches an **AAD token** with its managed identity.
- Traffic hits Azure OpenAI **through Private Link** (no public access).
- **Logs** flow to Log Analytics (`AzureDiagnostics`).

### 2) Rate-limit nudge

Run the same request in a loop to trigger 429s:

```bash
for i in $(seq 1 400); do
  curl -s -o /dev/null -w "%{http_code}
"     "$APIM/openai/deployments/$DEP/chat/completions?api-version=$API_VERSION"     -H "Content-Type: application/json"     -H "X-Operator-ID: stress"     -d '{"messages":[{"role":"user","content":"ping"}],"temperature":0}'
done
```

You’ll start seeing **429** once the per-operator limit is exceeded (defaults: 300 calls per 60s).

---

## Observe in Log Analytics (KQL)

Open **Logs** on the workspace and try:

```kusto
// Volume by category (Audit vs RequestResponse if enabled)
AzureDiagnostics
| where ResourceProvider == "MICROSOFT.COGNITIVESERVICES"
| summarize count() by Category, bin(TimeGenerated, 15m)
| order by TimeGenerated desc

// Top operators by call volume (from APIM to AOAI)
AzureDiagnostics
| where ResourceProvider == "MICROSOFT.COGNITIVESERVICES"
| extend OperatorID = tostring(parse_json(Headers_s)["X-Operator-ID"]) // field name may vary
| summarize Calls=count() by OperatorID
| top 20 by Calls desc
```

> Note: Exact columns vary by tenant/diagnostic version. Use the **Fields** pane in Logs to inspect what you’re getting.

---

## Configuration knobs that matter

- **Region & model availability:** If a deployment fails, your region/quota doesn’t allow that model/version. Swap to a supported GA version for your region.
- **Request/Response logs:** Not every tenant exposes them. Toggle `enable_request_response_logs` if `terraform apply` complains about the category.
- **APIM exposure:** The example uses **External** VNet mode (public inbound). For corp-only ingress, switch APIM to **Internal** and front it with Private DNS/LB (or add APIM IP restrictions/Firewall).
- **RBAC over keys:** The proxy uses **managed identity** to call AOAI. Don’t add keys unless you have a hard reason.

---

## Troubleshooting (read this before filing an issue)

- **403 from APIM → AOAI**
  - RBAC hasn’t propagated yet, or wrong role. Confirm APIM’s managed identity has **Cognitive Services OpenAI User** on the AOAI account. Wait a few minutes and retry.

- **Name resolution or timeout**
  - Your APIM must resolve `*.privatelink.openai.azure.com`. Make sure the **Private DNS zone** is linked to the **same VNet** where APIM is injected.

- **429 Too Many Requests**
  - You hit the APIM rate limit. That’s by design. Tune `rate_limit_calls`/`rate_limit_seconds` in `envs/dev/main.tf` or your tfvars.

- **Deployment succeeded but calls fail**
  - Your subscription may not be approved for Azure OpenAI, or the model version isn’t available in that region/sku. Try a different GA model/version or region.

- **No logs in Log Analytics**
  - Diagnostic settings are per-resource and not retroactive. Ensure `Audit` (and optionally `RequestResponse`) are enabled **before** you test.

---

## Costs (bluntly)

- **APIM Developer** is not free.
- **Log Analytics** charges per GB ingested. If you enable RequestResponse, expect higher ingestion.
- **Model usage** is metered. Rate-limit and keep tests tight.
- Keep **retention** low (e.g., 30 days) and **destroy** idle ranges.

---

## Security notes

- Azure OpenAI **Public Network Access is disabled**. Access is via **Private Endpoint** only.
- APIM authenticates to AOAI with a **managed identity**; no secret sprawl.
- Inbound to APIM is public by default in this sample. For internal-only, either:
  - Switch APIM to **Internal** VNet mode and use Private DNS, or
  - Add APIM **IP restrictions**/WAF and lock it to corp egress IPs.

---

## Clean up

```bash
cd envs/dev
terraform destroy -auto-approve
```

---

## Roadmap (optional extras)

- App Service sample (Node/Python) that hits APIM with MSI
- Azure Policy assignment: enforce **PNA Off** and **Private Link required** for Cognitive Services
- Sentinel workbook + detections over `AzureDiagnostics`
- Azure AI Content Safety pre-screen via APIM policy

---

## Contribute

PRs welcome. Keep changes modular (modules only), no model keys in code, and no defaulting to public access anywhere.

---

## License

MIT for the code. Intended for **internal testing/training**. You’re responsible for usage and cost.

---

### Paste-ready blurb for your team chat

> Want a safe AI red-team playground? Deploy our **Azure AI Red-Team Range**: private Azure OpenAI behind APIM (MSI/RBAC), per-operator throttling, and full logging.  
> **How:** open Azure Cloud Shell →  
> `git clone <REPO_URL> && cd azure-ai-redteam/envs/dev && terraform init && terraform apply -auto-approve`  
> Then run the curl smoke test from the README. Destroy when done.
