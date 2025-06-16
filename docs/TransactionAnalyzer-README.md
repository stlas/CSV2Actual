# TransactionAnalyzer - Umfassende Kategorisierungs-Analyse

Der **TransactionAnalyzer** ist ein mächtiges Werkzeug zur Analyse der Kategorisierungseffektivität von CSV2Actual. Er bietet eine detaillierte Übersicht über die Qualität der automatischen Kategorisierung und gibt konkrete Empfehlungen zur Verbesserung.

## Funktionsübersicht

### 1. Vollständige Transaktionsanalyse
- Lädt alle CSV-Dateien aus dem angegebenen Verzeichnis
- Analysiert jede Transaktion gegen alle verfügbaren Kategorisierungsregeln
- Erkennt verschiedene Kategorisierungstypen und deren Erfolgsrate

### 2. Detaillierte Statistiken
- **Gesamt-Transaktionen**: Anzahl aller analysierten Transaktionen
- **Transfer-Erkennung**: Transaktionen zwischen eigenen Konten (via IBAN-Matching)
- **Einkommen-Erkennung**: Positive Beträge automatisch als Einkommen kategorisiert
- **Exakte Matches**: Über categoryMappings zugeordnete Transaktionen
- **Keyword-Matches**: Aufgeschlüsselt nach Payee, Memo und Buchungstext-Keywords
- **Nicht kategorisiert**: Transaktionen ohne Zuordnung

### 3. Kategorie-Verteilung
- Zeigt alle verwendeten Kategorien mit Häufigkeit und Prozentwerten
- Sortiert nach Häufigkeit (absteigend)
- Hilft bei der Identifikation der wichtigsten Ausgabenkategorien

### 4. Analyse nicht kategorisierter Transaktionen
- Gruppiert nach Payee mit Transaktionszahl
- Zeigt Beispiel-Transaktionen für jeden Payee
- Priorität nach Häufigkeit für optimale Verbesserungsmaßnahmen

### 5. Kategorisierungsrate und Bewertung
- **≥95%**: Ausgezeichnet
- **≥85%**: Sehr gut  
- **≥70%**: Gut
- **<70%**: Verbesserungsbedarf

### 6. Automatische Empfehlungen
- Konkrete Vorschläge für häufige nicht kategorisierte Payees
- Empfehlungen für Keyword-Optimierung
- Hinweise zur Verbesserung der Einkommens-Erkennung

## Verwendung

### Über das Hauptskript
```powershell
# Deutsche Analyse
powershell -File CSV2Actual.ps1 -Analyze -Language de

# Englische Analyse  
powershell -File CSV2Actual.ps1 -Analyze -Language en
```

### Als eigenständige Funktion
```powershell
# Module laden
. "./modules/Config.ps1"
. "./modules/CategoryEngine.ps1" 
. "./modules/TransactionAnalyzer.ps1"

# Analyzer verwenden
Invoke-TransactionAnalysis -CsvDirectory "source" -Language "de"
```

### Programmierung
```powershell
# Konfiguration und Engine initialisieren
$config = [Config]::new("config.json")
$categoryEngine = [CategoryEngine]::new("categories.json", "de")

# Analyzer erstellen
$analyzer = [TransactionAnalyzer]::new($categoryEngine, $config.data, "de")

# Analyse durchführen
$analyzer.AnalyzeAllTransactions("source")
```

## Ausgabe-Beispiel

```
=== TRANSAKTIONS-KATEGORISIERUNGS-ANALYSE ===

Lade CSV-Dateien aus Verzeichnis:
  source

Gefundene CSV-Dateien:
  Girokonto.csv
  Kreditkarte.csv

=== KATEGORISIERUNGS-STATISTIKEN ===

Gesamt-Transaktionen: 150
Transfers (eigene IBANs): 5
Einnahmen (positive Beträge): 12
Exakte Payee-Matches: 45
Keyword-basierte Matches:
  Payee-Keywords: 23
  Memo-Keywords: 18
  Buchungstext-Keywords: 3
Betrags-Pattern: 2
Nicht kategorisiert: 42

=== KATEGORIE-VERTEILUNG ===

  Supermarkt: 32 (21.3%)
  Kraftstoff: 18 (12.0%)
  Einkommen (positiver Betrag): 12 (8.0%)
  Online Shopping: 8 (5.3%)
  ...

=== NICHT KATEGORISIERTE ZAHLUNGSEMPFÄNGER ===

Amazon (12 Transaktionen)
  - Memo: 'Bestellung #123456' | Betrag: -45,99
  - Memo: 'Prime Mitgliedschaft' | Betrag: -7,99
  - Memo: 'Kindle Unlimited' | Betrag: -9,99
  ... und 9 weitere

Netflix (8 Transaktionen)
  - Memo: 'Monatsabo' | Betrag: -12,99
  ... und 7 weitere

=== ZUSAMMENFASSUNG ===

Kategorisierungsrate: 72% (Gut)

=== EMPFEHLUNGEN ===

1. Füge exakte Mappings hinzu für häufige Payees:
   - 'Amazon' (12 Transaktionen)
   - 'Netflix' (8 Transaktionen)

2. Füge Keywords hinzu für ähnliche Payees
3. Prüfe Einkommens-Erkennungsregeln
```

## CSV-Format-Unterstützung

Der Analyzer erkennt automatisch verschiedene CSV-Formate und Spaltennamen:

### Payee-Felder
- `Empfänger/Zahlungspflichtige`
- `Payee`
- `Begünstigter`
- `Zahlungsempfänger`
- `Empfänger`

### Memo-Felder  
- `Verwendungszweck`
- `Memo`
- `Beschreibung`
- `Description`

### Buchungstext-Felder
- `Buchungstext`
- `Transaction Type`
- `Art der Transaktion`

### Betrag-Felder
- `Betrag`
- `Amount`
- `Umsatz`

### IBAN-Felder (für Transfer-Erkennung)
- `IBAN`
- `Kontonummer`
- `Account`

## Mehrsprachigkeit

### Unterstützte Sprachen
- **Deutsch** (`de`): Vollständige Lokalisierung
- **Englisch** (`en`): Vollständige Lokalisierung

### Sprachspezifische Features
- Lokalisierte Ausgabetexte
- Sprachspezifische Standard-Keywords
- Automatische Fallbacks für fehlende Übersetzungen

## Technische Details

### Kategorisierungslogik-Reihenfolge
1. **Transfer-Erkennung**: IBAN-Matching mit eigenen Konten
2. **Einkommens-Erkennung**: Positive Beträge 
3. **Exakte Payee-Matches**: categoryMappings
4. **Payee-Keywords**: Schlüsselwörter im Payee-Namen
5. **Memo-Keywords**: Schlüsselwörter im Verwendungszweck
6. **Buchungstext-Keywords**: Schlüsselwörter im Buchungstext
7. **Betrags-Pattern**: Spezifische Betragsregeln

### Performance
- Effiziente Verarbeitung großer CSV-Dateien
- Optimierte Keyword-Matching-Algorithmen
- Speicherschonende Implementierung

### Kompatibilität
- **PowerShell 5.1** und **PowerShell 7.x**
- **Windows**, **Linux**, **macOS**
- Automatische Encoding-Erkennung (UTF-8, ANSI)

## Verbesserung der Kategorisierung

### Basierend auf Analyzer-Ergebnissen

1. **Exakte Mappings hinzufügen**
   ```json
   "categoryMappings": {
     "Amazon": "Online Shopping",
     "Netflix": "Streaming & Abos"
   }
   ```

2. **Keywords erweitern**
   ```json
   "categoryKeywords": {
     "Streaming & Abos": "netflix,spotify,prime,youtube"
   }
   ```

3. **Memo-Keywords optimieren**
   ```json
   "memoKeywords": {
     "Kraftstoff": "tanken,tankstelle,shell,aral,esso"
   }
   ```

## Fehlerbehebung

### Häufige Probleme

**Problem**: Keine CSV-Dateien gefunden
```
Lösung: Überprüfen Sie das CSV-Verzeichnis und Dateiberechtigungen
```

**Problem**: Niedrige Kategorisierungsrate
```
Lösung: Verwenden Sie die Analyzer-Empfehlungen zur Optimierung
```

**Problem**: Falsche Sprache in der Ausgabe
```
Lösung: Stellen Sie sicher, dass die entsprechende lang/*.json Datei existiert
```

### Debug-Modus
```powershell
# Detaillierte Fehlerausgabe
$VerbosePreference = "Continue"
$analyzer.AnalyzeAllTransactions("source")
```

## Integration in Workflows

### Regelmäßige Qualitätsprüfung
```powershell
# Wöchentliche Analyse
powershell -File CSV2Actual.ps1 -Analyze -Language de > analysis_$(Get-Date -Format 'yyyyMMdd').log
```

### Automatisierte Optimierung
```powershell
# Analyse + interaktive Kategorisierung
powershell -File CSV2Actual.ps1 -Analyze -Language de
powershell -File CSV2Actual.ps1 -Categorize -Language de
```

## Zukunftige Erweiterungen

- **Export-Funktionen**: CSV/JSON-Export der Analyseergebnisse
- **Trend-Analyse**: Kategorisierung über Zeiträume verfolgen
- **Machine Learning**: Automatische Keyword-Vorschläge
- **Dashboard**: Web-basierte Visualisierung
- **API-Integration**: Automatische Optimierung basierend auf Ergebnissen

---

*Der TransactionAnalyzer ist ein essentielles Werkzeug zur Optimierung der Kategorisierungsqualität in CSV2Actual und hilft dabei, eine möglichst hohe Automatisierungsrate zu erreichen.*