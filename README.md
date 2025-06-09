# 💰 CSV2Actual - German Bank CSV to Actual Budget Converter

A PowerShell tool that converts German bank CSV exports into Actual Budget-compatible CSV files with intelligent automatic categorization.

[![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B-blue)](https://docs.microsoft.com/en-us/powershell/)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![German Banks](https://img.shields.io/badge/Banks-Volksbank%20%7C%20Sparkasse%20%7C%20etc-orange)](README.md)

## ✨ Features

- 🔄 **Automatic Transfer Recognition** between your own accounts via IBAN mapping
- 🏷️ **60-70% Automatic Categorization** of all transactions
- 👥 **Personalized Salary Recognition** (customizable names and employers)
- 💡 **Smart Fallback Logic** for unknown payees
- 📊 **Accurate Starting Balance Calculation** for Actual Budget setup
- ⚙️ **JSON-based Configuration** - Easy customization without code editing
- 🔧 **ASCII-compliant Output** prevents encoding issues
- 📝 **Comprehensive Logging** for debugging and analysis
- 🌍 **Internationalization** - English/German with UTF-8 support
- 🧙‍♂️ **Interactive Wizard** - Step-by-step guidance for beginners

## 🚀 Quick Start

> **⚠️ Windows-Nutzer:** Verwenden Sie **immer** `-ExecutionPolicy Bypass` oder Sie erhalten einen "nicht digital signiert" Fehler!

### Option 1: Interactive Wizard (Recommended for beginners)
```powershell
# German version (Empfohlen für deutsche Banken):
powershell -ExecutionPolicy Bypass -File CSV2Actual.ps1 -Language de

# English version:
powershell -ExecutionPolicy Bypass -File CSV2Actual.ps1 -Language en
```

### Option 2: Direct Processing (For advanced users)
```bash
# 1. Calculate starting balances
powershell -ExecutionPolicy Bypass -File calculate_starting_balances.ps1

# 2. Preview (recommended)
powershell -ExecutionPolicy Bypass -File bank_csv_processor.ps1 -DryRun

# 3. Convert CSV files
powershell -ExecutionPolicy Bypass -File bank_csv_processor.ps1
```

## 📁 Setup Your Files

Place your bank CSV exports in the `source/` folder:
```
source/
├── Anna_Checking.csv
├── Max_Checking.csv  
├── Household_Account.csv
└── Credit_Card.csv
```

**Supported formats:** German banks (Volksbank, Sparkasse) and international CSV formats with automatic column detection.

## 📋 Supported Banks

- ✅ **Volksbank** / Cooperative Banks (primary tested)
- ✅ **Sparkassen** (Savings Banks)
- ✅ **Other German Banks** with similar CSV format

### Expected CSV Columns:
```
# German Bank Format (automatically mapped):
Buchungstag (Date), Valutadatum (Value Date), 
Name Zahlungsbeteiligter (Payee), IBAN Zahlungsbeteiligter (Payee IBAN),
Verwendungszweck (Purpose/Memo), Betrag (Amount), 
Saldo nach Buchung (Balance After Transaction)

# International/English equivalents also supported:
Date, Payee, Amount, Purpose, Memo, Balance
```

## 🏷️ Automatic Categorization

The tool automatically recognizes **39 categories**:

### 💰 Income (5)
- Salary Max/Anna, Tax Refunds, Capital Gains, etc.

### 💸 Expenses (20) 
- Groceries, Fuel, Insurance, Online Shopping, etc.

### 🔄 Transfers (14)
- Transfer from/to all your accounts + fallback categories

**Example categorization:**
```
FreshMart Ltd → "Groceries"
QuickFuel Station → "Fuel"  
StreamFlix → "Streaming & Subscriptions"
IBAN Transfer → "Transfer from Max-Checking"
```

## ⚙️ Customization for Your Data

**Easy Configuration via `config.json`** - No code editing required!

### 1. Update Your Personal Information
```json
{
  "users": {
    "user1": {
      "name": "YourName",
      "displayName": "YourName",
      "salaryPatterns": ["yourcompany", "youremployer.*salary"]
    },
    "user2": {
      "name": "PartnerName", 
      "displayName": "PartnerName",
      "salaryPatterns": ["partnercompany", "partner.*salary"]
    }
  }
}
```

### 2. Add Your IBAN Mappings
```json
{
  "accounts": {
    "ibanMapping": {
      "DE12345678901234567890": "user1-checking",
      "DE09876543210987654321": "user2-checking",
      "DE11223344556677889900": "household-account"
    }
  }
}
```

### 3. Customize Categories & Patterns
```json
{
  "categorization": {
    "expenses": {
      "groceries": ["your-local-store", "your-supermarket"],
      "fuel": ["your-gas-station"]
    }
  }
}
```

### 4. Advanced Customization
For detailed categorization patterns, check the config.json file and the actual_import/ACTUAL_IMPORT_GUIDE.txt for category setup instructions.

## 📊 Typical Results

```
Total Transactions: 2,700
Transfer Categories: 711 (26.3%)
Other Categories: 918 (34.0%)
Categorization Rate: 60.3%
```

## 🛠️ CLI Options

### Interactive Wizard
```powershell
CSV2Actual.ps1 [-Language en|de] [-Help]
```

### Direct Processing
```powershell
bank_csv_processor.ps1 [-DryRun|-n] [-Silent|-q] [-Help|-h]
```

## 📁 Project Structure

```
CSV2Actual/
├── 📄 CSV2Actual.ps1                  # Main wizard script
├── 📄 bank_csv_processor.ps1          # Core conversion script
├── 📄 calculate_starting_balances.ps1 # Starting balance calculation
├── ⚙️ config.json                     # Main configuration file (CUSTOMIZE THIS!)
├── 📁 source/                         # Source CSV files
├── 📁 actual_import/                  # Converted files
├── 📁 lang/                           # Language files (en.json, de.json)
├── 📁 modules/                        # PowerShell modules
│   ├── Config.ps1                     # Configuration management
│   ├── I18n.ps1                       # Internationalization
│   └── CsvValidator.ps1               # CSV validation
├── 📄 actual_import/ACTUAL_IMPORT_GUIDE.txt # Import guide with category list
└── 📄 starting_balances.txt           # Calculated starting balances
```

## 🎯 Actual Budget Import

1. **Create Categories**: All 39 categories in Actual Budget
2. **Create Accounts**: With calculated starting balances from `starting_balances.txt`
3. **Import CSVs**: Files from `actual_import/` folder
4. **Set Mapping**: Date→Date, Payee→Payee, Category→Category, Amount→Amount

Detailed instructions: [`actual_import/ACTUAL_IMPORT_GUIDE.txt`](actual_import/ACTUAL_IMPORT_GUIDE.txt)

## 🔧 System Requirements

- **Windows** with PowerShell 5.1+ (or PowerShell Core 6+ on Linux/macOS)
- **No additional dependencies** required

## ⚠️ **Troubleshooting für Windows-Benutzer**

### **Problem: "Die Datei kann nicht geladen werden... nicht digital signiert"**

**Ursache:** Windows PowerShell verhindert die Ausführung nicht-signierter Skripts (Sicherheitsfeature).

**Lösung:** Verwenden Sie **immer** den `-ExecutionPolicy Bypass` Parameter:

```powershell
# ✅ RICHTIG - Mit ExecutionPolicy Bypass
powershell -ExecutionPolicy Bypass -File CSV2Actual.ps1 -Language de

# ❌ FALSCH - Ohne ExecutionPolicy (führt zu Fehlern)
./CSV2Actual.ps1 -Language de
```

**Alternative Lösungen:**

1. **Temporäre Erlaubnis für aktuellen Benutzer:**
   ```powershell
   Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
   ./CSV2Actual.ps1 -Language de
   ```

2. **PowerShell Core verwenden (falls installiert):**
   ```powershell
   pwsh -ExecutionPolicy Bypass -File CSV2Actual.ps1 -Language de
   ```

**Ist das sicher?** ✅ Ja! Der `-ExecutionPolicy Bypass` Parameter:
- Ist nur für dieses eine Skript aktiv
- Verändert keine Systemeinstellungen dauerhaft
- Ist der empfohlene Weg für PowerShell-Tools
- Wird von Microsoft für vertrauenswürdige Skripts empfohlen

## 📖 Documentation

- [`CSV2Actual.ps1`](CSV2Actual.ps1) - Interactive wizard (start here!)
- [`actual_import/ACTUAL_IMPORT_GUIDE.txt`](actual_import/ACTUAL_IMPORT_GUIDE.txt) - Import guide with complete category list
- [`lang/`](lang/) - Language files for internationalization

## 🌍 Language Support

This tool supports multiple languages:
- **English** (default) - Full documentation and interface
- **German** (Deutsch) - Use `-Language de` parameter

### PowerShell Core (pwsh) Support
For Linux/macOS or PowerShell Core users, simply replace `powershell` with `pwsh`:
```bash
# PowerShell Core example:
pwsh -ExecutionPolicy Bypass -File CSV2Actual.ps1 -Language de
```

Want to add your language? Create a new JSON file in the `lang/` folder!

## 🤝 Contributing

### 🚀 Easy Community Contributions

**No coding required!** Help expand CSV2Actual for more banks and use cases:

#### 🏦 **Add Your Bank's CSV Format**
- Create an [Issue with CSV Format Template](https://github.com/sTLAs/CSV2Actual/issues/new?template=csv-format-submission.md)
- Provide column names and sample data (anonymized)
- We'll integrate it for everyone to use!

#### 🏷️ **Share Your Category Sets**  
- Create an [Issue with Category Template](https://github.com/sTLAs/CSV2Actual/issues/new?template=category-list-submission.md)
- Share categories for business, students, families, etc.
- Help others with similar needs!

📖 **Full Guidelines:** See [`community/README.md`](community/README.md)

### 🛠️ Code Contributions

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

### Especially welcome:
- 🏦 **Support for new banks** (CSV format variants)
- 🏷️ **Extended categorization patterns**  
- 🌍 **Internationalization** (other countries/languages)

## 📄 License

This project is licensed under the [MIT License](LICENSE).

## 👨‍💻 Author

**Author: sTLAs (https://github.com/sTLAs)** - *Initial work and development*

## ⭐ Acknowledgments

- Developed for the [Actual Budget](https://actualbudget.org/) community
- Inspired by the German banking landscape
- ASCII-safe categories for maximum compatibility
- Development assisted by Claude AI for code optimization and internationalization

---

**Made with ❤️ for the Actual Budget Community by [sTLAs](https://github.com/sTLAs)**

Like this tool? Give us a ⭐ star on GitHub!

