param(
    [Parameter(Mandatory=$true)]
    [string]$TFVCPath,   # TFVC folder

    [Parameter(Mandatory=$true)]
    [string]$GitPath,   # Git folder

    # Relative path segments to ignore anywhere
    [string[]]$Exclude = @('.git', '$tf', '.vs', 'bin', 'obj'),

    # If set, text files are normalized (line endings + UTF-8) before hashing
    [switch]$NormalizeText
)

function Get-NormalizedTextHash {
    param(
        [string]$Path
    )

    try {
        # Read as text, one string
        $content = Get-Content -LiteralPath $Path -Raw

        # Normalize line endings: CRLF / CR / LF all -> LF
        $normalized = $content -replace "`r`n", "`n"
        $normalized = $normalized -replace "`r", "`n"

        # Encode as UTF-8 (no BOM)
        $bytes = [System.Text.Encoding]::UTF8.GetBytes($normalized)

        $sha = [System.Security.Cryptography.SHA256]::Create()
        $hashBytes = $sha.ComputeHash($bytes)
        # Return hex string
        return -join ($hashBytes | ForEach-Object { $_.ToString('x2') })
    }
    catch {
        Write-Warning "Failed to normalize as text, falling back to raw hash: $Path"
        return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash
    }
}

function Get-FileMap {
    param(
        [string]$Root,
        [string[]]$Exclude,
        [switch]$NormalizeText
    )

    $rootNorm = (Resolve-Path $Root).Path.TrimEnd('\')

    $files = Get-ChildItem -Path $rootNorm -Recurse -File | Where-Object {
        $full = $_.FullName
        foreach ($ex in $Exclude) {
            if ($full -like "*\${ex}\*") { return $false }
        }
        return $true
    }

    $map = @{}

    Write-Host "Hashing files under $rootNorm ..."
    $i = 0
    $total = $files.Count

    foreach ($f in $files) {
        $relative = $f.FullName.Substring($rootNorm.Length).TrimStart('\')

        if ($NormalizeText) {
            $hash = Get-NormalizedTextHash -Path $f.FullName
        }
        else {
            $hash = (Get-FileHash -LiteralPath $f.FullName -Algorithm SHA256).Hash
        }

        $map[$relative] = $hash

        $i++
        if ($i % 100 -eq 0 -or $i -eq $total) {
            Write-Host ("  {0}/{1} files hashed in {2}" -f $i, $total, $rootNorm)
        }
    }

    return $map
}

Write-Host "Comparing:"
Write-Host "  TFVCPath (TFVC): $TFVCPath"
Write-Host "  GitPath (Git) : $GitPath"
Write-Host "Excluding paths containing: $($Exclude -join ', ')"
if ($NormalizeText) {
    Write-Host "Normalizing text files"
}
Write-Host ""

$map1 = Get-FileMap -Root $TFVCPath -Exclude $Exclude -NormalizeText:$NormalizeText
$map2 = Get-FileMap -Root $GitPath -Exclude $Exclude -NormalizeText:$NormalizeText

$keys1 = $map1.Keys
$keys2 = $map2.Keys

$allKeys = ($keys1 + $keys2) | Sort-Object -Unique

$onlyIn1    = New-Object System.Collections.Generic.List[string]
$onlyIn2    = New-Object System.Collections.Generic.List[string]
$different  = New-Object System.Collections.Generic.List[string]

foreach ($rel in $allKeys) {
    $in1 = $map1.ContainsKey($rel)
    $in2 = $map2.ContainsKey($rel)

    if ($in1 -and -not $in2) {
        $onlyIn1.Add($rel) | Out-Null
    }
    elseif (-not $in1 -and $in2) {
        $onlyIn2.Add($rel) | Out-Null
    }
    elseif ($in1 -and $in2) {
        if ($map1[$rel] -ne $map2[$rel]) {
            $different.Add($rel) | Out-Null
        }
    }
}

Write-Host ""
Write-Host "===== SUMMARY ====="
Write-Host ("Files only in TFVCPath (TFVC): {0}" -f $onlyIn1.Count)
Write-Host ("Files only in GitPath (Git) : {0}" -f $onlyIn2.Count)
Write-Host ("Files with different content: {0}" -f $different.Count)
Write-Host "===================="
Write-Host ""

if ($onlyIn1.Count -eq 0 -and $onlyIn2.Count -eq 0 -and $different.Count -eq 0) {
    Write-Host "✅ Folders are symmetric (under chosen normalization)." -ForegroundColor Green
} else {
    Write-Host "⚠ Differences found." -ForegroundColor Yellow

    if ($onlyIn1.Count -gt 0) {
        Write-Host "`nFiles only in TFVCPath (TFVC):"
        $onlyIn1 | Sort-Object | ForEach-Object { "  $_" }
    }

    if ($onlyIn2.Count -gt 0) {
        Write-Host "`nFiles only in GitPath (Git):"
        $onlyIn2 | Sort-Object | ForEach-Object { "  $_" }
    }

    if ($different.Count -gt 0) {
        Write-Host "`nFiles with different content (after normalization):"
        $different | Sort-Object | ForEach-Object { "  $_" }
    }
}
