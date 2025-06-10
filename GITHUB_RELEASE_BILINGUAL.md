# 🚀 CSV2Actual v1.0.5 - Feature Enhancement Release

*[English version below](#english-version)*

## 🇩🇪 **Deutsche Version**

### 🎯 **Feature Enhancement v1.0.5 Änderungen**

**✨ Neue Features:**
- 📊 **Umfassende Statistik-Anzeige** - Zeigt verarbeitete Dateien, Buchungen, Kategorisierung mit Emoji-Symbolen (📁💳🏷️🔄)
- 🇩🇪 **Verbesserte deutsche Übersetzungen** - "ERFOLG" statt "SUCCESS" für authentisch deutsche Ausgabe  
- 🔧 **WSL → Windows PowerShell Test-Framework** - Nahtloses Testen von Windows PowerShell aus WSL heraus
- 🌍 **Community-Beiträge erweitert** - Volksbank (DE) Format + Deutsche Paar-Kategorien

**🔧 Verbesserungen:**
- ✅ **PowerShell Syntax-Probleme behoben** - Vollständige WSL/Windows Kompatibilität
- ✅ **Präzise Log-Analyse** - Genaue Statistik-Extraktion aus Processor-Logs
- ✅ **Mathematische Präzision** - Korrekte Prozentberechnung bei Kategorisierung
- ✅ **Encoding-Behandlung** - Optimiert für WSL ↔ Windows Dateisysteme

### 🎉 Was ist CSV2Actual?

CSV2Actual ist ein PowerShell-Tool, das **deutsche Bank-CSV-Exporte** in Actual Budget-kompatible CSV-Dateien mit **intelligenter automatischer Kategorisierung** konvertiert.

### ✨ **Hauptfunktionen**

#### 🏦 **Bank-Unterstützung**
- ✅ **Volksbank/Genossenschaftsbanken** (primär getestet)
- ✅ **Sparkassen** 
- ✅ **Internationale CSV-Formate** mit automatischer Spaltenerkennung
- 🔍 **Automatische Encoding-Erkennung** (UTF-8, Windows-1252, etc.)

#### 🏷️ **Intelligente Kategorisierung**
- 🎯 **60-70% automatische Kategorisierung** aller Transaktionen
- 🔄 **Automatische Überweisungserkennung** zwischen eigenen Konten via IBAN
- 👥 **Personalisierte Gehaltserkennung** (anpassbare Muster)
- 📊 **39 vordefinierte Kategorien** für alle wichtigen Ausgabentypen

#### 🌍 **Mehrsprachigkeit**
- 🇩🇪 **Vollständige deutsche Sprachunterstützung**
- 🇬🇧 **Komplette englische Benutzeroberfläche**
- 🔧 **Dynamisches Spalten-Mapping** - funktioniert mit deutschen und internationalen CSV-Formaten

#### 🧙‍♂️ **Benutzerfreundlich**
- 🎯 **Interaktiver 5-Schritt-Wizard** für Anfänger
- ⚡ **Direkte CLI-Verarbeitung** für Power-User
- 👁️ **Dry-Run-Modus** für sicheres Testen
- 🔇 **Silent-Modus** mit umfassendem Logging

### 🚀 **Schnellstart**

#### Option 1: Interaktiver Wizard (Empfohlen für Anfänger)
```bash
# Deutsche Version
powershell -ExecutionPolicy Bypass -File CSV2Actual.ps1 -Language de

# Englische Version  
powershell -ExecutionPolicy Bypass -File CSV2Actual.ps1 -Language en
```

#### Option 2: Direkte Verarbeitung (für Fortgeschrittene)
```bash
# Vorschau Ihrer Daten (empfohlen)
powershell -ExecutionPolicy Bypass -File bank_csv_processor.ps1 -DryRun

# Dateien verarbeiten
powershell -ExecutionPolicy Bypass -File bank_csv_processor.ps1
```

### 📊 **Erwartete Ergebnisse**

Basierend auf Tests mit echten deutschen Bankdaten:

```
📈 Performance-Metriken:
   ✅ Kategorisierungsrate: 60-70%
   ✅ Überweisungserkennung: 95%+
   ✅ Verarbeitungsgeschwindigkeit: ~1-2 Sekunden pro Datei
   ✅ Sprachabdeckung: Vollständig DE/EN
```

### 🔧 **Systemanforderungen**

- **Windows 10/11** mit PowerShell 5.1+
- **PowerShell Core 7.0+** (Linux/macOS-Unterstützung)
- **Keine zusätzlichen Abhängigkeiten** erforderlich

### 🤝 **Community-Beiträge willkommen!**

Helfen Sie dabei, CSV2Actual für mehr Banken und Anwendungsfälle zu erweitern:

- 🏦 **Reichen Sie das CSV-Format Ihrer Bank ein** via GitHub Issues
- 🏷️ **Teilen Sie Kategorie-Sets** für verschiedene Berufe/Länder
- 🌍 **Fügen Sie neue Sprachen hinzu** mit Übersetzungsdateien
- 🔧 **Keine Programmiererfahrung erforderlich!**

---

## 🇬🇧 **English Version** {#english-version}

### 🎯 **Feature Enhancement v1.0.5 Changes**

**✨ New Features:**
- 📊 **Comprehensive statistics display** - Shows processed files, transactions, categorization with emoji symbols (📁💳🏷️🔄)
- 🇩🇪 **Enhanced German translations** - "ERFOLG" instead of "SUCCESS" for authentic German output
- 🔧 **WSL → Windows PowerShell testing framework** - Seamless testing of Windows PowerShell from WSL
- 🌍 **Extended community contributions** - Volksbank (DE) format + German couple categories

**🔧 Improvements:**
- ✅ **Fixed PowerShell syntax issues** - Full WSL/Windows compatibility
- ✅ **Precise log analysis** - Accurate statistics extraction from processor logs
- ✅ **Mathematical precision** - Correct percentage calculation for categorization
- ✅ **Encoding handling** - Optimized for WSL ↔ Windows filesystems

### 🎉 What is CSV2Actual?

CSV2Actual is a PowerShell tool that converts **German bank CSV exports** into Actual Budget-compatible CSV files with **intelligent automatic categorization**.

### ✨ **Key Features**

#### 🏦 **Bank Support**
- ✅ **Volksbank/Cooperative Banks** (primary tested)
- ✅ **Sparkassen (Savings Banks)**
- ✅ **International CSV formats** with automatic column detection
- 🔍 **Automatic encoding detection** (UTF-8, Windows-1252, etc.)

#### 🏷️ **Smart Categorization**
- 🎯 **60-70% automatic categorization** of all transactions
- 🔄 **Automatic transfer recognition** between your accounts via IBAN mapping
- 👥 **Personalized salary recognition** (customizable patterns)
- 📊 **39 predefined categories** covering all major expense types

#### 🌍 **Internationalization**
- 🇩🇪 **Full German language support**
- 🇬🇧 **Complete English interface**
- 🔧 **Dynamic column mapping** - works with German and international CSV formats

#### 🧙‍♂️ **User-Friendly**
- 🎯 **Interactive 5-step wizard** for beginners
- ⚡ **Direct CLI processing** for power users
- 👁️ **Dry-run mode** for safe testing
- 🔇 **Silent mode** with comprehensive logging

### 🚀 **Quick Start**

#### Option 1: Interactive Wizard (Recommended for beginners)
```bash
# English version (default)
powershell -ExecutionPolicy Bypass -File CSV2Actual.ps1

# German version
powershell -ExecutionPolicy Bypass -File CSV2Actual.ps1 -Language de
```

#### Option 2: Direct Processing (For advanced users)
```bash
# Preview your data (recommended)
powershell -ExecutionPolicy Bypass -File bank_csv_processor.ps1 -DryRun

# Process your files
powershell -ExecutionPolicy Bypass -File bank_csv_processor.ps1
```

### 📊 **Expected Results**

Based on testing with real German bank data:

```
📈 Performance Metrics:
   ✅ Categorization Rate: 60-70%
   ✅ Transfer Recognition: 95%+
   ✅ Processing Speed: ~1-2 seconds per file
   ✅ Language Coverage: Complete DE/EN
```

### 🔧 **System Requirements**

- **Windows 10/11** with PowerShell 5.1+
- **PowerShell Core 7.0+** (Linux/macOS support)
- **No additional dependencies** required

### 🤝 **Community Contributions Welcome!**

Help expand CSV2Actual for more banks and use cases:

- 🏦 **Submit your bank's CSV format** via GitHub Issues
- 🏷️ **Share category sets** for different professions/countries
- 🌍 **Add new languages** with translation files
- 🔧 **No coding experience required!**

---

## 📋 **Setup Instructions / Einrichtungsanleitung**

### 🇩🇪 **Deutsch:**
1. **Laden Sie die neueste Version herunter** und entpacken Sie sie
2. **Legen Sie Ihre Bank-CSV-Dateien** in den `source/` Ordner
3. **Führen Sie den Wizard aus:** `CSV2Actual.ps1 -Language de`
4. **Importieren Sie die Ergebnisse** aus `actual_import/` in Actual Budget

### 🇬🇧 **English:**
1. **Download the latest release** and extract it
2. **Place your bank CSV files** in the `source/` folder
3. **Run the wizard:** `CSV2Actual.ps1 -Language en`
4. **Import the results** from `actual_import/` into Actual Budget

## 📄 **License / Lizenz**

This project is licensed under the **MIT License** / Dieses Projekt ist unter der **MIT-Lizenz** lizenziert.

---

**Made with ❤️ for the Actual Budget Community by [sTLAs](https://github.com/stlas)**

🌟 **Like this tool? Give us a star on GitHub! / Gefällt Ihnen dieses Tool? Geben Sie uns einen Stern auf GitHub!**