# ================================
# Load variables (CORRECT WAY)
# ================================
. "$PSScriptRoot/variables.ps1"

Write-Host "RG=$RG"
Write-Host "LOC=$LOC"
Write-Host "WEBAPP_PLAN=$WEBAPP_PLAN"
Write-Host "WEBAPP_NAME=$WEBAPP_NAME"
Write-Host "APIM_NAME=$APIM_NAME"
Write-Host "DOCKER_IMAGE=$DOCKER_IMAGE"

# ================================
# Resource Group
# ================================
az group create --name $RG --location $LOC

# ================================
# App Service Plan (Linux - Cheap)
# ================================
az appservice plan create `
  --name $WEBAPP_PLAN `
  --resource-group $RG `
  --location $LOC `
  --sku F1 `
  --is-linux

# ================================
# WebApp (Docker)
# ================================
az webapp create `
  --resource-group $RG `
  --plan $WEBAPP_PLAN `
  --name $WEBAPP_NAME `
  --deployment-container-image-name $DOCKER_IMAGE

# ================================
# Spring Boot Port
# ================================
az webapp config appsettings set `
  --resource-group $RG `
  --name $WEBAPP_NAME `
  --settings WEBSITES_PORT=8080

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
# Get WebApp Host
# ================================
$WEBAPP_HOST = az webapp show `
  --name $WEBAPP_NAME `
  --resource-group $RG `
  --query defaultHostName -o tsv

# ================================
# APIM Backend
# ================================
az apim backend create `
  --resource-group $RG `
  --service-name $APIM_NAME `
  --backend-id cardops-backend `
  --url "https://$WEBAPP_HOST"

# ================================
# APIM API
# ================================
az apim api create `
  --resource-group $RG `
  --service-name $APIM_NAME `
  --api-id cardops-api `
  --path cardops `
  --display-name "Card Ops API" `
  --protocols https

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
