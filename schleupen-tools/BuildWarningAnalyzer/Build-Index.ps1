param (
    [Parameter(Mandatory)]
    [string]$InputRoot,    # Path where warnings_*.json files live

    [Parameter(Mandatory)]
    [string]$OutputRoot    # Where index.json + dashboard go
)

$index = @()
$warningsDbRoot = Join-Path $OutputRoot "warningsDB"

Write-Host "-----Indexing jsons from $warningsDbRoot-----"

Get-ChildItem -Path $InputRoot -Recurse -Filter "warnings_*.json" | Group-Object { $_.Directory.Name } | ForEach-Object {
    $solutionName = $_.Name
    $sortedBuilds = $_.Group | Sort-Object { [int]($_.BaseName -replace 'warnings_', '') } -Descending
    $latest = $sortedBuilds | Select-Object -First 1
    $previous = $sortedBuilds | Select-Object -Skip 1 -First 1
    $jsonLatest = Get-Content $latest.FullName | ConvertFrom-Json
    $latestTotal = $jsonLatest.WarningCount
    $previousTotal = 0
    $trendValue = $null
    if ($previous) {
        $jsonPrevious = Get-Content $previous.FullName | ConvertFrom-Json
        $previousTotal = $jsonPrevious.WarningCount
        $trendValue = [int]($latestTotal - $previousTotal)
    }

    # Create destination folder and copy the JSON file
    $targetFolder = Join-Path $warningsDbRoot $solutionName
    if (-not (Test-Path $targetFolder)) {
        New-Item -ItemType Directory -Path $targetFolder | Out-Null
    }

    $targetFile = Join-Path $targetFolder $latest.Name
    # Copy-Item -Path $latest.FullName -Destination $targetFile -Force

    # Create relative path to use in index.json
    $relativePath = [System.IO.Path]::GetRelativePath($OutputRoot, $targetFile) -replace '\\', '/'

    $index += [pscustomobject]@{
        ProductShortcut = $jsonLatest.ProductShortcut
        BuildId         = $jsonLatest.BuildId
        FilePath        = $relativePath
        TotalWarnings   = $latestTotal
        DistinctCodes   = $jsonLatest.Warnings.Count
        Codes           = $jsonLatest.Warnings.Code
        TrendValue      = $trendValue
    }
}

# Ensure index.json is saved next to the dashboard
$outputPath = Join-Path $OutputRoot "index.json"
,@($index) | ConvertTo-Json -Depth 4 | Set-Content -Encoding UTF8 -Path $outputPath
Write-Host "✅ index.json created at $outputPath"
