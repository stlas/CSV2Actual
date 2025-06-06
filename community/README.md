# 🤝 Community Contributions

Welcome to the CSV2Actual community! This directory contains user-contributed CSV formats and category sets that extend the tool's compatibility with different banks and use cases.

## 📁 Directory Structure

```
community/
├── csv-formats/          # Bank-specific CSV format definitions
├── categories/           # Custom category sets for different use cases
├── templates/            # Templates for creating new contributions
└── README.md            # This file
```

## 🏦 CSV Format Contributions

### How to Contribute a New Bank Format

1. **Create an Issue** using the [CSV Format Submission template](../.github/ISSUE_TEMPLATE/csv-format-submission.md)
2. **Provide Required Information:**
   - Bank name and country
   - CSV column names and format details
   - Anonymized sample data (2-3 rows)
   - Any special handling requirements

3. **Template File:** Use [`templates/csv-format-template.json`](templates/csv-format-template.json) as a starting point

### Supported Banks

Currently supported bank formats:
- **Volksbank/Cooperative Banks** (Germany) - Built-in
- **Sparkassen** (Germany) - Built-in
- *Community contributions welcome!*

## 🏷️ Category Set Contributions

### How to Contribute Category Sets

1. **Create an Issue** using the [Category List Submission template](../.github/ISSUE_TEMPLATE/category-list-submission.md)
2. **Provide Category Information:**
   - Category names and recognition patterns
   - Target use case (personal, business, student, etc.)
   - Language and localization

3. **Template File:** Use [`templates/categories-template.json`](templates/categories-template.json) as a starting point

### Available Category Sets

- **German Standard** - Built-in (39 categories)
- **English Standard** - Built-in (39 categories)
- *Community contributions welcome!*

## 🎯 Use Cases for Community Contributions

### CSV Formats Needed
- **International Banks** (US, UK, France, etc.)
- **Business Banking** formats
- **Credit Unions** and regional banks
- **Online Banks** (N26, DKB, etc.)
- **Investment Platforms** (Trade Republic, etc.)

### Category Sets Needed
- **Business/Freelancer** categories
- **Student** budget categories
- **Family** budget categories
- **Investment** categories
- **Multi-language** category sets

## 📝 Contribution Guidelines

### Quality Standards
- ✅ **Anonymized Data:** Never include real personal/financial information
- ✅ **Tested Formats:** Test with CSV2Actual if possible
- ✅ **Clear Documentation:** Provide complete information about the format
- ✅ **Realistic Patterns:** Use actual merchant names and patterns

### File Naming Convention
- **CSV Formats:** `bankname-country.json` (e.g., `sparkasse-de.json`)
- **Categories:** `usecase-language.json` (e.g., `business-en.json`)

### JSON Structure
Follow the templates exactly:
- [`csv-format-template.json`](templates/csv-format-template.json) for bank formats
- [`categories-template.json`](templates/categories-template.json) for category sets

## 🔄 Integration Process

### For Contributors
1. Submit via GitHub Issue with required information
2. Maintainer reviews and provides feedback
3. Once approved, files are added to appropriate directory
4. Contributor gets credited in README

### For Maintainer (@sTLAs)
1. Review submission for completeness and quality
2. Test format/categories if possible
3. Create JSON file in appropriate directory
4. Update README with new contribution
5. Close issue and thank contributor

## 🏆 Credits

### CSV Format Contributors
*Community contributors will be listed here*

### Category Set Contributors  
*Community contributors will be listed here*

## 📧 Questions?

- **Create an Issue** for questions about contributing
- **Email:** Contact @sTLAs for private inquiries
- **Documentation:** See main [README.md](../README.md) for usage instructions

## 📄 License

All community contributions are shared under the same [MIT License](../LICENSE) as the main project.

---

**Thank you for helping make CSV2Actual better for everyone! 🚀**