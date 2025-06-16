# 🛠️ CSV2Actual Development & Debug Guide

## Debug-Tools Übersicht

### Testing Framework

#### `verbose-debugger.ps1`
- **Zweck**: Umfassendes Debugging-Framework mit Transcript-Logging
- **Features**: 
  - Automatisches Fehler-Capturing
  - Stack-Trace-Erfassung
  - Modul-Validierung
  - Cross-Platform PowerShell Support
- **Verwendung**: `pwsh -File dev/testing/verbose-debugger.ps1`

#### `transaction-analyzer-test.ps1`
- **Zweck**: Test-Framework für Transaktions-Kategorisierung
- **Features**:
  - Künstliche Test-Daten Generation
  - Multi-Language Testing (de/en)
  - Vollständige Kategorie-Engine Tests
- **Verwendung**: `pwsh -File dev/testing/transaction-analyzer-test.ps1 -Language de`

#### `category-engine-test.ps1`
- **Zweck**: I18n-System und Kategorie-Engine Validation
- **Features**:
  - Sprachvergleiche
  - Keyword-Matching Tests
  - Kategorien-Struktur Validierung
- **Verwendung**: `pwsh -File dev/testing/category-engine-test.ps1`

### Development Tools

#### `ai-prompt-tracker/`
- **Zweck**: Universeller AI-Cost-Tracker
- **Features**:
  - Token-Cost-Calculation für verschiedene Modelle
  - Budget-Management und Cost-Analytics
  - Live-Dashboard für Kostenüberwachung
- **Verwendung**: 
  ```powershell
  . dev/tools/ai-prompt-tracker/tracker.ps1
  Start-AISession -Project "CSV2Actual" -Feature "Kategorisierung"
  Track-AIOperation -Feature "CategoryEngine" -ActualCost 1.25
  Show-CostDashboard
  ```

## Best Practices

### Debug-Workflow
1. **Erste Fehleranalyse**: `verbose-debugger.ps1` für umfassende Logging
2. **Spezifische Tests**: Entsprechendes Test-Framework verwenden
3. **AI-Kosten tracking**: Bei AI-unterstützter Entwicklung Kosten protokollieren

### Test-Daten
- Test-Daten werden automatisch in `test_data/` Verzeichnissen erstellt
- Künstliche CSV-Daten für verschiedene Szenarien verfügbar
- Multi-Language Test-Unterstützung

### Cross-Platform Kompatibilität
- Alle Tools sind für PowerShell 5.1 und 7.x optimiert
- WSL-Kompatibilität getestet
- Encoding-Handling für internationale Daten

## Erweiterung der Tools

Die Debug-Tools sind modular aufgebaut und können für andere PowerShell-Projekte wiederverwendet werden. Bei Erweiterungen:

1. Bestehende Patterns beibehalten
2. Cross-Version-Kompatibilität sicherstellen  
3. I18n-Support berücksichtigen
4. Umfassende Fehlerbehandlung implementieren