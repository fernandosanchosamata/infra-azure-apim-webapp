# ================================
# Load variables
# ================================
. "$PSScriptRoot/variables.ps1"

Write-Host "Deploying INFRA + APIM POLICIES (backend placeholder)"

# ================================
# Resource Group
# ================================
az group create `
  --name $RG `
  --location $LOC

# Providers
az provider register --namespace Microsoft.ApiManagement --wait

# APIM extension (CLAVE)
az extension add --name apim --upgrade

# API Management
az apim create `
  --name $APIM_NAME `
  --resource-group $RG `
  --location $LOC `
  --publisher-name "Verdugox" `
  --publisher-email "demo@demo.com" `
  --sku-name Consumption

# Backend placeholder
az apim backend create `
  --resource-group $RG `
  --service-name $APIM_NAME `
  --backend-id placeholder-backend `
  --url "https://httpbin.org"

# API
az apim api create `
  --resource-group $RG `
  --service-name $APIM_NAME `
  --api-id cardops-api `
  --path cardops `
  --display-name "Card Ops API" `
  --protocols https `
  --subscription-required false

# Policy
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
Write-Host "APIM READY WITH POLICIES"
Write-Host "Backend: PLACEHOLDER"
Write-Host "Next step: Jenkins updates backend URL"
Write-Host "===================================="
