# ================================
# Load variables
# ================================
. "$PSScriptRoot/variables.ps1"

Write-Host "Deploying INFRA (AKS + APIM) — SAFE & IDEMPOTENT"

# ================================
# Resource Group
# ================================
if (-not (az group exists --name $RG | ConvertFrom-Json)) {
  Write-Host "Creating Resource Group $RG"
  az group create --name $RG --location $LOC
} else {
  Write-Host "Resource Group $RG already exists"
}

# ================================
# Providers (MANDATORY)
# ================================
Write-Host "Registering Azure Providers..."
az provider register --namespace Microsoft.ContainerService --wait
az provider register --namespace Microsoft.ApiManagement --wait

# ================================
# AKS (IDEMPOTENT)
# ================================
Write-Host "Checking AKS..."

$AKS_EXISTS = az aks show `
  --resource-group $RG `
  --name $AKS_NAME `
  --query name -o tsv 2>$null

if (-not $AKS_EXISTS) {
  Write-Host "Creating AKS $AKS_NAME..."

  az aks create `
    --resource-group $RG `
    --name $AKS_NAME `
    --location $LOC `
    --node-count $AKS_NODE_COUNT `
    --node-vm-size $AKS_NODE_SIZE `
    --enable-managed-identity `
    --generate-ssh-keys
} else {
  Write-Host "AKS $AKS_NAME already exists"
}

Write-Host "Waiting for AKS to be ready..."
az aks wait --resource-group $RG --name $AKS_NAME --created

# ================================
# API Management (IDEMPOTENT)
# ================================
Write-Host "Checking APIM..."

$APIM_EXISTS = az apim show `
  --name $APIM_NAME `
  --resource-group $RG `
  --query name -o tsv 2>$null

if (-not $APIM_EXISTS) {
  Write-Host "Creating APIM $APIM_NAME..."

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

Write-Host "Waiting for APIM provisioning..."
az apim wait --name $APIM_NAME --resource-group $RG --created
Start-Sleep -Seconds 20

# ================================
# APIM Backend (REST — STABLE)
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

Start-Sleep -Seconds 10

# ================================
# APIM API (REST)
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

Start-Sleep -Seconds 10

# ================================
# APIM Policy (REST — XML)
# ================================
$policyUrl = "https://management.azure.com/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RG/providers/Microsoft.ApiManagement/service/$APIM_NAME/apis/cardops-api/policies/policy?api-version=2022-08-01"

$policyXml = @"
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

az rest `
  --method PUT `
  --uri $policyUrl `
  --headers "{ `"Content-Type`": `"application/vnd.ms-azure-apim.policy+xml`" }" `
  --body $policyXml

# ================================
# DONE
# ================================
Write-Host "===================================="
Write-Host "INFRA READY ✅"
Write-Host "- AKS: $AKS_NAME (empty, ready for kubectl)"
Write-Host "- APIM: $APIM_NAME (policy + backend ready)"
Write-Host "Safe to re-run N times"
Write-Host "===================================="
