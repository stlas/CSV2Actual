# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

**Version:** 1.0  
**Release Date:** January 6, 2025  
**Author:** sTLAs (https://github.com/sTLAs)  
**Windows Compatibility:** Windows 10 (v1607+) and Windows 11  
**PowerShell Required:** Windows PowerShell 5.1+ or PowerShell Core 7.0+

## Project Overview

CSV2Actual is a PowerShell-based tool that converts German bank CSV exports to Actual Budget-compatible CSV files with automatic categorization. The project processes multiple bank accounts and provides intelligent transfer recognition between accounts.

**Key Features:**
- **Internationalized** - English/German language support via JSON configuration  
- **Modular Architecture** - PowerShell classes for Config, I18n, and CSV validation
- **JSON Configuration** - Externalized all settings, user names, IBAN mappings, and categorization patterns
- **Automatic Categorization** - Pattern-based recognition for expenses, income, and transfers
- **Transfer Recognition** - IBAN-based detection between personal accounts
- **PowerShell Core Support** - Works with `pwsh` (PowerShell 7.5+)

## Important Scripts and Their Purpose

### Main Processing Scripts
- **`bank_csv_processor.ps1`** - Main script that processes all CSV files, applies automatic categorization, and converts German bank formats to Actual Budget format
- **`calculate_starting_balances.ps1`** - Calculates starting balances for Actual Budget import from CSV transaction history
- **`CSV2Actual.ps1`** - Interactive wizard interface for beginners with step-by-step guidance

### Support Scripts  
All main functionality is integrated into the three main scripts above.

### Module System
- **`modules/Config.ps1`** - Configuration management class for loading and processing config.json
- **`modules/I18n.ps1`** - Internationalization class for English/German language support  
- **`modules/CsvValidator.ps1`** - CSV format validation and error reporting class

## Architecture

### Data Flow
1. Source CSV files (German bank exports) → `bank_csv_processor.ps1` → `actual_import/` folder → Actual Budget
2. Processor converts German formats (DD.MM.YYYY dates, comma decimals) to ISO standard (YYYY-MM-DD, dot decimals)
3. Automatic categorization based on payee/memo pattern recognition from JSON configuration
4. Transfer recognition between personal accounts via IBAN mapping

### Key Configuration (config.json)
```json
{
  "users": {
    "user1": {
      "name": "Max",
      "displayName": "Max", 
      "salaryPatterns": ["johnson", "max.*salary", "techcorp.*ltd"]
    }
  },
  "accounts": {
    "ibanMapping": {
      "DE12345678901234567890": "user2-checking"
    }
  }
}
```

### Categorization Logic
- Pattern-based recognition via payee and memo fields from JSON configuration
- Hierarchical categorization: Transfers → Income → Expenses  
- German merchant recognition (REWE, EDEKA, etc.)
- Configurable patterns for all expense categories

## Standard Workflow

### Run Main Processor (English)
```powershell
powershell -ExecutionPolicy Bypass -File bank_csv_processor.ps1 -Language en
```

### Run Main Processor (German)  
```powershell
powershell -ExecutionPolicy Bypass -File bank_csv_processor.ps1 -Language de
```

### Calculate Starting Balances
```powershell
powershell -ExecutionPolicy Bypass -File calculate_starting_balances.ps1 -Language en
```

### Interactive Wizard for Beginners
```powershell
powershell -ExecutionPolicy Bypass -File CSV2Actual.ps1 -Language en
```

### Debugging
Use the DryRun mode to preview processing without writing files:
```powershell
powershell -ExecutionPolicy Bypass -File bank_csv_processor.ps1 -DryRun -Language en
```

## Output Format

All processed files use the Actual Budget standard format:
- `date` (YYYY-MM-DD)
- `account` (derived from filename via config.json mapping)
- `payee` 
- `notes`
- `category` (automatically assigned from JSON patterns or empty)
- `amount` (decimal with dot separator)

## Important Files

- **`config.json`** - Central configuration file with user settings, IBAN mappings, and categorization patterns
- **`lang/en.json`** - English language strings for all user-facing messages
- **`lang/de.json`** - German language strings for all user-facing messages  
- **`actual_import/ACTUAL_IMPORT_GUIDE.txt`** - Step-by-step import instructions for Actual Budget
- **`actual_import/` folder** - Contains all processed CSV files ready for import
- **`starting_balances.txt`** - Generated starting balance report

## Internationalization

The project supports full internationalization:
- **Language Parameter**: All scripts accept `-Language en` or `-Language de`
- **External Language Files**: All user-facing strings in `lang/*.json`
- **UTF-8 Support**: Proper encoding handling throughout
- **Fallback Mechanism**: English fallback if German strings missing

## Configuration Management

### JSON Configuration Structure
```json
{
  "paths": {
    "sourceDir": "source",
    "outputDir": "actual_import", 
    "languageDir": "lang"
  },
  "csv": {
    "delimiter": ";",
    "encoding": "UTF8"
  },
  "users": { /* user definitions */ },
  "accounts": { /* IBAN mappings */ },
  "categorization": { /* pattern rules */ }
}
```

### Template System
Account names use template substitution:
- `"{{user1.displayName}}-Checking"` → `"Max-Checking"`
- `"{{user2.displayName}}-Savings"` → `"Anna-Savings"`

## Testing

### Manual Verification
1. Use DryRun mode for problematic files: `bank_csv_processor.ps1 -DryRun`
2. Check output in `actual_import/` folder  
3. Verify categorization assignment statistics in console output
4. Test both English and German language modes

### Expected Performance
- **Categorization Rate**: 60-70% automatic assignment
- **Transfer Recognition**: 95%+ with IBAN mapping
- **Processing Speed**: ~1-2 seconds per file
- **Language Support**: Complete English/German coverage

### Test Commands
```powershell
# Test English mode
powershell -ExecutionPolicy Bypass -File bank_csv_processor.ps1 -Language en

# Test German mode  
powershell -ExecutionPolicy Bypass -File bank_csv_processor.ps1 -Language de

# Test balance calculator
powershell -ExecutionPolicy Bypass -File calculate_starting_balances.ps1 -Language en
```

## Encoding Handling

The project specifically handles German banking CSV encoding issues:
- Automatic BOM detection and removal
- UTF-8/ASCII conversion for maximum compatibility  
- German umlaut replacement (ä→ae, ö→oe, ü→ue, ß→ss) in category names
- Proper PowerShell Core (pwsh) encoding support

## Development Notes

### PowerShell Best Practices
- Parameter aliases: `-h` (Help), `-n` (DryRun), `-q` (Silent), `-l` (Language)
- Error handling with try/catch blocks
- UTF-8 encoding throughout
- Class-based architecture for reusability

### Adding New Languages
1. Create `lang/[code].json` with all required strings
2. Add language to `I18n.GetAvailableLanguages()`
3. Test all scripts with new language parameter

### Adding New Categories
1. Update `config.json` categorization patterns
2. Add corresponding language strings to `lang/*.json`
3. Test pattern matching with sample transactions

## GitHub Repository Structure

```
CSV2Actual/
├── config.json                    # Central configuration
├── bank_csv_processor.ps1         # Main processor  
├── calculate_starting_balances.ps1 # Balance calculator
├── CSV2Actual.ps1                 # Interactive wizard
├── modules/                       # PowerShell classes
│   ├── Config.ps1                 # Configuration management
│   ├── I18n.ps1                   # Internationalization
│   └── CsvValidator.ps1           # CSV validation
├── lang/                          # Language files
│   ├── en.json                    # English strings
│   └── de.json                    # German strings  
├── source/                        # Input CSV files
├── actual_import/                 # Output CSV files
└── CLAUDE.md                      # This documentation
```

# important-instruction-reminders
Do what has been asked; nothing more, nothing less.
NEVER create files unless they're absolutely necessary for achieving your goal.
ALWAYS prefer editing an existing file to creating a new one.
NEVER proactively create documentation files (*.md) or README files. Only create documentation files if explicitly requested by the User.

## Memory
- Erkenne die Laufzeit Umgebung und schlage entsprechend pwsh oder powershell vor