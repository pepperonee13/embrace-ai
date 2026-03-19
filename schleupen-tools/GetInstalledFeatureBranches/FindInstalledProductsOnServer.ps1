# This script is a wrapper to list all feature-branch products installed on a specific server.

param (
    [Parameter(Mandatory = $true)]
    [string]$Server,
    [string]$Username
)

# Import the main script (dot-sourcing ensures functions are available in the current scope)
. "$(Split-Path -Parent $MyInvocation.MyCommand.Path)\GetInstalledFeatureBranches.ps1"

# Call the GetInstalledProductsOnServer function
$installedProducts = GetInstalledProductsOnServer -Server $Server -Username $Username | Sort-Object | Select-Object -Unique

# Ergebnisse anzeigen
if ($installedProducts.Count -eq 0) {
    Write-Host "Auf dem Server '$Server' sind keine Produkte mit Feature-Branch installiert."
} else {
    Write-Host "Auf dem Server '$Server' sind folgende Produkte mit Feature-Branch installiert:"
    $installedProducts | ForEach-Object { Write-Host $_ }
}