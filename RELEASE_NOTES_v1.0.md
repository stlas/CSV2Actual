# 🚀 CSV2Actual v1.0 - Initial Release

## 🎉 Welcome to CSV2Actual!

CSV2Actual is a PowerShell tool that converts German bank CSV exports into Actual Budget-compatible CSV files with intelligent automatic categorization.

## ✨ **Key Features**

### 🏦 **Bank Support**
- ✅ **Volksbank/Cooperative Banks** (primary tested)
- ✅ **Sparkassen (Savings Banks)**
- ✅ **International CSV formats** with automatic column detection
- 🔍 **Automatic encoding detection** (UTF-8, Windows-1252, etc.)

### 🏷️ **Smart Categorization**
- 🎯 **60-70% automatic categorization** of all transactions
- 🔄 **Automatic transfer recognition** between your accounts via IBAN mapping
- 👥 **Personalized salary recognition** (customizable patterns)
- 📊 **39 predefined categories** covering all major expense types

### 🌍 **Internationalization**
- 🇩🇪 **Full German language support**
- 🇬🇧 **Complete English interface**
- 🔧 **Dynamic column mapping** - works with German and international CSV formats
- 📝 **UTF-8 encoding throughout**

### 🧙‍♂️ **User-Friendly Interface**
- 🎯 **Interactive 5-step wizard** for beginners
- ⚡ **Direct CLI processing** for power users
- 👁️ **Dry-run mode** for safe testing
- 🔇 **Silent mode** with comprehensive logging

### 🤝 **Community Features**
- 📦 **Community CSV format submissions** (GitHub Issues)
- 🏷️ **Shared category sets** for different use cases
- 📋 **Easy contribution templates**
- 🔧 **No coding required** for contributions

## 📋 **What's Included**

### 🎯 **Main Scripts**
- **`CSV2Actual.ps1`** - Interactive 5-step wizard (recommended for beginners)
- **`bank_csv_processor.ps1`** - Core conversion engine with advanced options
- **`calculate_starting_balances.ps1`** - Automatic starting balance calculation

### ⚙️ **Configuration System**
- **`config.json`** - Central configuration (customize without coding!)
- **`lang/`** - Language files (German/English)
- **`community/`** - Community contributions framework

### 🎓 **Documentation**
- **`README.md`** - Complete setup and usage guide
- **`actual_import/ACTUAL_IMPORT_GUIDE.txt`** - Step-by-step Actual Budget import
- **`community/README.md`** - Contribution guidelines

## 🚀 **Quick Start**

### Option 1: Interactive Wizard (Recommended)
```bash
# German version
powershell -ExecutionPolicy Bypass -File CSV2Actual.ps1 -Language de

# English version
powershell -ExecutionPolicy Bypass -File CSV2Actual.ps1 -Language en
```

### Option 2: Direct Processing
```bash
# Preview your data first
powershell -ExecutionPolicy Bypass -File bank_csv_processor.ps1 -DryRun

# Process your files
powershell -ExecutionPolicy Bypass -File bank_csv_processor.ps1
```

## 📊 **Expected Results**

Based on testing with real German bank data:

```
📈 Performance Metrics:
   ✅ Categorization Rate: 60-70%
   ✅ Transfer Recognition: 95%+
   ✅ Processing Speed: ~1-2 seconds per file
   ✅ Language Coverage: Complete DE/EN
```

## 🔧 **System Requirements**

- **Windows 10/11** with PowerShell 5.1+ 
- **PowerShell Core 7.0+** (Linux/macOS support)
- **No additional dependencies** required

## 🎯 **Typical Workflow**

1. **Place CSV files** in `source/` folder
2. **Run wizard** or direct processor
3. **Import generated files** from `actual_import/` into Actual Budget
4. **Set starting balances** from calculated values
5. **Enjoy automatic categorization!**

## 🤝 **Community Contributions Welcome!**

Help expand CSV2Actual for more banks and use cases:

- 🏦 **Submit your bank's CSV format** via GitHub Issues
- 🏷️ **Share category sets** for different professions/countries
- 🌍 **Add new languages** with translation files
- 🔧 **No coding experience required!**

## 🙏 **Acknowledgments**

- Developed for the **[Actual Budget](https://actualbudget.org/)** community
- Inspired by the **German banking landscape**
- **ASCII-safe categories** for maximum compatibility
- Development assisted by **Claude AI** for code optimization

## 📄 **License**

This project is licensed under the **MIT License**.

---

**Made with ❤️ for the Actual Budget Community by [sTLAs](https://github.com/stlas)**

🌟 **Like this tool? Give us a star on GitHub!**