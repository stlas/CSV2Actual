# Changelog

All notable changes to CSV2Actual will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### ✨ Planned
- Enhanced CSV format auto-detection
- Additional German bank support
- Performance optimizations

## [1.2.1] - 2025-12-06

### 🔧 Improved
- **Parameter-Struktur bereinigt** - Entfernt überflüssige -Wizard und -Silent Parameter aus Hauptskript
- **Cross-Platform-Unterstützung** - Vollständige Dokumentation für Linux/macOS mit pwsh
- **Klarere Benutzerführung** - Vereinfachte Parameter-Struktur: Language, Setup, DryRun, Help
- **Terminologie korrigiert** - "Startsalden" statt "Startguthaben" für präzisere Beschreibung

### 🌍 Added
- **Linux/macOS Unterstützung** - Komplette Beispiele und Anweisungen für PowerShell Core (pwsh)
- **Platform-spezifische Dokumentation** - Getrennte Anweisungen für Windows und Unix-Systeme
- **Development-Tools** - Geschütztes develop/ Verzeichnis mit Release-Backup-System

### 📚 Documentation
- **Deutsche und englische README** - Vollständig aktualisiert mit neuer Parameter-Struktur
- **Multi-Language Support** - Cross-Platform-Beispiele für beide Sprachen
- **Systemanforderungen** - Erweitert um PowerShell Core 7+ für Unix-Systeme

### 🐛 Fixed
- **Redundante Parameter** - Entfernt -Wizard (Standard-Modus) und -Silent (aus Hauptskript)
- **Sprachdateien** - Bereinigt wizard_option Referenzen
- **Help-Texte** - Aktualisiert für neue Parameter-Struktur

## [1.2.0] - 2025-12-06

### ✨ Added
- **Enhanced Kreditkarte (Credit Card) Processing** - Improved payee extraction from Verwendungszweck field
- **Complex Credit Card Demo Data** - Added Complex_Credit_Card.csv for comprehensive testing
- **Optimized README Documentation** - Enhanced German and English explanations of tool purpose and benefits

### 🔧 Improved
- **Credit Card Payee Recognition** - Better extraction and cleaning of merchant names from transaction descriptions
- **User Documentation** - Clearer explanation of why and when to use CSV2Actual for Actual Budget imports
- **Repository Structure** - Cleaned up development files and improved organization
- **Security** - Enhanced .gitignore to prevent any sensitive data from being committed

### 🐛 Fixed
- **PowerShell 5.1/7.x Compatibility** - Improved cross-version compatibility for array and object handling
- **Encoding Issues** - Better handling of German umlauts and special characters in starting balance calculations
- **Internationalization** - Fixed parameter passing for bilingual balance messages

### 🏗️ Technical
- **Project Cleanup** - Removed development artifacts and temporary files
- **Git Security** - Enhanced protection against accidental commits of personal data
- **Release Process** - Streamlined preparation for new releases

## [1.1.0] - 2025-06-10

### ✨ Added
- **Automatic IBAN Discovery System** - Dynamically analyzes CSV files and creates account configurations
- **Enhanced Log Management** - Logs directory with automatic cleanup (7-day retention)
- **Integrated Starting Balance Calculation** - Automatic calculation during processing with detailed output
- **Repository Cleanup System** - Intelligent cleanup of redundant files and development artifacts
- **Backup Snapshot Management** - Automated backup creation with duplicate detection and cleanup
- **Enhanced Statistics Display** - Shows account count and total starting balances in output

### 🔧 Improved
- **Configuration Management** - Auto-merge system for local configurations (config.local.json)
- **Security Enhancements** - Comprehensive .gitignore to prevent private data commits
- **User Experience** - Streamlined output with better progress indication
- **Documentation** - Consolidated and cleaned up repository structure

### 🏗️ Technical
- **Modular Log Cleanup** - Integrated into main processor with automatic old file removal
- **Enhanced File Organization** - Production-ready repository structure
- **Improved Error Handling** - Better encoding detection and PowerShell compatibility

## [1.0.5] - 2025-01-07

### ✨ Added
- **Community Framework Expansion** - Enhanced CSV format and category submission system
- **Alternative Export Formats** - Multiple CSV variants (semicolon, tab-delimited, manual ASCII)
- **Advanced CSV Debugging** - Comprehensive encoding analysis and format detection tools

### 🔧 Improved
- **Encoding Handling** - Enhanced BOM detection and multi-encoding support
- **Silent Mode Defaults** - Streamlined user experience with minimal prompts
- **Transfer Recognition** - Improved IBAN-based detection accuracy

### 🐛 Fixed
- **String Interpolation Issues** - Resolved PowerShell syntax errors in various locales
- **UTF-8 Compatibility** - Better handling of German umlauts and special characters

## [1.0.4] - 2025-01-07

### 🐛 Fixed
- **Critical String Interpolation Bug** - Fixed wizard prompts and variable expansion issues
- **Data Protection** - Enhanced security measures for private information

### 🔧 Improved
- **PowerShell Core Compatibility** - Better support for both Windows PowerShell and PowerShell Core
- **Error Messages** - More descriptive and actionable error reporting

## [1.0.3] - 2025-01-07

### ✨ Added
- **Production Polish** - Final optimizations for production release
- **Enhanced Documentation** - Improved README and setup instructions

### 🔧 Improved
- **User Interface** - Refined wizard steps and better user guidance
- **Performance** - Optimized processing for larger CSV files

## [1.0.2] - 2025-01-07

### 🐛 Fixed
- **Critical Encoding Issues** - Resolved CSV reading problems with German banks
- **Documentation Fixes** - Corrected setup instructions and examples

### 🔧 Improved
- **Error Recovery** - Better handling of malformed CSV files
- **Logging** - Enhanced debug information for troubleshooting

## [1.0.1] - 2025-01-07

### 🐛 Fixed
- **Minor Bug Fixes** - Resolved edge cases in categorization
- **Configuration Issues** - Fixed template substitution problems

### 🔧 Improved
- **Stability** - Enhanced error handling and recovery mechanisms

## [1.0.0] - 2025-01-06

### 🎉 Initial Release

This is the first stable release of CSV2Actual, a PowerShell tool for converting German bank CSV exports to Actual Budget format.

### ✨ Added

#### Core Functionality
- **Bank CSV Processing Engine** - Converts German bank exports to Actual Budget CSV format
- **Automatic Categorization System** - 39 predefined categories with 60-70% success rate
- **Transfer Recognition** - IBAN-based detection between personal accounts
- **Starting Balance Calculator** - Automatic calculation for Actual Budget setup

#### User Interface
- **Interactive 5-Step Wizard** (`CSV2Actual.ps1`) - Beginner-friendly guided process
- **Direct CLI Processing** (`bank_csv_processor.ps1`) - Advanced user interface
- **Dry-Run Mode** - Safe preview without writing files
- **Silent Mode** - Minimal output with comprehensive logging

#### Internationalization
- **German Language Support** - Complete interface translation
- **English Language Support** - Full international compatibility  
- **Dynamic Column Mapping** - Automatic detection of German/English CSV columns
- **UTF-8 Encoding** - Proper handling of German umlauts and special characters

#### Bank Support
- **Volksbank/Cooperative Banks** - Primary tested format
- **Sparkassen (Savings Banks)** - Full compatibility
- **International CSV Formats** - Automatic column detection and mapping
- **Multi-encoding Support** - UTF-8, Windows-1252, ASCII detection

#### Configuration System
- **JSON-based Configuration** (`config.json`) - No code editing required
- **User Pattern Customization** - Salary patterns, account names, IBAN mappings
- **Category Pattern Matching** - Extensible expense/income recognition
- **Template Substitution** - Dynamic account naming system

#### Community Framework
- **CSV Format Submissions** - GitHub Issue templates for new bank formats
- **Category Set Sharing** - Community-contributed categorization schemes
- **Contribution Guidelines** - Easy participation without coding
- **Format Validation** - Automatic validation of community submissions

#### Documentation
- **Complete README** - Setup, usage, and customization guide
- **Import Guide** - Step-by-step Actual Budget integration
- **Community Guidelines** - Contribution and collaboration documentation
- **Test Data Management** - Safe testing with demo and real data switching

#### Advanced Features
- **CSV Validation** - Format checking with detailed error reporting
- **Multiple Export Formats** - Comma, semicolon, tab-delimited variants
- **Comprehensive Logging** - Detailed operation logs for debugging
- **PowerShell Core Support** - Linux/macOS compatibility

#### Architecture
- **Modular Design** - Separate classes for Config, I18n, CSV validation
- **Error Handling** - Robust error recovery and user feedback
- **Performance Optimization** - Efficient processing of large CSV files
- **Memory Management** - Optimized for processing multiple large files

### 🎯 Categories Supported

#### Income Categories (5)
- Salary recognition for multiple users
- Tax refunds and government payments
- Capital gains and investment income
- Cash deposits and transfers
- Other income sources

#### Expense Categories (20)
- Groceries (German supermarket chains)
- Fuel and transportation
- Insurance and financial services
- Housing and utilities
- Internet and telecommunications
- Restaurants and entertainment
- Online shopping and electronics
- Streaming services and subscriptions
- Healthcare and pharmacy
- Clothing and personal items
- Bank fees and taxes
- And more...

#### Transfer Categories (14)
- Automatic detection between personal accounts
- Household account management
- Savings and investment transfers
- Credit card payments
- Loan and mortgage handling

### 🔧 CLI Parameters

- `-DryRun` / `-n` - Preview mode without file writing
- `-Silent` / `-q` - Minimal output with logging
- `-Help` / `-h` - Display usage information
- `-Language` - Choose interface language (en/de)
- `-AlternativeFormats` - Generate multiple CSV format variants

### 📊 Performance Metrics

- **Categorization Rate**: 60-70% automatic assignment
- **Transfer Recognition**: 95%+ accuracy with IBAN mapping
- **Processing Speed**: 1-2 seconds per typical CSV file
- **Memory Usage**: Optimized for files with thousands of transactions
- **Language Support**: Complete German/English coverage

### 🏦 Tested Bank Formats

- **Volksbank eG** - Primary development target
- **Sparkasse** - Full compatibility verified
- **Generic German Banks** - Standard CSV export formats
- **International Formats** - English column names supported

### 📁 File Structure

```
CSV2Actual/
├── CSV2Actual.ps1                  # Interactive wizard
├── bank_csv_processor.ps1          # Core processor
├── calculate_starting_balances.ps1 # Balance calculator
├── config.json                     # Main configuration
├── modules/                        # PowerShell modules
├── lang/                           # Language files
├── community/                      # Community framework
├── actual_import/                  # Output directory
└── docs and guides
```

### 🌟 Community Features

- **GitHub Issue Templates** for CSV format submissions
- **JSON-based Format Definitions** for easy contribution
- **Category Set Templates** for different user types
- **Automatic Validation** of community contributions
- **Multi-language Support** for international contributors

---

## Version History

- **v1.1.0** (2025-06-10) - Major feature release with auto-discovery and log management
- **v1.0.5** (2025-01-07) - Community framework and alternative formats
- **v1.0.4** (2025-01-07) - Critical fixes and data protection
- **v1.0.3** (2025-01-07) - Production polish and documentation
- **v1.0.2** (2025-01-07) - Encoding fixes and error recovery
- **v1.0.1** (2025-01-07) - Minor bug fixes and stability
- **v1.0.0** (2025-01-06) - Initial stable release

---

**For detailed usage instructions, see [README.md](README.md)**
**For contribution guidelines, see [community/README.md](community/README.md)**