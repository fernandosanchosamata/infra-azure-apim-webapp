. "$PSScriptRoot/variables.ps1"

Write-Host "🔥 DESTROYING EVERYTHING IN $RG 🔥"

az group delete `
  --name $RG `
  --yes `
  --no-wait

Write-Host "✅ Resource Group deletion started"
