# 💰 CSV2Actual - Automatische Bank-CSV Konvertierung | Automatic Bank CSV Conversion

**🇩🇪 Deutsch** | **🇺🇸 English** (scroll down)

---

## 🇩🇪 Deutsch

Konvertiert deutsche Bank-CSV-Exporte automatisch zu Actual Budget mit intelligenter Kategorisierung und Transfer-Erkennung.

[![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B-blue)](https://docs.microsoft.com/en-us/powershell/)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![Auto-Discovery](https://img.shields.io/badge/Auto--Discovery-IBAN%20%7C%20Categories-brightgreen)](README.md)

### 🚀 Ein-Klick Start (Empfohlen)

```powershell
powershell -ExecutionPolicy Bypass -File CSV2Actual.ps1 -Silent
```

**Das war's!** Das Tool:
- 🔍 **Erkennt automatisch** alle IBANs und Konten aus Ihren CSV-Dateien
- 🏷️ **Kategorisiert automatisch** 60-70% aller Transaktionen  
- 🔄 **Erkennt Transfers** zwischen Ihren Konten
- 💰 **Berechnet Startguthaben** automatisch für Actual Budget Setup
- 📊 **Erstellt Statistiken** über verarbeitete Daten
- 🗂️ **Log-Management** mit automatischer Bereinigung
- 💾 **Speichert alles** im `actual_import/` Ordner für Actual Budget

### ✨ Wozu dieses Skript?

Stellen Sie sich vor, Sie möchten Ihre Konten neu in Actual Budget importieren. Warum sollten Sie das tun? Sie können die Kontodaten ja bequem per Bankabruf abholen - aber das geht nur wenige Wochen zurück!

Für eine Übersicht über einen längeren Zeitraum müssen Sie aus der Banking-Software exportierte CSV-Dateien, die möglichst weit zurückreichen, in Actual Budget importieren. Wenn Sie dies machen, müssen Sie für jede Buchung manuell die Kategorie anlegen, was eine Menge Arbeit bedeuten kann!

**Hier kommt dieses Skript ins Spiel!** Es durchsucht die CSV-Dateien, sucht interne Buchungen, markiert diese und versucht für alle weiteren Buchungen passende Kategorien zu finden. Dabei haben wir versucht, die Kategorien-Erkennung so clever wie möglich zu gestalten.

#### 🎯 **Was CSV2Actual für Sie bereitstellt:**

**a) 📊 Startguthaben-Liste**: Eine Liste von Kontenbezeichnungen mit Startdatum und Startsaldo. Mit diesen können die Konten in Actual Budget angelegt werden.

**b) 🏷️ Kategorien-Liste**: Eine Liste mit Kategorien, die Sie anlegen müssen, bevor Sie die vom Skript erzeugten CSV-Dateien importieren.

**c) 💾 Import-bereite CSV-Dateien**: CSV-Dateien, die direkt in Actual Budget importiert werden können! Sie haben zu großen Teilen bereits korrekte Kategorien, die die Arbeit mit Actual Budget erheblich erleichtern!

#### 🔍 **Automatische Konto-Erkennung**
- Analysiert Ihre CSV-Dateien und erkennt alle IBANs
- Erstellt automatisch Konto-Zuordnungen basierend auf Dateinamen
- Erkennt Benutzer-Namen (z.B. aus "Max_Girokonto.csv" → "Max")

#### 🏷️ **Intelligente Kategorisierung**
- **Transfer-Kategorien**: Geld zwischen Ihren eigenen Konten
- **Gehalts-Kategorien**: Automatische Arbeitgeber-Erkennung
- **Ausgaben-Kategorien**: REWE, EDEKA, Amazon, PayPal, etc.

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
```powershell
powershell -ExecutionPolicy Bypass -File CSV2Actual.ps1 -Silent
```

#### 3️⃣ **Ergebnisse importieren**
- Dateien aus `actual_import/` Ordner in Actual Budget importieren
- Kategorien automatisch erstellen lassen
- Startguthaben aus `starting_balances.txt` übernehmen

**Fertig!** 🎉

### 🔧 Kommandozeilen-Parameter

CSV2Actual bietet verschiedene Parameter für unterschiedliche Anwendungsfälle:

#### **Hauptskript: CSV2Actual.ps1**

```powershell
powershell -ExecutionPolicy Bypass -File CSV2Actual.ps1 [PARAMETER]
```

| Parameter | Kurz | Beschreibung | Beispiel |
|-----------|------|--------------|----------|
| `-Language` | `-l` | Sprache wählen (`de`, `en`) | `-Language de` |
| `-Silent` | `-s` | Minimale Ausgabe, ideal für Automatisierung | `-Silent` |
| `-DryRun` | `-n` | Vorschau ohne Dateien zu schreiben | `-DryRun` |
| `-Wizard` | `-w` | Interaktiver Wizard-Modus (Standard) | `-Wizard` |
| `-Interview` | `-i` | Setup-Interview erzwingen (Neukonfiguration) | `-Interview` |
| `-Help` | `-h` | Hilfe anzeigen | `-Help` |

#### **Bank CSV Processor: scripts/bank_csv_processor.ps1**

```powershell
powershell -ExecutionPolicy Bypass -File scripts/bank_csv_processor.ps1 [PARAMETER]
```

| Parameter | Kurz | Beschreibung | Beispiel |
|-----------|------|--------------|----------|
| `-Language` | `-l` | Sprache wählen (`de`, `en`) | `-Language de` |
| `-DryRun` | `-n` | Vorschau ohne Dateien zu schreiben | `-DryRun` |
| `-Silent` | `-q` | Minimale Ausgabe, schreibt nur Log-Datei | `-Silent` |
| `-Help` | `-h` | Hilfe anzeigen | `-Help` |
| `-AlternativeFormats` | | Erstellt zusätzliche CSV-Formate (Semikolon, Tab, ASCII) | `-AlternativeFormats` |

#### **Häufige Anwendungsfälle**

```powershell
# 🚀 Standard-Verwendung (Empfohlen):
powershell -ExecutionPolicy Bypass -File CSV2Actual.ps1 -Silent

# 🇩🇪 Deutsche Ausgabe mit interaktiver Führung:
powershell -ExecutionPolicy Bypass -File CSV2Actual.ps1 -Language de

# 👀 Vorschau was passieren würde (ohne Dateien zu schreiben):
powershell -ExecutionPolicy Bypass -File CSV2Actual.ps1 -DryRun -Silent

# 🔧 Setup neu konfigurieren (bei neuen Konten/Bank):
powershell -ExecutionPolicy Bypass -File CSV2Actual.ps1 -Interview

# 🏭 Nur CSV-Verarbeitung (ohne Wizard):
powershell -ExecutionPolicy Bypass -File scripts/bank_csv_processor.ps1 -Language de

# 📋 Alternative CSV-Formate erstellen (für problematische Importe):
powershell -ExecutionPolicy Bypass -File scripts/bank_csv_processor.ps1 -AlternativeFormats

# ❓ Hilfe und verfügbare Optionen anzeigen:
powershell -ExecutionPolicy Bypass -File CSV2Actual.ps1 -Help
```

#### **Kombinierte Parameter**

Parameter können kombiniert werden:

```powershell
# Deutsche Vorschau ohne Dateien zu schreiben:
powershell -ExecutionPolicy Bypass -File CSV2Actual.ps1 -Language de -DryRun

# Stille Verarbeitung mit alternativen Formaten:
powershell -ExecutionPolicy Bypass -File scripts/bank_csv_processor.ps1 -Silent -AlternativeFormats

# Setup-Interview auf Deutsch:
powershell -ExecutionPolicy Bypass -File CSV2Actual.ps1 -Language de -Interview
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
- **Execution Policy**: Verwenden Sie immer `-ExecutionPolicy Bypass`
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
- Bei Problemen: Interaktiven Modus verwenden (`-Language de`)

#### **Encoding-Probleme**
- Das Tool erkennt automatisch die meisten Encoding-Formate
- Bei anhaltenden Problemen: GitHub Issue erstellen mit Beispiel-CSV

---

## 🇺🇸 English

Automatically converts German bank CSV exports to Actual Budget with intelligent categorization and transfer detection.

### 🚀 One-Click Start (Recommended)

```powershell
powershell -ExecutionPolicy Bypass -File CSV2Actual.ps1 -Silent
```

**That's it!** The tool:
- 🔍 **Automatically detects** all IBANs and accounts from your CSV files
- 🏷️ **Automatically categorizes** 60-70% of all transactions  
- 🔄 **Detects transfers** between your accounts
- 💰 **Calculates starting balances** automatically for Actual Budget setup
- 📊 **Creates statistics** about processed data
- 🗂️ **Log management** with automatic cleanup
- 💾 **Saves everything** in the `actual_import/` folder for Actual Budget

### ✨ Why this script?

Imagine you want to import your accounts fresh into Actual Budget. Why would you want to do that? You can conveniently fetch account data via bank API - but that only goes back a few weeks!

For an overview over a longer period, you need to import CSV files exported from your banking software that reach back as far as possible into Actual Budget. When you do this, you have to manually create the category for each transaction, which can mean a lot of work!

**This is where this script comes into play!** It searches through the CSV files, finds internal transactions, marks them, and tries to find suitable categories for all other transactions. We've tried to make the category recognition as smart as possible.

#### 🎯 **What CSV2Actual provides for you:**

**a) 📊 Starting Balance List**: A list of account names with start date and starting balance. These can be used to create accounts in Actual Budget.

**b) 🏷️ Category List**: A list of categories that you need to create before importing the CSV files generated by the script.

**c) 💾 Import-ready CSV Files**: CSV files that can be imported directly into Actual Budget! They already have correct categories for the most part, which greatly simplifies working with Actual Budget!

#### 🔍 **Automatic Account Detection**
- Analyzes your CSV files and detects all IBANs
- Automatically creates account mappings based on filenames
- Detects user names (e.g., from "Max_Checking.csv" → "Max")

#### 🏷️ **Intelligent Categorization**
- **Transfer categories**: Money between your own accounts
- **Salary categories**: Automatic employer detection
- **Expense categories**: REWE, EDEKA, Amazon, PayPal, etc.

#### 📊 **Example Output**
```
STATISTICS:
  📁 Processed files: 8
  💳 Total transactions: 445
  🏷️ Categorized: 312 (70.1%)
  🔄 Transfers between accounts: 28
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
```powershell
powershell -ExecutionPolicy Bypass -File CSV2Actual.ps1 -Silent
```

#### 3️⃣ **Import results**
- Import files from `actual_import/` folder into Actual Budget
- Let categories be created automatically
- Use starting balances from `starting_balances.txt`

**Done!** 🎉

### 🔧 Command Line Parameters

CSV2Actual offers various parameters for different use cases:

#### **Main Script: CSV2Actual.ps1**

```powershell
powershell -ExecutionPolicy Bypass -File CSV2Actual.ps1 [PARAMETER]
```

| Parameter | Short | Description | Example |
|-----------|-------|-------------|---------|
| `-Language` | `-l` | Choose language (`de`, `en`) | `-Language en` |
| `-Silent` | `-s` | Minimal output, ideal for automation | `-Silent` |
| `-DryRun` | `-n` | Preview without writing files | `-DryRun` |
| `-Wizard` | `-w` | Interactive wizard mode (default) | `-Wizard` |
| `-Interview` | `-i` | Force setup interview (reconfiguration) | `-Interview` |
| `-Help` | `-h` | Show help | `-Help` |

#### **Bank CSV Processor: scripts/bank_csv_processor.ps1**

```powershell
powershell -ExecutionPolicy Bypass -File scripts/bank_csv_processor.ps1 [PARAMETER]
```

| Parameter | Short | Description | Example |
|-----------|-------|-------------|---------|
| `-Language` | `-l` | Choose language (`de`, `en`) | `-Language en` |
| `-DryRun` | `-n` | Preview without writing files | `-DryRun` |
| `-Silent` | `-q` | Minimal output, writes only log file | `-Silent` |
| `-Help` | `-h` | Show help | `-Help` |
| `-AlternativeFormats` | | Creates additional CSV formats (semicolon, tab, ASCII) | `-AlternativeFormats` |

#### **Common Use Cases**

```powershell
# 🚀 Standard usage (Recommended):
powershell -ExecutionPolicy Bypass -File CSV2Actual.ps1 -Silent

# 🇺🇸 English output with interactive guidance:
powershell -ExecutionPolicy Bypass -File CSV2Actual.ps1 -Language en

# 👀 Preview what would happen (without writing files):
powershell -ExecutionPolicy Bypass -File CSV2Actual.ps1 -DryRun -Silent

# 🔧 Reconfigure setup (for new accounts/bank):
powershell -ExecutionPolicy Bypass -File CSV2Actual.ps1 -Interview

# 🏭 CSV processing only (without wizard):
powershell -ExecutionPolicy Bypass -File scripts/bank_csv_processor.ps1 -Language en

# 📋 Create alternative CSV formats (for problematic imports):
powershell -ExecutionPolicy Bypass -File scripts/bank_csv_processor.ps1 -AlternativeFormats

# ❓ Show help and available options:
powershell -ExecutionPolicy Bypass -File CSV2Actual.ps1 -Help
```

#### **Combined Parameters**

Parameters can be combined:

```powershell
# English preview without writing files:
powershell -ExecutionPolicy Bypass -File CSV2Actual.ps1 -Language en -DryRun

# Silent processing with alternative formats:
powershell -ExecutionPolicy Bypass -File scripts/bank_csv_processor.ps1 -Silent -AlternativeFormats

# Setup interview in English:
powershell -ExecutionPolicy Bypass -File CSV2Actual.ps1 -Language en -Interview
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
- **Execution Policy**: Always use `-ExecutionPolicy Bypass`
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
- If problems persist: Use interactive mode (`-Language en`)

#### **Encoding problems**
- Tool automatically detects most encoding formats
- For persistent problems: Create GitHub issue with example CSV

---

## 🌍 Multi-Language Support

### Deutsch
```powershell
powershell -ExecutionPolicy Bypass -File CSV2Actual.ps1 -Language de -Silent
```

### English
```powershell
powershell -ExecutionPolicy Bypass -File CSV2Actual.ps1 -Language en -Silent
```

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