# TFS Contributors Analyzer
# This script analyzes contributors in specified TFS version control paths and visualizes collaboration over time.

param(
    [Parameter(Mandatory = $true)]
    [string]$TfsCollectionUrl,
    [Parameter(Mandatory = $true)]
    [string[]]$Paths,
    [datetime]$Since = (Get-Date).AddMonths(-12),
    [string]$OutputCsv,
    [string]$CultureInfo = "de-DE"
)

# Format for /version:Dyyyy-MM-dd
$sinceVersion = $Since.ToString("yyyy-MM-dd")
$culture = [System.Globalization.CultureInfo]::GetCultureInfo($CultureInfo)
$allRecords = @()

foreach ($path in $Paths) {
    Write-Host "📂 Processing path: $path (since $sinceVersion)..."
    $recordCount = 0

    $tfsOutput = tf history $path /collection:$TfsCollectionUrl /recursive /format:detailed /noprompt /user:* /version:D$sinceVersion~T 2>&1
    $currentChangeset = $null
    $currentUser = $null
    $currentDate = $null
    $parsingChanges = $false

    foreach ($line in $tfsOutput) {
        if ($line -match "^Changeset:\s+(\d+)") {
            $currentChangeset = $matches[1]
        }
        elseif ($line -match "^User:\s+(.+)") {
            $currentUser = $matches[1] -replace '÷', 'ö' -replace '▀', 'ß' -replace '³', 'ü'
        }
        elseif ($line -match "^Date:\s+(.+)") {    
            # there are some german character encoding problems in the tf output with powershell :(     
            $dateStr = $matches[1] -replace 'Mõrz', 'März'
            try {
                $currentDate = [datetime]::Parse($dateStr, $culture)
            }
            catch {
                Write-Warning "⚠️ Date parsing failed: $dateStr"
                $currentDate = $null
            }
        }
        elseif ($line -match "^Items:") {
            $parsingChanges = $true
        }
        elseif ($parsingChanges -and $line -match "^\s+([^$]+?)\s+(\$.+)$") {
            $changeType = $matches[1].Trim()
            $filePath = $matches[2].Trim()
            # Remove suffixes like ;X79607 from the end of the file path
            $filePath = $filePath -replace ';[A-Z0-9]+$', ''

            if ($currentChangeset -and $currentUser -and $currentDate) {
                $allRecords += [pscustomobject]@{
                    ChangesetId = $currentChangeset
                    Author      = $currentUser
                    ChangeDate  = $currentDate
                    ChangeType  = $changeType
                    FilePath    = $filePath
                    TfsRootPath = $path
                }
                $recordCount++
            }
            else {
                Write-Warning "⚠️no changes added for Changeset: $currentChangeset"
            }
        }
        elseif ($line -eq "") {
            $parsingChanges = $false
        }
    }

    Write-Host "$recordCount changes processed"
}

# Export all results (include ChangesetId in CSV)
$allRecords | Export-Csv -Path $OutputCsv -NoTypeInformation -Encoding UTF8
Write-Host "✅ Exported $($allRecords.Count) entries to '$OutputCsv'. (Includes ChangesetId)"