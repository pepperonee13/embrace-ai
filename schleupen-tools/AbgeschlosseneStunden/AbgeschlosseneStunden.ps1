$Collection = "https://tfsprod/tfs/DefaultCollection" # Update this to your TFS Collection
$BaseUri = "$Collection/_apis"
$workItemsCache = @{}

# Function: Get Work Item Details
function Get-WorkItem {
    param([int]$id)

    if ($workItemsCache.ContainsKey($id)) {
        return $workItemsCache[$id]
    }

    $url = "$BaseUri/wit/workitems/$($id)"
    Write-Host "Fetching work item details from: $url"

    try {
        Start-Sleep -Seconds 1
        $response = Invoke-RestMethod -Uri $url -Method Get -UseDefaultCredentials
        $workItemsCache[$id] = $response
        return $response
    }
    catch {
        Write-Host "Failed to fetch work item details. Error: $_" -ForegroundColor Red
        return $null
    }
}

$tempoExport = Import-Csv -Path $args[0]

$regex = "(?<Type>Aufgabe|Fehler|User Story) (?<WorkItemId>\d{6}):"
$result = @()

foreach ($groupedEntries in $tempoExport | Group-Object -Property Worklog) {

    if ($groupedEntries.Name -match $regex) {
        $workItemId = $matches['WorkItemId']
        $workItem = Get-WorkItem $workItemId

        $loggedinTfs = $workItem.fields."Microsoft.VSTS.Scheduling.CompletedWork"
        $loggedInTempo = ($groupedEntries.Group | Measure-Object 'Logged' -Sum).Sum

        $result += [PSCustomObject]@{
            TFSId        = $workItem.id
            Title        = $workItem.fields."System.Title"
            TempoHours   = $loggedInTempo
            TFSHours     = $loggedInTfs
            HasDeviation = $loggedInTempo -ne $loggedinTfs
            TFSUrl       = "$BaseUri/wit/workitems/$($workItem.id)"
        }
    }
}

$deviations = $result | Where-Object HasDeviation -eq $true
if ($deviations.Count -eq 0) {
    $totalHours = $result | Measure-Object 'TempoHours' -Sum
    Write-Host "Hours OK. Total Hours: $($totalHours.Sum)"
}
else {
    Write-Error "Deviations found:"
    $deviations
}