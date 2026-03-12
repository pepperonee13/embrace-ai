[CmdletBinding()]
param(
    [string]$ConfigPath = ".\git-config.json",

    # Optional overrides
    [datetime]$SinceDate,

    # Optional: override output format
    [ValidateSet('Json','Csv','Both','None')]
    [string]$OutputFormat
)

$ScriptDir  = Split-Path -Parent $MyInvocation.MyCommand.Path
$CoreScript = Join-Path $ScriptDir "Get-BranchesCommits.ps1"
$OutDir     = $ScriptDir

if (-not (Test-Path $CoreScript)) {
    Write-Error "Get-BranchesCommits.ps1 not found at '$CoreScript'"
    exit 1
}

if (-not (Test-Path $ConfigPath)) {
    Write-Error "Config file not found at '$ConfigPath'"
    exit 1
}

# Capture analysis date once
$analysisDate = Get-Date

# -------------------------
# LOAD CONFIG
# -------------------------
$configJson = Get-Content $ConfigPath -Raw
$config     = $configJson | ConvertFrom-Json

if (-not $config.Organization -or -not $config.Project -or -not $config.Repositories) {
    Write-Error "Config must contain Organization, Project, and Repositories."
    exit 1
}

# -------------------------
# EFFECTIVE SinceDate
# -------------------------
$effectiveSinceDate = $null
if ($PSBoundParameters.ContainsKey('SinceDate')) {
    $effectiveSinceDate = $SinceDate
}
elseif ($config.PSObject.Properties.Name -contains 'SinceDate' -and $config.SinceDate) {
    $effectiveSinceDate = [datetime]$config.SinceDate
}

# -------------------------
# EFFECTIVE OutputFormat
# -------------------------
if ($PSBoundParameters.ContainsKey('OutputFormat')) {
    # CLI overrides config
    $effectiveOutputFormat = $OutputFormat
}
elseif ($config.PSObject.Properties.Name -contains 'OutputFormat' -and $config.OutputFormat) {
    $effectiveOutputFormat = $config.OutputFormat
}
else {
    $effectiveOutputFormat = 'None'
}

switch ($effectiveOutputFormat.ToLower()) {
    'json' { $effectiveOutputFormat = 'Json' }
    'csv'  { $effectiveOutputFormat = 'Csv' }
    'both' { $effectiveOutputFormat = 'Both' }
    'none' { $effectiveOutputFormat = 'None' }
    default { $effectiveOutputFormat = 'None' }
}

Write-Host "Effective OutputFormat = $effectiveOutputFormat" -ForegroundColor Cyan

# Normalized base URL for building commit links
$baseOrgUrl = $config.Organization.TrimEnd('/')

# -------------------------
# MAIN PROCESSING LOOP
# -------------------------
$all = @()

foreach ($repo in $config.Repositories) {
    if ($repo -is [string]) {
        # If the repository is a string, treat it as the name
        $repoName = $repo
        $mainBranch = $config.MainBranchName
        $featureBranchPrefix = $config.FeatureBranchPrefix
    } elseif ($repo -is [pscustomobject]) {
        # If the repository is an object, use its properties
        $repoName = $repo.name
        $mainBranch = if ($repo.PSObject.Properties.Name -contains 'main') { $repo.main } else { $config.MainBranchName }
        $featureBranchPrefix = if ($repo.PSObject.Properties.Name -contains 'featureBranch') { $repo.featureBranch } else { $config.FeatureBranchPrefix }
    } else {
        Write-Error "Invalid repository format: $repo"
        continue
    }

    # Process the repository with $repoName, $mainBranch, and $featureBranchPrefix
    Write-Host "Processing repository: $repoName with main: $mainBranch and featureBranch: $featureBranchPrefix"

    $params = @{
        Organization = $config.Organization
        Project      = $config.Project
        Repository   = $repoName
        MainBranchName = $mainBranch
        FeatureBranchPrefix = $featureBranchPrefix
    }

    if ($effectiveSinceDate) {
        $params.SinceDate = $effectiveSinceDate
    }

    # run core script → returns commit records (with raw CommitId)
    $repoResults = & $CoreScript @params

    foreach ($r in $repoResults) {
        # store the URL in CommitId field (as requested)
        $all += [PSCustomObject]@{
            Repository = $repoName
            Date       = $r.Date
            Branch     = $r.Branch
            Author     = $r.Author
            Comment    = $r.Comment
            CommitUrl  = $r.CommitUrl
        }
    }
}

# final sorting: Branch ASC, Date DESC
$all = $all |
    Sort-Object Branch, @{ Expression = { [datetime]$_.Date }; Descending = $true }

# -------------------------
# OUTPUT FORMATS
# -------------------------
$timestamp     = (Get-Date).ToString("yyyyMMdd_HHmmss")
$analysisStamp = $analysisDate.ToString("o")   # ISO 8601

switch ($effectiveOutputFormat) {
    'Json' {
        $path = Join-Path $OutDir "BranchCommits_$timestamp.json"

        $jsonObject = New-Object PSObject -Property @{
            AnalysisDate = $analysisStamp
            Commits      = $all
        }

        $jsonObject | ConvertTo-Json -Depth 5 | Set-Content $path -Encoding UTF8
        Write-Host "JSON written to: $path"
    }
    'Csv' {
        $path = Join-Path $OutDir "BranchCommits_$timestamp.csv"
        $all | Export-Csv $path -NoTypeInformation -Encoding UTF8

        # Append analysis date as last line
        Add-Content -Path $path -Value "AnalysisDate,$analysisStamp"

        Write-Host "CSV written to: $path (analysis date appended as last line)"
    }
    'Both' {
        # JSON
        $jsonPath = Join-Path $OutDir "BranchCommits_$timestamp.json"
        $jsonObj  = New-Object PSObject -Property @{
            AnalysisDate = $analysisStamp
            Commits      = $all
        }
        $jsonObj | ConvertTo-Json -Depth 5 | Set-Content $jsonPath -Encoding UTF8

        # CSV
        $csvPath = Join-Path $OutDir "BranchCommits_$timestamp.csv"
        $all | Export-Csv $csvPath -NoTypeInformation -Encoding UTF8
        Add-Content -Path $csvPath -Value "AnalysisDate,$analysisStamp"

        Write-Host "JSON written to: $jsonPath"
        Write-Host "CSV written to:  $csvPath (analysis date appended as last line)"
    }
    'None' {
        # No files, just return objects
    }
}

# always return the list
$all
