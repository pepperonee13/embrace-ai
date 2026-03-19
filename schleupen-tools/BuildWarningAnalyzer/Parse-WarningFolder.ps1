param (
    [Parameter(Mandatory)]
    [string]$InputRoot,
    
    [Parameter(Mandatory)]
    [string]$OutputRoot
)

function Parse-Warning($logPath) {
    # Validate and extract BuildId from filename
    $filename = [System.IO.Path]::GetFileNameWithoutExtension($logPath)
    if ($filename -match 'warnings_(\d+)$') {
        $buildId = $matches[1]
    }
    else {
        throw "Filename '$filename' does not match expected format 'warnings_<BuildId>.log'"
    }

    # Extract product shortcut from parent directory
    $productShortcut = Split-Path -Path $logPath -Parent | Split-Path -Leaf

    # Prepare data structure for warnings
    $warningData = @{}
    $warningCount = 0
    
    $bytes = [System.IO.File]::ReadAllBytes($LogPath)
    $encoding = [System.Text.Encoding]::GetEncoding("Windows-1252")
    $lines = $encoding.GetString($bytes) -split "`r?`n"

    # Read and categorize warnings
    $lines | ForEach-Object {
        $line = $_.Trim()
    
        if ($line -match 'warning\s+([A-Z]+\d+):\s+(.*)') {
            # Coded warning (e.g., CS8618, CA1822)
            $code = $matches[1]
            $message = $matches[2]
        }
        elseif ($line -match 'warning\s*:\s+(.*)') {
            # Uncoded warning (e.g., SDK upgrade warnings)
            $code = "Uncoded"
            $message = $matches[1]
        }
        else {
            return # Not a warning line
        }

        if (-not $warningData.ContainsKey($code)) {
            $warningData[$code] = @()
        }
        $warningData[$code] += $message
        $warningCount++
    }

    # Create structured output
    $output = [pscustomobject]@{
        LogPath         = $logPath
        ProductShortcut = $productShortcut
        BuildId         = $buildId
        WarningCount    = $warningCount
        Warnings        = @()
    }

    foreach ($code in $warningData.Keys) {
        $output.Warnings += [pscustomobject]@{
            Code     = $code
            Messages = $warningData[$code]
        }
    }

    # Emit as JSON
    $output | ConvertTo-Json -Depth 5
    Write-Host "✅ Warnings parsed from $logPath"
}

# Get first-level folders (e.g., produktA, produktB)
$firstLevelFolders = Get-ChildItem -Path $InputRoot -Directory

foreach ($folder in $firstLevelFolders) {
    Write-Host "-----Parsing warning logs from $folder-----"

    # Only look for .log files directly inside this folder (not deeper)
    $logFiles = Get-ChildItem -Path $folder.FullName -Filter "warnings_*.log" -File

    foreach ($logFile in $logFiles) {
        $relativePath = $logFile.FullName.Substring($InputRoot.Length).TrimStart('\')
        $outputPath = Join-Path $OutputRoot ($relativePath -replace '\.log$', '.json')

        $outputDir = Split-Path $outputPath -Parent
        if (-not (Test-Path $outputDir)) {
            New-Item -ItemType Directory -Path $outputDir | Out-Null
        }

        # Run parser and save JSON
        Parse-Warning($logFile.FullName) | Out-File -FilePath $outputPath -Encoding utf8
    }
}
