[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$Organization,

    [Parameter(Mandatory)]
    [string]$Project,

    [Parameter(Mandatory)]
    [string]$Repository,

    [string]$FeatureBranchPrefix = "refs/heads/feature",
    [string]$MainBranchName = "main",

    [datetime]$SinceDate
)

# --- FALLBACK DATE (today - 4 days) ---
if (-not $PSBoundParameters.ContainsKey('SinceDate')) {
    $SinceDate = (Get-Date).Date.AddDays(-4)
}

function Get-CommitsForBranch {
    param(
        [string]$BaseUrl,
        [string]$BranchShortName,
        [datetime]$SinceDate
    )

    $encodedBranch = [System.Uri]::EscapeDataString($BranchShortName)
    $requestedTop = 100

    $url = "$BaseUrl/commits?searchCriteria.itemVersion.version=$encodedBranch&`$top=$requestedTop"

    if ($SinceDate) {
        $sinceIso = [System.Uri]::EscapeDataString($SinceDate.ToString("o"))
        $url += "&searchCriteria.fromDate=$sinceIso"
    }

    try {
        $dateString = $SinceDate.ToString("yyyy-MM-dd")
        Write-Host "Fetching commits for Repository '$Repository' branch '$BranchShortName' since '$dateString'..." -ForegroundColor Green
        $response = Invoke-RestMethod -Uri $url -Method GET -UseDefaultCredentials
        $commits = $response.value

        if (-not $commits) { 
            Write-Host "No commits found." -ForegroundColor Yellow
            return @() 
        }

        # strict client-side date filter
        if ($SinceDate) {
            $commits = $commits | Where-Object {
                [datetime]$_.author.date -ge $SinceDate
            }
        }

        if (-not $commits) { 
            Write-Host "No commits found after client-side date filtering." -ForegroundColor Yellow
            return @() 
        }

        Write-Host "Found $($commits.Count) commits." -ForegroundColor Cyan
        return $commits |
        Sort-Object { [datetime]$_.author.date } -Descending
    }
    catch {
        Write-Error "Error fetching commits for branch $($BranchShortName): $_"
        return @()
    }
}

# --- MAIN ---
$baseUrl = "$Organization/$Project/_apis/git/repositories/$Repository"
$baseCommitUrl = "$($Organization.TrimEnd('/'))/$Project/_git/$Repository/commit"

# fetch branches
$refs = Invoke-RestMethod -Uri "$baseUrl/refs?filter=heads/" -Method GET -UseDefaultCredentials
$branches = $refs.value

if (-not $branches) { return @() }

# normalize main branch
$mainRef = $null
if ($MainBranchName.StartsWith("refs/heads/")) {
    $mainRef = $MainBranchName
}
else {
    $mainRef = "refs/heads/$MainBranchName"
}

# normalize feature branch prefix
$normalizedFeaturePrefix = $FeatureBranchPrefix
if ($FeatureBranchPrefix.EndsWith("/")) {
    $normalizedFeaturePrefix = $FeatureBranchPrefix.TrimEnd("/")
}

$mainBranch = $branches | Where-Object { $_.name -eq $mainRef }
$featureBranches = $branches | Where-Object { $_.name -like "$normalizedFeaturePrefix*" }

$results = @()

# ---- MAIN BRANCH ----
if ($mainBranch) {
    $short = $mainBranch.name.Replace("refs/heads/", "")
    $commits = Get-CommitsForBranch $baseUrl $short $SinceDate

    foreach ($c in $commits) {
        $results += [PSCustomObject]@{
            Branch    = $short
            CommitId  = $c.commitId
            CommitUrl = "$baseCommitUrl/$($c.commitId)"
            Author    = $c.author.name
            Email     = $c.author.email
            Date      = $c.author.date
            Comment   = $c.comment
        }
    }
}

# ---- FEATURE BRANCHES ----
foreach ($b in $featureBranches) {
    $short = $b.name.Replace("refs/heads/", "")
    $commits = Get-CommitsForBranch $baseUrl $short $SinceDate

    foreach ($c in $commits) {
        $results += [PSCustomObject]@{
            Branch    = $short
            CommitId  = $c.commitId
            CommitUrl = "$baseCommitUrl/$($c.commitId)"
            Author    = $c.author.name
            Email     = $c.author.email
            Date      = $c.author.date
            Comment   = $c.comment
        }
    }
}

# sort by Branch ASC, Date DESC
$results |
Sort-Object Branch, @{ Expression = { [datetime]$_.Date }; Descending = $true }
