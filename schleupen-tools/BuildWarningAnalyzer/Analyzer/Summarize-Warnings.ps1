<#
.SYNOPSIS
  Phase-1, facts-only summarizer for build warnings.

  Reads per-repo build.json (array of { Code, Text, Title, File }) and writes:
  - warnings-summary.json
  - warnings-summary.md

  Buckets warnings into:
  - Tooling   (nuget packages, .targets/.props)
  - Generated (obj/bin, *.g.cs)
  - RepoCode  (everything else)

.USAGE
  pwsh .\Summarize-Warnings.ps1 -ConfigPath .\config.json

.NOTES
  - No editorconfig
  - No recommendations
  - Deterministic and easy to verify
#>

param(
  [Parameter(Mandatory)]
  [string] $ConfigPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function To-FullPath([string] $path, [string] $baseDir = $null) {
  if (-not $path) { return $path }
  if ($baseDir -and -not [System.IO.Path]::IsPathRooted($path)) {
    $path = Join-Path $baseDir $path
  }
  return [System.IO.Path]::GetFullPath($path)
}

function Resolve-FromPwd([string] $path) {
  if (-not [System.IO.Path]::IsPathRooted($path)) {
    $path = Join-Path (Get-Location) $path
  }
  return (To-FullPath $path)
}

function Read-Json([string] $path) {
  Get-Content -Raw -Path $path | ConvertFrom-Json
}

function Write-Utf8NoBom([string] $path, [string] $content) {
  $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
  [System.IO.File]::WriteAllText($path, $content, $utf8NoBom)
}

function Extract-ProjectPathFromTitle([string] $title) {
  if (-not $title) { return $null }

  # Most MSBuild warnings end with: [C:\path\to\project.csproj]
  $m = [regex]::Match($title, '\[(?<proj>[A-Za-z]:\\[^\]]+?\.csproj)\]\s*$')
  if ($m.Success) { return $m.Groups["proj"].Value }

  # Sometimes solution / other formats might exist; ignore for now.
  return $null
}

function Extract-LineColumnFromTitle([string] $title) {
  if (-not $title) { return $null }

  # Example: Foo.cs(37,41): warning CS0618: ...
  $m = [regex]::Match($title, '\((?<line>\d+),(?<col>\d+)\):\s*warning\s+')
  if ($m.Success) {
    return @{
      line = [int]$m.Groups["line"].Value
      column = [int]$m.Groups["col"].Value
    }
  }
  return $null
}

function Normalize-PathSlashes([string] $path) {
  if (-not $path) { return $path }
  return $path.Replace("/","\")
}

function Bucket-FromFileOrTitle([string] $file, [string] $title) {
  $f = (Normalize-PathSlashes $file)
  $t = (Normalize-PathSlashes $title)

  $lf = if ($f) { $f.ToLowerInvariant() } else { "" }
  $lt = if ($t) { $t.ToLowerInvariant() } else { "" }

  # Tooling / external
  if ($lf.Contains("\.nuget\packages\") -or $lt.Contains("\.nuget\packages\") -or
      $lf.EndsWith(".targets") -or $lf.EndsWith(".props")) {
    return "Tooling"
  }

  # Generated
  if ($lf.Contains("\obj\") -or $lf.Contains("\bin\") -or
      $lf.EndsWith(".g.cs") -or $lf.EndsWith(".generated.cs")) {
    return "Generated"
  }

  return "RepoCode"
}

function Is-TestPath([string] $path) {
  if (-not $path) { return $false }
  $p = (Normalize-PathSlashes $path)
  $lp = $p.ToLowerInvariant()
  return $lp -match '(^|[\\/_\\.])(test|tests|testing|unittests|connectiontests|componenttests|integrativetests|integrationtests|benchmark|benchmarks)([\\/_\\.]|$)'
}

function Try-Get-RelativePath([string] $fullPath, [string] $repoDir) {
  if (-not $fullPath) { return $null }
  if (-not $repoDir) { return $fullPath }

  $p = Normalize-PathSlashes $fullPath
  $r = Normalize-PathSlashes $repoDir

  if ($p.StartsWith($r, [System.StringComparison]::OrdinalIgnoreCase)) {
    return $p.Substring($r.Length).TrimStart('\','/')
  }
  return $fullPath
}

function Get-FolderPrefix([string] $relPath, [int] $segments = 3) {
  if (-not $relPath) { return "(unknown)" }
  $p = $relPath.Replace("\","/").TrimStart("/")
  $parts = $p.Split("/", [System.StringSplitOptions]::RemoveEmptyEntries)
  if ($parts.Length -eq 0) { return "(root)" }

  $take = [Math]::Min($segments, $parts.Length)
  return ($parts[0..($take-1)] -join "/")
}

function Summarize-WarningsForRepo([string] $repoName, [string] $repoDir, [string] $warningsJsonPath, [string] $outDir) {
  $repoDir = To-FullPath $repoDir
  $warningsJsonPath = To-FullPath $warningsJsonPath
  $outDir = To-FullPath $outDir

  if (-not (Test-Path $warningsJsonPath)) {
    throw "build.json not found: $warningsJsonPath"
  }

  Ensure-Dir $outDir

  $raw = Read-Json $warningsJsonPath

  # Handle a failure-shaped build.json (object) gracefully
  if ($raw -isnot [System.Collections.IEnumerable] -or $raw -is [string]) {
    $summaryObj = @{
      repo = $repoName
      generatedAt = (Get-Date).ToString("o")
      status = "UNKNOWN_FORMAT"
      message = "build.json did not contain an array"
      inputs = @{ warningsJson = $warningsJsonPath; repoDir = $repoDir }
      summary = @{ total = 0; tooling = 0; generated = 0; repoCode = 0; testCode = 0 }
      byCode = @()
      byBucket = @()
      topFolders = @()
    }

    $jsonOut = ($summaryObj | ConvertTo-Json -Depth 20)
    Write-Utf8NoBom (Join-Path $outDir "$repoName-warnings-summary.json") $jsonOut
    Write-Utf8NoBom (Join-Path $outDir "$repoName-warnings-summary.md") "# Warning summary for $repoName`n`n(No array found in build.json)"
    return
  }

  $items = @()
  foreach ($w in $raw) {
    $code = [string]$w.Code
    if (-not $code) { $code = "(no code)" }

    $file = [string]$w.File
    $title = [string]$w.Title
    $text = [string]$w.Text

    $bucket = Bucket-FromFileOrTitle $file $title
    $relPath = Try-Get-RelativePath $file $repoDir
    $folder = Get-FolderPrefix $relPath 3

    $proj = Extract-ProjectPathFromTitle $title
    $projRel = Try-Get-RelativePath $proj $repoDir
    if ($bucket -eq "RepoCode" -and ((Is-TestPath $relPath) -or (Is-TestPath $projRel))) {
      $bucket = "TestCode"
    }

    $items += [pscustomobject]@{
      Code = $code
      Bucket = $bucket
      File = $file
      RelPath = $relPath
      Folder = $folder
      Project = $proj
      ProjectRel = $projRel
      Text = $text
      Title = $title
    }
  }

  $bucketCounts = $items | Group-Object Bucket | ForEach-Object {
    [pscustomobject]@{ Bucket = $_.Name; Count = $_.Count }
  } | Sort-Object Count -Descending

  $codeCounts = $items | Group-Object Code | ForEach-Object {
    [pscustomobject]@{ Code = $_.Name; Count = $_.Count }
  } | Sort-Object Count -Descending

  $codeCountsRepo = $items |
    Where-Object { $_.Bucket -eq "RepoCode" } |
    Group-Object Code |
    ForEach-Object { [pscustomobject]@{ Code = $_.Name; Count = $_.Count } } |
    Sort-Object Count -Descending

  $codeCountsTest = $items |
    Where-Object { $_.Bucket -eq "TestCode" } |
    Group-Object Code |
    ForEach-Object { [pscustomobject]@{ Code = $_.Name; Count = $_.Count } } |
    Sort-Object Count -Descending

  $topFolders = $items |
    Where-Object { $_.Bucket -eq "RepoCode" } |
    Group-Object Folder |
    ForEach-Object { [pscustomobject]@{ Folder = $_.Name; Count = $_.Count } } |
    Sort-Object Count -Descending |
    Select-Object -First 15

  $topRepoFolders = $topFolders

  $topProjects = $items |
    Where-Object { $_.ProjectRel } |
    Group-Object ProjectRel |
    ForEach-Object { [pscustomobject]@{ Project = $_.Name; Count = $_.Count } } |
    Sort-Object Count -Descending |
    Select-Object -First 15

  $topProjectsRepo = $items |
    Where-Object { $_.ProjectRel -and $_.Bucket -eq "RepoCode" } |
    Group-Object ProjectRel |
    ForEach-Object { [pscustomobject]@{ Project = $_.Name; Count = $_.Count } } |
    Sort-Object Count -Descending |
    Select-Object -First 15

  $topProjectsTest = $items |
    Where-Object { $_.ProjectRel -and $_.Bucket -eq "TestCode" } |
    Group-Object ProjectRel |
    ForEach-Object { [pscustomobject]@{ Project = $_.Name; Count = $_.Count } } |
    Sort-Object Count -Descending |
    Select-Object -First 15

  $codeProjects = $items |
    Where-Object { $_.ProjectRel } |
    Group-Object Code |
    ForEach-Object {
      $code = $_.Name
      $projects = $_.Group |
        Group-Object ProjectRel |
        ForEach-Object { [pscustomobject]@{ Project = $_.Name; Count = $_.Count } } |
        Sort-Object Count -Descending
      [pscustomobject]@{
        Code = $code
        Projects = $projects
      }
    }

  $codeProjectsRepo = $items |
    Where-Object { $_.ProjectRel -and $_.Bucket -eq "RepoCode" } |
    Group-Object Code |
    ForEach-Object {
      $code = $_.Name
      $projects = $_.Group |
        Group-Object ProjectRel |
        ForEach-Object { [pscustomobject]@{ Project = $_.Name; Count = $_.Count } } |
        Sort-Object Count -Descending
      [pscustomobject]@{
        Code = $code
        Projects = $projects
      }
    }

  $codeProjectsTest = $items |
    Where-Object { $_.ProjectRel -and $_.Bucket -eq "TestCode" } |
    Group-Object Code |
    ForEach-Object {
      $code = $_.Name
      $projects = $_.Group |
        Group-Object ProjectRel |
        ForEach-Object { [pscustomobject]@{ Project = $_.Name; Count = $_.Count } } |
        Sort-Object Count -Descending
      [pscustomobject]@{
        Code = $code
        Projects = $projects
      }
    }

  $summary = @{
    total = @($items).Count
    tooling = @($items | Where-Object Bucket -eq "Tooling").Count
    generated = @($items | Where-Object Bucket -eq "Generated").Count
    repoCode = @($items | Where-Object Bucket -eq "RepoCode").Count
    testCode = @($items | Where-Object Bucket -eq "TestCode").Count
  }

  # For quick navigation: give a few examples per top code
  $topCodeExamples = @()
  foreach ($cc in ($codeCounts | Select-Object -First 10)) {
    $examples = $items |
      Where-Object { $_.Code -eq $cc.Code } |
      Select-Object -First 3 |
      ForEach-Object {
        [pscustomobject]@{
          Bucket = $_.Bucket
          File = $_.RelPath
          Project = $_.ProjectRel
          Text = $_.Text
          Title = $_.Title
        }
      }

    $topCodeExamples += [pscustomobject]@{
      Code = $cc.Code
      Count = $cc.Count
      Examples = $examples
    }
  }

  $topCodeExamplesRepo = @()
  foreach ($cc in ($codeCountsRepo | Select-Object -First 10)) {
    $examples = $items |
      Where-Object { $_.Code -eq $cc.Code -and $_.Bucket -eq "RepoCode" } |
      Select-Object -First 3 |
      ForEach-Object {
        [pscustomobject]@{
          Bucket = $_.Bucket
          File = $_.RelPath
          Project = $_.ProjectRel
          Text = $_.Text
          Title = $_.Title
        }
      }

    $topCodeExamplesRepo += [pscustomobject]@{
      Code = $cc.Code
      Count = $cc.Count
      Examples = $examples
    }
  }

  $topCodeExamplesTest = @()
  foreach ($cc in ($codeCountsTest | Select-Object -First 10)) {
    $examples = $items |
      Where-Object { $_.Code -eq $cc.Code -and $_.Bucket -eq "TestCode" } |
      Select-Object -First 3 |
      ForEach-Object {
        [pscustomobject]@{
          Bucket = $_.Bucket
          File = $_.RelPath
          Project = $_.ProjectRel
          Text = $_.Text
          Title = $_.Title
        }
      }

    $topCodeExamplesTest += [pscustomobject]@{
      Code = $cc.Code
      Count = $cc.Count
      Examples = $examples
    }
  }

  $summaryObj = @{
    repo = $repoName
    generatedAt = (Get-Date).ToString("o")
    status = "OK"
    inputs = @{
      warningsJson = $warningsJsonPath
      repoDir = $repoDir
    }
    summary = $summary
    byBucket = $bucketCounts
    byCode = $codeCounts
    byCodeRepo = $codeCountsRepo
    byCodeTest = $codeCountsTest
    topRepoFolders = $topFolders
    topProjects = $topProjects
    topProjectsRepo = $topProjectsRepo
    topProjectsTest = $topProjectsTest
    byCodeProjects = $codeProjects
    byCodeProjectsRepo = $codeProjectsRepo
    byCodeProjectsTest = $codeProjectsTest
    topCodeExamples = $topCodeExamples
    topCodeExamplesRepo = $topCodeExamplesRepo
    topCodeExamplesTest = $topCodeExamplesTest
  }

  $jsonOut = ($summaryObj | ConvertTo-Json -Depth 30)
  Write-Utf8NoBom (Join-Path $outDir "$repoName-warnings-summary.json") $jsonOut

  # Markdown output
  $md = @()
  $md += "# Warning summary for $repoName"
  $md += ""
  $md += "Generated: $((Get-Date).ToString("yyyy-MM-dd HH:mm:ss"))"
  $md += ""
  $md += "## Totals"
  $md += "- Total: **$($summaryObj.summary.total)**"
  $md += "- RepoCode: **$($summaryObj.summary.repoCode)**"
  $md += "- TestCode: **$($summaryObj.summary.testCode)**"
  $md += "- Tooling: **$($summaryObj.summary.tooling)**"
  $md += "- Generated: **$($summaryObj.summary.generated)**"
  $md += ""
  $md += "## By bucket"
  foreach ($b in $summaryObj.byBucket) { $md += "- $($b.Bucket): $($b.Count)" }
  $md += ""
  $md += "## Top diagnostic codes (RepoCode)"
  foreach ($c in ($summaryObj.byCodeRepo | Select-Object -First 15)) {
    $md += "- $($c.Code): $($c.Count)"
    $projectBreakdown = $summaryObj.byCodeProjectsRepo |
      Where-Object { $_.Code -eq $c.Code } |
      ForEach-Object { $_.Projects } |
      Select-Object -First 5
    foreach ($p in $projectBreakdown) { $md += "  - $($p.Project): $($p.Count)" }
  }
  $md += ""
  $md += "## Top diagnostic codes (TestCode)"
  foreach ($c in ($summaryObj.byCodeTest | Select-Object -First 15)) {
    $md += "- $($c.Code): $($c.Count)"
    $projectBreakdown = $summaryObj.byCodeProjectsTest |
      Where-Object { $_.Code -eq $c.Code } |
      ForEach-Object { $_.Projects } |
      Select-Object -First 5
    foreach ($p in $projectBreakdown) { $md += "  - $($p.Project): $($p.Count)" }
  }
  $md += ""
  if (@($summaryObj.topRepoFolders).Count -gt 0) {
    $md += "## Top folders (RepoCode only)"
    foreach ($f in $summaryObj.topRepoFolders) { $md += "- $($f.Folder): $($f.Count)" }
    $md += ""
  }
  if (@($summaryObj.topProjectsRepo).Count -gt 0) {
    $md += "## Top projects (RepoCode)"
    foreach ($p in $summaryObj.topProjectsRepo) { $md += "- $($p.Project): $($p.Count)" }
    $md += ""
  }
  if (@($summaryObj.topProjectsTest).Count -gt 0) {
    $md += "## Top projects (TestCode)"
    foreach ($p in $summaryObj.topProjectsTest) { $md += "- $($p.Project): $($p.Count)" }
    $md += ""
  }
  $md += "## Examples (top codes, RepoCode)"
  foreach ($ex in $summaryObj.topCodeExamplesRepo) {
    $md += "### $($ex.Code) (x$($ex.Count))"
    foreach ($e in $ex.Examples) {
      $titleSuffix = if ($e.Title) { " - $($e.Title)" } else { "" }
      $md += "- [$($e.Bucket)] $($e.File)  ($($e.Project))$titleSuffix"
      $txt = ([string]$e.Text)
      if ($txt.Length -gt 180) { $txt = $txt.Substring(0,180) + "…" }
      $md += "  - $txt"
    }
    $md += ""
  }
  $md += "## Examples (top codes, TestCode)"
  foreach ($ex in $summaryObj.topCodeExamplesTest) {
    $md += "### $($ex.Code) (x$($ex.Count))"
    foreach ($e in $ex.Examples) {
      $titleSuffix = if ($e.Title) { " - $($e.Title)" } else { "" }
      $md += "- [$($e.Bucket)] $($e.File)  ($($e.Project))$titleSuffix"
      $txt = ([string]$e.Text)
      if ($txt.Length -gt 180) { $txt = $txt.Substring(0,180) + "…" }
      $md += "  - $txt"
    }
    $md += ""
  }

  Write-Utf8NoBom (Join-Path $outDir "$repoName-warnings-summary.md") ($md -join "`r`n")
}

function Ensure-Dir([string] $path) {
  if (-not (Test-Path $path)) { New-Item -ItemType Directory -Path $path | Out-Null }
}

# -------- main --------
$ConfigPath = Resolve-FromPwd $ConfigPath
$config = Read-Json $ConfigPath

$gitBaseDir    = To-FullPath ([string]$config.gitBaseDir)
$outputBaseDir = To-FullPath ([string]$config.outputBaseDir)
$repos         = @($config.repositories)

foreach ($repo in $repos) {
  $repo = [string]$repo
  $repoDir = To-FullPath $repo $gitBaseDir
  $repoOut = To-FullPath $repo $outputBaseDir
  $warningsPath = To-FullPath "binlog\\build.json" $repoOut

  if (-not (Test-Path $warningsPath)) {
    Write-Host "Skipping $repo (no build.json at $warningsPath)" -ForegroundColor Yellow
    continue
  }

  try {
    Summarize-WarningsForRepo -repoName $repo -repoDir $repoDir -warningsJsonPath $warningsPath -outDir $repoOut
    Write-Host "Summarized $repo" -ForegroundColor Green
  }
  catch {
    Write-Host "Failed to summarize $($repo): $($_.Exception.Message)" -ForegroundColor Red
  }
}
