# ---------------------------------------------------------------------------
# set-secrets.example.ps1  —  copy to set-secrets.ps1 and edit the values below.
#
#   Copy-Item set-secrets.example.ps1 set-secrets.ps1
#   # edit set-secrets.ps1 (subscription id + hub APIM resource group/name)
#   . .\set-secrets.ps1        # dot-source it (note the leading dot)
#
# set-secrets.ps1 is git-ignored so your environment values are never committed.
# This sets the TF_VAR_* secrets + ARM_SUBSCRIPTION_ID into the CURRENT shell only.
# ---------------------------------------------------------------------------

# --- EDIT THESE ------------------------------------------------------------
$SubscriptionId   = "<your-subscription-id>"
$ApimResourceGroup = "<hub-apim-resource-group>"
$ApimName         = "<hub-apim-name>"
$ApimSubscription = "master"   # APIM subscription whose key you want (default: master)
$JumpboxUser      = "azureuser"
# ---------------------------------------------------------------------------

# Ensure both Machine and User PATH are available (so az/terraform resolve).
$env:Path = "$([System.Environment]::GetEnvironmentVariable('Path','Machine'));$([System.Environment]::GetEnvironmentVariable('Path','User'))"
$env:ARM_SUBSCRIPTION_ID = $SubscriptionId

# 1) Fetch the hub APIM subscription key from Azure (requires `az login`).
$uri = "https://management.azure.com/subscriptions/$SubscriptionId/resourceGroups/$ApimResourceGroup/providers/Microsoft.ApiManagement/service/$ApimName/subscriptions/$ApimSubscription/listSecrets?api-version=2024-05-01"
$key = az rest --method post --uri $uri --query primaryKey -o tsv
if (-not $key) { Write-Error "Failed to fetch APIM key. Check az login, subscription, and APIM names."; return }
$env:TF_VAR_apim_subscription_key = $key

# 2) Generate a jumpbox admin password that meets Windows complexity rules.
$upper = 'ABCDEFGHJKLMNPQRSTUVWXYZ'
$lower = 'abcdefghijkmnpqrstuvwxyz'
$dig   = '23456789'
$spec  = '!@#$%^*-_'
$all   = $upper + $lower + $dig + $spec
$pw  = [string]$upper[(Get-Random -Maximum $upper.Length)]
$pw += [string]$lower[(Get-Random -Maximum $lower.Length)]
$pw += [string]$dig[(Get-Random -Maximum $dig.Length)]
$pw += [string]$spec[(Get-Random -Maximum $spec.Length)]
for ($i = 0; $i -lt 16; $i++) { $pw += [string]$all[(Get-Random -Maximum $all.Length)] }
$pw = -join (($pw.ToCharArray()) | Sort-Object { Get-Random })
$env:TF_VAR_jumpbox_admin_password = $pw

Write-Host "APIM key set (length=$($key.Length))."
Write-Host "ARM_SUBSCRIPTION_ID = $env:ARM_SUBSCRIPTION_ID"
Write-Host ""
Write-Host "Jumpbox login (SAVE THIS — needed for Bastion):" -ForegroundColor Yellow
Write-Host "  username: $JumpboxUser"
Write-Host "  password: $pw"
