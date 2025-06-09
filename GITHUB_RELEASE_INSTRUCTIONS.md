# 🚀 GitHub Release Instructions for CSV2Actual v1.0.0

Da die WSL-Umgebung Git-Authentifizierungsprobleme hat, hier die komplette Anleitung für das manuelle GitHub Release:

## 📋 **Schritt 1: Code zu GitHub pushen**

Verwenden Sie **Windows PowerShell** oder **GitHub Desktop**:

### Option A: Windows PowerShell
```powershell
# Wechseln Sie in das Projektverzeichnis
cd "C:\Pfad\zu\CSV2Actual"

# Push commit und tags
git push origin main
git push origin --tags
```

### Option B: GitHub Desktop
1. Öffnen Sie GitHub Desktop
2. Wählen Sie das CSV2Actual Repository
3. Commit und Push der Änderungen
4. Push Tags: Repository → Push origin

## 📋 **Schritt 2: GitHub Release erstellen**

### Via GitHub Web Interface:

1. **Gehen Sie zu:** https://github.com/stlas/CSV2Actual
2. **Klicken Sie:** "Releases" → "Create a new release"
3. **Tag:** `v1.0.0` (bereits erstellt)
4. **Release Title:** `🚀 CSV2Actual v1.0.0 - Initial Stable Release`

### **Release Description verwenden:**

```markdown
# 🎉 CSV2Actual v1.0.0 - Initial Stable Release

## 🚀 **Was ist CSV2Actual?**

CSV2Actual ist ein PowerShell-Tool, das deutsche Bank-CSV-Exporte in Actual Budget-kompatible CSV-Dateien mit intelligenter automatischer Kategorisierung konvertiert.

## ✨ **Hauptfunktionen**

### 🏦 **Bank-Unterstützung**
- ✅ **Volksbank/Genossenschaftsbanken** (primär getestet)
- ✅ **Sparkassen** 
- ✅ **Internationale CSV-Formate** mit automatischer Spaltenerkennung
- 🔍 **Automatische Encoding-Erkennung** (UTF-8, Windows-1252, etc.)

### 🏷️ **Intelligente Kategorisierung**
- 🎯 **60-70% automatische Kategorisierung** aller Transaktionen
- 🔄 **Automatische Überweisungserkennung** zwischen eigenen Konten via IBAN
- 👥 **Personalisierte Gehaltserkennung** (anpassbare Muster)
- 📊 **39 vordefinierte Kategorien** für alle wichtigen Ausgabentypen

### 🌍 **Internationalisierung**
- 🇩🇪 **Vollständige deutsche Sprachunterstützung**
- 🇬🇧 **Komplette englische Benutzeroberfläche**
- 🔧 **Dynamisches Spalten-Mapping** - funktioniert mit deutschen und internationalen CSV-Formaten
- 📝 **UTF-8-Encoding durchgängig**

### 🧙‍♂️ **Benutzerfreundliche Oberfläche**
- 🎯 **Interaktiver 5-Schritt-Wizard** für Anfänger
- ⚡ **Direkte CLI-Verarbeitung** für Power-User
- 👁️ **Dry-Run-Modus** für sicheres Testen
- 🔇 **Silent-Modus** mit umfassendem Logging

### 🤝 **Community-Features**
- 📦 **Community CSV-Format-Beiträge** (GitHub Issues)
- 🏷️ **Geteilte Kategorie-Sets** für verschiedene Anwendungsfälle
- 📋 **Einfache Beitrags-Templates**
- 🔧 **Keine Programmierkenntnisse erforderlich**

## 🚀 **Schnellstart**

### Option 1: Interaktiver Wizard (Empfohlen)
```bash
# Deutsche Version
powershell -ExecutionPolicy Bypass -File CSV2Actual.ps1 -Language de

# Englische Version  
powershell -ExecutionPolicy Bypass -File CSV2Actual.ps1 -Language en
```

### Option 2: Direkte Verarbeitung
```bash
# Vorschau Ihrer Daten
powershell -ExecutionPolicy Bypass -File bank_csv_processor.ps1 -DryRun

# Dateien verarbeiten
powershell -ExecutionPolicy Bypass -File bank_csv_processor.ps1
```

## 📊 **Erwartete Ergebnisse**

Basierend auf Tests mit echten deutschen Bankdaten:

```
📈 Performance-Metriken:
   ✅ Kategorisierungsrate: 60-70%
   ✅ Überweisungserkennung: 95%+
   ✅ Verarbeitungsgeschwindigkeit: ~1-2 Sekunden pro Datei
   ✅ Sprachabdeckung: Vollständig DE/EN
```

## 🔧 **Systemanforderungen**

- **Windows 10/11** mit PowerShell 5.1+
- **PowerShell Core 7.0+** (Linux/macOS-Unterstützung)
- **Keine zusätzlichen Abhängigkeiten** erforderlich

## 🤝 **Community-Beiträge willkommen!**

Helfen Sie dabei, CSV2Actual für mehr Banken und Anwendungsfälle zu erweitern:

- 🏦 **Reichen Sie das CSV-Format Ihrer Bank ein** via GitHub Issues
- 🏷️ **Teilen Sie Kategorie-Sets** für verschiedene Berufe/Länder
- 🌍 **Fügen Sie neue Sprachen hinzu** mit Übersetzungsdateien
- 🔧 **Keine Programmiererfahrung erforderlich!**

## 📄 **Lizenz**

Dieses Projekt ist unter der **MIT-Lizenz** lizenziert.

---

**Made with ❤️ for the Actual Budget Community by [sTLAs](https://github.com/stlas)**

🌟 **Gefällt Ihnen dieses Tool? Geben Sie uns einen Stern auf GitHub!**
```

## 📋 **Schritt 3: Release-Konfiguration**

### **Release-Einstellungen:**
- ✅ **Set as the latest release** 
- ✅ **Create a discussion for this release**
- ⚠️ **NICHT** als Pre-release markieren (dies ist stabile v1.0.0)

### **Assets (automatisch generiert):**
- Source code (zip)
- Source code (tar.gz)

## 📋 **Schritt 4: Nach dem Release**

### **Sofort nach Veröffentlichung:**
1. **Teilen Sie den Release** in relevanten Communities
2. **Aktualisieren Sie Links** in der Dokumentation falls nötig
3. **Überwachen Sie** GitHub Issues für Feedback

### **Community-Outreach:**
- Actual Budget Discord/Forum
- Reddit r/ActualBudget
- Deutsche Banking/Finance Communities

## 🎯 **Release-URL**

Nach der Erstellung wird der Release verfügbar sein unter:
**https://github.com/stlas/CSV2Actual/releases/tag/v1.0.0**

## ✅ **Erfolg prüfen**

Nach dem Release prüfen Sie:
- [ ] Release ist auf GitHub sichtbar
- [ ] Download-Links funktionieren
- [ ] Tag v1.0.0 ist korrekt
- [ ] Release-Notes sind vollständig
- [ ] "Latest Release" Badge zeigt v1.0.0

---

## 🎉 **Herzlichen Glückwunsch!**

CSV2Actual v1.0.0 ist jetzt offiziell released und bereit für die Community!