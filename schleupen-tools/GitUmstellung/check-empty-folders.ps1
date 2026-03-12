param (
    [Parameter(Mandatory)]
    [string]$RootPath
)

if (-not (Test-Path $RootPath)) {
    throw "Path does not exist: $RootPath"
}

Get-ChildItem -Path $RootPath -Directory -Recurse |
    Where-Object {
        # A folder is empty if it contains no files and no subfolders
        -not (Get-ChildItem -Path $_.FullName -Force | Select-Object -First 1)
    } |
    Select-Object -ExpandProperty FullName
