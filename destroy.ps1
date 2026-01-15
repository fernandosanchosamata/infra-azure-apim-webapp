. "$PSScriptRoot/variables.ps1"

Write-Host "🔥 DESTROYING ALL INFRASTRUCTURE 🔥"
Write-Host "Resource Group: $RG"

az group delete `
  --name $RG `
  --yes `
  --no-wait
