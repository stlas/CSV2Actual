# Changelog

All notable changes to CSV2Actual will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### ✨ Planned
- Enhanced CSV format auto-detection
- Additional German bank support
- Performance optimizations

## [1.3.0] - 2025-06-14

### 🚀 Major Features
- **CategoryManager**: Vollständiges modulares Kategorien-Management-System (634 LOC)
- **Multi-Set-Loading**: Laden und Zusammenführen mehrerer Kategorien-Sets zu persönlichen Bibliotheken
- **Community-Sharing**: Import/Export von Kategorien-Sets für Community-Austausch
- **Session-Management**: Automatische Sicherung und Wiederherstellung bei großen Datasets
- **Conflict Resolution**: Interaktive Konflikterkennung und -auflösung beim Merger von Sets

### 🌍 Internationalization  
- **Vollständige i18n**: Alle hardcodierten Strings durch i18n-System ersetzt
- **CategoryManager i18n**: Vollständige Übersetzung aller CategoryManager-Features
- **Erweiterte Sprachdateien**: 200+ neue Übersetzungsschlüssel hinzugefügt

### 🤖 AI-Collaboration
- **AI-Prompt-Tracker**: Universelles Tool für Kostenüberwachung bei AI-Entwicklung
- **Case Study Dokumentation**: Vollständige Dokumentation der Human-AI Collaborative Development
- **Cost Analysis**: Reale Kostenanalyse ($357+ monatlich dokumentiert)
- **Technical Insights**: Detaillierte Analyse AI-generierter Code-Patterns

### 🔧 Technical Improvements
- **PowerShell Class Compatibility**: Reparatur von Syntax-Fehlern für PowerShell 5.1/7.x
- **Error Handling**: Verbesserte Fehlerbehandlung in CategoryManager
- **Module Structure**: 9 Module für bessere Wartbarkeit
- **Code Quality**: Enterprise-Level defensive Programmierung

### 📁 Project Structure
- **docs/ai-collaboration/**: Vollständige AI-Collaboration Case Study
- **tools/ai-prompt-tracker/**: Universelles AI-Cost-Tracking-Tool  
- **categories/**: Demo-Community-Sets (Deutsche_Banken, Familie, Business)
- **Verbesserte .gitignore**: Schutz vor versehentlichem Commit privater Daten

### 🐛 Bug Fixes
- CategoryManager.ps1 Syntax-Fehler behoben (doppelte Case-Labels)
- PowerShell-Klassen Return-Path-Probleme behoben  
- Hardcodierte String-Probleme in allen Modulen behoben

## [1.2.2] - 2025-06-12

### 🔧 Fixed
- **Enhanced transfer detection** - Improved IBAN-based transfer recognition
- **Payee extraction** - Better extraction from "Verwendungszweck" field for credit cards
- **Encoding fixes** - Resolved UTF-8 encoding issues

### 📊 Improved
- **Starting balance calculation** - More accurate account balance detection
- **Categories file** - Fixed internationalization for category files
- **User experience** - Removed manual exit prompts, added direct file links

## [1.2.1] - 2025-06-06

### 🔧 Improved
- **Parameter structure cleanup** - Removed redundant -Wizard and -Silent parameters from main script
- **Cross-platform support** - Complete documentation for Linux/macOS with pwsh
- **Clearer user guidance** - Simplified parameter structure: Language, Setup, DryRun, Help
- **Setup optimization** - Streamlined first-run experience

### 📝 Documentation
- **README enhancement** - Clear command examples for all platforms
- **Parameter documentation** - Comprehensive parameter usage guide
- **Platform-specific instructions** - Detailed setup for Windows/Linux/macOS

### 🐛 Fixed
- **Parameter validation** - Better error handling for invalid parameter combinations
- **Help system** - More intuitive help display and usage examples

## [1.2.0] - 2025-05-30

### ✨ Added
- **Multi-language support** - Full internationalization with German and English
- **Advanced categorization** - Granular rules with payee+keyword combinations
- **Community contributions** - Framework for sharing CSV formats and categories
- **Auto-detection** - Automatic IBAN and account discovery from CSV files
- **Transfer recognition** - Intelligent detection of transfers between own accounts

### 🌍 Internationalization
- **Language files** - Complete de.json and en.json translation files
- **Dynamic switching** - Runtime language switching with -Language parameter
- **Localized output** - All user-facing text properly internationalized

### 🔧 Technical
- **Modular architecture** - Separated concerns into specialized modules
- **Config system** - Flexible JSON-based configuration
- **Validation framework** - Comprehensive CSV validation and error reporting
- **Cross-platform** - Full PowerShell 5.1 and 7.x compatibility

## [1.1.0] - 2025-05-15

### ✨ Added
- **Automatic IBAN discovery** - Extract all IBANs from CSV files automatically
- **Enhanced categorization** - Smart payee recognition and category assignment
- **Starting balance calculation** - Automatic calculation for Actual Budget setup
- **Improved CSV handling** - Better detection of various German bank formats

### 🔧 Improved
- **Error handling** - More robust error messages and recovery
- **Performance** - Faster processing of large CSV files
- **Documentation** - Enhanced README with clear setup instructions

## [1.0.0] - 2025-05-01

### ✨ Initial Release
- **CSV conversion** - Convert German bank CSV exports to Actual Budget format
- **Basic categorization** - Simple category assignment based on payee matching
- **Volksbank support** - Full support for Volksbank CSV format
- **Transfer detection** - Basic detection of internal transfers
- **Starting balances** - Manual starting balance calculation support

### 📋 Features
- PowerShell-based automation
- German bank CSV format support
- Actual Budget compatible output
- Basic error handling and validation