# 💰 CSV2Actual - Automatische Bank-CSV Konvertierung | Automatic Bank CSV Conversion

**🇩🇪 Deutsch** | **🇺🇸 English** (scroll down)

---

## 🇩🇪 Deutsch

Konvertiert deutsche Bank-CSV-Exporte automatisch zu Actual Budget mit **intelligenter CategoryEngine** und Transfer-Erkennung.

[![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B%20%7C%207.x-blue)](https://docs.microsoft.com/en-us/powershell/)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![CategoryEngine](https://img.shields.io/badge/CategoryEngine-I18n%20%7C%20Smart%20Rules-brightgreen)](README.md)
[![Cross-Platform](https://img.shields.io/badge/Cross--Platform-Windows%20%7C%20Linux%20%7C%20macOS-blue)](README.md)

### 🚀 Schnellstart

**Windows PowerShell:**
```powershell
powershell -ExecutionPolicy Bypass -File CSV2Actual.ps1 -Language de
```

**Linux/macOS PowerShell:**
```bash
pwsh -File CSV2Actual.ps1 -Language de
```

**Erste Nutzung (Setup):**
```powershell
powershell -File CSV2Actual.ps1 -Setup -Language de
```

### ✨ **Neue Features v1.3.0**

- 🧠 **CategoryEngine:** Intelligente, regel-basierte Kategorisierung mit Prioritätslogik
- 🌍 **Vollständige I18n:** Deutsche und englische Oberfläche + Kategorien
- 🔄 **Cross-Platform:** Windows PowerShell 5.1/7.x + Linux/macOS PowerShell 7.x
- 📊 **64%+ Kategorisierung:** Automatische Erkennung durch smarte Algorithmen
- 🎯 **Modulares Design:** Wartbar, testbar, erweiterbar

### 🎯 **Was CSV2Actual leistet:**

- 🔍 **Auto-Discovery:** Erkennt alle IBANs und Konten aus CSV-Dateien
- 🏷️ **Smart Categorization:** 64%+ automatische Kategorisierung mit CategoryEngine
- 🔄 **Transfer-Erkennung:** Automatische Erkennung interner Überweisungen
- 💰 **Startsaldo-Berechnung:** Automatische Berechnung für Actual Budget Setup
- 📊 **Detaillierte Statistiken:** Verarbeitungsübersicht und Kategorisierungsraten
- 🗂️ **Intelligentes Logging:** Strukturierte Logs mit automatischer Bereinigung
- 💾 **Ready-to-Import:** Fertige CSV-Dateien für direkten Actual Budget Import

### ✨ Wozu dieses Skript?

Stellen Sie sich vor, Sie möchten Ihre Konten neu in Actual Budget importieren. Warum sollten Sie das tun? Sie können die Kontodaten ja bequem per Bankabruf abholen - aber das geht nur wenige Wochen zurück!

Für eine Übersicht über einen längeren Zeitraum müssen Sie aus der Banking-Software exportierte CSV-Dateien, die möglichst weit zurückreichen, in Actual Budget importieren. Wenn Sie dies machen, müssen Sie für jede Buchung manuell die Kategorie anlegen, was eine Menge Arbeit bedeuten kann!

**Hier kommt dieses Skript ins Spiel!** Es durchsucht die CSV-Dateien, sucht interne Buchungen, markiert diese und versucht für alle weiteren Buchungen passende Kategorien zu finden. Dabei haben wir versucht, die Kategorien-Erkennung so clever wie möglich zu gestalten.

#### 🎯 **Was CSV2Actual für Sie bereitstellt:**

**a) 📊 Startsalden-Liste**: Eine Liste von Kontenbezeichnungen mit Startdatum und Anfangssaldo. Mit diesen können die Konten in Actual Budget korrekt angelegt werden.

**b) 🏷️ Kategorien-Liste**: Eine Liste mit Kategorien, die Sie anlegen müssen, bevor Sie die vom Skript erzeugten CSV-Dateien importieren.

**c) 💾 Import-bereite CSV-Dateien**: CSV-Dateien, die direkt in Actual Budget importiert werden können! Sie haben zu großen Teilen bereits korrekte Kategorien, die die Arbeit mit Actual Budget erheblich erleichtern!

#### 🔍 **Automatische Konto-Erkennung**
- Analysiert Ihre CSV-Dateien und erkennt alle IBANs
- Erstellt automatisch Konto-Zuordnungen basierend auf Dateinamen
- Erkennt Benutzer-Namen (z.B. aus "Max_Girokonto.csv" → "Max")

#### 🧠 **CategoryEngine - Intelligente Kategorisierung**

Die CategoryEngine ist das Herzstück der automatischen Kategorisierung mit einer **Prioritäts-basierten Regel-Engine:**

1. **🎯 Exakte Payee-Matches** (höchste Priorität)
   - Direkte Zuordnung von Empfängernamen zu Kategorien
   - Beispiel: "ALDI SUED" → "Supermarkt"

2. **🔍 Payee-Keywords** (mittlere Priorität)
   - Keyword-basierte Suche in Empfängernamen
   - Beispiel: "ALDI" → "Supermarkt", "SHELL" → "Kraftstoff"

3. **📝 Memo-Keywords** (niedrige Priorität)
   - Textsuche in Verwendungszweck/Memo-Feldern
   - Beispiel: "Tankstelle" → "Kraftstoff"

4. **💰 Buchungstext-Patterns** (Fallback)
   - Pattern-Matching für spezielle Transaktionstypen
   - Beispiel: "SB-Einzahlung" → "Bareinzahlungen"

**Automatische Kategorien:**
- **🔄 Transfer-Kategorien:** Geld zwischen Ihren eigenen Konten
- **💼 Gehalts-Kategorien:** Automatische Arbeitgeber-Erkennung  
- **🛒 Ausgaben-Kategorien:** ALDI, REWE, EDEKA, Amazon, PayPal, etc.
- **🏦 Banking-Kategorien:** Bankgebühren, Kapitalerträge, Steuern
- **🌍 Mehrsprachig:** Deutsche und englische Kategorie-Namen

**Konfiguration:**
- Kategorien werden in `config.local.json` definiert
- Keywords per Kategorie: `"Supermarkt": "EDEKA,ALDI,REWE,Penny,Netto,LIDL"`
- Automatische Speicherung und Wiederverwendung der Regeln

#### 📊 **Beispiel-Ausgabe**
```
STATISTIKEN:
  📁 Verarbeitete Dateien: 8
  💳 Gesamte Buchungen: 445
  🏷️ Kategorisiert: 312 (70.1%)
  🔄 Transfers zwischen Konten: 28
```

### 🏦 Unterstützte Banken

- ✅ **Volksbank/Genossenschaftsbanken** (vollständig getestet)
- ✅ **Sparkassen** (Community-Format verfügbar)
- ✅ **Alle CSV-Formate** mit automatischer Spalten-Erkennung

### 📋 Schnellstart-Anleitung

#### 1️⃣ **CSV-Dateien bereitstellen**
```
source/
├── Girokonto.csv
├── Sparkonto.csv
└── Kreditkarte.csv
```

#### 2️⃣ **Tool ausführen**
**Windows:**
```powershell
powershell -ExecutionPolicy Bypass -File CSV2Actual.ps1
```

**Linux/macOS:**
```bash
pwsh -File CSV2Actual.ps1
```

#### 3️⃣ **Konten in Actual Budget einrichten**
- **WICHTIG:** Zuerst Konten anhand der `starting_balances.txt` anlegen
- Die exakten Kontonamen und Startsalden aus der Datei verwenden
- Startdatum für jedes Konto entsprechend setzen

#### 4️⃣ **Ergebnisse importieren**
- Dateien aus `actual_import/` Ordner in Actual Budget importieren
- Kategorien automatisch erstellen lassen

**Fertig!** 🎉

### 🔧 Kommandozeilen-Parameter

CSV2Actual bietet verschiedene Parameter für unterschiedliche Anwendungsfälle:

#### **Hauptskript: CSV2Actual.ps1**

```powershell
powershell -ExecutionPolicy Bypass -File CSV2Actual.ps1 [PARAMETER]
```

| Parameter | Kurz | Beschreibung | Beispiel |
|-----------|------|--------------|----------|
| `-Language` | `-l` | **Sprache:** `de` (Deutsch) oder `en` (English) | `-Language de` |
| `-Setup` | `-s` | **Erstkonfiguration:** Erzwingt vollständiges Setup (Konten, Kategorien, Startdaten) | `-Setup` |
| `-DryRun` | `-n` | **Vorschau-Modus:** Zeigt nur an was passieren würde, schreibt keine Dateien | `-DryRun` |
| `-Categorize` | `-c` | **Interaktive Kategorisierung:** Startet direkt den Kategorie-Scanner | `-Categorize` |
| `-Help` | `-h` | **Hilfe:** Zeigt Parameterübersicht | `-Help` |
| `-NoScreenClear` | | **Debug-Modus:** Deaktiviert Screen-Clearing für Fehleranalyse | `-NoScreenClear` |

#### **Bank CSV Processor: scripts/bank_csv_processor.ps1**

```powershell
powershell -ExecutionPolicy Bypass -File scripts/bank_csv_processor.ps1 [PARAMETER]
```

| Parameter | Kurz | Beschreibung | Beispiel |
|-----------|------|--------------|----------|
| `-Language` | `-l` | Sprache wählen (`de`, `en`) | `-Language de` |
| `-DryRun` | `-n` | Vorschau ohne Dateien zu schreiben | `-DryRun` |
| `-Help` | `-h` | Hilfe anzeigen | `-Help` |
| `-AlternativeFormats` | | Erstellt zusätzliche CSV-Formate (Semikolon, Tab, ASCII) | `-AlternativeFormats` |

#### **Häufige Anwendungsfälle**

**Windows:**
```powershell
# 🚀 Standard-Verwendung (Empfohlen):
powershell -ExecutionPolicy Bypass -File CSV2Actual.ps1

# 🇩🇪 Deutsche Ausgabe:
powershell -ExecutionPolicy Bypass -File CSV2Actual.ps1 -Language de

# 👀 Vorschau was passieren würde (ohne Dateien zu schreiben):
powershell -ExecutionPolicy Bypass -File CSV2Actual.ps1 -DryRun -Language de

# 🔧 Setup neu konfigurieren (First run erzwingen):
powershell -ExecutionPolicy Bypass -File CSV2Actual.ps1 -Setup -Language de

# 🏷️ Direkt zur interaktiven Kategorisierung:
powershell -ExecutionPolicy Bypass -File CSV2Actual.ps1 -Categorize -Language de
```

**Linux/macOS:**
```bash
# 🚀 Standard-Verwendung (Empfohlen):
pwsh -File CSV2Actual.ps1

# 🇩🇪 Deutsche Ausgabe:
pwsh -File CSV2Actual.ps1 -Language de

# 👀 Vorschau was passieren würde (ohne Dateien zu schreiben):
pwsh -File CSV2Actual.ps1 -DryRun -Language de

# 🔧 Setup neu konfigurieren (First run erzwingen):
pwsh -File CSV2Actual.ps1 -Setup -Language de

# 🏷️ Direkt zur interaktiven Kategorisierung:
pwsh -File CSV2Actual.ps1 -Categorize -Language de
```

**Zusätzliche Optionen (alle Plattformen):**
```bash
# 🏭 Nur CSV-Verarbeitung (direkt):
pwsh -File scripts/bank_csv_processor.ps1 -Language de

# 📋 Alternative CSV-Formate erstellen (für problematische Importe):
pwsh -File scripts/bank_csv_processor.ps1 -AlternativeFormats

# ❓ Hilfe und verfügbare Optionen anzeigen:
pwsh -File CSV2Actual.ps1 -Help
```

#### **Kombinierte Parameter**

Parameter können kombiniert werden:

```powershell
# Deutsche Vorschau ohne Dateien zu schreiben:
powershell -ExecutionPolicy Bypass -File CSV2Actual.ps1 -Language de -DryRun

# Direkte Verarbeitung mit alternativen Formaten:
powershell -ExecutionPolicy Bypass -File scripts/bank_csv_processor.ps1 -AlternativeFormats

# Setup auf Deutsch erzwingen:
powershell -ExecutionPolicy Bypass -File CSV2Actual.ps1 -Language de -Setup
```

### 🔐 Datenschutz & Sicherheit

- ✅ **Lokale Verarbeitung** - Ihre Daten verlassen nie Ihren Computer
- ✅ **Automatische .gitignore** - Verhindert versehentliche Uploads persönlicher Daten
- ✅ **Beispiel-Konfiguration** - Repository enthält nur anonyme Beispiel-IBANs
- ✅ **config.local.json** - Ihre echten IBANs bleiben lokal und privat

### 🏗️ Community & Erweiterungen

#### **Bank-Formate hinzufügen**
Das Tool erkennt automatisch die meisten CSV-Formate. Für spezielle Banken können Community-Formate in `community/csv-formats/` hinzugefügt werden.

#### **Kategorien anpassen**
Kategorien werden automatisch aus den Transaktionsdaten erkannt. Für spezielle Kategorisierungen können Community-Sets in `community/categories/` erstellt werden.

### ⚠️ Systemanforderungen

- **Windows 10/11** mit PowerShell 5.1+ oder PowerShell Core 7+
- **Linux/macOS** mit PowerShell Core 7+ (pwsh)
- **Execution Policy**: Verwenden Sie unter Windows immer `-ExecutionPolicy Bypass`
- **Encoding**: UTF-8 für deutsche Umlaute

### 🆘 Problemlösung

#### **"Skript ist nicht digital signiert"**
```powershell
# Immer verwenden:
powershell -ExecutionPolicy Bypass -File CSV2Actual.ps1
```

#### **Keine IBANs erkannt**
- Prüfen Sie, dass CSV-Dateien IBAN-Spalten enthalten
- Tool analysiert automatisch die häufigsten Spalten-Namen
- Bei Problemen: Setup-Modus verwenden (`-Setup`)

#### **Encoding-Probleme**
- Das Tool erkennt automatisch die meisten Encoding-Formate
- Bei anhaltenden Problemen: GitHub Issue erstellen mit Beispiel-CSV

---

## 🇺🇸 English

Automatically converts German bank CSV exports to Actual Budget with **intelligent CategoryEngine** and transfer detection.

[![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B%20%7C%207.x-blue)](https://docs.microsoft.com/en-us/powershell/)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![CategoryEngine](https://img.shields.io/badge/CategoryEngine-I18n%20%7C%20Smart%20Rules-brightgreen)](README.md)
[![Cross-Platform](https://img.shields.io/badge/Cross--Platform-Windows%20%7C%20Linux%20%7C%20macOS-blue)](README.md)

### ✨ **New Features v1.3.0**

- 🧠 **CategoryEngine:** Intelligent, rule-based categorization with priority logic
- 🌍 **Full I18n:** German and English interface + categories
- 🔄 **Cross-Platform:** Windows PowerShell 5.1/7.x + Linux/macOS PowerShell 7.x
- 📊 **64%+ Categorization:** Automatic recognition through smart algorithms
- 🎯 **Modular Design:** Maintainable, testable, extensible

### 🚀 One-Click Start (Recommended)

**Windows:**
```powershell
powershell -ExecutionPolicy Bypass -File CSV2Actual.ps1
```

**Linux/macOS:**
```bash
pwsh -File CSV2Actual.ps1
```

### 🎯 **What CSV2Actual delivers:**

- 🔍 **Auto-Discovery:** Detects all IBANs and accounts from CSV files
- 🏷️ **Smart Categorization:** 64%+ automatic categorization with CategoryEngine
- 🔄 **Transfer Detection:** Automatic detection of internal transfers
- 💰 **Starting Balance Calculation:** Automatic calculation for Actual Budget setup
- 📊 **Detailed Statistics:** Processing overview and categorization rates
- 🗂️ **Intelligent Logging:** Structured logs with automatic cleanup
- 💾 **Ready-to-Import:** Finished CSV files for direct Actual Budget import

### ✨ Why this script?

Imagine you want to import your accounts fresh into Actual Budget. Why would you want to do that? You can conveniently fetch account data via bank API - but that only goes back a few weeks!

For an overview over a longer period, you need to import CSV files exported from your banking software that reach back as far as possible into Actual Budget. When you do this, you have to manually create the category for each transaction, which can mean a lot of work!

**This is where this script comes into play!** It searches through the CSV files, finds internal transactions, marks them, and tries to find suitable categories for all other transactions. We've tried to make the category recognition as smart as possible.

#### 🎯 **What CSV2Actual provides for you:**

**a) 📊 Account Balance List**: A list of account names with start date and initial balance. These can be used to create accounts in Actual Budget.

**b) 🏷️ Category List**: A list of categories that you need to create before importing the CSV files generated by the script.

**c) 💾 Import-ready CSV Files**: CSV files that can be imported directly into Actual Budget! They already have correct categories for the most part, which greatly simplifies working with Actual Budget!

#### 🔍 **Automatic Account Detection**
- Analyzes your CSV files and detects all IBANs
- Automatically creates account mappings based on filenames
- Detects user names (e.g., from "Max_Checking.csv" → "Max")

#### 🧠 **CategoryEngine - Intelligent Categorization**

The CategoryEngine is the core of automatic categorization with a **Priority-based Rule Engine:**

1. **🎯 Exact Payee Matches** (highest priority)
   - Direct mapping of payee names to categories
   - Example: "ALDI SUED" → "Groceries"

2. **🔍 Payee Keywords** (medium priority)
   - Keyword-based search in payee names
   - Example: "ALDI" → "Groceries", "SHELL" → "Gas"

3. **📝 Memo Keywords** (low priority)
   - Text search in memo/reference fields
   - Example: "Gas Station" → "Gas"

4. **💰 Transaction Patterns** (fallback)
   - Pattern matching for special transaction types
   - Example: "ATM Deposit" → "Cash Deposits"

**Automatic Categories:**
- **🔄 Transfer Categories:** Money between your own accounts
- **💼 Salary Categories:** Automatic employer detection
- **🛒 Expense Categories:** ALDI, REWE, EDEKA, Amazon, PayPal, etc.
- **🏦 Banking Categories:** Bank fees, capital gains, taxes
- **🌍 Multi-language:** German and English category names

**Configuration:**
- Categories are defined in `config.local.json`
- Keywords per category: `"Groceries": "EDEKA,ALDI,REWE,Penny,Netto,LIDL"`
- Automatic saving and reuse of rules

#### 📊 **Example Output**
```
STATISTICS:
  📁 Processed files: 11
  💳 Total transactions: 618
  🏷️ Categorized: 396 (64.1%)
  🔄 Transfers between accounts: 214
```

### 🏦 Supported Banks

- ✅ **Volksbank/Cooperative banks** (fully tested)
- ✅ **Sparkassen** (Community format available)
- ✅ **All CSV formats** with automatic column detection

### 📋 Quick Start Guide

#### 1️⃣ **Provide CSV files**
```
source/
├── Checking.csv
├── Savings.csv
└── CreditCard.csv
```

#### 2️⃣ **Run tool**
**Windows:**
```powershell
powershell -ExecutionPolicy Bypass -File CSV2Actual.ps1
```

**Linux/macOS:**
```bash
pwsh -File CSV2Actual.ps1
```

#### 3️⃣ **Set up accounts in Actual Budget**
- **IMPORTANT:** First create accounts based on `starting_balances.txt`
- Use the exact account names and starting balances from the file
- Set the start date for each account accordingly

#### 4️⃣ **Import results**
- Import files from `actual_import/` folder into Actual Budget
- Let categories be created automatically

**Done!** 🎉

### 🔧 Command Line Parameters

CSV2Actual offers various parameters for different use cases:

#### **Main Script: CSV2Actual.ps1**

```powershell
powershell -ExecutionPolicy Bypass -File CSV2Actual.ps1 [PARAMETER]
```

| Parameter | Short | Description | Example |
|-----------|-------|-------------|---------|
| `-Language` | `-l` | **Language:** `de` (German) or `en` (English) | `-Language en` |
| `-Setup` | `-s` | **Initial setup:** Force complete setup (accounts, categories, start dates) | `-Setup` |
| `-DryRun` | `-n` | **Preview mode:** Shows only what would happen, writes no files | `-DryRun` |
| `-Categorize` | `-c` | **Interactive categorization:** Starts directly the category scanner | `-Categorize` |
| `-Help` | `-h` | **Help:** Shows parameter overview | `-Help` |
| `-NoScreenClear` | | **Debug mode:** Disables screen clearing for error analysis | `-NoScreenClear` |

#### **Bank CSV Processor: scripts/bank_csv_processor.ps1**

```powershell
powershell -ExecutionPolicy Bypass -File scripts/bank_csv_processor.ps1 [PARAMETER]
```

| Parameter | Short | Description | Example |
|-----------|-------|-------------|---------|
| `-Language` | `-l` | Choose language (`de`, `en`) | `-Language en` |
| `-DryRun` | `-n` | Preview without writing files | `-DryRun` |
| `-Help` | `-h` | Show help | `-Help` |
| `-AlternativeFormats` | | Creates additional CSV formats (semicolon, tab, ASCII) | `-AlternativeFormats` |

#### **Common Use Cases**

**Windows:**
```powershell
# 🚀 Standard usage (Recommended):
powershell -ExecutionPolicy Bypass -File CSV2Actual.ps1

# 🇺🇸 English output:
powershell -ExecutionPolicy Bypass -File CSV2Actual.ps1 -Language en

# 👀 Preview what would happen (without writing files):
powershell -ExecutionPolicy Bypass -File CSV2Actual.ps1 -DryRun

# 🔧 Reconfigure setup (force First run):
powershell -ExecutionPolicy Bypass -File CSV2Actual.ps1 -Setup

# 🏷️ Directly to interactive categorization:
powershell -ExecutionPolicy Bypass -File CSV2Actual.ps1 -Categorize
```

**Linux/macOS:**
```bash
# 🚀 Standard usage (Recommended):
pwsh -File CSV2Actual.ps1

# 🇺🇸 English output:
pwsh -File CSV2Actual.ps1 -Language en

# 👀 Preview what would happen (without writing files):
pwsh -File CSV2Actual.ps1 -DryRun

# 🔧 Reconfigure setup (force First run):
pwsh -File CSV2Actual.ps1 -Setup

# 🏷️ Directly to interactive categorization:
pwsh -File CSV2Actual.ps1 -Categorize
```

**Additional options (all platforms):**
```bash
# 🏭 CSV processing only (direct):
pwsh -File scripts/bank_csv_processor.ps1 -Language en

# 📋 Create alternative CSV formats (for problematic imports):
pwsh -File scripts/bank_csv_processor.ps1 -AlternativeFormats

# ❓ Show help and available options:
pwsh -File CSV2Actual.ps1 -Help
```

#### **Combined Parameters**

Parameters can be combined:

```powershell
# English preview without writing files:
powershell -ExecutionPolicy Bypass -File CSV2Actual.ps1 -Language en -DryRun

# Direct processing with alternative formats:
powershell -ExecutionPolicy Bypass -File scripts/bank_csv_processor.ps1 -AlternativeFormats

# Force setup in English:
powershell -ExecutionPolicy Bypass -File CSV2Actual.ps1 -Language en -Setup

# Direct categorization in English:
powershell -ExecutionPolicy Bypass -File CSV2Actual.ps1 -Language en -Categorize
```

### 🔐 Privacy & Security

- ✅ **Local processing** - Your data never leaves your computer
- ✅ **Automatic .gitignore** - Prevents accidental uploads of personal data
- ✅ **Example configuration** - Repository contains only anonymous example IBANs
- ✅ **config.local.json** - Your real IBANs stay local and private

### 🏗️ Community & Extensions

#### **Adding Bank Formats**
The tool automatically detects most CSV formats. For special banks, community formats can be added in `community/csv-formats/`.

#### **Customizing Categories**
Categories are automatically detected from transaction data. For special categorizations, community sets can be created in `community/categories/`.

### ⚠️ System Requirements

- **Windows 10/11** with PowerShell 5.1+ or PowerShell Core 7+
- **Linux/macOS** with PowerShell Core 7+ (pwsh)
- **Execution Policy**: Always use `-ExecutionPolicy Bypass` on Windows
- **Encoding**: UTF-8 for German umlauts

### 🆘 Troubleshooting

#### **"Script is not digitally signed"**
```powershell
# Always use:
powershell -ExecutionPolicy Bypass -File CSV2Actual.ps1
```

#### **No IBANs detected**
- Check that CSV files contain IBAN columns
- Tool automatically analyzes the most common column names
- If problems persist: Use setup mode (`-Setup`)

#### **Encoding problems**
- Tool automatically detects most encoding formats
- For persistent problems: Create GitHub issue with example CSV

---

## 🌍 Multi-Language Support

### Deutsch
**Windows:**
```powershell
powershell -ExecutionPolicy Bypass -File CSV2Actual.ps1 -Language de
```
**Linux/macOS:**
```bash
pwsh -File CSV2Actual.ps1 -Language de
```

### English
**Windows:**
```powershell
powershell -ExecutionPolicy Bypass -File CSV2Actual.ps1 -Language en
```
**Linux/macOS:**
```bash
pwsh -File CSV2Actual.ps1 -Language en
```

---

---

## 🤖👨‍💻 AI-Collaborative Development Case Study

CSV2Actual ist ein **Proof-of-Concept für Human-AI Collaborative Development**. Dieses Projekt demonstriert die Möglichkeiten und Grenzen der kooperativen Softwareentwicklung zwischen Mensch und KI.

### 📊 Projekt-Highlights:
- **2000+ Lines of Code** (75% AI-generiert, 25% human-guided)
- **Enterprise-Level Features**: Modulare Klassen, i18n, Community-Sharing
- **Entwicklungszeit**: 4+ Wochen statt geschätzte 8+ Wochen traditional
- **Reale Kostenanalyse**: $357+ monatlich für AI-Entwicklung dokumentiert

### 📖 Vollständige Dokumentation:
- **[AI-Collaboration Overview](docs/ai-collaboration/README.md)** - Überblick und Quick Start
- **[Development Journey](docs/ai-collaboration/development-journey.md)** - Chronologische Entwicklungsreise
- **[Cost Analysis](docs/ai-collaboration/cost-analysis.md)** - Prompt-Statistiken und Kostenanalyse
- **[Benefits & Challenges](docs/ai-collaboration/benefits-challenges.md)** - Lessons Learned
- **[Technical Insights](docs/ai-collaboration/technical-insights.md)** - Code-Patterns und Komplexität
- **[Live Metrics](docs/ai-collaboration/metrics.json)** - Entwicklungs-Statistiken

### 🎯 Für andere Entwickler:
Dieses Projekt zeigt, wie komplexe Software-Tools durch Human-AI Collaboration in einem Bruchteil der traditionellen Zeit entwickelt werden können. Die vollständige Dokumentation bietet praktische Einblicke für eigene AI-unterstützte Projekte.

---

## 📄 License | Lizenz

MIT License - See [LICENSE](LICENSE) for details. | Siehe [LICENSE](LICENSE) für Details.

---

## 🤝 Contributing | Beitragen

Contributions are welcome! | Beiträge sind willkommen! This repository is the **End-User Release**. | Dieses Repository ist der **End-User Release**. For developers: | Für Entwickler:

### **End-User Contributions:**
- **Bank format definitions** in `community/csv-formats/` | **Bank-Format-Definitionen** in `community/csv-formats/`
- **Categorization sets** in `community/categories/` | **Kategorisierungs-Sets** in `community/categories/`
- **Feature requests** via [GitHub Issues](https://github.com/sTLAs/CSV2Actual/issues) | **Feature-Requests** via [GitHub Issues](https://github.com/sTLAs/CSV2Actual/issues)

### **Developer Contributions:**
- **Code contributions:** See [DEVELOPMENT.md](DEVELOPMENT.md) for setup | **Code-Beiträge:** Siehe [DEVELOPMENT.md](DEVELOPMENT.md) für Setup
- **Testing:** With your own CSV data and feedback | **Testing:** Mit eigenen CSV-Daten und Feedback
- **Documentation:** Improvements and translations | **Dokumentation:** Verbesserungen und Übersetzungen

**📝 Important:** This repository focuses on end-users. Development tools are deliberately excluded for a clean user experience. | **📝 Wichtig:** Dieses Repository fokussiert sich auf End-User. Entwickler-Tools sind bewusst ausgeschlossen für eine saubere User-Experience.

---

*💰 CSV2Actual - Automate your Actual Budget imports | Automatisieren Sie Ihre Actual Budget Imports*