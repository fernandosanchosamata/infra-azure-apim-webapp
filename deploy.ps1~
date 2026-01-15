# ================================
# Load variables
# ================================
. "$PSScriptRoot/variables.ps1"

Write-Host "Deploying INFRA only (NO Docker real deploy)"

# ================================
# Resource Group
# ================================
az group create `
  --name $RG `
  --location $LOC

# ================================
# Register providers (SAFE)
# ================================
az provider register --namespace Microsoft.Web --wait
az provider register --namespace Microsoft.App --wait
az provider register --namespace Microsoft.OperationalInsights --wait
az provider register --namespace Microsoft.ApiManagement --wait

# ================================
# Log Analytics (REQUIRED)
# ================================
$LAW_NAME = "$RG-law"

$LAW_ID = az monitor log-analytics workspace create `
  --resource-group $RG `
  --workspace-name $LAW_NAME `
  --location $LOC `
  --query id -o tsv

$LAW_KEY = az monitor log-analytics workspace get-shared-keys `
  --resource-group $RG `
  --workspace-name $LAW_NAME `
  --query primarySharedKey -o tsv

# ================================
# Container Apps Environment
# ================================
$ENV_NAME = "$RG-env"

az containerapp env create `
  --name $ENV_NAME `
  --resource-group $RG `
  --location $LOC `
  --logs-workspace-id $LAW_ID `
  --logs-workspace-key $LAW_KEY

# ================================
# Container App (PLACEHOLDER ONLY)
# ================================
az containerapp create `
  --name cardops-backend `
  --resource-group $RG `
  --environment $ENV_NAME `
  --image mcr.microsoft.com/azuredocs/containerapps-helloworld:latest `
  --ingress external `
  --target-port 80 `
  --min-replicas 0 `
  --max-replicas 1

# ================================
# Get Backend URL
# ================================
$BACKEND_URL = az containerapp show `
  --name cardops-backend `
  --resource-group $RG `
  --query properties.configuration.ingress.fqdn -o tsv

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
