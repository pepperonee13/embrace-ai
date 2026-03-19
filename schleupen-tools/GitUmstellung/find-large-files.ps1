<#
.SYNOPSIS
  Lists files larger than a given size (in MB) under a folder, recursively.

.PARAMETER Root
  The folder to scan.

.PARAMETER MinSizeMB
  Minimum file size in megabytes (MB). Defaults to 50.

.EXAMPLE
  .\Find-LargeFiles.ps1 -Root "D:\Data" -MinSizeMB 100
#>

[CmdletBinding()]
param(
  [Parameter(Mandatory)]
  [ValidateNotNullOrEmpty()]
  [string] $Root,

  [ValidateRange(1, 1024*1024)]
  [int] $MinSizeMB = 50
)

$minBytes = $MinSizeMB * 1MB

Get-ChildItem -Path $Root -Recurse -File -ErrorAction SilentlyContinue |
  Where-Object { $_.Length -gt $minBytes } |
  Select-Object FullName,
                @{ Name = 'SizeMB'; Expression = { [math]::Round($_.Length / 1MB, 2) } },
                LastWriteTime |
  Sort-Object { $_.SizeMB } -Descending
