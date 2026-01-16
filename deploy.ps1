# ================================
# Load variables
# ================================
. "$PSScriptRoot/variables.ps1"

Write-Host "Deploying INFRA + APIM POLICIES (idempotent)"

# ================================
# Resource Group
# ================================
if (-not (az group exists --name $RG | ConvertFrom-Json)) {
  Write-Host "Creating Resource Group $RG"
  az group create `
    --name $RG `
    --location $LOC
} else {
  Write-Host "Resource Group $RG already exists"
}

# ================================
# Provider
# ================================
az provider register --namespace Microsoft.ApiManagement --wait

# ================================
# API Management
# ================================
$APIM_EXISTS = az apim show `
  --name $APIM_NAME `
  --resource-group $RG `
  --query name `
  -o tsv 2>$null

if (-not $APIM_EXISTS) {
  Write-Host "Creating APIM $APIM_NAME"
  az apim create `
    --name $APIM_NAME `
    --resource-group $RG `
    --location $LOC `
    --publisher-name "Verdugox" `
    --publisher-email "demo@demo.com" `
    --sku-name Consumption
} else {
  Write-Host "APIM $APIM_NAME already exists"
}

# ⏳ Esperar APIM
az apim wait `
  --name $APIM_NAME `
  --resource-group $RG `
  --created

# ================================
# BACKEND (create or update)
# ================================
$BACKEND_EXISTS = az apim backend show `
  --resource-group $RG `
  --service-name $APIM_NAME `
  --backend-id placeholder-backend `
  --query id `
  -o tsv 2>$null

if (-not $BACKEND_EXISTS) {
  Write-Host "Creating backend placeholder-backend"
  az apim backend create `
    --resource-group $RG `
    --service-name $APIM_NAME `
    --backend-id placeholder-backend `
    --url "https://httpbin.org"
} else {
  Write-Host "Updating backend placeholder-backend"
  az apim backend update `
    --resource-group $RG `
    --service-name $APIM_NAME `
    --backend-id placeholder-backend `
    --url "https://httpbin.org"
}

# ================================
# API (create or skip)
# ================================
$API_EXISTS = az apim api show `
  --resource-group $RG `
  --service-name $APIM_NAME `
  --api-id cardops-api `
  --query name `
  -o tsv 2>$null

if (-not $API_EXISTS) {
  Write-Host "Creating API cardops-api"
  az apim api create `
    --resource-group $RG `
    --service-name $APIM_NAME `
    --api-id cardops-api `
    --path cardops `
    --display-name "Card Ops API" `
    --protocols https `
    --subscription-required false
} else {
  Write-Host "API cardops-api already exists"
}

# ================================
# POLICY (ALWAYS UPDATE)
# ================================
Write-Host "Applying policy to API cardops-api"

az apim api policy set `
  --resource-group $RG `
  --service-name $APIM_NAME `
  --api-id cardops-api `
  --xml-content @"
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
Write-Host "APIM READY (IDEMPOTENT)"
Write-Host "Backend: PLACEHOLDER"
Write-Host "Safe to re-run N times"
Write-Host "===================================="
