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

# Helper: confirm user action
function Confirm-UserAction {
    param (
        [string]$Message,
        [string]$WarningMessage
    )
    
    Write-Warning $WarningMessage
    $confirmation = Read-Host -Prompt "$Message [y/N]"
    return $confirmation -eq 'y'
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
    } else {
        Push-Location $repoPath
        
        # Check repository status
        $status = & git status --porcelain
        $hasChanges = $null -ne $status
        $behindCount = & git rev-list HEAD..origin/main --count
        $needsUpdate = $behindCount -gt 0
        
        if ($hasChanges -or $needsUpdate) {
            $warningMsg = "Repository '$repoName' requires updates:"
            if ($hasChanges) { $warningMsg += "`n - Local uncommitted changes will be stashed" }
            if ($needsUpdate) { $warningMsg += "`n - $behindCount commits behind remote" }
            
            if (-not (Confirm-UserAction -Message "Do you want to proceed with these changes?" -WarningMessage $warningMsg)) {
                Write-Host "Skipping repository $repoName by user request" -ForegroundColor Yellow
                Pop-Location
                continue
            }
        }
        
        Write-Host "Updating repository..." -ForegroundColor Yellow
        
        # Stash any local changes if they exist
        if ($hasChanges) {
            Write-Host "  Stashing local changes..." -ForegroundColor Yellow
            & git stash
        }
        
        # Try fast-forward only pull first
        $pullResult = & git pull --ff-only 2>&1
        if ($LASTEXITCODE -ne 0) {
            if (-not (Confirm-UserAction -Message "Fast-forward pull failed. Attempt to merge changes?" `
                    -WarningMessage "This will create a merge commit in your local repository")) {
                Write-Host "Operation cancelled by user" -ForegroundColor Yellow
                if ($hasChanges) {
                    Write-Host "Restoring local changes..." -ForegroundColor Yellow
                    & git stash pop
                }
                Pop-Location
                continue
            }
            
            # Fetch latest and merge
            & git fetch
            & git merge --no-commit origin/main
            if ($LASTEXITCODE -ne 0) {
                Write-Warning "Merge conflicts detected. Aborting merge and skipping repository."
                & git merge --abort
                if ($hasChanges) {
                    Write-Host "Restoring local changes..." -ForegroundColor Yellow
                    & git stash pop
                }
                Pop-Location
                continue
            }
            # If merge was successful, commit it
            & git commit -m "Merge origin/main for analysis"
        }
        
        # Restore stashed changes if they were stashed
        if ($hasChanges) {
            Write-Host "  Restoring local changes..." -ForegroundColor Yellow
            & git stash pop
            if ($LASTEXITCODE -ne 0) {
                Write-Warning "Failed to restore local changes. They remain in the stash."
            }
        }
        Pop-Location
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
