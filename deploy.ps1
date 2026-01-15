../variables.ps1

az group create --name $RG --location $LOC

az appservice plan create `
  --name $WEBAPP_PLAN `
  --resource-group $RG `
  --location $LOC `
  --sku B1 `
  --is-linux

az webapp create `
  --resource-group $RG `
  --plan $WEBAPP_PLAN `
  --name $WEBAPP_NAME `
  --deployment-container-image-name $DOCKER_IMAGE

az webapp config appsettings set `
  --resource-group $RG `
  --name $WEBAPP_NAME `
  --settings WEBSITES_PORT=8080

az apim create `
  --name $APIM_NAME `
  --resource-group $RG `
  --location $LOC `
  --publisher-name "Verdugox" `
  --publisher-email "demo@demo.com" `
  --sku-name Consumption

$WEBAPP_HOST=$(az webapp show `
  --name $WEBAPP_NAME `
  --resource-group $RG `
  --query defaultHostName -o tsv)

az apim backend create `
  --resource-group $RG `
  --service-name $APIM_NAME `
  --backend-id cardops-backend `
  --url "https://$WEBAPP_HOST"

az apim api create `
  --resource-group $RG `
  --service-name $APIM_NAME `
  --api-id cardops-api `
  --path cardops `
  --display-name "Card Ops API" `
  --protocols https

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
  <backend><base /></backend>
  <outbound><base /></outbound>
</policies>
"@
