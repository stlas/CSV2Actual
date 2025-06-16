# 📊 AI Prompt Tracker

**Kosten- und Statistik-Tracking für AI-Entwicklungsprojekte**

Ein universelles Tool zum Überwachen und Analysieren von AI-Entwicklungskosten in Echtzeit. Entwickelt aus den Erfahrungen des CSV2Actual-Projekts, wo die tatsächlichen Kosten 32x höher waren als geschätzt.

## 🎯 Problem & Lösung

### Das Problem:
- **Kostenexplosion**: AI-Entwicklungskosten werden oft um Faktor 10-30x unterschätzt
- **Fehlende Transparenz**: Keine Übersicht über Token-Verbrauch und Costs
- **Unerwartete Rechnungen**: $357+ monatlich statt geschätzter $30
- **Mangelnde Kontrolle**: Keine Warnungen bei teuren Operationen

### Die Lösung:
- **Echtzeit-Tracking**: Live-Überwachung jeder AI-Interaction
- **Proaktive Warnungen**: Automatische Alerts bei teuren Operationen  
- **Detailed Analytics**: Aufschlüsselung nach Features, Sessions, Zeiträumen
- **Budget-Management**: Monatliche Limits und Ausgaben-Prognosen

## 🚀 Quick Start

### Installation
```bash
# Download zu Ihrem Projekt
curl -o ai-prompt-tracker.ps1 https://raw.githubusercontent.com/yourusername/ai-prompt-tracker/main/tracker.ps1

# Oder klonen Sie das Repository
git clone https://github.com/yourusername/ai-prompt-tracker.git
```

### Basis-Usage
```powershell
# Tracker laden
. ./ai-prompt-tracker.ps1

# AI-Operation tracken
Track-AIOperation -Feature "CategoryManager" -EstimatedTokens 15000 -ActualCost 1.25

# Live-Dashboard anzeigen  
Show-CostDashboard

# Monats-Report generieren
Export-CostReport -Month 6 -Year 2025
```

## 📊 Features

### 1. **Echtzeit-Kostenüberwachung**
```powershell
function Track-AIOperation {
    param(
        [string]$Feature,
        [int]$EstimatedTokens,
        [decimal]$ActualCost,
        [string]$Model = "claude-sonnet-4",
        [string]$SessionType = "development"
    )
    
    # Automatische Warnung bei teuren Operationen
    if ($ActualCost -gt 0.50) {
        Write-Warning "⚠️ Teure Operation: $ActualCost USD"
        Write-Host "💡 Optimierungsvorschläge:"
        Write-Host "  • Batch multiple requests"
        Write-Host "  • Reduce context size"
        Write-Host "  • Use cheaper model for simple tasks"
    }
}
```

### 2. **Live-Dashboard**
```
📊 AI DEVELOPMENT COSTS - Live Dashboard
════════════════════════════════════════════

💰 HEUTE:        $12.50   (8 Sessions)
📅 DIESE WOCHE:  $67.20   (45 Sessions)  
📆 DIESER MONAT: $357.80  (189 Sessions)

⚠️ BUDGET ALERT: 89% des Monatsbudgets verbraucht ($400 Limit)

🔥 TOP KOSTENTREIBER:
  1. CategoryManager Development: $35.50 (15 Sessions)
  2. Documentation Generation:   $28.20 (12 Sessions)
  3. Code Review & Debugging:    $22.10 (18 Sessions)

📈 TREND: +15% gegenüber Vorwoche
⏰ PROGNOSE: $425 Monatsende (106% Budget)
```

### 3. **Detaillierte Analytics**
```powershell
# Feature-basierte Analyse
Get-CostsByFeature | Format-Table

Feature                 Sessions  Total_Cost  Avg_Cost  Tokens_Used
-------                 --------  ----------  --------  -----------
CategoryManager         15        $35.50      $2.37     425,000
I18n_Implementation     8         $18.20      $2.28     220,000
Documentation           12        $28.20      $2.35     340,000
```

### 4. **Budget-Management**
```powershell
# Monatsbudget setzen
Set-MonthlyBudget -Amount 400.00

# Ausgaben-Prognose
Get-SpendingForecast
# Output: Prognostizierte Monatskosten: $425 (106% des Budgets)

# Kostenwarnungen konfigurieren
Set-CostAlerts -DailyLimit 20.00 -WeeklyLimit 100.00 -OperationLimit 2.00
```

## 💻 Multi-Platform Support

### PowerShell (Windows/Linux/macOS)
```powershell
# Windows
powershell -File ai-prompt-tracker.ps1

# Linux/macOS  
pwsh -File ai-prompt-tracker.ps1
```

### Python (geplant)
```python
from ai_prompt_tracker import track_operation, show_dashboard

track_operation(
    feature="CategoryManager",
    tokens=15000,
    cost=1.25,
    model="claude-sonnet-4"
)

show_dashboard()
```

### Node.js (geplant)
```javascript
const tracker = require('./ai-prompt-tracker');

tracker.trackOperation({
    feature: 'CategoryManager',
    tokens: 15000,
    cost: 1.25,
    model: 'claude-sonnet-4'
});

tracker.showDashboard();
```

## 📈 Use Cases

### 1. **Entwicklungs-Projekte**
```powershell
# Zu Beginn jeder AI-Session
Track-AIStart -Project "MyApp" -Feature "UserAuthentication"

# Nach AI-Code-Generation
Track-AIOperation -Feature "UserAuth" -Tokens 8500 -Cost 0.85

# Session beenden
Track-AIEnd -SessionSummary "User auth module completed"
```

### 2. **Team-Projekte**
```powershell
# Team-Tracking aktivieren
Enable-TeamTracking -TeamName "Frontend" -SharedFile "\\server\ai-costs.json"

# Entwickler-spezifische Zuordnung
Track-AIOperation -Feature "LoginUI" -Developer "Alice" -Tokens 5000 -Cost 0.50
```

### 3. **Budget-Compliance**
```powershell
# Projekt-Budget überwachen
Set-ProjectBudget -Project "CSV2Actual" -Budget 500.00 -Period "Monthly"

# Automatische Reports
Schedule-CostReport -Frequency Weekly -Recipients @("manager@company.com")
```

## 📊 Reporting & Export

### CSV-Export
```powershell
Export-CostData -Format CSV -OutputPath "costs_june_2025.csv"
```

### JSON-API für Dashboards
```powershell
# REST-API starten für externe Dashboards
Start-CostAPI -Port 8080

# Endpunkte:
# GET /api/costs/today
# GET /api/costs/week  
# GET /api/costs/month
# GET /api/costs/project/{name}
```

### Management-Reports
```powershell
# Wöchentlicher Management-Report
New-ManagementReport -Period Week | Export-Pdf -Path "weekly_ai_costs.pdf"
```

## ⚙️ Integration in bestehende Projekte

### 1. **Automatische Integration**
```powershell
# In Ihrem Projekt-Setup
. ./tools/ai-prompt-tracker.ps1

# Wrapper für AI-Calls erstellen
function Invoke-AIWithTracking {
    param($Prompt, $Feature)
    
    $startTime = Get-Date
    Track-AIStart -Feature $Feature
    
    # Ihr AI-Call hier
    $result = Invoke-YourAIService $Prompt
    
    $endTime = Get-Date
    $duration = ($endTime - $startTime).TotalMinutes
    
    Track-AIOperation -Feature $Feature -Duration $duration -Tokens $result.TokensUsed -Cost $result.Cost
    
    return $result
}
```

### 2. **CI/CD Integration**
```yaml
# GitHub Actions Beispiel
- name: Track AI Development Costs
  run: |
    pwsh -Command "
    . ./ai-prompt-tracker.ps1;
    $cost = Get-SessionCost;
    if ($cost -gt 10.00) {
      Write-Error 'Session too expensive: $$cost'
      exit 1
    }
    "
```

### 3. **IDE-Integration**
```powershell
# VS Code Extension (geplant)
# Automatisches Tracking von AI-Assistenten wie GitHub Copilot, Claude Code, etc.
```

## 🎯 Lessons Learned aus CSV2Actual

### Kostentreiber identifiziert:
1. **Iterative Entwicklung**: 40% der Kosten durch Code-Reviews
2. **Context-Loading**: 20% Overhead durch große Dateien
3. **Documentation**: 30% der Entwicklungskosten
4. **Debugging**: 2-3x Token für Analyse vs. Generation

### Best Practices:
1. **Batch Requests**: Mehrere kleine Anfragen zusammenfassen
2. **Context Optimization**: Nur relevanten Code laden
3. **Proactive Budgeting**: $100-500 je nach Projekt-Größe
4. **Feature Prioritization**: Teure Features nur bei echtem Bedarf

## 📞 Support & Community

- **GitHub Issues**: Bug reports und Feature requests
- **Discussions**: Best practices und Use cases
- **Wiki**: Erweiterte Konfiguration und Tipps
- **Community Slack**: Real-time Hilfe und Austausch

## 🔮 Roadmap

### Version 1.1 (Juli 2025)
- [ ] Python und Node.js Versionen
- [ ] GitHub Actions Integration
- [ ] Slack/Teams Notifications
- [ ] Advanced Analytics Dashboard

### Version 1.2 (August 2025)  
- [ ] Multi-AI-Provider Support (OpenAI, Anthropic, etc.)
- [ ] VS Code Extension
- [ ] Team-Collaboration Features
- [ ] API für custom Integrations

### Version 2.0 (Q4 2025)
- [ ] Machine Learning Cost Predictions
- [ ] Automated Optimization Suggestions  
- [ ] Enterprise Features (SSO, RBAC)
- [ ] SaaS-Version für Teams

---

**Entwickelt aus realen Erfahrungen des CSV2Actual-Projekts, wo Kostenüberwachung von Tag 1 an den Unterschied zwischen $30 und $357+ monatlich gemacht hätte.**

**Lizenz**: MIT - Kostenlos für kommerzielle und private Nutzung