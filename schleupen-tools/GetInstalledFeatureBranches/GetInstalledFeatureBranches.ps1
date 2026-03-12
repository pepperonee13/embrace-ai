param (
    [string]$Username,
    [string[]]$Servers,
    [switch] $Repeat = $false
)

# Determine the directory of this script in a robust way so dot-sourcing won't break
if ($PSCommandPath) {
    $ScriptDirectory = Split-Path -Parent $PSCommandPath
}
elseif ($PSScriptRoot) {
    $ScriptDirectory = $PSScriptRoot
}
elseif ($MyInvocation.MyCommand.Definition) {
    $ScriptDirectory = Split-Path -Parent $MyInvocation.MyCommand.Definition
}
elseif ($MyInvocation.MyCommand.Path) {
    $ScriptDirectory = Split-Path -Parent $MyInvocation.MyCommand.Path
}
else {
    $ScriptDirectory = (Get-Location).ProviderPath
}

# Path to the configuration file
$ConfigFilePath = Join-Path -Path $ScriptDirectory -ChildPath "config.json"

$Collection = "https://tfsprod/tfs/DefaultCollection" # Update this to your TFS Collection
$BaseUri = "$Collection/_apis"
$PipelineJsonFilePath = "install\pipeline.json"

$workItemsCache = @{}
    
$logLevelConfig = @{
    Debug       = 0
    Information = 1
    Warning     = 2
    Error       = 3
}

function ReadEffectiveConfiguration {
    param(
        [object]$configFilePath
    )
    $config = @{
        Username                = $Username
        Servers                 = $Servers
        Domain                  = "SCHLEUPEN-AG"
        OutputFormat            = "JSON"
        OutputDir               = $ScriptDirectory
        AdditionalFields        = @()
        IncludeBaselineProdukte = $false
        Logging                 = @{
            MinimumLogLevel = "Information"
        }
        Repeat                  = $Repeat
        RepeatTimeInMinutes     = 30
    }
    
    # Load configuration from JSON if the file exists
    if (Test-Path -Path $configFilePath) {
        try {
            $JsonContent = Get-Content -Path $configFilePath -Raw
            $LoadedConfiguration = $JsonContent | ConvertFrom-Json

            # Merge the loaded configuration into the default configuration
            foreach ($key in $LoadedConfiguration.PSObject.Properties.Name) {
                if ($key -eq "AdditionalFields") {
                    foreach ($fieldKey in $LoadedConfiguration.$key) {
                        $config.AdditionalFields += $fieldKey
                    }
                }
                elseif ($key -eq "Logging") {
                    foreach ($loggingKey in $LoadedConfiguration.Logging.PSObject.Properties.Name) {
                        if ($loggingKey -eq "MinimumLogLevel") {
                            if ($logLevelConfig.ContainsKey($LoadedConfiguration.Logging.$loggingKey) -eq $false) {
                                throw "Unsupported MinimumLogLevel '$($LoadedConfiguration.Logging.$loggingKey)'. Supported Values are [Debug|Information|Warning|Error]"
                            }
                        }
                        $config.Logging.$loggingKey = $LoadedConfiguration.Logging.$loggingKey
                    }
                }
                else {
                    $config[$key] = $LoadedConfiguration.$key
                }
            }

            Write-Host "Configuration loaded from $configFilePath."
        }
        catch {
            Write-Error "Error loading configuration from $configFilePath. Using default configuration. $_"
            throw $_
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

# Function: Get Work Item Details
function Get-WorkItem {
    param([int]$id)

    if ($workItemsCache.ContainsKey($id)) {
        return $workItemsCache[$id]
    }

    $url = "$BaseUri/wit/workitems/$($id)"
    Log "Fetching work item details from: $url"

    try {
        $response = Invoke-RestMethod -Uri $url -Method Get -UseDefaultCredentials
        $workItemsCache[$id] = $response
        return $response
    }
    catch {
        Log "Failed to fetch work item details. Error: $_" -ForegroundColor Red
        return $null
    }
}

function Read-PipelineJson {
    param([securestring]$Password)

    # Only build a credential object when both username and password are supplied.
    # If neither is provided the PSDrive will use the current Windows identity.
    $credential = $null
    if (-not [string]::IsNullOrEmpty($Configuration.Username) -and $null -ne $Password) {
        $usernameWithDomain = "$($Configuration.Domain)\$($Configuration.Username)"
        $credential = New-Object System.Management.Automation.PSCredential ($usernameWithDomain, $Password)
    }
    
    if ($null -ne $credential) {
        Write-Host "Connecting as: $usernameWithDomain"
    } else {
        Write-Host "Connecting as: $([System.Security.Principal.WindowsIdentity]::GetCurrent().Name) (current Windows identity)"
    }

    # Result hashtable to store server data
    $pipelineJsonPerServer = @{}

    foreach ($server in $Configuration.Servers) {
        try {
            Log "Connecting to $server..."

            # Build the UNC path for the server's C$ drive
            $rootPath = "\\$server\c$"

            # Create a temporary drive mapped to the remote server.
            # Only pass -Credential when explicit credentials were supplied.
            $psDriveParams = @{
                Name        = "RemoteAccess"
                PSProvider  = "FileSystem"
                Root        = $rootPath
                ErrorAction = "Stop"
            }
            if ($null -ne $credential) {
                $psDriveParams.Credential = $credential
            }
            $session = New-PSDrive @psDriveParams

            # Construct the full path to the JSON file
            $fileFullPath = Join-Path -Path $session.Root -ChildPath $PipelineJsonFilePath

            # Check if the file exists
            if (Test-Path -Path $fileFullPath) {
                Log "Reading pipeline.json from $server..."
                # Read the JSON file and convert to a PowerShell object
                $jsonContent = Get-Content -Path $fileFullPath -Raw | ConvertFrom-Json

                $pipelineJsonPerServer[$server] = $jsonContent.components
            }        
            else {
                Write-Error "Error on $server. $PipelineJsonFilePath wurde nicht gefunden"
            }
        }
        catch {
            Log "Error on ($server): $_"
            # Capture errors
            $pipelineJsonPerServer[$server] = "Error: $_"
        }
        finally {
            Log "Disconnecting from $server..."
            # Remove the session after use
            Remove-PSDrive -Name "RemoteAccess" -ErrorAction SilentlyContinue
            Log "-----------------------------------------"
        }
    }


    return $pipelineJsonPerServer
}

function Get-WorkItemInfo {
    param(
        [string]$Qualitaet
    )

    # Extract the relevant portion using regex
    $regex = "^Features/(?<TeamName>[^/]+)/(?<WorkItemId>\d+).*/CI"

    if ($Qualitaet -match $regex) {
        $workItemId = $matches['WorkItemId']
        if ($null -ne $WorkItemId) {
            $workItem = Get-WorkItem -id $workItemId
            $assignedTo = $workItem.fields."System.AssignedTo".displayName
            
            $info = @{
                Zugewiesen = $assignedTo
                TfsLink    = "$Collection/_workitems/edit/$workItemId"
            }

            if ($null -ne $Configuration.AdditionalFields) {
                foreach ($field in $Configuration.AdditionalFields) {
                    $info += @{$field = $workItem.fields.$field }
                }
            }

            $sortedObject = [PSCustomObject]@{}
            ($info.Keys | Sort-Object).ForEach({
                    $sortedObject | Add-Member -NotePropertyName $_ -NotePropertyValue $info[$_]
                })
            
            return $sortedObject
        }
    }   

    Write-Warning "WorkItem Info could not be loaded for $Qualitaet"

    return $null
}

function CreateFeatureBranchInfos {
    param(
        [object]$Components
    )

    # Extract components and filter feature branches
    $branchInfos = @{}

    foreach ($property in $Components.PSObject.Properties) {
        $qualitaet = $property.Value
        $produkt = $property.Name

        $branchInfo = [PSCustomObject]@{                
            Qualitaet = $qualitaet
        }

        if ($qualitaet -match "^Features.*") {
            $workItemInfo = Get-WorkItemInfo -Qualitaet $qualitaet
            if ($null -ne $workItemInfo) {
                foreach ($property in $workItemInfo.PSObject.Properties) {
                    $branchInfo | Add-Member -NotePropertyName $property.Name -NotePropertyValue $property.Value
                }
            }   
        }
        elseif ($Configuration.IncludeBaselineProdukte -eq $false) {
            # ignoriere baseline Produkt
            continue
        }

        $branchInfos[$produkt] = $branchInfo
    }

    return $branchInfos
}

function CreateOutput {
    param(
        [object]$Result,
        [string]$OutputDir
    )
    
    if ($null -ne $Configuration.OutputFormat -and $Configuration.OutputFormat.ToUpper() -eq "JSON") {

        $currentDate = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")

        $output = [PSCustomObject]@{
            Ausfuehrungszeitpunkt = $currentDate
            Servers               = @()
        }
    
        foreach ($server in $Result.Keys | Sort-Object) {
            $output.Servers += [PSCustomObject]@{
                ServerName = $server
                Produkte   = $Result.$server
            }
        }

        $filename = "InstalledFeatureBranches.json"
        $jsonFilePath = Join-Path -Path $OutputDir -ChildPath $filename
    
        # Output the results
        Log "Creating result..."
        $json = $output | ConvertTo-Json -Depth 10
        Log "Creating JSON output $jsonFilePath"
        $json = $output | ConvertTo-Json -Depth 10
        $json | Out-File -FilePath $jsonFilePath -Encoding utf8
        Log "Results saved to $jsonFilePath"
    }
    elseif ($null -ne $Configuration.OutputFormat -and $Configuration.OutputFormat.ToUpper() -eq "CSV") {
        CreateCsvOutput -Result $Result -OutputDir $OutputDir
    }
    elseif ($null -ne $Configuration.OutputFormat -and $Configuration.OutputFormat.ToUpper() -eq "XLSX") {
        CreateExcelOutput -Result $Result -OutputDir $OutputDir
    }
    else {
        Log "No OutputFormat was configured."
        Log "Done"
    }

}

function CreateCsvOutput {
    param(
        [object]$Result,
        [string]$OutputDir
    )
    
    # Produkt	ServerName  Qualitaet	Zugewiesen	TfsLink [WorkItemDetails]
    $flattenedObjects = @();

    foreach ($server in $Result.Keys | Sort-Object) {
        $produkte = $Result.$server
        foreach ($produkt in $produkte.Keys | Sort-Object) {
            $branch = $produkte.$produkt
            $entry = [PSCustomObject]@{
                Server     = $server
                Produkt    = $produkt
                Qualitaet  = $branch.Qualitaet
                Zugewiesen = if ($null -ne $branch.Zugewiesen) { $branch.Zugewiesen } else { "" }
                TfsLink    = if ($null -ne $branch.TfsLink) { $branch.TfsLink } else { "" }
            }

            foreach ($field in $Configuration.AdditionalFields) {
                $propertyValue = if ($null -ne $branch.$field) { $branch.$field } else { "" }
                $entry | Add-Member -NotePropertyName $field -NotePropertyValue $propertyValue
            }

            $flattenedObjects += $entry                    
        }
    }    

    $filename = "InstalledFeatureBranches.csv"
    $jsonFilePath = Join-Path -Path $OutputDir -ChildPath $filename
    Log "Creating CSV output $jsonFilePath"
    $flattenedObjects | Export-Csv -Path $jsonFilePath -NoTypeInformation

    $currentDate = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    $creationDateLine = '"Erzeugungsdatum","{0}"' -f $currentDate
    $creationDateLine | Add-Content -Path $jsonFilePath
}

function CreateExcelOutput {
    param(
        [object]$Result,
        [string]$OutputDir
    )

    $flattenedObjects = FlattenResult -Result $Result

    $filename = "InstalledFeatureBranches.xlsx"
    $tmpPath = Join-Path -Path $ScriptDirectory -ChildPath $filename
    $outputPath = Join-Path -Path $OutputDir -ChildPath $filename

    if (Test-Path $tmpPath -PathType Leaf) {
        Set-ItemProperty -Path $tmpPath -Name IsReadOnly -Value $false
    }

    Write-Host "Creating XLSX output $outputPath"

    $Excel = $null
    try {
        $Excel = New-Object -ComObject Excel.Application
        $Excel.Visible = $false
        $Excel.DisplayAlerts = $false
        $workbook = $excel.Workbooks.Add(1)
        $worksheet = $workbook.worksheets.Item(1)
        $worksheet.name = "Installierte Feature Branches"

        if ($flattenedObjects.Length -gt 0) {
            # Header
            $Header = $flattenedObjects[0].PSObject.Properties.Name
            for ($i = 0; $i -lt $Header.Length; $i++) {
                $worksheet.Cells.Item(1, ($i + 1)) = $Header[$i]
            }

            # Content
            for ($i = 0; $i -lt $flattenedObjects.Length; $i++) {
                $rowContent = $flattenedObjects[$i]
                $j = 0
                $rowContent.PSObject.Properties | ForEach-Object {
                    $j = $j + 1
                    $worksheet.Cells.Item(($i + 2), ($j)) = $_.Value
                }
            }

            $Range = "$(GetExcelCellAddress -RowNumber 1 -ColumnNumber 1):$(GetExcelCellAddress -RowNumber ($flattenedObjects.Length + 1) -ColumnNumber $Header.Length)"
            $worksheet.ListObjects.Add(
                1,  #op.Excel.XlListObjectSourceType]::xlSrcRange,
                $worksheet.Range($Range),
                "Installierte Feature Branches",
                2   #[Microsoft.Office.Interop.Excel.XlYesNoGuess]::xlYes
            ) > $null

            $worksheet.Range($Range).EntireColumn.Autofit() > $null

            $currentDate = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
            $creationDateLine = 'Erzeugungsdatum: {0}' -f $currentDate
            $worksheet.Cells.Item(($flattenedObjects.Length + 4), 1) = $creationDateLine
        }

        $worksheet.SaveAs($tmpPath, 51, $null, $null, $null, $null, $null, $null, $null, 'True')
    }
    finally {
        if ($null -ne $Excel) {
            $Excel.Quit()
            while ( [System.Runtime.Interopservices.Marshal]::ReleaseComObject($Excel) ) {} 
        }
    }

    Set-ItemProperty -Path $tmpPath -Name IsReadOnly -Value $true

    if ((Split-Path -Parent $tmpPath) -ne (Split-Path -Parent $outputPath)) {
        Copy-Item $tmpPath -Destination $outputPath -Force
    }

    Write-Host "Creating XLSX output $outputPath complete."
}

function FlattenResult {
    param(
        [object]$Result
    )

    # Produkt	ServerName  Qualitaet	Zugewiesen	TfsLink [WorkItemDetails]
    $flattenedObjects = @();

    foreach ($server in $Result.Keys | Sort-Object) {
        $produkte = $Result.$server
        foreach ($produkt in $produkte.Keys | Sort-Object) {
            $branch = $produkte.$produkt
            $entry = [PSCustomObject]@{
                Server     = $server
                Produkt    = $produkt
                Qualitaet  = $branch.Qualitaet
                Zugewiesen = if ($null -ne $branch.Zugewiesen) { $branch.Zugewiesen } else { "" }
                TfsLink    = if ($null -ne $branch.TfsLink) { $branch.TfsLink } else { "" }
            }

            foreach ($field in $Configuration.AdditionalFields) {
                $propertyValue = if ($null -ne $branch.$field) { $branch.$field } else { "" }
                $entry | Add-Member -NotePropertyName $field -NotePropertyValue $propertyValue
            }

            $flattenedObjects += $entry                    
        }
    }

    return $flattenedObjects
}


function GetExcelCellAddress {
    param(
        [int]$RowNumber, # 1 = Oberste Zeie
        [int]$ColumnNumber # 1 = Erste Spalte von Links
    )

    if ($RowNumber -lt 1) {
        throw Exception "RowNumber in Excel muss groesser als 0 sein, war aber $RowNumber"
    }
    if ($ColumnNumber -lt 1) {
        throw Exception "ColumnNumber in Excel muss groesser als 0 sein, war aber $ColumnNumber"
    }
    if ($ColumnNumber -gt 20) {
        throw Exception "Dieser einfache Code unterstuetzt nur die Umwandlung in einfache Spalten-Buchstaben und ist der Einfachheit halber auf 20 begrenzt. Wird wohl Zeit den Code zu verbessern. Denn ColumnNumber war $ColumnNumber"
    }

    return "$([char](64 + $ColumnNumber))$RowNumber"
}

function IsLoggable($logLevel) {
    if ($logLevel -eq "Error") {
        return $true
    }

    $logLevelRank = $logLevelConfig.$logLevel
    $configuredMinimumLogLevel = $Configuration.Logging.MinimumLogLevel
    $minimumLogLevelRank = $logLevelConfig.$configuredMinimumLogLevel

    if ($null -eq $minimumLogLevelRank) {
        return $false
    }
    return $logLevelRank -ge $minimumLogLevelRank
}

function Log($message, $logLevel = "Information") {
    $currentDate = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    $formattedMessage = "$($currentDate): [$($logLevel)] $message"

    if (IsLoggable $logLevel) {
        switch ($logLevel) {
            "Debug" { Write-Host $formattedMessage }
            "Information" { Write-Host $formattedMessage }
            "Warning" { Write-Host $formattedMessage -ForegroundColor Yellow }
            "Error" { Write-Host $formattedMessage -ForegroundColor Red }
        }       
    }
}

function Log-Debug($message) { Log $message "Debug" }
function Log-Info($message) { Log $message "Information" }
function Log-Warning($message) { Log $message "Warning" }
function Log-Error($message) { Log $message "Error" }

function LoadInstalledFeatures {
    param (
        $Configuration,
        $pipelineJsonPerServer
    )
    $InstalledFeatures = @{}
    foreach ($server in $Configuration.Servers) {
        try {
            # Output the key and value
            Write-host "Looking for feature branches on $server..."
    
            $components = $pipelineJsonPerServer[$server]
            if ($component -is [string] -and $components -like "Error*" -eq $true) {
                Write-Host $components
                continue
            }
    
            $branchInfos = CreateFeatureBranchInfos -Components $components
            $InstalledFeatures[$server] = $branchInfos
        }
        catch {
            Write-Host "Error on ($server): $_"
        }
        finally {
            Write-Host "Done"
            Write-Host "-----------------------------------------"
        }
    }
    return $InstalledFeatures
}

function GetAvailableServerFor {
    param(
        [string[]]$Products,
        [string]$Username
    )

    # Ensure InstalledFeatures is loaded
    if (-not $InstalledFeatures) {
        Write-Host "InstalledFeatures data is not loaded. Running the script to load data..."

        
        # Use the precomputed ScriptDirectory and ConfigFilePath
        $Configuration = ReadEffectiveConfiguration -configFilePath $ConfigFilePath

        # Explicit -Username param takes priority over config.json
        if (-not [string]::IsNullOrEmpty($Username)) {
            $Configuration.Username = $Username
        }

        # Only prompt for a password when a username is known;
        # otherwise New-PSDrive will use the current Windows identity.
        $Password = $null
        if (-not [string]::IsNullOrEmpty($Configuration.Username)) {
            $Password = Read-Host "Enter Password for $($Configuration.Domain)\$($Configuration.Username)" -AsSecureString
        }

        # Load InstalledFeatures
        $pipelineJsonPerServer = Read-PipelineJson -Password $Password
        $InstalledFeatures = LoadInstalledFeatures -Configuration $Configuration -pipelineJsonPerServer $pipelineJsonPerServer
    }

    $availableServers = @()

    foreach ($server in $InstalledFeatures.Keys) {
        $produkte = $InstalledFeatures[$server]
        $hasAnyProduct = $false

        foreach ($product in $Products) {
            if ($produkte.ContainsKey($product)) {
                $hasAnyProduct = $true
                break
            }
        }

        if (-not $hasAnyProduct) {
            $availableServers += $server
        }
    }

    if ($availableServers.Count -eq 0) {
        Write-Host "No servers found where the specified products are not installed."
    }

    return $availableServers
}

function GetInstalledProductsOnServer {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Server,
        [string]$Username
    )

    # Ensure InstalledFeatures is loaded
    if (-not $InstalledFeatures) {
        Write-Host "InstalledFeatures data is not loaded. Running the script to load data..."

        $Configuration = ReadEffectiveConfiguration -configFilePath $ConfigFilePath

        # Explicit -Username param takes priority over config.json
        if (-not [string]::IsNullOrEmpty($Username)) {
            $Configuration.Username = $Username
        }

        # Only prompt for a password when a username is known;
        # otherwise New-PSDrive will use the current Windows identity.
        $Password = $null
        if (-not [string]::IsNullOrEmpty($Configuration.Username)) {
            $Password = Read-Host "Enter Password for $($Configuration.Domain)\$($Configuration.Username)" -AsSecureString
        }

        $pipelineJsonPerServer = Read-PipelineJson -Password $Password
        $InstalledFeatures = LoadInstalledFeatures -Configuration $Configuration -pipelineJsonPerServer $pipelineJsonPerServer
    }

    if (-not $InstalledFeatures.ContainsKey($Server)) {
        Write-Host "Server '$Server' wurde nicht in den geladenen Daten gefunden."
        return @()
    }

    return $InstalledFeatures[$Server].Keys | Sort-Object
}

# Script is safe to dot-source; it only defines functions and variables by default

# Move the main execution logic into a function
function Execute-GetInstalledFeatureBranches {
    param (
        [string]$Username,
        [string[]]$Servers,
        [switch]$Repeat = $false
    )

    $Configuration = ReadEffectiveConfiguration -configFilePath $ConfigFilePath

    # Explicit -Username param takes priority over config.json
    if (-not [string]::IsNullOrEmpty($Username)) {
        $Configuration.Username = $Username
    }

    # Only prompt for a password when a username is known;
    # otherwise New-PSDrive will use the current Windows identity.
    $Password = $null
    if (-not [string]::IsNullOrEmpty($Configuration.Username)) {
        $Password = Read-Host "Enter Password for $($Configuration.Domain)\$($Configuration.Username)" -AsSecureString
    }

    # Result hashtable to store server data
    $pipelineJsonPerServer = Read-PipelineJson -Password $Password
    $InstalledFeatures = LoadInstalledFeatures -Configuration $Configuration -pipelineJsonPerServer $pipelineJsonPerServer
    CreateOutput -Result $InstalledFeatures -OutputDir $Configuration.OutputDir

    if (($Configuration.Repeat)) {
        Write-Host "$((Get-Date).ToString("yyyy-MM-dd HH:mm:ss")): Installierte Features wurden geladen und ausgegeben. Warte $($Configuration.RepeatTimeInMinutes) Minuten um installierte Features erneut zu laden und auszugeben."
        Start-Sleep -Seconds ($Configuration.RepeatTimeInMinutes * 60)
    }
}

if ($MyInvocation.InvocationName -ne '.') {
    Execute-GetInstalledFeatureBranches -Username $Username -Servers $Servers -Repeat:$Repeat
}
