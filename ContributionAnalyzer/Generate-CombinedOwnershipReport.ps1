param(
    [string[]]$TfsPaths = @(),
    [string[]]$GitRepos = @(),
    [string]$TfsCsv,
    [string]$GitRepoRoot = "..",
    [string]$GitBaseUrl = $null,
    [switch]$CloneIfMissing,
    [string]$FromDate = $null,
    [string]$AuthorMappingFile = "$PSScriptRoot/Vue-App/author_mappings.local.json",
    [string]$OutputCsv = "$PSScriptRoot/RawOwnershipReport.local.csv"
)

# Helper: Parse German datetime
function Parse-GermanDate($dateStr) {
    $culture = [System.Globalization.CultureInfo]::GetCultureInfo("de-DE")
    try {
        return [datetime]::Parse($dateStr, $culture)
    }
    catch {
        return $null
    }
}

# Helper: extract product shortcut from TfsRootPath
function Get-ProductShortcut($root) {
    if ($root -match "/Kontinente/([^/]+)/([^/]+)/") {
        return ("$($matches[1].ToLower()).$($matches[2].ToLower())")
    }
    elseif ($root -match "/GP/([^/]+)/([^/]+)/") {
        return ("$($matches[1].ToLower()).$($matches[2].ToLower())")
    }
    else {
        return $root
    }
}

# Helper: append date info to CSV
function Append-DateInfoToCsv($csvPath, $since, $until) {
    $sinceStr = if ($since) {
        if ($since -is [datetime]) { $since.ToString('yyyy-MM-dd') }
        else { $since }
    }
    else { '' }
    $untilStr = if ($until) {
        if ($until -is [datetime]) { $until.ToString('yyyy-MM-dd') }
        else { $until }
    }
    else { '' }
    $dateRow = "Since=$sinceStr,Until=$untilStr"
    Add-Content -Path $csvPath -Value $dateRow
}

# Load author mappings if file exists
$authorMap = @{}
if (Test-Path $AuthorMappingFile) {
    try {
        $authorMap = Get-Content $AuthorMappingFile | ConvertFrom-Json
    }
    catch {
        Write-Warning "Failed to load author mapping file: $AuthorMappingFile"
    }
}
else {
    Write-Host "Test Path $AuthorMappingFile for Author map failed"
}

$csvRows = @()

# --- TFS Section ---
if ($TfsPaths.Count -gt 0 -and (Test-Path $TfsCsv)) {
    $tfsRows = Import-Csv -Path $TfsCsv | ForEach-Object {
        $obj = $_ | Select-Object *, @{Name = 'ProductShortcut'; Expression = { $null } }
        $obj.ChangeDate = Parse-GermanDate $obj.ChangeDate
        $obj.ProductShortcut = Get-ProductShortcut $obj.TfsRootPath
        $obj
    }
    if ($FromDate) {
        $fromDateObj = Parse-GermanDate $FromDate
        $tfsRows = $tfsRows | Where-Object { $_.ChangeDate -ge $fromDateObj }
    }

    foreach ($tfsPath in $TfsPaths) {
    Write-Host "--- Processing TFS Path: $tfsPath ---" -ForegroundColor Cyan
        $filtered = $tfsRows | Where-Object { $_.TfsRootPath -like "*$tfsPath*" }
        $grouped = $filtered | Group-Object { "$(Get-ProductShortcut $_.TfsRootPath)|$($_.Author)" }
        foreach ($g in $grouped) {
            $first = $g.Group[0]
            $product = Get-ProductShortcut $first.TfsRootPath
            $author = $first.Author
            $contributionCount = ($g.Group | Select-Object -ExpandProperty ChangesetId | Sort-Object -Unique).Count
            $fileCount = ($g.Group | Select-Object -ExpandProperty FilePath | Sort-Object -Unique).Count
            $canonicalAuthor = if ($authorMap.PSObject.Properties.Name -contains $author) { $authorMap.$author } else { $author }
            $csvRows += [PSCustomObject]@{
                Product           = $product
                Author            = $canonicalAuthor
                ContributionCount = $contributionCount
                FileCount         = $fileCount
            }
        }
    }
}

# --- Git Section ---
foreach ($shortcut in $GitRepos) {
    $repoName = "cs-Schleupen.CS.$shortcut"
    $repoPath = Join-Path $GitRepoRoot $repoName
    Write-Host "--- Processing Git repo: $shortcut (repo: $repoName) ---" -ForegroundColor Cyan
    if (-not (Test-Path $repoPath)) {
        if ($CloneIfMissing -and $GitBaseUrl) {
            $remoteUrl = "$GitBaseUrl$repoName"
            Write-Host "Cloning $repoName from $remoteUrl ..." -ForegroundColor Yellow
            git clone $remoteUrl $repoPath
            if (-not (Test-Path $repoPath)) {
                Write-Warning "Failed to clone repository: $repoName"
                continue
            }
        }
        else {
            Write-Warning "Repository not found: $repoPath"
            continue
        }
    }
    Write-Host "Entering repository: $repoPath" -ForegroundColor Green
    Push-Location $repoPath
    try {
        $sinceArgs = @()
        if ($FromDate) { $sinceArgs += "--since=$FromDate" }
        $branch = "main"  # Change this if your main branch has a different name
        $authors = & git log $branch @sinceArgs --format='%an' | Where-Object { $_ -and ($_ -notmatch '\\') } | Sort-Object -Unique
        if (-not $authors) {
            Write-Host "  No authors found for this repository." -ForegroundColor Yellow
            continue
        }
        foreach ($author in $authors) {
            $canonicalAuthor = if ($authorMap.PSObject.Properties.Name -contains $author) { $authorMap.$author } else { $author }
            $authorCommits = (& git log $branch @sinceArgs --author="$author" --pretty=format:'%H' | Measure-Object).Count
            if ($authorCommits -eq 0) { continue }
            $files = & git log $branch @sinceArgs --author="$author" --name-only --pretty=format: | Where-Object { $_ -ne "" } | Sort-Object -Unique
            $fileCount = $files.Count
            $csvRows += [PSCustomObject]@{
                Product           = $shortcut
                Author            = $canonicalAuthor
                ContributionCount = $authorCommits
                FileCount         = $fileCount
            }
        }
    }
    finally {
        Pop-Location
    }
}

# --- Output Section ---
$csvRows | Export-Csv -Path $OutputCsv -NoTypeInformation -Encoding UTF8
Append-DateInfoToCsv $OutputCsv $FromDate $null
Write-Host "CSV generated: $OutputCsv" -ForegroundColor Green
