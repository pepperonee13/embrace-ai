# TFS History Analyse Skript

## Übersicht
Dieses Skript analysiert Änderungen in TFS-Produktpfaden basierend auf einem angegebenen Startdatum. Es unterstützt die Konfiguration über eine `config.json`-Datei und bietet flexible Ausgabemöglichkeiten im JSON- oder CSV-Format.

## Voraussetzungen
- **PowerShell**: Stellen Sie sicher, dass PowerShell installiert ist.
- **TFS Command Line Tool**: `tf.exe` muss installiert sein und entweder im Systempfad verfügbar oder in der `config.json` konfiguriert sein.
- **Konfigurationsdatei**: Eine `config.json` muss im selben Verzeichnis wie das Skript erstellt werden.

### `tf.exe`-Pfad konfigurieren
Falls `tf.exe` nicht im PATH verfügbar ist, fügen Sie den folgenden Standardpfad hinzu:
`C:\Program Files\Microsoft Visual Studio\2022\Professional\Common7\IDE\CommonExtensions\Microsoft\TeamFoundation\Team Explorer`

Ein PowerShell-Skript zum Hinzufügen des Pfads:
```powershell
$userpath = [System.Environment]::GetEnvironmentVariable("PATH","USER")
$userpath = $userpath + ";C:\Program Files\Microsoft Visual Studio\2022\Professional\Common7\IDE\CommonExtensions\Microsoft\TeamFoundation\Team Explorer"
[System.Environment]::SetEnvironmentVariable("PATH",$userpath,"USER")
```

Alternativ kann der Pfad in der `config.json` konfiguriert werden.

## Konfigurationsdatei
Die `config.json` ermöglicht eine flexible Anpassung des Skripts. Ein Beispiel:
```json
{
    "Locale": "de",
    "ProduktPfade": [
        "$/CS3/Kontinente/FW/HB",
        "$/CS3/GP/zlm/gav/Baseline"
    ],
    "OutputFormat": "CSV",
    "TfExePath": "c:\\Program Files\\Microsoft Visual Studio\\2022\\Professional\\Common7\\IDE\\CommonExtensions\\Microsoft\\TeamFoundation\\Team Explorer\\TF.exe"
}
```

### Felder der Konfigurationsdatei
1. **`Locale`**: Sprache für die Analyse (`de` oder `en`).
2. **`ProduktPfade`**: Liste der zu analysierenden TFS-Produktpfade.
3. **`OutputFormat`**: Ausgabemodus (`JSON` oder `CSV`).
4. **`TfExePath`**: Pfad zu `tf.exe`.

## Verwendung

### Parameter
1. **`SinceDate`** (Pflicht):
   - Startdatum für die Analyse der Changeset-Historie.
   - Beispiel: `"2024-12-01"`.

2. **`ProduktPfad`** (Optional):
   - Überschreibt die Produktpfade aus der `config.json`.
   - Beispiel: `"$/CS3/Kontinente/FW/HB"`.
   
### Hinweis zur Ausführungszeit
Der `SinceDate`-Parameter gibt das Startdatum für die Analyse der Changeset-Historie an. Beachten Sie, dass bei der Angabe von älteren Datumswerten die Ausführung des Skripts länger dauern kann, da eine größere Historie aus TFS abgerufen und verarbeitet werden muss. Um die Ausführungszeit zu optimieren, wählen Sie ein möglichst aktuelles Startdatum.

### Ausführen des Skripts
1. Öffnen Sie ein PowerShell-Terminal.
2. Navigieren Sie zum Verzeichnis des Skripts.
3. Führen Sie das Skript aus:

```powershell
.\GetLastChangesets.ps1 -SinceDate "2024-12-01"
```

Um einen spezifischen Produktpfad zu analysieren:
```powershell
.\GetLastChangesets.ps1 -SinceDate "2024-12-01" -ProduktPfad "$/CS3/Kontinente/FW/HB"
```

## Ausgabeformate

### JSON
Standardmäßig wird die Ausgabe als JSON gespeichert. Beispiel:
```json
{
    "Ausfuehrungszeitpunkt": "2024-12-20 15:19:05",
    "AenderungenSeit": "2024-12-17",
    "Aenderungen": {
        "$/CS3/Kontinente/FW/HB": [
            {
                "ChangesetId": 1263541,
                "User": "Szarvas, Peter",
                "Comment": "[cs.fw.zm 3.41.0.7539] chore: cleanup",
                "Date": "2024-12-17 22:06:16",
                "Branches": [
                    "$/CS3/Kontinente/FW/HB/Baseline"
                ]
            }
        ]
    }
}
```

### CSV
Falls in der `config.json` `OutputFormat: "CSV"` definiert wurde, wird die Ausgabe in eine CSV-Datei konvertiert:
```csv
Produkt,ChangesetId,User,Comment,Date,FeatureBranch1,FeatureBranch2,FeatureBranch3
$/CS3/Kontinente/FW/HB,1263541,Szarvas, Peter,"[cs.fw.zm 3.41.0.7539] chore: cleanup",2024-12-17 22:06:16,$/CS3/Kontinente/FW/HB/Baseline,,,
```

### Ausgabedateien
Die generierten Dateien werden im Skriptverzeichnis gespeichert:
- JSON: `LastChangesets.json`
- CSV: `LastChangesets.csv`

## Hauptfunktionen
- **Lokalisierung**: Unterstützung für Deutsch und Englisch.
- **Flexible Konfiguration**: Steuerung über `config.json`.
- **CSV- und JSON-Ausgabe**: Wählen Sie das bevorzugte Format.
- **Branches extrahieren**: Identifiziert Branches aus Changesets.
- **Fehlerbehandlung**: Überspringt fehlerhafte Pfade, ohne die Analyse zu unterbrechen.

## Hinweise
- Aktualisieren Sie die Variable `$Collection`, um Ihren TFS-Server zu konfigurieren.
- Überprüfen Sie die Konfiguration der Produktpfade und der `TfExePath`.
- Stellen Sie sicher, dass das gewünschte Ausgabeverzeichnis beschreibbar ist.

## Support
Für Fragen oder Verbesserungsvorschläge wenden Sie sich an Peter Szarvas.