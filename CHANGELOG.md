# Changelog

All notable changes to CSV2Actual will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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

- **v1.0.0** (2025-01-06) - Initial stable release
- **v0.1 Alpha** (2025-01-06) - Development version

---

**For detailed usage instructions, see [README.md](README.md)**
**For contribution guidelines, see [community/README.md](community/README.md)**