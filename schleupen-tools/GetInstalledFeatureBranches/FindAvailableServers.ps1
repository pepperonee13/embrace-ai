# This script is a wrapper to make it easier to find available servers for specific products.

param (
    [Parameter(Mandatory = $true)]
    [string[]]$Products,
    [string]$Username
)

# Import the main script (dot-sourcing ensures functions are available in the current scope)
. "$(Split-Path -Parent $MyInvocation.MyCommand.Path)\GetInstalledFeatureBranches.ps1"

# Call the GetAvailableServerFor function
$availableServers = GetAvailableServerFor -Products $Products -Username $Username | Sort-Object | Select-Object -Unique

# Ergebnisse anzeigen
if ($availableServers.Count -eq 0) {
    $productList = $Products -join ", "
    if ($Products.Count -eq 1) {
        Write-Host "Das Produkt ($productList) kann grundsätzlich installiert werden. Bitte klären Sie im Team, ob die aktuelle Version ersetzt werden kann."
    } else {
        Write-Host "Die Produkte ($productList) können grundsätzlich installiert werden. Bitte klären Sie im Team, ob die aktuellen Versionen ersetzt werden können."
    }
} else {
    $productList = $Products -join ", "
    if ($Products.Count -eq 1) {
        Write-Host "Das Produkt ($productList) kann auf den folgenden Servern installiert werden. Bitte klären Sie im Team, ob die aktuelle Version ersetzt werden kann:"
    } else {
        Write-Host "Die Produkte ($productList) können auf den folgenden Servern installiert werden. Bitte klären Sie im Team, ob die aktuellen Versionen ersetzt werden können:"
    }
    $availableServers | ForEach-Object { Write-Host $_ }
}