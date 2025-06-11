# 🛠️ CSV2Actual - Entwickler-Dokumentation

**Version:** 1.1.0  
**Zielgruppe:** Entwickler, die zu CSV2Actual beitragen möchten  
**Repository:** Production Release (End-User fokussiert)

---

## 📋 **Wichtiger Hinweis**

Dieses Repository ist der **Production Release** für End-User. Entwickler-Tools und Debug-Utilities sind bewusst **nicht enthalten**, um die End-User Experience sauber zu halten.

---

## 🎯 **End-User vs. Developer Trennung**

### **📦 Production Release (dieses Repo)**
**Zielgruppe:** PowerShell-User, die CSV-Dateien konvertieren wollen

```
CSV2Actual/
├── CSV2Actual.ps1           # ✅ Haupt-Wizard
├── bank_csv_processor.ps1   # ✅ Core Engine
├── calculate_starting_balances.ps1  # ✅ Balance Calculator
├── config.json             # ✅ Haupt-Konfiguration
├── modules/                 # ✅ Core Module
├── lang/                    # ✅ Internationalisierung
├── community/               # ✅ Community Framework
├── test_data/demo_csvs/     # ✅ Demo-Daten für Tests
├── README.md               # ✅ User-Guide
├── CHANGELOG.md            # ✅ Release Notes
└── LICENSE                 # ✅ MIT Lizenz
```

### **🔧 Developer Tools (nicht im Production Release)**
**Diese Dateien gehören in eine separate Entwicklungsumgebung:**

```
# Entwickler-Utilities (bewusst ausgeschlossen):
├── cleanup_logs.ps1         # ❌ Log-Management Tool
├── backup_snapshots/        # ❌ Entwickler-Backups
├── RELEASE_*.md            # ❌ Release-Dokumentation
├── *_dev.ps1               # ❌ Debug-Scripts
├── *_debug.ps1             # ❌ Development Tools
└── development_tools/      # ❌ Build-Scripts, Tests
```

---

## 🚀 **Release Strategy**

### **1. End-User Releases (GitHub Releases)**
- **Tag Format:** `v1.1.0` 
- **Zielgruppe:** PowerShell-User
- **Inhalt:** Nur produktive Dateien
- **README:** User-fokussiert, einfache Installation

### **2. Developer Contributions (Separate Branches/Repos)**
- **Branch:** `development` oder separates Repository
- **Zielgruppe:** Contributers, Entwickler
- **Inhalt:** Vollständige Entwicklungsumgebung
- **Dokumentation:** Setup-Guides, Build-Prozesse

---

## 🔄 **Development Workflow**

### **Für Entwickler, die beitragen möchten:**

#### **1. Development Setup**
```bash
# Clone Development Branch (wenn verfügbar)
git clone https://github.com/sTLAs/CSV2Actual.git
git checkout development

# Oder: Setup lokale Entwicklungsumgebung
mkdir CSV2Actual-Dev
cd CSV2Actual-Dev
git clone https://github.com/sTLAs/CSV2Actual.git production
```

#### **2. Entwickler-Tools installieren**
```powershell
# Log-Management Tool erstellen
New-Item -Name "cleanup_logs.ps1" -ItemType File

# Backup-System einrichten  
New-Item -Name "backup_snapshots" -ItemType Directory

# Debug-Utilities
New-Item -Name "debug_tools" -ItemType Directory
```

#### **3. Testing und Debugging**
```powershell
# Lokale Tests mit echten Daten
cp real_bank_data/*.csv source/
powershell -File bank_csv_processor.ps1 -DryRun

# Automatische Backups während Entwicklung
powershell -File cleanup_logs.ps1 -CreateBackup

# Performance Testing
Measure-Command { powershell -File bank_csv_processor.ps1 -Silent }
```

---

## 📚 **Contribution Guidelines**

### **Was gehört ins Production Release:**
✅ **Core Funktionalität** - CSV-Processing, Kategorisierung, IBAN-Erkennung  
✅ **User Interface** - Wizard, CLI-Parameter, Hilfe-Texte  
✅ **Dokumentation** - README, CHANGELOG, User-Guides  
✅ **Community Features** - Template-System, Format-Submissions  
✅ **Demo-Daten** - Anonymisierte Test-CSVs  

### **Was NICHT ins Production Release gehört:**
❌ **Debug-Tools** - Cleanup-Scripts, Backup-Utilities  
❌ **Development Logs** - Detaillierte Entwickler-Logs  
❌ **Personal Scripts** - Individuelle Test-Skripte  
❌ **Build-Tools** - Automatisierung, CI/CD-Scripts  
❌ **Echte Daten** - Persönliche CSVs, echte IBANs  

---

## 🏗️ **Architektur-Entscheidungen**

### **End-User Fokus:**
- **Minimale Konfiguration** - Zero-Config mit automatischer IBAN-Erkennung
- **Klare Trennung** - Produktive Features vs. Entwickler-Tools
- **Saubere Dokumentation** - User-fokussiert ohne technische Details
- **Keine Verwirrung** - End-User sehen nur relevante Dateien

### **Entwickler-Unterstützung:**
- **Separate Umgebung** - Development-Branch oder eigenes Repository
- **Vollständige Tools** - Alle Debug- und Build-Utilities verfügbar
- **Detaillierte Docs** - Technische Implementierungsdetails
- **Testing Framework** - Umfassende Test-Möglichkeiten

---

## 📞 **Kontakt für Entwickler**

### **Feature Requests:**
- **GitHub Issues:** [CSV2Actual Issues](https://github.com/sTLAs/CSV2Actual/issues)
- **Feature Template:** Verwende Issue-Templates für neue Features

### **Code Contributions:**
- **Pull Requests:** Gegen `development` Branch (falls verfügbar)
- **Code Review:** Alle Änderungen werden reviewed vor Merge
- **Testing:** Umfassende Tests mit Demo-Daten erforderlich

### **Community Contributions:**
- **Bank-Formate:** Neue CSV-Format-Definitionen in `community/csv-formats/`
- **Kategorien:** Neue Kategorisierungs-Sets in `community/categories/`
- **Übersetzungen:** Neue Sprachen in `lang/` Verzeichnis

---

## 🎯 **Nächste Steps für Contributors**

### **1. Issues durchschauen**
- Schaue in [GitHub Issues](https://github.com/sTLAs/CSV2Actual/issues) für offene Aufgaben
- Label: `good-first-issue` für Einsteiger
- Label: `help-wanted` für komplexere Features

### **2. Development Environment einrichten**
- Lokale Entwicklungsumgebung mit allen Tools
- Test-Setup mit Demo-Daten und echten CSVs
- PowerShell 5.1+ und PowerShell Core 7+ testen

### **3. Contribution erstellen**
- Fork das Repository
- Erstelle Feature-Branch
- Implementiere mit Tests
- Pull Request mit detaillierter Beschreibung

---

**💡 Wichtig:** Diese Trennung hält das End-User Repository sauber und professionell, während Entwickler trotzdem alle benötigten Tools und Dokumentationen erhalten.

---

*🛠️ Generated with [Claude Code](https://claude.ai/code) - Development Documentation v1.1.0*