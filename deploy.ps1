# ================================
# Load variables
# ================================
. "$PSScriptRoot/variables.ps1"

Write-Host "Deploying INFRA only (no Docker deploy)"

# ================================
# Resource Group
# ================================
az group create `
  --name $RG `
  --location $LOC

# ================================
# Log Analytics (required)
# ================================
$LAW_ID=$(az monitor log-analytics workspace create `
  --resource-group $RG `
  --workspace-name "$RG-law" `
  --location $LOC `
  --query id -o tsv)

# ================================
# Container Apps Environment
# ================================
az containerapp env create `
  --name "$RG-env" `
  --resource-group $RG `
  --location $LOC `
  --logs-workspace-id $LAW_ID

# ================================
# Container App (EMPTY / PLACEHOLDER)
# ================================
az containerapp create `
  --name cardops-backend `
  --resource-group $RG `
  --environment "$RG-env" `
  --image mcr.microsoft.com/azuredocs/containerapps-helloworld:latest `
  --ingress external `
  --target-port 80 `
  --min-replicas 0 `
  --max-replicas 1

# ================================
# Get Container App URL
# ================================
$BACKEND_URL=$(az containerapp show `
  --name cardops-backend `
  --resource-group $RG `
  --query properties.configuration.ingress.fqdn -o tsv)

# ================================
# API Management (Consumption)
# ================================
az apim create `
  --name $APIM_NAME `
  --resource-group $RG `
  --location $LOC `
  --publisher-name "Verdugox" `
  --publisher-email "demo@demo.com" `
  --sku-name Consumption

# ================================
# APIM Backend
# ================================
az apim backend create `
  --resource-group $RG `
  --service-name $APIM_NAME `
  --backend-id cardops-backend `
  --url "https://$BACKEND_URL"

# ================================
# APIM API
# ================================
az apim api create `
  --resource-group $RG `
  --service-name $APIM_NAME `
  --api-id cardops-api `
  --path cardops `
  --display-name "Card Ops API" `
  --protocols https `
  --subscription-required false

# ================================
# APIM Policy
# ================================
az apim api policy set `
  --resource-group $RG `
  --service-name $APIM_NAME `
  --api-id cardops-api `
  --xml-content @"
<policies>
  <inbound>
    <base />
    <set-backend-service backend-id="cardops-backend" />
  </inbound>
  <backend>
    <base />
  </backend>
  <outbound>
    <base />
  </outbound>
</policies>
"@
