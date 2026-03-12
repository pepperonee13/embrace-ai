# Feature Branch Analysis Script

## Übersicht
Dieses Skript automatisiert die Analyse von Feature-Branches über mehrere Server. Es liest Pipeline-JSON-Dateien von angegebenen Servern, extrahiert Informationen zu Feature-Branches und bereichert diese mit Daten von einem TFS-Server.

## Verwendung

### Voraussetzungen
1. Stellen Sie sicher, dass PowerShell installiert ist.
2. Platzieren Sie das Skript in einem Verzeichnis zusammen mit einer `config.json`-Datei für die Konfiguration.
3. Besitzen Sie Zugangsdaten für den Zugriff auf TFS und die Remote-Server.

### Konfigurationsdatei
Erstellen Sie eine `config.json`-Datei im selben Verzeichnis wie das Skript mit folgendem Aufbau:

```json
{
    "Username": "buildinstaller",
    "Servers": ["ServerA", "ServerB"],
    "Domain": "YOUR-DOMAIN",
    "AdditionalFields": [
        "System.State",
        "System.WorkItemType"
    ],
    "CreateOutputJson": true
}
```

Eine Liste der verfügbaren zusätzlichen Felder finden Sie in der [offiziellen Dokumentation](https://learn.microsoft.com/en-us/rest/api/azure/devops/wit/work-items/get-work-item?view=azure-devops-rest-7.1&tabs=HTTP#get-work-item).

### Ausführen des Skripts
1. Öffnen Sie ein PowerShell-Terminal.
2. Navigieren Sie zum Verzeichnis, in dem sich das Skript befindet.
3. Führen Sie das Skript aus:

   ```powershell
   .\GetInstalledFeatureBranches.ps1
   ```

4. Geben Sie das Passwort für die angegebene Domain und den Benutzernamen ein, wenn Sie dazu aufgefordert werden.

### Ausgabe
- Das Skript verarbeitet Feature-Branches und gibt die Ergebnisse als JSON-Objekt in der Konsole aus.
- Wenn `CreateOutputJson` auf `true` gesetzt ist, werden die Ergebnisse in einer Datei namens `InstalledFeatureBranches.json` gespeichert.

## Hauptfunktionen
- **Dynamische Konfiguration**: Verwendet eine `config.json`-Datei, um Server, Benutzeranmeldedaten und zusätzliche Felder zu spezifizieren.
- **Erkennung von Feature-Branches**: Identifiziert Feature-Branches aus `pipeline.json`-Dateien auf Remote-Servern.
- **Work-Item-Anreicherung**: Ruft Details zu TFS-Work-Items ab und fügt zusätzliche Metadaten hinzu.
- **Fehlerbehandlung**: Protokolliert Fehler und überspringt problematische Server, während die Analyse fortgesetzt wird.

## Beispielausgabe
```json
{
    "Server1": {
        "Product1": {
            "Qualitaet": "Features/XYZ/1234-U/CI",
            "Zugewiesen": "John Doe",
            "TfsLink": "https://tfsprod/tfs/DefaultCollection/_workitems/edit/575512",
            "AdditionalFields": {
                "System.State": "Active",
                "System.WorkItemType": "User Story"
            }
        }
    },
    "Server2": {
        "Product2": "No WorkItem found"
    }
}
```

## Hinweise
- Stellen Sie sicher, dass die `pipeline.json`-Datei auf den angegebenen Servern im `install`-Verzeichnis vorhanden ist.
- Das Skript ordnet und verarbeitet Feature-Branches dynamisch und überspringt ungültige oder fehlende Daten.
- Aktualisieren Sie die Variable `$Collection`, um die URL Ihres TFS-Servers anzupassen.

## Support
Bei Problemen oder Verbesserungsvorschlägen wenden Sie sich bitte an die Verantwortlichen.

## Skript: FindAvailableServers.ps1

### Zweck
Das Skript `FindAvailableServers.ps1` dient dazu, verfügbare Server für bestimmte Produkte zu finden. Es durchsucht die Konfigurationsdateien und gibt eine Liste der Server zurück, die die angegebenen Produkte unterstützen.

### Verwendung
1. Öffnen Sie ein PowerShell-Terminal.
2. Navigieren Sie zum Verzeichnis `GetInstalledFeatureBranches`.
3. Führen Sie das Skript aus, indem Sie die gewünschten Produkte angeben:

   ```powershell
   .\FindAvailableServers.ps1 -Products @("Produkt1", "Produkt2")
   ```

4. Das Skript gibt die Liste der verfügbaren Server in der Konsole aus.

### Beispielausgabe
```plaintext
Server1
Server2
Server3
```

### Hinweise
- Die Produkte müssen in der Konfigurationsdatei `config.json` definiert sein.
- Das Skript liest die Konfiguration aus der Datei `config.json` und verarbeitet die angegebenen Produkte.
- Stellen Sie sicher, dass die Konfigurationsdatei korrekt eingerichtet ist, bevor Sie das Skript ausführen.
- Der Parameter `-Username` ist optional. Wird er weggelassen und ist auch in der `config.json` kein Benutzername angegeben, wird die Windows-Identität des ausführenden Benutzers verwendet.

## Skript: FindInstalledProductsOnServer.ps1

### Zweck
Das Skript `FindInstalledProductsOnServer.ps1` gibt alle Produkte aus, die auf einem bestimmten Server mit einem Feature-Branch installiert sind (d. h. deren `Qualitaet` in der `pipeline.json` mit `Features/` beginnt).

### Verwendung
1. Öffnen Sie ein PowerShell-Terminal.
2. Navigieren Sie zum Verzeichnis `GetInstalledFeatureBranches`.
3. Führen Sie das Skript aus, indem Sie den gewünschten Server angeben:

   ```powershell
   .\FindInstalledProductsOnServer.ps1 -Server TESTSERVER1234
   ```

   Mit explizitem Benutzernamen (überschreibt den Wert aus `config.json`):

   ```powershell
   .\FindInstalledProductsOnServer.ps1 -Server TESTSERVER1234 -Username FirstName.LastName
   ```

### Beispielausgabe
```plaintext
Auf dem Server 'TESTSERVER1234' sind folgende Produkte mit Feature-Branch installiert:
Schleupen.CS.PM.AE
Schleupen.CS.PM.ZFA
```

### Hinweise
- Es werden nur Produkte aufgelistet, deren `Qualitaet` in der `pipeline.json` mit `Features/` beginnt. Baseline-Produkte werden nicht angezeigt.
- Der Parameter `-Username` ist optional. Wird er weggelassen und ist auch in der `config.json` kein Benutzername angegeben, wird die Windows-Identität des ausführenden Benutzers verwendet.