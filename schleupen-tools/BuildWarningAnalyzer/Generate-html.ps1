<#
.SYNOPSIS
  Build a .sln, parse MSBuild warnings to JSON, generate a static HTML dashboard.

.USAGE
  .\Build-WarningsDashboard.ps1 -SlnPath "E:\git\MySolution.sln" -Configuration Release -OutDir ".\artifacts"

OUTPUT
  - warnings.json
  - warnings.html
  - build.log (full msbuild output)
#>

param(
    [Parameter(Mandatory = $true)]
    [string]$SlnPath,

    [string]$Configuration = "Release",

    [string]$OutDir = ".\warnings-artifacts"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Get-MSBuildPath {
    # Try MSBuild in PATH first
    $cmd = Get-Command msbuild -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }

    # Try vswhere (typical location)
    $vswhere = Join-Path ${env:ProgramFiles(x86)} "Microsoft Visual Studio\Installer\vswhere.exe"
    if (Test-Path $vswhere) {
        $installPath = & $vswhere -latest -products * -requires Microsoft.Component.MSBuild -property installationPath
        if ($installPath) {
            $candidates = @(
                Join-Path $installPath "MSBuild\Current\Bin\MSBuild.exe"
                Join-Path $installPath "MSBuild\17.0\Bin\MSBuild.exe"
                Join-Path $installPath "MSBuild\16.0\Bin\MSBuild.exe"
            )
            foreach ($c in $candidates) {
                if (Test-Path $c) { return $c }
            }
        }
    }

    throw "MSBuild not found. Install Visual Studio or Visual Studio Build Tools (with MSBuild)."
}

function Join-WrappedLinesSmart {
    param([string[]]$Lines)

    # Join console-wrapped lines without accidentally inserting spaces mid-word.
    # Rule: if previous ends with whitespace OR next starts with '[' or '(' then add a space, else concatenate directly.
    $sb = New-Object System.Text.StringBuilder
    for ($i = 0; $i -lt $Lines.Count; $i++) {
        $line = $Lines[$i]
        if ($i -eq 0) {
            [void]$sb.Append($line)
            continue
        }

        $prev = $Lines[$i - 1]
        $needsSpace =
        ($prev -match '\s$') -or
        ($line -match '^[\[\(]') -or
        ($prev -match '[:;,\)]$') # punctuation: safer to separate

        if ($needsSpace) { [void]$sb.Append(' ') }
        [void]$sb.Append($line)
    }

    # Normalize whitespace (keep single spaces)
    ($sb.ToString() -replace '[\t ]{2,}', ' ').Trim()
}

function Parse-MSBuildWarnings {
    param([string[]]$AllLines)

    $warnings = New-Object System.Collections.Generic.List[object]

    # We handle patterns like:
    #   <file>(line,col):
    #   warning <ID>: <message> ... (<url>) [<project.csproj>]
    #
    # And also cases where the warning line is wrapped across multiple lines until the final ].
    $pendingFile = $null
    $pendingLoc = $null

    $collecting = $false
    $buf = New-Object System.Collections.Generic.List[string]

    for ($i = 0; $i -lt $AllLines.Count; $i++) {
        $line = ($AllLines[$i] ?? "").TrimEnd()

        # Start: file location line
        $m1 = [regex]::Match($line, '^(?<file>.+)\((?<line>\d+),(?<col>\d+)\):\s*$')
        if ($m1.Success) {
            $pendingFile = $m1.Groups['file'].Value
            $pendingLoc = @{
                line = [int]$m1.Groups['line'].Value
                col  = [int]$m1.Groups['col'].Value
            }
            continue
        }

        # If we have a pending file/loc and see a warning line, start collecting it (it may wrap)
        if ($pendingFile -and ($line -match '^\s*warning\s+[A-Z0-9_]+\s*:')) {
            $collecting = $true
            $buf.Clear()
            $buf.Add($line) | Out-Null

            # If warning ends on this line (has trailing [project]) finalize; otherwise continue collecting
            if ($line -match '\]\s*$') {
                $collecting = $false
                $full = Join-WrappedLinesSmart -Lines $buf.ToArray()
                $w = ConvertTo-WarningObject -File $pendingFile -Loc $pendingLoc -WarningText $full
                if ($w) { $warnings.Add($w) | Out-Null }
                $pendingFile = $null
                $pendingLoc = $null
            }
            continue
        }

        # Continue collecting wrapped warning lines until we hit closing bracket
        if ($collecting) {
            $buf.Add($line) | Out-Null
            if ($line -match '\]\s*$') {
                $collecting = $false
                $full = Join-WrappedLinesSmart -Lines $buf.ToArray()
                $w = ConvertTo-WarningObject -File $pendingFile -Loc $pendingLoc -WarningText $full
                if ($w) { $warnings.Add($w) | Out-Null }
                $pendingFile = $null
                $pendingLoc = $null
            }
            continue
        }

        # Some MSBuild formats emit "path(line,col): warning ..." on the same line.
        $m2 = [regex]::Match($line, '^(?<file>.+)\((?<line>\d+)(?:,(?<col>\d+))?\):\s*warning\s+(?<id>[A-Z0-9_]+)\s*:\s*(?<rest>.+)$')
        if ($m2.Success) {
            $file = $m2.Groups['file'].Value
            $loc = @{
                line = [int]$m2.Groups['line'].Value
                col  = if ($m2.Groups['col'].Success) { [int]$m2.Groups['col'].Value } else { 0 }
            }
            $full = "warning $($m2.Groups['id'].Value): $($m2.Groups['rest'].Value)"
            $w = ConvertTo-WarningObject -File $file -Loc $loc -WarningText $full
            if ($w) { $warnings.Add($w) | Out-Null }
            continue
        }
        
        # Compiler / tool warnings like:
        # CSC : warning CSxxxx: message [project]
        $m3 = [regex]::Match($line, '^(?<tool>[A-Za-z0-9_.-]+)\s*:\s*warning\s+(?<id>[A-Z0-9_]+)\s*:\s*(?<rest>.+)$')
        if ($m3.Success) {
            $full = "warning $($m3.Groups['id'].Value): $($m3.Groups['rest'].Value)"
            # No file/line info on this line; keep it queryable anyway
            $w = ConvertTo-WarningObject -File "" -Loc @{ line = 0; col = 0 } -WarningText $full
            if ($w) { $warnings.Add($w) | Out-Null }
            continue
        }


        # Reset pending file if something else comes (avoid incorrect carry-over)
        if ($pendingFile -and $line) {
            # If next content is unrelated, drop pending state.
            $pendingFile = $null
            $pendingLoc = $null
        }
    }

    return $warnings
}

function ConvertTo-WarningObject {
    param(
        [Parameter(Mandatory = $true)][string]$File,
        [Parameter(Mandatory = $true)][hashtable]$Loc,
        [Parameter(Mandatory = $true)][string]$WarningText
    )

    # Example WarningText (already joined):
    # warning CA1707: Remove the underscores ... Execute_...(). (https://docs...) [E:\...\Gateway.UnitTests.csproj]
    $rx = [regex]::Match(
        $WarningText,
        '^\s*warning\s+(?<id>[A-Z0-9_]+)\s*:\s*(?<msg>.*?)(?:\s*\((?<url>https?://[^\)]+)\))?\s*\[(?<proj>.+?\.csproj)\]\s*$',
        [System.Text.RegularExpressions.RegexOptions]::IgnoreCase
    )

    if (-not $rx.Success) {
        # Still return something usable
        return [pscustomobject]@{
            severity = "warning"
            id       = $null
            message  = $WarningText.Trim()
            file     = $File
            line     = $Loc.line
            column   = $Loc.col
            project  = $null
            ruleUrl  = $null
            symbol   = $null
            raw      = $WarningText
        }
    }

    $msg = $rx.Groups['msg'].Value.Trim()
    $url = $rx.Groups['url'].Value.Trim()
    $proj = $rx.Groups['proj'].Value.Trim()

    # Try to extract a “symbol-ish” last token before a URL/project (best-effort)
    # Often the fully qualified member ends with ") ." so we grab the last dotted part.
    $symbol = $null
    $mSym = [regex]::Match($msg, '(?<sym>[A-Za-z_][A-Za-z0-9_]*\s*\([^)]*\)\.?)\s*$')
    if ($mSym.Success) { $symbol = ($mSym.Groups['sym'].Value.Trim().TrimEnd('.')) }

    [pscustomobject]@{
        severity = "warning"
        id       = $rx.Groups['id'].Value.Trim()
        message  = $msg
        file     = $File
        line     = $Loc.line
        column   = $Loc.col
        project  = $proj
        ruleUrl  = if ($url) { $url } else { $null }
        symbol   = $symbol
        raw      = $WarningText
    }
}

function New-WarningsHtml {
    param(
        [Parameter(Mandatory = $true)][object[]]$Warnings,
        [Parameter(Mandatory = $true)][string]$Title
    )

    $json = $Warnings | ConvertTo-Json -Depth 8

    $htmlTemplate = @'
<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width,initial-scale=1" />
  <title>__TITLE__</title>
  <style>
    body { font-family: system-ui, -apple-system, Segoe UI, Roboto, sans-serif; margin: 16px; }
    h1 { margin: 0 0 12px 0; font-size: 20px; }
    .bar { display: flex; gap: 12px; flex-wrap: wrap; align-items: end; margin: 12px 0 16px; }
    label { display: grid; gap: 6px; font-size: 12px; }
    input, select { padding: 8px; font-size: 14px; min-width: 220px; }
    table { width: 100%; border-collapse: collapse; }
    th, td { text-align: left; padding: 8px 10px; border-bottom: 1px solid #ddd; vertical-align: top; }
    th { position: sticky; top: 0; background: #fff; z-index: 1; }
    .muted { color: #666; font-size: 12px; }
    .pill { display: inline-block; padding: 2px 8px; border: 1px solid #ccc; border-radius: 999px; font-size: 12px; }
    .counts { display: flex; gap: 12px; flex-wrap: wrap; margin: 8px 0 12px; }
    .mono { font-family: ui-monospace, SFMono-Regular, Menlo, Consolas, monospace; }
    a { color: inherit; }
  </style>
</head>
<body>
  <h1>$Title</h1>
  <div class="muted" id="meta"></div>

  <div class="bar">
    <label>
      Search (id/message/file/project/symbol)
      <input id="q" placeholder="e.g. CA1707 or Gateway.UnitTests" />
    </label>

    <label>
      Group by
      <select id="groupBy">
        <option value="none">None (list all)</option>
        <option value="id">Warning ID</option>
        <option value="project">Project</option>
        <option value="file">File</option>
      </select>
    </label>

    <label>
      Warning ID
      <select id="idFilter">
        <option value="">(all)</option>
      </select>
    </label>

    <label>
      Project
      <select id="projFilter">
        <option value="">(all)</option>
      </select>
    </label>
  </div>

  <div class="counts" id="counts"></div>

  <table>
    <thead>
      <tr>
        <th style="width:130px;">ID</th>
        <th>Message</th>
        <th style="width:340px;">Location</th>
        <th style="width:260px;">Project</th>
      </tr>
    </thead>
    <tbody id="rows"></tbody>
  </table>

<script>
const warnings = __JSON__;

const el = (id) => document.getElementById(id);

function uniq(arr) { return [...new Set(arr)].filter(Boolean).sort((a,b)=>a.localeCompare(b)); }

function fillSelect(select, values) {
  const current = select.value;
  select.innerHTML = '<option value="">(all)</option>' + values.map(v => '<option>' + escapeHtml(v) + '</option>').join('');
  if ([...select.options].some(o => o.value === current)) select.value = current;
}

function escapeHtml(s) {
  return (s ?? '').toString()
    .replaceAll('&','&amp;').replaceAll('<','&lt;').replaceAll('>','&gt;')
    .replaceAll('"','&quot;').replaceAll("'","&#039;");
}

function matches(w, q) {
  if (!q) return true;
  const hay = [
    w.id, w.message, w.file, w.project, w.symbol, w.ruleUrl
  ].filter(Boolean).join(' ').toLowerCase();
  return hay.includes(q.toLowerCase());
}

function applyFilters() {
  const q = el('q').value.trim();
  const idF = el('idFilter').value;
  const pjF = el('projFilter').value;

  let filtered = warnings.filter(w =>
    matches(w, q) &&
    (!idF || w.id === idF) &&
    (!pjF || w.project === pjF)
  );

  renderCounts(filtered);
  renderRows(filtered);
}

function renderCounts(list) {
  const total = list.length;
  const byId = {};
  const byProj = {};
  for (const w of list) {
    byId[w.id || '(unknown)'] = (byId[w.id || '(unknown)'] || 0) + 1;
    byProj[w.project || '(unknown)'] = (byProj[w.project || '(unknown)'] || 0) + 1;
  }

  const topIds = Object.entries(byId).sort((a,b)=>b[1]-a[1]).slice(0,8);
  const topProjs = Object.entries(byProj).sort((a,b)=>b[1]-a[1]).slice(0,6);

  el('counts').innerHTML = `
    <span class="pill"><b>Total</b> ${total}</span>
    <span class="pill"><b>Top IDs</b> ${topIds.map(([k,v]) => escapeHtml(k)+': '+v).join(' · ')}</span>
    <span class="pill"><b>Top Projects</b> ${topProjs.map(([k,v]) => escapeHtml(k)+': '+v).join(' · ')}</span>
  `;
}

function renderRows(list) {
  const groupBy = el('groupBy').value;

  if (groupBy === 'none') {
    el('rows').innerHTML = list.map(rowHtml).join('');
    return;
  }

  const groups = new Map();
  for (const w of list) {
    const key = (w[groupBy] || '(unknown)');
    if (!groups.has(key)) groups.set(key, []);
    groups.get(key).push(w);
  }

  const sortedKeys = [...groups.keys()].sort((a,b) => {
    const da = groups.get(a).length, db = groups.get(b).length;
    if (db !== da) return db - da;
    return a.localeCompare(b);
  });

  let html = '';
  for (const key of sortedKeys) {
    const items = groups.get(key);
    html += `
      <tr>
        <td colspan="4" style="padding-top:16px;">
          <span class="pill"><b>${escapeHtml(groupBy)}</b> ${escapeHtml(key)} · <b>${items.length}</b></span>
        </td>
      </tr>
    `;
    html += items.map(rowHtml).join('');
  }
  el('rows').innerHTML = html;
}

function rowHtml(w) {
  const loc = `${escapeHtml(w.file)} (${w.line},${w.column})`;
  const msg = escapeHtml(w.message);
  const id = escapeHtml(w.id || '(unknown)');
  const proj = escapeHtml(w.project || '(unknown)');
  const url = w.ruleUrl ? `<div class="muted"><a href="${escapeHtml(w.ruleUrl)}" target="_blank" rel="noreferrer">${escapeHtml(w.ruleUrl)}</a></div>` : '';
  const sym = w.symbol ? `<div class="muted mono">${escapeHtml(w.symbol)}</div>` : '';
  return `
    <tr>
      <td class="mono">${id}</td>
      <td>
        ${msg}
        ${sym}
        ${url}
      </td>
      <td class="mono">${loc}</td>
      <td class="mono">${proj}</td>
    </tr>
  `;
}

function init() {
  el('meta').textContent = `Warnings loaded: ${warnings.length}`;

  fillSelect(el('idFilter'), uniq(warnings.map(w => w.id)));
  fillSelect(el('projFilter'), uniq(warnings.map(w => w.project)));

  el('q').addEventListener('input', applyFilters);
  el('idFilter').addEventListener('change', applyFilters);
  el('projFilter').addEventListener('change', applyFilters);
  el('groupBy').addEventListener('change', applyFilters);

  applyFilters();
}

init();
</script>
</body>
</html>
'@

    return $htmlTemplate.Replace('__TITLE__', $Title).Replace('__JSON__', $json)
}

# --- main ---
if (-not (Test-Path $SlnPath)) {
    throw "Solution not found: $SlnPath"
}

New-Item -ItemType Directory -Force -Path $OutDir | Out-Null

$msbuild = Get-MSBuildPath
$logPath = Join-Path $OutDir "build.log"
$jsonPath = Join-Path $OutDir "warnings.json"
$htmlPath = Join-Path $OutDir "warnings.html"

# Build with warning-focused console output (still prints warnings in standard format)
# /v:minimal keeps noise down but doesn't break warnings
$args = @(
  $SlnPath,
  "/t:Build",
  "/p:Configuration=$Configuration",
  "/nologo",
  "/v:minimal",
  "/clp:WarningsOnly;NoSummary",
  "/fl",
  "/flp:LogFile=$logPath;Verbosity=normal"
)

Write-Host "MSBuild: $msbuild"
Write-Host "Building: $SlnPath ($Configuration)"
Write-Host "Logging:  $logPath"

# Capture all output
& $msbuild @args | Out-Host
$lines = Get-Content -Path $logPath -Encoding UTF8

Write-Host "Raw lines containing ' warning ': $(( $lines | Where-Object { $_ -match '\bwarning\b' } ).Count)"


$warnings = Parse-MSBuildWarnings -AllLines $lines

# Write JSON
$warnings | ConvertTo-Json -Depth 8 | Set-Content -Encoding UTF8 $jsonPath

# Write HTML
$title = "Build Warnings — $(Split-Path $SlnPath -Leaf) — $Configuration"
$html = New-WarningsHtml -Warnings $warnings -Title $title
Set-Content -Encoding UTF8 $htmlPath -Value $html

Write-Host ""
Write-Host "Done ✅"
Write-Host "Warnings: $($warnings.Count)"
Write-Host "JSON:     $jsonPath"
Write-Host "HTML:     $htmlPath"

# Exit code: you can decide policy:
# - If build failed, msbuild already returned non-zero; PowerShell would have continued because we didn't check $LASTEXITCODE.
# We'll surface it here (useful for CI):
if ($LASTEXITCODE -ne 0) {
    Write-Host "MSBuild exit code: $LASTEXITCODE"
    exit $LASTEXITCODE
}
