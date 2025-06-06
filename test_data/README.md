# Test Data Directory

This directory contains different CSV test datasets for CSV2Actual.

## Directory Structure

- **`demo_csvs/`** - Demo/example CSV files with sample German bank data
- **`real_bank_csvs/`** - Your real bank CSV exports for testing

## How to Use

### Testing with Demo Data (Default)
```powershell
# Uses the files in source/ directory (already configured)
powershell -ExecutionPolicy Bypass -File CSV2Actual.ps1 -Language de -DryRun
```

### Testing with Real Bank Data
1. Copy your real bank CSV exports to `test_data/real_bank_csvs/`
2. Run the test script:
```powershell
powershell -ExecutionPolicy Bypass -File test_with_real_data.ps1 -Language de -DryRun
```

### Switch Between Test Sets
```powershell
# Switch to real bank data
powershell -ExecutionPolicy Bypass -File switch_test_data.ps1 -TestSet real

# Switch back to demo data  
powershell -ExecutionPolicy Bypass -File switch_test_data.ps1 -TestSet demo
```

## CSV File Requirements

Your CSV files should have these German bank columns:
- `Buchungstag` or `Valutadatum` (Date)
- `Betrag` or `Umsatz` (Amount) 
- `Name Zahlungsbeteiligter` or `Empfaenger` (Payee)
- `Verwendungszweck` or `Buchungstext` (Purpose/Memo)
- `IBAN Zahlungsbeteiligter` (optional, for transfer detection)

## Privacy Note

**IMPORTANT:** Never commit real bank data to version control!
The `real_bank_csvs/` directory is excluded from git via `.gitignore`.