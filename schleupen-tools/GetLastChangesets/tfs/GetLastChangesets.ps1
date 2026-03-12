[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$SinceDate, # Example: "2024-12-01"
    [string]$ToDate,      # Example: "2024-03-31" — defaults to today if omitted
    [string]$ProduktPfad # Example: "fw.zm", "zlm.gav", or "hb.hbk"
)

$Collection = "https://tfsprod/tfs/DefaultCollection" # Update this to your TFS Collection

# Main Execution
function Main {
    param([object]$Configuration, [string]$SinceDate, [string]$ToDate)

    $pfade = $Configuration.ProduktPfade
    if ($null -ne $ProduktPfad -and "" -ne $ProduktPfad) {
        $pfade = @($ProduktPfad)
    }
    
    $result = @{}
    
    foreach ($tfsPath in $pfade) {
        # change log to display todate if given

        $dateInfo = "since $SinceDate"
        if ($ToDate) {
            $dateInfo += " to $ToDate"
        }
        Write-Host "Checking changesets $dateInfo in $tfsPath..."
        $changesets = CheckChangesets -path $tfsPath -date $SinceDate -toDate $ToDate
    
        if ($changesets -and $changesets.Count -gt 0) {
            Write-Host "Changesets found between $($SinceDate) and $($ToDate): $($changesets.Count)"
            $result += @{ "$($tfsPath)" = $changesets }
        }
        else {
            Write-Host "No changesets found between $($SinceDate) and $($ToDate)."
            $result += @{ "$($tfsPath)" = "No changesets found between $($SinceDate) and $($ToDate)." }
        }
    }

    return $result
}

function Invoke-TfCommand {
    param(
        [string]$TfPath,
        [string[]]$Arguments
    )

    $escapedArgs = foreach ($a in $Arguments) {
        if ($null -eq $a) { "" }
        elseif ($a -match '[\s"]') { '"' + ($a -replace '"', '\"') + '"' }
        else { $a }
    }

    # Use ANSI code page (German Windows typically 1252)
    $ansiCp = [System.Globalization.CultureInfo]::CurrentCulture.TextInfo.ANSICodePage
    $enc    = [System.Text.Encoding]::GetEncoding($ansiCp)

    $psi = [System.Diagnostics.ProcessStartInfo]::new()
    $psi.FileName               = $TfPath
    $psi.Arguments              = ($escapedArgs -join ' ')
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError  = $true
    $psi.UseShellExecute        = $false
    $psi.StandardOutputEncoding = $enc
    $psi.StandardErrorEncoding  = $enc

    $p = [System.Diagnostics.Process]::new()
    $p.StartInfo = $psi
    Write-Host "Executing: $($psi.FileName) $($psi.Arguments)" -ForegroundColor Gray
    [void]$p.Start()

    $stdout = $p.StandardOutput.ReadToEnd()
    $stderr = $p.StandardError.ReadToEnd()
    $p.WaitForExit()

    if ($stderr) { Write-Host $stderr -ForegroundColor Yellow }

    if ($p.ExitCode -ne 0) {
        throw "tf.exe failed (exit $($p.ExitCode)): $stderr"
    }

    return $stdout
}

function CheckChangesets {
    param([string]$path, [string]$date, [string]$toDate)

    try {
        $tfPath = $Configuration.TfExePath
        # "D<from>~D<to>" for a bounded range, "D<from>~T" to query up to today
        $versionSpec = if ($toDate) { "D$($date)~D$($toDate)" } else { "D$($date)~T" }
        $historyOutput = Invoke-TfCommand -TfPath $tfPath -Arguments @(
            'history', "$($path)",
            "/collection:$Collection",
            '/recursive',
            "/version:$versionSpec",
            '/format:brief',
            '/noprompt'
        )

        $changesetIds = ParseChangesetIds -HistoryOutput $historyOutput
        $changesetDetails = Get-ChangesetDetails -ChangesetIds $changesetIds

        return , $changesetDetails
    }
    catch {
        Write-Host "Error: $_" -ForegroundColor Red
        return $null
    }
}

function ParseChangesetIds {
    param(
        [string[]]$HistoryOutput
    )

    $changesetIds = @()

    $lines = $HistoryOutput -split "`n"
    foreach ($line in $lines) {
        $line = $line.Trim()
        if ($line -match "^\s*$" -or $line -match "^-+" -or $line -match "Changeset") {
            LogToConsole -Message "Skipping line: $line"
            continue
        }

        $parts = $line -split " "
        $changesetId = $parts[0].Trim()
        if ([int]::TryParse($changesetId, [ref]$null)) {
            $changesetIds += [int]$changesetId
        }
        else {
            Write-Warning "No ChangesetId found in line: $line"
        }
    }

    return , $changesetIds
}

function Get-ChangesetDetails {
    param(
        [int[]]$ChangesetIds
    )

    $result = @()

    $tfPath = $Configuration.TfExePath

    foreach ($changesetId in $ChangesetIds) {
        $details = Invoke-TfCommand -TfPath $tfPath -Arguments @(
            'changeset', "$changesetId",
            "/collection:$Collection",
            '/noprompt'
        )
        $user = $null
        $comment = ""
        $datetime = $null
        $branches = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
        $isCommentLine = $false
        $isItemsLine = $false

        $keywords = GetKeywordsForParsing
        $branchPattern = '(\$/CS3.*?)/Quellen/.*'

        # Write-Host $details
        $lines = $details -split "`n"
        foreach ($line in $lines) {
            $line = $line.Trim()

            if ($line -match "^$($keywords.Date):\s*(.+)") {
                $dateMatch = $matches[1] | Out-String
                $culture = [System.Globalization.CultureInfo]::CreateSpecificCulture("de-DE")
                $datetime = [datetime]::Parse($dateMatch, $culture)
            }
            elseif ($line -match "^$($keywords.User):\s*(.+)$") {
                $userMatch = $matches[1] | Out-String
                $user = $userMatch.Trim()
            }
            elseif ($line -match "^$($keywords.Comment):") {
                $isCommentLine = $true
                continue
            }
            elseif ($line -match "^$($keywords.Items):") {
                $isItemsLine = $true
                continue
            }
            elseif ($isCommentLine -and $line.Trim() -ne "") {
                $comment += $line.Trim() + " "
                $isCommentLine = $false
            }
            elseif ($isItemsLine -and $line.Trim() -ne "") {

                if ($line -match $branchPattern) {  
                    $branch = $matches[1]
                    $branches.Add($branch) | Out-Null
                }
            }
            elseif ($isItemsLine -and $line.Trim() -eq "") {
                $isItemsLine = $false
            }
        }

        if ($null -eq $user) {
            Write-Warning "Could not parse User. Are you using the right locale?"
            continue
        }

        if ($null -eq $datetime) {
            Write-Warning "Could not parse datetime. Are you using the right locale?"
            continue
        }

        if ($null -eq $comment) {
            Write-Warning "Could not parse comment. Are you using the right locale?"
            continue
        }

        if ($null -eq $branches -or $branches.Count -eq 0) {
            Write-Warning "Could not parse branches because Path does not match $branchPattern"

            # Changeset https://tfsprod/tfs/DefaultCollection/CS3/_versionControl/changeset/1304861/ hatte keine Quellen im Pfad
            # continue
        }

        $result += [PSCustomObject]@{
            ChangesetId = $changesetId
            User        = $user
            Comment     = $comment.Trim()
            Date        = $datetime
            Branches    = @($branches)
        }
    }

    return , $result
}

function ReadEffectiveConfiguration {
    param(
        [object]$configFilePath
    )
    $config = @{
        Locale       = "de"
        ProduktPfade = @()
        OutputFormat = "JSON" # JSON or CSV
        TfExePath    = "tf"   #assuming it's added to the PATH
    }
    
    # Load configuration from JSON if the file exists
    if (Test-Path -Path $configFilePath) {
        try {
            $JsonContent = Get-Content -Path $configFilePath -Raw
            $LoadedConfiguration = $JsonContent | ConvertFrom-Json

            # Merge the loaded configuration into the default configuration
            foreach ($key in $LoadedConfiguration.PSObject.Properties.Name) {
                $config[$key] = $LoadedConfiguration.$key
            }

            if ($config.TfExePath -ne "tf" -and -not (Test-Path $config.TfExePath)) {
                throw "The configured tf.exe path '$($config.TfExePath)' does not exist. Please update the config.json file."
            }

            Write-Host "Configuration loaded from $configFilePath."
        }
        catch {
            Write-Host "Error loading configuration from $configFilePath. Using default configuration." -ForegroundColor Yellow
        }
    }
    else {
        Write-Host "Configuration file not found. Using default configuration."
        return $config
    }

    # Final configuration
    $configJson = $config | ConvertTo-Json -Depth 10
    Write-Host $configJson
    return $config
}

function GetKeywordsForParsing {
    $keywords = switch ($Configuration.locale) {
        "de" {
            @{
                Date    = "Datum"
                User    = "Benutzer"
                Comment = "Kommentar" 
                Items   = "Elemente" 
            }
        }
        "en" { 
            @{
                Date    = "Date"
                User    = "User"
                Comment = "Comment" 
                Items   = "Items" 
            } 
        }
        Default {
            throw "Invalid locale: $locale"
        }
    }

    return $keywords
}

function LogToConsole {
    param(
        [string]$Message
    )

    if ($null -ne $Configuration.Logging -and $Configuration.Logging.Enabled -eq $true) {
        Write-Host $Message
    }
}

function CreateOutput {
    param (
        [object]$Result,
        [string]$OutputDir
    )

    if ($null -ne $Configuration.OutputFormat -and $Configuration.OutputFormat.ToUpper() -eq "JSON") {
        CreateJsonOutput -Result $result -OutputDir $OutputDir
    }
    elseif ($null -ne $Configuration.OutputFormat -and $Configuration.OutputFormat.ToUpper() -eq "CSV") {
        CreateCsvOutput -Result $result -OutputDir $OutputDir
    }
    else {
        Write-Host "No OutputFormat was configured."
        Write-Host "Done"
    }
}

function CreateJsonOutput {
    param(
        [object]$Result,
        [string]$OutputDir
    )

    $dateFormat = "yyyy-MM-dd HH:mm:ss"
    $currentDate = (Get-Date).ToString($dateFormat)

    $output = [PSCustomObject]@{
        Ausfuehrungszeitpunkt = $currentDate
        AenderungenSeit       = $SinceDate
        Aenderungen           = @{}
    }
    
    
    foreach ($produkt in $Result.Keys) {
        if ($Result.$produkt -is [Array]) {
            $changesets = $Result.$produkt | Sort-Object | ForEach-Object {
                [PSCustomObject]@{
                    ChangesetId = $_.ChangesetId
                    User        = $_.User
                    Comment     = $_.Comment
                    Date        = $_.Date.ToString($dateFormat)
                    Branches    = $_.Branches
                }
            }    
            $output.Aenderungen += @{$produkt = $changesets }
        }
    }


    $filename = "LastChangesets.json"
    $jsonFilePath = Join-Path -Path $OutputDir -ChildPath $filename
    Write-Host "Creating JSON output $jsonFilePath"
    $json = $output | ConvertTo-Json -Depth 10
    $json | Out-File -FilePath $jsonFilePath -Encoding utf8
    Write-Host "Results saved to $jsonFilePath"
}

function CreateCsvOutput {
    param(
        [object]$Result,
        [string]$OutputDir
    )

    # Produkt	ChangesetId	User	Comment	Date	FeatureBranch1	FeatureBranch2	FeatureBranch3
    $flattenedObjects = @();

    foreach ($produkt in $Result.Keys | Sort-Object) {
        $changes = $Result.$produkt

        foreach ($change in $changes) {
            if ($null -ne $change.ChangesetId) {
                $flattenedObjects += [PSCustomObject]@{
                    Date           = $change.Date
                    Produkt        = $produkt
                    ChangesetId    = $change.ChangesetId
                    User           = $change.User
                    Comment        = $change.Comment
                    FeatureBranch1 = If ($change.Branches.Length -gt 0) { $change.Branches[0] } Else { "" }
                    FeatureBranch2 = If ($change.Branches.Length -gt 1) { $change.Branches[1] } Else { "" }
                    FeatureBranch3 = If ($change.Branches.Length -gt 2) { $change.Branches[2] } Else { "" }
                }
            }
        }
    }    

    $filename = "LastChangesets.csv"
    $jsonFilePath = Join-Path -Path $OutputDir -ChildPath $filename
    Write-Host "Creating CSV output $jsonFilePath"
    $flattenedObjects | Export-Csv -Path $jsonFilePath -NoTypeInformation
}

# Get the directory of the script
$ScriptDirectory = Split-Path -Parent $MyInvocation.MyCommand.Path
# Path to the configuration file
$ConfigFilePath = Join-Path -Path $scriptDirectory -ChildPath "config.json"

$Configuration = ReadEffectiveConfiguration -configFilePath $ConfigFilePath

$effectiveToDate = if ($null -ne $ToDate -and $ToDate.Trim() -ne "") { $ToDate } else { (Get-Date).ToString("yyyy-MM-dd") }

# validate SinceDate and effectiveToDate are valid datetimes and todate is after sincedate
try {
    [datetime]$sinceDateParsed = $SinceDate
    [datetime]$effectiveToDateParsed = $effectiveToDate
    if ($sinceDateParsed -gt $effectiveToDateParsed) {
        throw "SinceDate must be before ToDate. SinceDate: $SinceDate, ToDate: $effectiveToDate"
    }
}
catch {
    Write-Error "Invalid date format: $_"
    exit 1
}



$result = Main -Configuration $Configuration -SinceDate $SinceDate -ToDate $effectiveToDate

# Write-Host $result

# CreateJsonOutput -Result $result -OutputDir $ScriptDirectory

CreateOutput -Result $result -OutputDir $ScriptDirectory