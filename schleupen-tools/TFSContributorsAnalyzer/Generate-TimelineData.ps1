param(
    [string[]]$TfsPaths = @(),
    [string[]]$GitRepos = @(),
    [string]$TfsCsv,
    [string]$GitRepoRoot = "..",
    [string]$GitBaseUrl = $null,
    [switch]$CloneIfMissing,
    [string]$FromDate = $null,
    [string]$Environment = "",
    [string]$AuthorMappingFile = "$PSScriptRoot/Vue-App/author_mappings.<CHANGEME>.json",
    [string]$OutputCsv = "$PSScriptRoot/Vue-App/TimelineData.<CHANGEME>.csv"
)

# Helper function to append environment suffix to filenames
function Get-EnvironmentFilename {
    param (
        [string]$BaseFilename
    )

    if ($Environment -and $Environment -ne "") {
        $BaseFilename = $BaseFilename -replace "<CHANGEME>", $Environment  # Remove existing .local if present
        return $BaseFilename
    } else {
        return $BaseFilename -replace "\.<CHANGEME>", ""  # Default to no environment suffix
    }
}

# Update paths with dynamic environment suffix
$AuthorMappingFile = Get-EnvironmentFilename $AuthorMappingFile
$OutputCsv = Get-EnvironmentFilename $OutputCsv

# Helper: Fix encoding issues commonly seen with Windows-1252 to UTF-8 conversion
function Fix-EncodingIssues($text) {
    if ($null -eq $text) { return $text }
    
    # Fix Windows-1252 to UTF-8 double-encoding issues
    $text = $text -replace '├Ñ', 'Ä'   # Ä
    $text = $text -replace '├ñ', 'ä'   # ä
    $text = $text -replace '├û', 'Ö'   # Ö
    $text = $text -replace '├Â', 'ö'   # ö
    $text = $text -replace '├£', 'Ü'   # Ü
    $text = $text -replace '├╝', 'ü'   # ü
    $text = $text -replace '├ƒ', 'ß'   # ß
    
    # Additional common encoding fixes from TFS script
    $text = $text -replace '÷', 'ö'    # Original TFS fix
    $text = $text -replace '▀', 'ß'    # Original TFS fix
    $text = $text -replace '³', 'ü'    # Original TFS fix
    $text = $text -replace 'Mõrz', 'März' # Original TFS fix
    
    return $text
}

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

$timelineData = @()

# --- TFS Section ---
if ($TfsPaths.Count -gt 0 -and (Test-Path $TfsCsv)) {
    Write-Host "Processing TFS timeline data..." -ForegroundColor Cyan
    
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

    foreach ($row in $tfsRows) {
        # Fix encoding issues in TFS data as well
        $author = Fix-EncodingIssues $row.Author
        $filePath = Fix-EncodingIssues $row.FilePath
        
        $canonicalAuthor = if ($authorMap.PSObject.Properties.Name -contains $author) { $authorMap.$author } else { $author }
        
        $timelineData += [PSCustomObject]@{
            Date = $row.ChangeDate.ToString("yyyy-MM-dd")
            DateTime = $row.ChangeDate.ToString("yyyy-MM-dd HH:mm:ss")
            Product = $row.ProductShortcut
            Author = $canonicalAuthor
            ChangesetId = $row.ChangesetId
            ChangeType = $row.ChangeType
            FilePath = $filePath
            Source = "TFS"
        }
    }
}

# --- Git Section ---
foreach ($shortcut in $GitRepos) {
    $repoName = "cs-Schleupen.CS.$shortcut"
    $repoPath = Join-Path $GitRepoRoot $repoName
    Write-Host "Processing Git timeline data for: $shortcut (repo: $repoName)" -ForegroundColor Cyan
    
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
    
    Write-Host "Extracting Git timeline data from: $repoPath" -ForegroundColor Green
    Push-Location $repoPath
    try {
        $sinceArgs = @()
        if ($FromDate) { $sinceArgs += "--since=$FromDate" }
        $branch = "main"  # Change this if your main branch has a different name
        
        # Get detailed commit information with file changes
        $gitLogFormat = "%H|%an|%ad|%s"  # Hash|Author|Date|Subject
        $gitLogOutput = & git log $branch @sinceArgs --date=iso --pretty=format:$gitLogFormat --name-only
        
        $currentCommit = $null
        $currentAuthor = $null
        $currentDate = $null
        $currentSubject = $null
        $parsingFiles = $false
        
        foreach ($line in $gitLogOutput) {
            if ($line -match '^([a-f0-9]+)\|([^|]+)\|([^|]+)\|(.*)$') {
                # New commit line
                $currentCommit = $matches[1]
                $currentAuthor = $matches[2]
                $currentDate = [datetime]::Parse($matches[3])
                $currentSubject = $matches[4]
                
                # Fix encoding issues in author names and commit messages
                $currentAuthor = Fix-EncodingIssues $currentAuthor
                $currentSubject = Fix-EncodingIssues $currentSubject
                
                $parsingFiles = $true
            }
            elseif ($parsingFiles -and $line.Trim() -ne "") {
                # File path
                $filePath = $line.Trim()
                
                # Fix encoding issues in file paths
                $filePath = Fix-EncodingIssues $filePath
                
                $canonicalAuthor = if ($authorMap.PSObject.Properties.Name -contains $currentAuthor) { $authorMap.$currentAuthor } else { $currentAuthor }
                
                $timelineData += [PSCustomObject]@{
                    Date = $currentDate.ToString("yyyy-MM-dd")
                    DateTime = $currentDate.ToString("yyyy-MM-dd HH:mm:ss")
                    Product = $shortcut
                    Author = $canonicalAuthor
                    ChangesetId = $currentCommit
                    ChangeType = "edit"  # Git doesn't distinguish change types as granularly as TFS
                    FilePath = $filePath
                    Source = "Git"
                    CommitMessage = $currentSubject
                }
            }
            elseif ($line.Trim() -eq "") {
                $parsingFiles = $false
            }
        }
    }
    finally {
        Pop-Location
    }
}

# Sort by date and output
$timelineData = $timelineData | Sort-Object DateTime
$timelineData | Export-Csv -Path $OutputCsv -NoTypeInformation -Encoding UTF8

Write-Host "Timeline data generated: $OutputCsv" -ForegroundColor Green
Write-Host "Total timeline entries: $($timelineData.Count)" -ForegroundColor Green