# 💰 CSV2Actual - Automatische Bank-CSV Konvertierung

Konvertiert deutsche Bank-CSV-Exporte automatisch zu Actual Budget mit intelligenter Kategorisierung und Transfer-Erkennung.

[![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B-blue)](https://docs.microsoft.com/en-us/powershell/)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![Auto-Discovery](https://img.shields.io/badge/Auto--Discovery-IBAN%20%7C%20Categories-brightgreen)](README.md)

---

## 🚀 Ein-Klick Start (Empfohlen)

```powershell
powershell -ExecutionPolicy Bypass -File CSV2Actual.ps1 -Silent
```

**Das war's!** Das Tool:
- 🔍 **Erkennt automatisch** alle IBANs und Konten aus Ihren CSV-Dateien
- 🏷️ **Kategorisiert automatisch** 60-70% aller Transaktionen  
- 🔄 **Erkennt Transfers** zwischen Ihren Konten
- 💰 **Berechnet Startguthaben** automatisch für Actual Budget Setup
- 📊 **Erstellt Statistiken** über verarbeitete Daten
- 🗂️ **Log-Management** mit automatischer Bereinigung
- 💾 **Speichert alles** im `actual_import/` Ordner für Actual Budget

---

## ✨ Was macht CSV2Actual?

### 🔍 **Automatische Konto-Erkennung**
- Analysiert Ihre CSV-Dateien und erkennt alle IBANs
- Erstellt automatisch Konto-Zuordnungen basierend auf Dateinamen
- Erkennt Benutzer-Namen (z.B. aus "Max_Girokonto.csv" → "Max")

### 🏷️ **Intelligente Kategorisierung**
- **Transfer-Kategorien**: Geld zwischen Ihren eigenen Konten
- **Gehalts-Kategorien**: Automatische Arbeitgeber-Erkennung
- **Ausgaben-Kategorien**: REWE, EDEKA, Amazon, PayPal, etc.

### 📊 **Beispiel-Ausgabe**
```
STATISTIKEN:
  📁 Verarbeitete Dateien: 8
  💳 Gesamte Buchungen: 445
  🏷️ Kategorisiert: 312 (70.1%)
  🔄 Transfers zwischen Konten: 28
```

---

## 🏦 Unterstützte Banken

- ✅ **Volksbank/Genossenschaftsbanken** (vollständig getestet)
- ✅ **Sparkassen** (Community-Format verfügbar)
- ✅ **Alle CSV-Formate** mit automatischer Spalten-Erkennung

---

## 📋 Schnellstart-Anleitung

### 1️⃣ **CSV-Dateien bereitstellen**
```
source/
├── Girokonto.csv
├── Sparkonto.csv
└── Kreditkarte.csv
```

### 2️⃣ **Tool ausführen**
```powershell
powershell -ExecutionPolicy Bypass -File CSV2Actual.ps1 -Silent
```

### 3️⃣ **Ergebnisse importieren**
- Dateien aus `actual_import/` Ordner in Actual Budget importieren
- Kategorien automatisch erstellen lassen
- Startguthaben aus `starting_balances.txt` übernehmen

**Fertig!** 🎉

---

## 🔧 Erweiterte Optionen

### **Interaktiver Modus (für Anpassungen)**
```powershell
# Deutsche Version mit Schritt-für-Schritt Anleitung:
powershell -ExecutionPolicy Bypass -File CSV2Actual.ps1 -Language de

# Englische Version:
powershell -ExecutionPolicy Bypass -File CSV2Actual.ps1 -Language en
```

### **Vorschau-Modus (ohne Dateien zu schreiben)**
```powershell
powershell -ExecutionPolicy Bypass -File CSV2Actual.ps1 -DryRun -Silent
```

### **Direkter Prozessor (ohne Wizard)**
```powershell
powershell -ExecutionPolicy Bypass -File bank_csv_processor.ps1 -Language de
```

---

## 🔐 Datenschutz & Sicherheit

- ✅ **Lokale Verarbeitung** - Ihre Daten verlassen nie Ihren Computer
- ✅ **Automatische .gitignore** - Verhindert versehentliche Uploads persönlicher Daten
- ✅ **Beispiel-Konfiguration** - Repository enthält nur anonyme Beispiel-IBANs
- ✅ **config.local.json** - Ihre echten IBANs bleiben lokal und privat

---

## 🌍 Multi-Language Support

### Deutsch
```powershell
powershell -ExecutionPolicy Bypass -File CSV2Actual.ps1 -Language de -Silent
```

### English
```powershell
powershell -ExecutionPolicy Bypass -File CSV2Actual.ps1 -Language en -Silent
```

---

## 🏗️ Community & Erweiterungen

### **Bank-Formate hinzufügen**
Das Tool erkennt automatisch die meisten CSV-Formate. Für spezielle Banken können Community-Formate in `community/csv-formats/` hinzugefügt werden.

### **Kategorien anpassen**
Kategorien werden automatisch aus den Transaktionsdaten erkannt. Für spezielle Kategorisierungen können Community-Sets in `community/categories/` erstellt werden.

---

## ⚠️ Systemanforderungen

- **Windows 10/11** mit PowerShell 5.1+ oder PowerShell Core 7+
- **Execution Policy**: Verwenden Sie immer `-ExecutionPolicy Bypass`
- **Encoding**: UTF-8 für deutsche Umlaute

---

## 🆘 Problemlösung

### **"Skript ist nicht digital signiert"**
```powershell
# Immer verwenden:
powershell -ExecutionPolicy Bypass -File CSV2Actual.ps1
```

### **Keine IBANs erkannt**
- Prüfen Sie, dass CSV-Dateien IBAN-Spalten enthalten
- Tool analysiert automatisch die häufigsten Spalten-Namen
- Bei Problemen: Interaktiven Modus verwenden (`-Language de`)

### **Encoding-Probleme**
- Das Tool erkennt automatisch die meisten Encoding-Formate
- Bei anhaltenden Problemen: GitHub Issue erstellen mit Beispiel-CSV

---

## 📄 Lizenz

MIT License - Siehe [LICENSE](LICENSE) für Details.

---

## 🤝 Beitragen

Beiträge sind willkommen! Dieses Repository ist der **End-User Release**. Für Entwickler:

### **End-User Contributions:**
- **Bank-Format-Definitionen** in `community/csv-formats/`
- **Kategorisierungs-Sets** in `community/categories/`
- **Feature-Requests** via [GitHub Issues](https://github.com/sTLAs/CSV2Actual/issues)

### **Developer Contributions:**
- **Code-Beiträge:** Siehe [DEVELOPMENT.md](DEVELOPMENT.md) für Setup
- **Testing:** Mit eigenen CSV-Daten und Feedback
- **Dokumentation:** Verbesserungen und Übersetzungen

**📝 Wichtig:** Dieses Repository fokussiert sich auf End-User. Entwickler-Tools sind bewusst ausgeschlossen für eine saubere User-Experience.

---

*💰 CSV2Actual - Automatisieren Sie Ihre Actual Budget Imports*