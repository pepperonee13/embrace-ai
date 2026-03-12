<#
.SYNOPSIS
  Collect feature branches for a list of solution codes from TFS and write them to a JSON file.

.DESCRIPTION
  Solution code formats:
    1) xxx.yyy  -> GP solution -> $/CS3/GP/xxx/yyy/Features
    2) xx.yy(y) -> Land solution -> $/CS3/Kontinente/xx/yy(y)/Features

  For each solution code, the script lists the subfolders directly under the corresponding
  "Features" folder in TFS, and writes a JSON file like:

    {
      "ABC.DEF": [ "feature-1", "feature-2" ],
      "AB.CDE":  [ "another-feature" ]
    }

.PARAMETER CollectionUrl
  The TFS collection URL, e.g. http://tfs:8080/tfs/DefaultCollection

.PARAMETER SolutionCodes
  One or more solution codes, e.g. "ABC.DEF", "AB.CDE"

.PARAMETER OutputPath
  Path to the JSON output file. Default: .\featureBranches.json
#>
param(
    [Parameter(Mandatory = $true)]
    [string]
    $CollectionUrl,

    [Parameter(Mandatory = $true)]
    [string[]]
    $SolutionCodes,

    [Parameter(Mandatory = $false)]
    [string]
    $OutputPath = ".\featureBranches.json"
)

# --- Helpers -----------------------------------------------------------------

function Get-SolutionTypeAndParts {
    param(
        [Parameter(Mandatory = $true)]
        [string] $SolutionCode
    )

    $gpPattern    = '^[A-Za-z]{3}\.[A-Za-z]{3}$'       # xxx.yyy
    $landPattern  = '^[A-Za-z]{2}\.[A-Za-z]{2,3}$'     # xx.yy(y)

    if ($SolutionCode -match $gpPattern) {
        $parts = $SolutionCode.Split('.')
        return [PSCustomObject]@{
            Type  = 'GP'
            Part1 = $parts[0]
            Part2 = $parts[1]
        }
    }
    elseif ($SolutionCode -match $landPattern) {
        $parts = $SolutionCode.Split('.')
        return [PSCustomObject]@{
            Type  = 'Land'
            Part1 = $parts[0]
            Part2 = $parts[1]
        }
    }
    else {
        throw "Invalid solution code format: '$SolutionCode'"
    }
}

function Get-FeaturesPathForSolution {
    param(
        [Parameter(Mandatory = $true)]
        [string] $SolutionCode
    )

    $info = Get-SolutionTypeAndParts -SolutionCode $SolutionCode

    switch ($info.Type) {
        'GP' {
            # $/CS3/GP/xxx/yyy/Features
            return ('$/' + "CS3/GP/{0}/{1}/Features" -f $info.Part1, $info.Part2)
        }
        'Land' {
            # $/CS3/Kontinente/xx/yy(y)/Features
            return ('$/' + "CS3/Kontinente/{0}/{1}/Features" -f $info.Part1, $info.Part2)
        }
        default {
            throw "Unknown solution type '$($info.Type)' for '$SolutionCode'"
        }
    }
}

function Get-FeatureBranchesFromTfs {
    param(
        [Parameter(Mandatory = $true)]
        [string] $CollectionUrl,

        [Parameter(Mandatory = $true)]
        [string] $FeaturesServerPath
    )

    $args = @(
        'dir',
        $FeaturesServerPath,
        "/collection:$CollectionUrl",
        '/folders'
    )

    $output = & tf @args 2>$null

    if ($LASTEXITCODE -ne 0 -or -not $output) {
        return @()
    }

    # Remove empty lines
    $lines = $output | Where-Object { $_.Trim() -ne "" }

    if ($lines.Count -le 1) {
        return @()
    }

    # Skip the header line "$/CS3/.../Features:"
    $folderLines =
        $lines |
        Select-Object -Skip 1 |
        Where-Object { $_.TrimStart().StartsWith('$') }

    $branches = foreach ($line in $folderLines) {
        $name = $line.Trim()

        # TFS prints "$FolderName" -> remove leading $
        if ($name.StartsWith('$')) {
            $name = $name.Substring(1)
        }

        # Return an object instead of a string
        [PSCustomObject]@{
            Name = $name
        }
    }

    return $branches
}

# --- Main --------------------------------------------------------------------

$results = @{}

foreach ($code in $SolutionCodes) {
    try {
        $featuresPath   = Get-FeaturesPathForSolution -SolutionCode $code
        $featureBranches = Get-FeatureBranchesFromTfs -CollectionUrl $CollectionUrl -FeaturesServerPath $featuresPath
        $results[$code]  = $featureBranches
    }
    catch {
        # For invalid codes or other errors, store an empty list but keep going.
        Write-Warning $_.Exception.Message
        $results[$code] = @()
    }
}

# Convert to JSON and save
$results |
    ConvertTo-Json -Depth 5 |
    Set-Content -Path $OutputPath -Encoding UTF8

Write-Host "Feature branch information written to '$OutputPath'."
