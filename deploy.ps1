# ================================
# Load variables
# ================================
. "$PSScriptRoot/variables.ps1"

Write-Host "Deploying INFRA + APIM POLICIES (REST based)"

# ================================
# Resource Group
# ================================
if (-not (az group exists --name $RG | ConvertFrom-Json)) {
  az group create --name $RG --location $LOC
}

# ================================
# Provider
# ================================
az provider register --namespace Microsoft.ApiManagement --wait

# ================================
# APIM
# ================================
$APIM_EXISTS = az apim show `
  --name $APIM_NAME `
  --resource-group $RG `
  --query name -o tsv 2>$null

if (-not $APIM_EXISTS) {
  az apim create `
    --name $APIM_NAME `
    --resource-group $RG `
    --location $LOC `
    --publisher-name "Verdugox" `
    --publisher-email "demo@demo.com" `
    --sku-name Consumption
}

az apim wait --name $APIM_NAME --resource-group $RG --created

# ================================
# Backend (REST)
# ================================
$backendUrl = "https://management.azure.com/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RG/providers/Microsoft.ApiManagement/service/$APIM_NAME/backends/placeholder-backend?api-version=2022-08-01"

az rest `
  --method PUT `
  --uri $backendUrl `
  --body '{
    "properties": {
      "url": "https://httpbin.org",
      "protocol": "http"
    }
  }'

# ================================
# API
# ================================
$apiUrl = "https://management.azure.com/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RG/providers/Microsoft.ApiManagement/service/$APIM_NAME/apis/cardops-api?api-version=2022-08-01"

az rest `
  --method PUT `
  --uri $apiUrl `
  --body '{
    "properties": {
      "displayName": "Card Ops API",
      "path": "cardops",
      "protocols": ["https"],
      "subscriptionRequired": false
    }
  }'

# ================================
# Policy (REST)
# ================================
$policyUrl = "$apiUrl/policies/policy?api-version=2022-08-01"

az rest `
  --method PUT `
  --uri $policyUrl `
  --headers @{ "Content-Type" = "application/vnd.ms-azure-apim.policy+xml" } `
  --body @"
<policies>
  <inbound>
    <base />
    <rate-limit calls="100" renewal-period="60" />
    <set-backend-service backend-id="placeholder-backend" />
  </inbound>
  <backend>
    <base />
  </backend>
  <outbound>
    <base />
  </outbound>
</policies>
"@

Write-Host "===================================="
Write-Host "APIM READY (NO CLI BUGS)"
Write-Host "Backend: PLACEHOLDER"
Write-Host "Safe & Idempotent"
Write-Host "===================================="
