param(
    [string]$InputCsv = "Vue-App\TFSChanges.csv",
    [Nullable[datetime]]$Since = $null,
    [Nullable[datetime]]$Until = $null
)

# Helper: Parse German datetime
function Parse-GermanDate($dateStr) {
    $culture = [System.Globalization.CultureInfo]::GetCultureInfo("de-DE")
    try {
        return [datetime]::Parse($dateStr, $culture)
    } catch {
        return $null
    }
}

# Helper: extract product shortcut from TfsRootPath
function Get-ProductShortcut($root) {
    if ($root -match "/Kontinente/([^/]+)/([^/]+)/") {
        return ("$($matches[1].ToLower()).$($matches[2].ToLower())")
    } elseif ($root -match "/GP/([^/]+)/([^/]+)/") {
        return ("$($matches[1].ToLower()).$($matches[2].ToLower())")
    } else {
        return $root
    }
}

# Helper: extract area/product from TfsRootPath
function Get-AreaFromRoot($root) {
    if ($root -match "/Kontinente/([^/]+/[^/]+)/") { return $matches[1] }
    elseif ($root -match "/GP/([^/]+/[^/]+)/") { return $matches[1] }
    elseif ($root -match "/Kontinente/([^/]+)/([^/]+)/") { return "$($matches[1])/$($matches[2])" }
    elseif ($root -match "/GP/([^/]+)/([^/]+)/") { return "$($matches[1])/$($matches[2])" }
    else { return $root }
}

# Import CSV and parse dates, add ProductShortcut column
$rows = Import-Csv -Path $InputCsv | ForEach-Object {
    $obj = $_ | Select-Object *, @{Name='ProductShortcut';Expression={ $null }}
    $obj.ChangeDate = Parse-GermanDate $obj.ChangeDate
    $obj.ProductShortcut = Get-ProductShortcut $obj.RootPath
    $obj
}

# Filter by date if parameters are provided
if ($Since -ne $null) {
    $rows = $rows | Where-Object { $_.ChangeDate -ge $Since }
}
if ($Until -ne $null) {
    $rows = $rows | Where-Object { $_.ChangeDate -le $Until }
}

# --- Analysis: Developers per Area (Product) ---
# Extract product/area from TfsRootPath (e.g., FW/HB, hbu/ext, HB/HBK, etc.)
$areaDeveloperStats = $allRecords | Group-Object {
    # Try to extract the area/product from the TfsRootPath
    $root = $_.TfsRootPath
    if ($root -match "/Kontinente/([^/]+/[^/]+)/") {
        $matches[1]
    } elseif ($root -match "/GP/([^/]+/[^/]+)/") {
        $matches[1]
    } elseif ($root -match "/Kontinente/([^/]+)/([^/]+)/") {
        "$($matches[1])/$($matches[2])"
    } elseif ($root -match "/GP/([^/]+)/([^/]+)/") {
        "$($matches[1])/$($matches[2])"
    } else {
        $root
    }
} | ForEach-Object {
    [PSCustomObject]@{
        Area = $_.Name
        DeveloperCount = ($_.Group | Select-Object -ExpandProperty Author | Sort-Object -Unique).Count
        Developers = ($_.Group | Select-Object -ExpandProperty Author | Sort-Object -Unique) -join ", "
        Changes = $_.Group.Count
    }
}

# Output to console
Write-Host "\n--- Developers per Area (Product) ---"
$areaDeveloperStats | Format-Table -AutoSize

# Optionally export to CSV
$areaDeveloperStats | Export-Csv -Path "DevelopersPerArea.csv" -NoTypeInformation -Encoding UTF8
Write-Host "\n✅ Exported developer stats per area to 'DevelopersPerArea.csv'"

# --- Weighted Contribution Analysis per Area (Product) ---
# Weights: edit/add/delete=1, rename=0.1, others=1
$changeWeights = @{ 'edit' = 1; 'add' = 1; 'delete' = 1; 'rename' = 0.1 }

$weightedStats = @{}
foreach ($rec in $allRecords) {
    $area = Get-AreaFromRoot $rec.TfsRootPath
    $dev = $rec.Author
    $type = ($rec.ChangeType -replace '[^a-zA-Z]', '').ToLower()
    $weight = $changeWeights[$type]
    if (-not $weight) { $weight = 1 }
    if (-not $weightedStats.ContainsKey($area)) { $weightedStats[$area] = @{} }
    if (-not $weightedStats[$area].ContainsKey($dev)) { $weightedStats[$area][$dev] = 0 }
    $weightedStats[$area][$dev] += $weight
}

# Prepare output structure
$weightedOutput = @()
foreach ($area in $weightedStats.Keys) {
    foreach ($dev in $weightedStats[$area].Keys) {
        $weightedOutput += [PSCustomObject]@{
            Area = $area
            Developer = $dev
            ContributionScore = [math]::Round($weightedStats[$area][$dev],2)
        }
    }
}

# Output as JSON
$weightedOutput | ConvertTo-Json -Depth 3 | Set-Content -Path "DevelopersPerAreaWeighted.json" -Encoding UTF8
Write-Host "\n✅ Exported weighted developer stats per area to 'DevelopersPerAreaWeighted.json'"

# Helper to append date info to CSV
function Append-DateInfoToCsv($csvPath, $since, $until) {
    $sinceStr = if ($since) { $since.ToString('yyyy-MM-dd') } else { '' }
    $untilStr = if ($until) { $until.ToString('yyyy-MM-dd') } else { '' }
    $dateRow = "Since=$sinceStr,Until=$untilStr"
    Add-Content -Path $csvPath -Value $dateRow
}

# 1. Raw Ownership Report
function Write-RawOwnershipReport($rows) {
    $ownership = $rows | Group-Object {
        $product = Get-ProductShortcut $_.TfsRootPath
        "$product|$($_.Author)"
    } | ForEach-Object {
        $first = $_.Group[0]
        $product = Get-ProductShortcut $first.TfsRootPath
        $author = $first.Author
        $contributionCount = $_.Count
        $fileCount = ($_.Group | Select-Object -ExpandProperty FilePath | Sort-Object -Unique).Count
        [PSCustomObject]@{
            Product = $product
            Author = $author
            ContributionCount = $contributionCount
            FileCount = $fileCount
        }
    }
    $csvPath = "RawOwnershipReport.csv"
    $ownership | Export-Csv -Path $csvPath -NoTypeInformation -Encoding UTF8
    Append-DateInfoToCsv $csvPath $Since $Until
    Write-Host "\nRaw Ownership Report (top 10):"
    $ownership | Sort-Object ContributionCount -Descending | Select-Object -First 10 | Format-Table -AutoSize
}

# 2. Weighted Contribution Report
function Write-WeightedContributionReport($rows) {
    $weights = @{ edit=1.0; add=1.0; delete=0.8; merge=0.5; rename=0.3; branch=0.1 }
    $weighted = $rows | Group-Object {
        $product = Get-ProductShortcut $_.TfsRootPath
        "$product|$($_.Author)"
    } | ForEach-Object {
        $first = $_.Group[0]
        $product = Get-ProductShortcut $first.TfsRootPath
        $author = $first.Author
        $score = ($_.Group | Measure-Object -Property {
            $weights[($_.ChangeType -replace '[^a-zA-Z]', '').ToLower()] ?? 1.0
        } -Sum).Sum
        [PSCustomObject]@{
            Product = $product
            Author = $author
            WeightedScore = [math]::Round($score,2)
        }
    }
    $csvPath = "WeightedContributionReport.csv"
    $weighted | Export-Csv -Path $csvPath -NoTypeInformation -Encoding UTF8
    Append-DateInfoToCsv $csvPath $Since $Until
    Write-Host "\nWeighted Contribution Report (top 10):"
    $weighted | Sort-Object WeightedScore -Descending | Select-Object -First 10 | Format-Table -AutoSize
}

# 3. Change Density Matrix
function Write-ChangeDensityMatrix($rows) {
    $authors = $rows | Select-Object -ExpandProperty Author | Sort-Object -Unique
    $files = $rows | Select-Object -ExpandProperty FilePath | Sort-Object -Unique
    $matrix = @()
    foreach ($file in $files) {
        $row = [ordered]@{ FilePath = $file }
        foreach ($author in $authors) {
            $count = ($rows | Where-Object { $_.FilePath -eq $file -and $_.Author -eq $author }).Count
            $row[$author] = $count
        }
        $matrix += [PSCustomObject]$row
    }
    $csvPath = "ChangeDensityMatrix.csv"
    $matrix | Export-Csv -Path $csvPath -NoTypeInformation -Encoding UTF8
    Append-DateInfoToCsv $csvPath $Since $Until
    Write-Host "\nChange Density Matrix: $($files.Count) files x $($authors.Count) authors."
}

# 4. Bus Factor Check
function Write-BusFactorCheck($rows) {
    $bus = $rows | Group-Object FilePath | ForEach-Object {
        $authors = $_.Group | Select-Object -ExpandProperty Author | Sort-Object -Unique
        [PSCustomObject]@{
            FilePath = $_.Name
            AuthorCount = $authors.Count
            MainAuthor = $authors[0]
        }
    } | Where-Object { $_.AuthorCount -le 2 }
    $csvPath = "BusFactorCheck.csv"
    $bus | Export-Csv -Path $csvPath -NoTypeInformation -Encoding UTF8
    Append-DateInfoToCsv $csvPath $Since $Until
    Write-Host "\nBus Factor Check: $($bus.Count) files with <=2 authors."
}

# 5. Commit Style Insights
function Write-CommitStyleInsights($rows) {
    $byChangeset = $rows | Group-Object ChangesetId
    $byAuthor = $rows | Group-Object Author | ForEach-Object {
        $author = $_.Name
        $changesets = $_.Group | Select-Object -ExpandProperty ChangesetId | Sort-Object -Unique
        $totalChangesets = $changesets.Count
        $uniqueFiles = $_.Group | Select-Object -ExpandProperty FilePath | Sort-Object -Unique
        $avgSize = ($byChangeset | Where-Object { $_.Group[0].Author -eq $author } | Measure-Object -Property Count -Average).Average
        [PSCustomObject]@{
            Author = $author
            AverageChangesetSize = [math]::Round($avgSize,2)
            TotalChangesets = $totalChangesets
            UniqueFilesTouched = $uniqueFiles.Count
        }
    }
    $csvPath = "CommitStyleInsights.csv"
    $byAuthor | Export-Csv -Path $csvPath -NoTypeInformation -Encoding UTF8
    Append-DateInfoToCsv $csvPath $Since $Until
    Write-Host "\nCommit Style Insights (top 10):"
    $byAuthor | Sort-Object TotalChangesets -Descending | Select-Object -First 10 | Format-Table -AutoSize
}

# Run all reports
Write-RawOwnershipReport $rows
Write-WeightedContributionReport $rows
#Write-ChangeDensityMatrix $rows
Write-BusFactorCheck $rows
Write-CommitStyleInsights $rows
