<#
.SYNOPSIS
  Multi-repo build audit:
  - clone/pull repos
  - dotnet paket install
  - build with Visual Studio MSBuild.exe + binlog
  - run BinlogWarningExtractor (dotnet run) that prints JSON to stdout
  - write warnings.json per repo

.USAGE
  pwsh .\Build-Repos-FromConfig.ps1 -ConfigPath .\config.json

.CONFIG (example)
{
  "gitBaseDir": "D:\\git",
  "outputBaseDir": "D:\\build-audit",
  "remoteBaseUrl": "https://dev.azure.com/<ORG>/<PROJECT>/_git",
  "msbuild": {
    "exePath": "C:\\Program Files\\Microsoft Visual Studio\\2022\\BuildTools\\MSBuild\\Current\\Bin\\MSBuild.exe",
    "configuration": "Release",
    "extraArgs": ["/m", "/nologo"]
  },
  "solution": { "relativePath": "" },
  "paket": { "command": "dotnet paket install" },
  "binlog": { "fileName": "build.binlog" },
  "converter": { "workingDirRelativeToScript": "BinlogWarningExtractor" },
  "repositories": [ "repo1", "repo2" ]
}
#>

param(
  [Parameter(Mandatory)]
  [string] $ConfigPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# ----------------- helpers -----------------

function To-FullPath([string] $path, [string] $baseDir = $null) {
  if (-not $path) { return $path }
  if ($baseDir -and -not [System.IO.Path]::IsPathRooted($path)) {
    $path = Join-Path $baseDir $path
  }
  return [System.IO.Path]::GetFullPath($path)
}

function Ensure-Dir([string] $path) {
  if (-not $path) { throw "Ensure-Dir: path is empty" }
  if (-not (Test-Path $path)) { New-Item -ItemType Directory -Path $path | Out-Null }
}

function Require-File([string] $path, [string] $what) {
  if (-not (Test-Path $path)) { throw "$what not found: $($path)" }
}

function Find-CommandPath([string] $name) {
  $cmd = Get-Command $name -ErrorAction SilentlyContinue
  if ($cmd) { return $cmd.Source }
  return $null
}

function Run-Process {
  param(
    [Parameter(Mandatory)][string] $FileName,
    [Parameter(Mandatory)][string[]] $Args,
    [Parameter(Mandatory)][string] $WorkingDirectory,
    [switch] $CaptureStdout
  )

  # Quote arguments that contain spaces or quotes in a safe way for the called process.
  # For MSBuild and dotnet, quoting with "..." is correct; embedded quotes are rare for file paths.
  $escapedArgs = foreach ($a in $Args) {
    if ($null -eq $a) { "" }
    elseif ($a -match '[\s"]') { '"' + ($a -replace '"', '\"') + '"' }
    else { $a }
  }

  $argLine = ($escapedArgs -join ' ')
  Write-Host ">> $FileName $argLine" -ForegroundColor Cyan

  $psi = New-Object System.Diagnostics.ProcessStartInfo
  $psi.FileName = $FileName
  $psi.Arguments = $argLine
  $psi.WorkingDirectory = $WorkingDirectory
  $psi.RedirectStandardOutput = $true
  $psi.RedirectStandardError = $true
  $psi.UseShellExecute = $false

  $p = New-Object System.Diagnostics.Process
  $p.StartInfo = $psi
  [void]$p.Start()

  $stdout = $p.StandardOutput.ReadToEnd()
  $stderr = $p.StandardError.ReadToEnd()
  $p.WaitForExit()

  if ($stdout) { Write-Host $stdout }
  if ($stderr) { Write-Host $stderr -ForegroundColor Yellow }

  if ($p.ExitCode -ne 0) {
    throw "Process failed (exit $($p.ExitCode)): $FileName $argLine"
  }

  if ($CaptureStdout) { return $stdout }
  return $null
}

function Try-Find-VsWhere() {
  $candidates = @(
    "$env:ProgramFiles(x86)\Microsoft Visual Studio\Installer\vswhere.exe",
    "$env:ProgramFiles\Microsoft Visual Studio\Installer\vswhere.exe"
  )
  foreach ($c in $candidates) { if (Test-Path $c) { return $c } }

  $fromPath = Find-CommandPath "vswhere.exe"
  if ($fromPath -and (Test-Path $fromPath)) { return $fromPath }

  return $null
}

function Find-MSBuildExe([string] $explicitPath) {
  if ($explicitPath) {
    $p = To-FullPath $explicitPath
    Require-File $p "MSBuild.exe"
    return $p
  }

  # Common VS2022 locations (BuildTools + Editions)
  $common = @(
    "C:\Program Files\Microsoft Visual Studio\2022\BuildTools\MSBuild\Current\Bin\MSBuild.exe",
    "C:\Program Files\Microsoft Visual Studio\2022\Community\MSBuild\Current\Bin\MSBuild.exe",
    "C:\Program Files\Microsoft Visual Studio\2022\Professional\MSBuild\Current\Bin\MSBuild.exe",
    "C:\Program Files\Microsoft Visual Studio\2022\Enterprise\MSBuild\Current\Bin\MSBuild.exe"
  )
  foreach ($c in $common) { if (Test-Path $c) { return (To-FullPath $c) } }

  # vswhere fallback (if available)
  $vswhere = Try-Find-VsWhere
  if ($vswhere) {
    $installPath = & $vswhere -latest -products * -requires Microsoft.Component.MSBuild -property installationPath
    if (-not $installPath) { $installPath = & $vswhere -latest -products * -property installationPath }
    if ($installPath) {
      $candidate = Join-Path $installPath "MSBuild\Current\Bin\MSBuild.exe"
      if (Test-Path $candidate) { return (To-FullPath $candidate) }

      $candidate15 = Join-Path $installPath "MSBuild\15.0\Bin\MSBuild.exe"
      if (Test-Path $candidate15) { return (To-FullPath $candidate15) }
    }
  }

  throw @"
MSBuild.exe not found.
Either set config.msbuild.exePath explicitly, or install Visual Studio Build Tools / VS with MSBuild.

Tried common locations:
- $($common -join "`n- ")

vswhere present: $([bool]$vswhere)
"@
}

function Get-SlnPath([string] $repoDir, [string] $solutionRelativePath) {
  if ($solutionRelativePath) {
    $p = To-FullPath $solutionRelativePath $repoDir
    Require-File $p "Solution"
    return $p
  }

  $sln = Get-ChildItem -Path $repoDir -Filter *.sln -Recurse -File |
         Sort-Object FullName |
         Select-Object -First 1
  if (-not $sln) { throw "No .sln found in repo: $repoDir" }
  return (To-FullPath $sln.FullName)
}

function Clone-Or-Pull([string] $repoName, [string] $repoDir, [string] $remoteBaseUrl, [string] $gitExe) {
  if (-not (Test-Path $repoDir)) {
    Ensure-Dir (Split-Path $repoDir -Parent)
    $remote = "$remoteBaseUrl/$repoName"
    Run-Process -FileName $gitExe -Args @("clone", $remote, $repoDir) -WorkingDirectory (Split-Path $repoDir -Parent)
  } else {
    Run-Process -FileName $gitExe -Args @("-C", $repoDir, "fetch", "--all", "--prune") -WorkingDirectory $repoDir
    Run-Process -FileName $gitExe -Args @("-C", $repoDir, "checkout", "main") -WorkingDirectory $repoDir
    Run-Process -FileName $gitExe -Args @("-C", $repoDir, "pull", "--ff-only") -WorkingDirectory $repoDir
  }
}

function Preflight-Check {
  param(
    [Parameter(Mandatory)][string] $gitExe,
    [Parameter(Mandatory)][string] $dotnetExe,
    [Parameter(Mandatory)][string] $msbuildExe,
    [Parameter(Mandatory)][string] $converterWorkDir,
    [Parameter(Mandatory)][string] $gitBaseDir,
    [Parameter(Mandatory)][string] $outputBaseDir
  )

  Write-Host "=== Preflight checks ===" -ForegroundColor Green

  Require-File $gitExe "git"
  Require-File $dotnetExe "dotnet"
  Require-File $msbuildExe "MSBuild.exe"
  Ensure-Dir $gitBaseDir
  Ensure-Dir $outputBaseDir
  if (-not (Test-Path $converterWorkDir)) { throw "Converter directory not found: $converterWorkDir" }

  Run-Process -FileName $gitExe -Args @("--version") -WorkingDirectory $gitBaseDir
  Run-Process -FileName $dotnetExe -Args @("--version") -WorkingDirectory $gitBaseDir
  Run-Process -FileName $msbuildExe -Args @("-version") -WorkingDirectory $gitBaseDir

  # quick check that converter can at least start (no binlog required); will still build on first run
  Run-Process -FileName $dotnetExe -Args @("--info") -WorkingDirectory $converterWorkDir

  Write-Host "Preflight OK ✅" -ForegroundColor Green
}

# ----------------- load config + normalize paths early -----------------

# Resolve config path relative to the CURRENT working directory
if (-not [System.IO.Path]::IsPathRooted($ConfigPath)) {
  $ConfigPath = Join-Path (Get-Location) $ConfigPath
}
$ConfigPath = [System.IO.Path]::GetFullPath($ConfigPath)
Require-File $ConfigPath "Config"

$config = Get-Content -Raw -Path $ConfigPath | ConvertFrom-Json

$scriptDir = To-FullPath (Split-Path -Parent $MyInvocation.MyCommand.Path)

$gitBaseDir    = To-FullPath ([string]$config.gitBaseDir)
$outputBaseDir = To-FullPath ([string]$config.outputBaseDir)
$remoteBaseUrl = [string]$config.remoteBaseUrl
$repos         = @($config.repositories)

if (-not $gitBaseDir)    { throw "config.gitBaseDir missing" }
if (-not $outputBaseDir) { throw "config.outputBaseDir missing" }
if (-not $remoteBaseUrl) { throw "config.remoteBaseUrl missing" }
if ($repos.Count -eq 0)  { throw "config.repositories is empty" }

$msbuildExe = Find-MSBuildExe ([string]$config.msbuild.exePath)

$configuration = [string]$config.msbuild.configuration
if (-not $configuration) { $configuration = "Release" }

$extraArgs = @()
if ($config.msbuild.extraArgs) { $extraArgs = @($config.msbuild.extraArgs | ForEach-Object { [string]$_ }) }

$solutionRelativePath = ""
if ($config.solution -and $config.solution.relativePath) {
  $solutionRelativePath = [string]$config.solution.relativePath
}

$paketCommand = "dotnet paket install"
if ($config.paket -and $config.paket.command) { $paketCommand = [string]$config.paket.command }

$binlogFileName = "build.binlog"
if ($config.binlog -and $config.binlog.fileName) { $binlogFileName = [string]$config.binlog.fileName }

$converterRel = [string]$config.converter.workingDirRelativeToScript
if (-not $converterRel) { throw "config.converter.workingDirRelativeToScript missing" }
$converterWorkDir = To-FullPath $converterRel $scriptDir

# Tools on PATH
$gitExe = Find-CommandPath "git"
if (-not $gitExe) { throw "git not found on PATH" }
$dotnetExe = Find-CommandPath "dotnet"
if (-not $dotnetExe) { throw "dotnet not found on PATH" }

# Normalize tool paths (just in case)
$gitExe = To-FullPath $gitExe
$dotnetExe = To-FullPath $dotnetExe

# Preflight (before doing any repo work)
Preflight-Check -gitExe $gitExe -dotnetExe $dotnetExe -msbuildExe $msbuildExe `
  -converterWorkDir $converterWorkDir -gitBaseDir $gitBaseDir -outputBaseDir $outputBaseDir

Write-Host "Using MSBuild.exe: $msbuildExe" -ForegroundColor Green
Write-Host "Git base dir:      $gitBaseDir" -ForegroundColor Green
Write-Host "Output base dir:   $outputBaseDir" -ForegroundColor Green
Write-Host "Converter dir:     $converterWorkDir" -ForegroundColor Green

# ----------------- main loop -----------------

$results = @()

foreach ($repo in $repos) {
  $repo = [string]$repo
  $repoDir = To-FullPath $repo $gitBaseDir
  $repoOut = To-FullPath $repo $outputBaseDir
  $binlogDir = To-FullPath "binlog" $repoOut

  Ensure-Dir $repoOut
  Ensure-Dir $binlogDir

  $binlogPath = To-FullPath $binlogFileName $binlogDir
  $warningsJsonPath = To-FullPath "warnings.json" $repoOut

  $status = "OK"
  $err = $null
  $slnPath = $null

  try {
    Write-Host "====================" -ForegroundColor Green
    Write-Host "Repo: $repo" -ForegroundColor Green
    Write-Host "====================" -ForegroundColor Green

    Clone-Or-Pull -repoName $repo -repoDir $repoDir -remoteBaseUrl $remoteBaseUrl -gitExe $gitExe

    # Paket step (runs in repo dir)
    # We execute it via pwsh only if it's a complex command; easiest is to invoke dotnet directly if it's the default.
    # Since your config allows any command string, we'll run it through pwsh but without losing quoting in paths.
    # (paket command typically has no file paths)
    Run-Process -FileName "pwsh" -Args @("-NoProfile", "-Command", $paketCommand) -WorkingDirectory $repoDir

    $slnPath = Get-SlnPath $repoDir $solutionRelativePath

    # MSBuild.exe (VS) with safe quoting for sln + binlog
    $msbuildArgs = @(
      $slnPath
      "/p:Configuration=$configuration"
      "/bl:$binlogPath"
    ) + $extraArgs

    Run-Process -FileName $msbuildExe -Args $msbuildArgs -WorkingDirectory $repoDir

    # Converter: dotnet run -- "<binlog>"
    # Run in converter working directory (next to script).
    Run-Process -FileName $dotnetExe -Args @("run", "--", $binlogPath) -WorkingDirectory $converterWorkDir -CaptureStdout
  }
  catch {
    $status = "FAILED"
    $err = $_.Exception.Message
    Write-Host "ERROR in $($repo): $err" -ForegroundColor Red

    $failureObj = @{
      repository  = $repo
      status      = "FAILED"
      error       = $err
      generatedAt = (Get-Date).ToString("o")
      build       = @{
        configuration = $configuration
        solution      = $slnPath
        binlog        = $binlogPath
        msbuildExe    = $msbuildExe
      }
      warnings    = @()
    }

    $failureJson = ($failureObj | ConvertTo-Json -Depth 30)
    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($warningsJsonPath, $failureJson, $utf8NoBom)
  }

  $results += [pscustomobject]@{
    Repo   = $repo
    Status = $status
    Output = $warningsJsonPath
    Binlog = $binlogPath
    Error  = $err
  }
}

$results | Format-Table -AutoSize
