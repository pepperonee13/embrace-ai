param(
    [Parameter(Mandatory=$true)]
    [string]$SourceRoot,
    [Parameter(Mandatory=$true)]
    [string]$TargetRoot,
    [switch]$DryRun,
    [switch]$KeepTopDollar  # If set, do not delete the $tf folder after move
)

Write-Host "Scanning for files under: $SourceRoot ..."
$files = Get-ChildItem -Path $SourceRoot -Recurse -File

$fileCount = $files.Count
Write-Host "Total files found: $fileCount"
Write-Host ""

if ($DryRun) {
    Write-Host "Dry run enabled. No files will be moved." -ForegroundColor Yellow
    Write-Host "This is only the file count; the real move is skipped."
    return
}

# ---- REAL MOVE BELOW (runs only when not in DryRun) ----

Write-Host "Starting file move..."
$counter = 0

foreach ($file in $files) {
    Write-Verbose "Processing file: $($file.FullName)"
    $relativePath = $file.FullName.Substring($SourceRoot.Length).TrimStart('\')
    $destPath     = Join-Path $TargetRoot $relativePath
    $destDir      = Split-Path $destPath

    if (-not (Test-Path $destDir)) {
        New-Item -ItemType Directory -Path $destDir -Force | Out-Null
        Write-Verbose "Created directory: $destDir"
    }

    if (Test-Path $destPath) {
        Write-Warning "Destination already exists, skipping: $destPath"
    }
    else {
        Move-Item -LiteralPath $file.FullName -Destination $destPath
        Write-Verbose "Moved file to: $destPath"
    }

    $counter++
    if ($counter % 50 -eq 0) {
        Write-Host "$counter / $fileCount files processed..."
    }
}

Write-Host "Move complete. Processed: $counter file(s)."

# Cleanup
Get-ChildItem -Path $SourceRoot -Recurse -Directory |
    Sort-Object FullName -Descending |
    Remove-Item -Force

$topDollar = "$SourceRoot\$"
if ($KeepTopDollar -ne $true && Test-Path $topDollar) {
    Remove-Item $topDollar -Recurse -Force
    Write-Host "Removed $topDollar."
}

Write-Host "Cleanup complete. Run 'git status' to review changes."
