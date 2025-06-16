# 🛠️ CSV2Actual Development Tools

Dieses Verzeichnis enthält wertvolle Entwicklungstools, die aus der Entwicklung von CSV2Actual entstanden sind und für zukünftige Projekte wiederverwendet werden können.

## 📁 Struktur

### `/testing/` - Test-Framework
- **`verbose-debugger.ps1`** - Umfassendes PowerShell-Debugging mit Transcript-Logging
- **`transaction-analyzer-test.ps1`** - Test-Framework für Transaktions-Kategorisierung  
- **`category-engine-test.ps1`** - I18n-System und Kategorie-Engine Tests

### `/tools/` - Entwickler-Werkzeuge
- **`ai-prompt-tracker/`** - Universeller AI-Cost-Tracker mit Budget-Management
- **`encoding-debugger.ps1`** - UTF-8 Encoding-Handler für internationale Projekte
- **`error-collector.ps1`** - Stderr/Stdout Capturing Framework

### `/docs/` - Entwickler-Dokumentation
- **`debugging-guide.md`** - Anleitung für alle Debug-Tools

## 🎯 Wiederverwendungswert

Diese Tools haben einen geschätzten Wiedererstellungsaufwand von **28-38 Stunden** und können in anderen PowerShell-Projekten eingesetzt werden:

### Universell einsetzbar:
- **AI-Cost-Tracker**: Für jedes AI-unterstützte Entwicklungsprojekt
- **Verbose-Debugger**: Für komplexe PowerShell-Anwendungen
- **Encoding-Tools**: Für internationale/mehrsprachige Projekte

### CSV2Actual-spezifisch aber adaptierbar:
- **Test-Frameworks**: Patterns für andere Kategorisierungs-/Analyse-Systeme
- **I18n-Testing**: Vorlage für mehrsprachige Anwendungen

## 🚀 Schnellstart

```powershell
# Debug-Session starten
pwsh -File dev/testing/verbose-debugger.ps1

# AI-Kosten tracken
. dev/tools/ai-prompt-tracker/tracker.ps1
Start-AISession -Project "MeinProjekt"

# Kategorie-Engine testen
pwsh -File dev/testing/category-engine-test.ps1
```

Siehe `docs/debugging-guide.md` für detaillierte Anleitungen.