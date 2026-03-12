# Get-LastCommitsFromAllRepositories – Git Repository Analysis Tool
*(Updated replacement for former TFS History Analyse Skript)*

## Übersicht

Dieses neue Tool ersetzt das bisherige [TFS-basierte Analysewerkzeug](../tfs/README.md) vollständig.  
Statt `tf.exe` oder TFS-Produktpfaden nutzt es jetzt die **Azure DevOps Git REST API**, um:

- mehrere Git-Repositories automatisch zu analysieren  
- Commits aus dem *Main*-Branch sowie definierbaren *Feature-Branches* auszulesen  
- optional ab einem bestimmten Startdatum (SinceDate) zu filtern  
- pro Branch eine konfigurierbare Anzahl der letzten Commits abzurufen  
- die Ergebnisse gesammelt im **JSON-** oder **CSV-Format** auszugeben  
- den **Zeitpunkt der Analyse** im Output zu speichern  

Das System besteht aus zwei Skripten:

1. **Get-BranchesCommits.ps1** – Analysiert ein einzelnes Repository  
2. **Get-LastCommitsFromAllRepositories.ps1** – Führt die Analyse für mehrere Repositories durch (Hauptskript)

---

## Voraussetzungen

- **PowerShell 5+ oder PowerShell 7+**
- Zugriff auf **Azure DevOps Server (on-prem)** oder Azure DevOps Git Repositories  
- Der Benutzer muss Leserechte auf die Ziel-Repositories besitzen  
- *Keine* Git-Installation nötig  
- *Keine* TFS-Tools (`tf.exe`) erforderlich  
- Authentifizierung erfolgt automatisch über **-UseDefaultCredentials** mit dem Windows-Konto

---

## Konfigurationsdatei (`git-config.json`)

Die gesamte Analyse wird über die Konfigurationsdatei gesteuert.

### Beispiel:

```json
{
  "Organization": "http://tfs:8080/tfs/DefaultCollection",
  "Project": "MyProject",
  "MainBranchName": "main",
  "FeatureBranchPrefix": "refs/heads/feature/",
  "SinceDate": "2025-01-01",
  "OutputFormat": "Both",
  "Repositories": [
    "RepoOne",
    "RepoTwo",
    "RepoThree"
  ]
}
```

### Felder der Konfigurationsdatei

| Feld | Beschreibung |
|------|--------------|
| **Organization** | Basis-URL des Azure DevOps Servers |
| **Project** | Name des Projekts, das die Git-Repositories enthält |
| **MainBranchName** | Name des Hauptbranches (`main`, `master`, `develop` …) |
| **FeatureBranchPrefix** | Prefix für Feature-Branches (z. B. `refs/heads/feature/`) |
| **SinceDate** *(optional)* | Nur Commits ab diesem Datum werden berücksichtigt. Wenn nicht gesetzt → Fallback: *heute – 7 Tage* |
| **OutputFormat** | Ausgabeformat: `Json`, `Csv`, `Both`, `None` |
| **Repositories** | Liste der Git-Repositories, die analysiert werden sollen |

---

## Skripte

### 1. Get-BranchesCommits.ps1

Analysiert ein einzelnes Repository und liefert eine Liste mit Commits:

- Main-Branch  
- Alle Feature-Branches, basierend auf dem Prefix  
- Clientseitige Filterung nach SinceDate  
- Sortierung: **Branch ASC**, **Date DESC**  

### 2. Get-LastCommitsFromAllRepositories.ps1

Wrapper-Skript, das:

- die Konfigurationsdatei liest  
- alle Repositories nacheinander analysiert  
- die Daten in einer großen Liste sammelt  
- optional JSON/CSV-Ausgaben generiert  
- den **Analysezeitpunkt** hinzufügt  

---

## Verwendung

### Analyse aller Repositories aus der config.json

```powershell
.\Get-LastCommitsFromAllRepositories.ps1 -ConfigPath ".\git-config.json"
```

### Mit Overrides

```powershell
.\Get-LastCommitsFromAllRepositories.ps1 `
    -ConfigPath ".\git-config.json" `
    -SinceDate "2025-01-10" `
    -OutputFormat Both
```

**Override-Priorität:**  
1. Command-Line Parameter  
2. Config-Datei  
3. Defaults  

---

## Ausgabeformate

### JSON-Ausgabe

Die JSON-Datei enthält:

- **AnalysisDate** (Zeitpunkt der Analyse)
- **Commits** (komplette Liste)

Beispiel:

```json
{
  "AnalysisDate": "2025-01-19T10:23:45.1234567+01:00",
  "Commits": [
    {
      "Repository": "RepoOne",
      "Branch": "main",
      "CommitId": "abc123...",
      "Author": "Jane Dev",
      "Email": "jane@example.com",
      "Date": "2025-01-18T09:12:34Z",
      "Comment": "Fix bug"
    }
  ]
}
```

---

### CSV-Ausgabe

Die CSV-Datei enthält alle Commits und am **Ende eine extra Zeile**:

```csv
Repository,Branch,CommitId,Author,Email,Date,Comment
RepoOne,main,abc123...,Jane Dev,jane@example.com,2025-01-18T09:12:34Z,Fix bug
RepoTwo,feature/XYZ-123,def456...,John Dev,john@example.com,2025-01-17T08:01:02Z,Add feature
AnalysisDate,2025-01-19T10:23:45.1234567+01:00
```

---

## Hauptfunktionen

- Analyse beliebig vieler Git-Repositories auf einmal  
- Nutzung der Azure DevOps REST API (kein lokales Git nötig)  
- Automatische Authentifizierung über Windows-Anmeldedaten  
- Analyse von Main- und Feature-Branches  
- Komplette Datumsauswertung über SinceDate  
- Konfigurierbare Anzahl Commits pro Branch  
- JSON/CSV-Ausgabe inklusive Analysezeitpunkt  
- Saubere, sortierte Commit-Liste für Reporting / Deltas / Release-Vorbereitung  

---

## Hinweise

- `searchCriteria.fromDate` der Azure DevOps API ist nicht streng → echte Filterung erfolgt **clientseitig**.  
- Falls **SinceDate** nicht angegeben ist, wird automatisch *heute – 7 Tage* verwendet.  
- Feature-Branches müssen über ein konsistentes Prefix identifizierbar sein.  
- Die Skripte verwenden ausschließlich REST API Calls – keine lokale Repository-Kopie.

---

## Support

Bei Fragen oder Verbesserungsvorschlägen wenden Sie sich an:

**Peter Szarvas**
