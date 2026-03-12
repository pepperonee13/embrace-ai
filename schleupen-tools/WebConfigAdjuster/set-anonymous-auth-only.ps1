[CmdletBinding()]
param(
    [Parameter()]
    [string[]]$WebConfigPaths = @(
        'C:\Program Files\Schleupen\www\Schleupen\CS.FB',
        'C:\Program Files\Schleupen\www\Schleupen\CS.SY'
    ),
    [switch]$SkipIISReset
)

$ErrorActionPreference = "Stop"

####################################################################
function Stop-IISWithRetry {
    # IIS stoppen, ansonsten sind die web.configs häufig blockiert
    & cmd.exe /c 'iisreset.exe /stop'
    if ($? -ne $true) {
        Write-Host "2. Versuch: iisreset /stop fehlgeschlagen, warte 30 Sekunden..."
        Start-Sleep -Seconds 30
        & cmd.exe /c 'iisreset.exe /stop'
        if ($? -ne $true) {
            throw "Fehler bei: iisreset /stop fehlgeschlagen"
        }
    }
}

Write-Host "Konfiguriere Anonyme Authentifizierung: ---------- 1. IIS stoppen"

if (-not $SkipIISReset) {
    Stop-IISWithRetry
}

# Definiere einen benutzerdefinierten Objekttyp für Binding-Konfiguration
class BindingConfig {
    [string]$Name
    [string]$Type
    [bool]$SetModeToNone

    BindingConfig([string]$name, [string]$type, [bool]$setModeToNone) {
        $this.Name = $name
        $this.Type = $type
        $this.SetModeToNone = $setModeToNone
    }

    [string] ToString() {
        return "$($this.Type)/$($this.Name)"
    }
}

function Get-ServiceBindings {
    $bindingDefinitions = @{
        'basicHttpBinding' = @(
            # Nur Windows-Bindings
            'httpWindows',
            'httpWindowsExtendedMsgCapacity',
            'httpWindowsExtendedMsgCapacityAndInfiniteTimeout',
            'httpsWindows',
            'httpsWindowsExtendedMsgCapacity',
            'httpsWindowsExtendedMsgCapacityAndInfiniteTimeout',
            'basicHttpBindingWindows'
        )
        'webHttpBinding'   = @(
            # Standard Windows-Authentifizierungs-Bindings
            'httpWindows',
            'httpsWindows'
        )
    }

    $bindings = @()
    foreach ($bindingType in $bindingDefinitions.Keys) {
        foreach ($name in $bindingDefinitions[$bindingType]) {
            # Sicherheitsmodus basierend auf Binding-Namen bestimmen (https = Transport-Sicherheit beibehalten)
            $setModeToNone = -not $name.StartsWith('https', [StringComparison]::OrdinalIgnoreCase)
            $bindings += [BindingConfig]::new($name, $bindingType, $setModeToNone)
        }
    }

    return $bindings
}

function Update-SecurityBinding {
    param (
        [Parameter(Mandatory = $true)]
        [System.Xml.XmlDocument]$Config,
        
        [Parameter(Mandatory = $true)]
        [BindingConfig]$Binding,
        
        [Parameter(Mandatory = $true)]
        [string]$ConfigPath
    )
    
    $changed = $false
    $security = $Config.selectSingleNode("//configuration/system.serviceModel/bindings/$($Binding.Type)/binding[@name = '$($Binding.Name)']/security")
    if ($security) {
        if ($Binding.SetModeToNone -and $security.GetAttribute("mode") -ne "None") {
            $security.setAttribute("mode", "None") | Out-Null
            Write-Host "$($ConfigPath): $($Binding) - mode none"
            $changed = $true
        }

        if ($security.FirstChild) {
            $security.RemoveChild($security.FirstChild) | Out-Null
            Write-Host "$($ConfigPath): $($Binding) - Child entfernt"
            $changed = $true
        }
    }
    return $changed
}

function Save-WebConfig {
    param (
        [Parameter(Mandatory = $true)]
        [System.Xml.XmlDocument]$config,
        
        [Parameter(Mandatory = $true)]
        [string]$configPath
    )
    
    $retryDelays = @(60, 300)  # Verzögerungen in Sekunden für den 2. und 3. Versuch
    $attempt = 1
    
    do {
        try {
            $config.Save($configPath)
            if ($attempt -gt 1) {
                Write-Host "$($configPath): Erfolgreich gespeichert beim $attempt. Versuch"
            }
            return
        }
        catch {
            if ($attempt -gt $retryDelays.Count) {
                throw  # Keine Wiederholungen mehr übrig, Fehler weiterwerfen
            }
            
            $delay = $retryDelays[$attempt - 1]
            Write-Host "Versuch $attempt fehlgeschlagen: warte $delay Sekunden vor erneutem Speichern von $configPath..."
            Start-Sleep -Seconds $delay
            $attempt++
        }
    } while ($true)
}

function Set-IISAuthenticationConfig {
    param (
        [Parameter(Mandatory = $true)]
        [System.Xml.XmlDocument]$config,
        
        [Parameter(Mandatory = $true)]
        [string]$configPath
    )
    
    $changed = $false
    $root = $config.selectSingleNode("//configuration")
    
    $systemWebServer = $root.selectSingleNode("system.webServer")
    if (!$systemWebServer) {
        $systemWebServer = $config.CreateElement("system.webServer")
        $root.AppendChild($systemWebServer) | Out-Null
        $changed = $true
    }

    $security = $systemWebServer.selectSingleNode("security")
    if (!$security) {
        $security = $config.CreateElement("security")
        $systemWebServer.AppendChild($security) | Out-Null
        $changed = $true
    }

    $authentication = $security.selectSingleNode("authentication")
    if (!$authentication) {
        $authentication = $config.CreateElement("authentication")
        $security.AppendChild($authentication) | Out-Null
        $changed = $true
    }

    $anonymousAuthentication = $authentication.selectSingleNode("anonymousAuthentication")
    if (!$anonymousAuthentication) {
        $anonymousAuthentication = $config.CreateElement("anonymousAuthentication")
        $authentication.AppendChild($anonymousAuthentication) | Out-Null
        $changed = $true
    }

    $basicAuthentication = $authentication.selectSingleNode("basicAuthentication")
    if (!$basicAuthentication) {
        $basicAuthentication = $config.CreateElement("basicAuthentication")
        $authentication.AppendChild($basicAuthentication) | Out-Null
        $changed = $true
    }

    # Prüfen und Aktualisieren der Authentifizierungseinstellungen
    if ($anonymousAuthentication.GetAttribute("enabled") -ne "true") {
        $anonymousAuthentication.setAttribute("enabled", "true") | Out-Null
        $changed = $true
    }
    
    if ($basicAuthentication.GetAttribute("enabled") -ne "false") {
        $basicAuthentication.setAttribute("enabled", "false") | Out-Null
        $changed = $true
    }
    
    if ($changed) {
        Write-Host "$($configPath): IIS-Authentifizierung konfiguriert - anonyme aktiviert, basic deaktiviert"
    }
    
    return $changed
}

function Backup-WebConfig {
    param (
        [Parameter(Mandatory = $true)]
        [string]$ConfigPath
    )
    
    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $directory = Split-Path -Parent $ConfigPath
    $backupPath = Join-Path $directory "web.backup_${timestamp}.config"
    
    Write-Host "Erstelle Sicherung von $ConfigPath nach $backupPath"
    Copy-Item -Path $ConfigPath -Destination $backupPath -Force
    
    return $backupPath
}

Write-Host "Konfiguriere Anonyme Authentifizierung: ---------- 2. Web.config-Dateien verarbeiten"

# Alle zu verarbeitenden web.config-Dateien sammeln
$files = @()
foreach ($path in $WebConfigPaths) {
    if (Test-Path $path -PathType Container) {
        # Wenn der Pfad ein Verzeichnis ist, alle web.config-Dateien darin holen
        $files += Get-ChildItem -Path $path -Recurse -Filter *web.config
    }
    elseif (Test-Path $path -PathType Leaf) {
        # Wenn der Pfad eine Datei ist, direkt hinzufügen, falls es eine web.config ist
        if ($path -like '*web.config') {
            $files += Get-Item $path
        }
    }
}

# Service-Bindings für die Verarbeitung holen
$bindings = Get-ServiceBindings

foreach ($file in $files) {
    $ConfigPath = $file.FullName
    $config = New-Object xml
    $config.Load($ConfigPath)

    $configChanged = $false
    
    # Prüfe und Aktualisiere Security Bindings
    foreach ($binding in $bindings) {
        $configChanged = (Update-SecurityBinding -Config $config -Binding $binding -ConfigPath $ConfigPath) -or $configChanged
    }
    
    # Prüfe und Aktualisiere IIS Authentication Konfiguration
    $configChanged = (Set-IISAuthenticationConfig -config $config -configPath $ConfigPath) -or $configChanged
    
    if ($configChanged) {
        # Sicherung nur erstellen wenn Änderungen vorgenommen wurden
        $backupPath = Backup-WebConfig -ConfigPath $ConfigPath
        Save-WebConfig -config $config -configPath $ConfigPath
    }
    else {
        Write-Host "$($ConfigPath): Web.config ist bereits korrekt konfiguriert - keine Änderungen notwendig"
    }
}

####################################################################
Write-Host "Konfiguriere Anonyme Authentifizierung: ---------- 3. IIS neu starten"

# IIS (AppPools) neu starten, wurde in Schritt 1 gestoppt
& iisreset /start

if ($? -ne $true) {
    throw "Fehler bei: iisreset /start fehlgeschlagen"
}