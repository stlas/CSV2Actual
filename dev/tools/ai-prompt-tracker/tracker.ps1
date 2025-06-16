# AI Prompt Tracker - Universal Cost & Statistics Tracking für AI Development
# Version: 1.0
# Entwickelt aus den Erfahrungen des CSV2Actual-Projekts
# Lizenz: MIT

#Requires -Version 5.1

# Global Configuration
$global:AITracker = @{
    ConfigFile = "ai-tracker-config.json"
    DataFile = "ai-costs.json"
    MonthlyBudget = 400.00
    DailyLimit = 20.00
    OperationLimit = 2.00
    DefaultModel = "claude-sonnet-4"
    TokenCosts = @{
        "claude-sonnet-4" = @{ input = 3.00; output = 15.00 }  # per 1M tokens
        "claude-haiku" = @{ input = 0.25; output = 1.25 }
        "gpt-4-turbo" = @{ input = 10.00; output = 30.00 }
        "gpt-3.5-turbo" = @{ input = 0.50; output = 1.50 }
    }
}

# Initialize data structure
function Initialize-AITracker {
    param([string]$ProjectName = "default")
    
    $config = @{
        project = $ProjectName
        initialized = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        version = "1.0"
        settings = $global:AITracker
    }
    
    if (-not (Test-Path $global:AITracker.ConfigFile)) {
        $config | ConvertTo-Json -Depth 5 | Out-File $global:AITracker.ConfigFile -Encoding UTF8
        Write-Host "✅ AI Tracker initialisiert für Projekt: $ProjectName" -ForegroundColor Green
    }
    
    if (-not (Test-Path $global:AITracker.DataFile)) {
        $initialData = @{
            metadata = @{
                project = $ProjectName
                created = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
                lastUpdate = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
                totalSessions = 0
                totalCost = 0.0
            }
            sessions = @()
            dailyStats = @{}
            monthlyStats = @{}
        }
        $initialData | ConvertTo-Json -Depth 5 | Out-File $global:AITracker.DataFile -Encoding UTF8
    }
}

# Core tracking function
function Track-AIOperation {
    param(
        [Parameter(Mandatory)]
        [string]$Feature,
        
        [int]$EstimatedTokens = 0,
        [int]$ActualTokens = 0,
        [decimal]$ActualCost = 0,
        [string]$Model = $global:AITracker.DefaultModel,
        [string]$SessionType = "development",
        [string]$Description = "",
        [hashtable]$Metadata = @{}
    )
    
    # Cost calculation if not provided
    if ($ActualCost -eq 0 -and $ActualTokens -gt 0) {
        $tokenCost = $global:AITracker.TokenCosts[$Model]
        if ($tokenCost) {
            # Simplified cost calculation (assuming 70% input, 30% output tokens)
            $inputTokens = [math]::Floor($ActualTokens * 0.7)
            $outputTokens = [math]::Ceiling($ActualTokens * 0.3)
            $ActualCost = ($inputTokens / 1000000 * $tokenCost.input) + ($outputTokens / 1000000 * $tokenCost.output)
        }
    }
    
    # Load existing data
    $data = Get-Content $global:AITracker.DataFile -Encoding UTF8 | ConvertFrom-Json
    
    # Create session entry
    $session = @{
        timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        feature = $Feature
        sessionType = $SessionType
        model = $Model
        estimatedTokens = $EstimatedTokens
        actualTokens = $ActualTokens
        actualCost = [math]::Round($ActualCost, 4)
        description = $Description
        metadata = $Metadata
    }
    
    # Add to sessions
    $data.sessions += $session
    $data.metadata.totalSessions++
    $data.metadata.totalCost += $ActualCost
    $data.metadata.lastUpdate = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    
    # Update daily stats
    $today = Get-Date -Format "yyyy-MM-dd"
    if (-not $data.dailyStats.$today) {
        $data.dailyStats.$today = @{
            sessions = 0
            totalCost = 0.0
            features = @{}
        }
    }
    $data.dailyStats.$today.sessions++
    $data.dailyStats.$today.totalCost += $ActualCost
    
    if (-not $data.dailyStats.$today.features.$Feature) {
        $data.dailyStats.$today.features.$Feature = @{ sessions = 0; cost = 0.0 }
    }
    $data.dailyStats.$today.features.$Feature.sessions++
    $data.dailyStats.$today.features.$Feature.cost += $ActualCost
    
    # Update monthly stats
    $currentMonth = Get-Date -Format "yyyy-MM"
    if (-not $data.monthlyStats.$currentMonth) {
        $data.monthlyStats.$currentMonth = @{
            sessions = 0
            totalCost = 0.0
            budget = $global:AITracker.MonthlyBudget
            features = @{}
        }
    }
    $data.monthlyStats.$currentMonth.sessions++
    $data.monthlyStats.$currentMonth.totalCost += $ActualCost
    
    if (-not $data.monthlyStats.$currentMonth.features.$Feature) {
        $data.monthlyStats.$currentMonth.features.$Feature = @{ sessions = 0; cost = 0.0 }
    }
    $data.monthlyStats.$currentMonth.features.$Feature.sessions++
    $data.monthlyStats.$currentMonth.features.$Feature.cost += $ActualCost
    
    # Save updated data
    $data | ConvertTo-Json -Depth 10 | Out-File $global:AITracker.DataFile -Encoding UTF8
    
    # Cost warnings
    Show-CostWarnings -Cost $ActualCost -DailyCost $data.dailyStats.$today.totalCost -MonthlyCost $data.monthlyStats.$currentMonth.totalCost
    
    # Return session info
    Write-Host "📊 AI Operation tracked: $Feature" -ForegroundColor Cyan
    Write-Host "   💰 Cost: $($ActualCost.ToString('F4')) USD" -ForegroundColor White
    if ($ActualTokens -gt 0) {
        Write-Host "   🎯 Tokens: $ActualTokens" -ForegroundColor Gray
    }
    
    return $session
}

# Cost warning system
function Show-CostWarnings {
    param(
        [decimal]$Cost,
        [decimal]$DailyCost,
        [decimal]$MonthlyCost
    )
    
    # Single operation warning
    if ($Cost -gt $global:AITracker.OperationLimit) {
        Write-Warning "⚠️ Teure Operation: $($Cost.ToString('F2')) USD (Limit: $($global:AITracker.OperationLimit))"
        Write-Host "💡 Optimierungsvorschläge:" -ForegroundColor Yellow
        Write-Host "  • Batch multiple requests together" -ForegroundColor Gray
        Write-Host "  • Reduce context size" -ForegroundColor Gray
        Write-Host "  • Use cheaper model for simple tasks" -ForegroundColor Gray
    }
    
    # Daily limit warning
    if ($DailyCost -gt $global:AITracker.DailyLimit) {
        Write-Warning "🚨 Tageslimit überschritten: $($DailyCost.ToString('F2')) USD (Limit: $($global:AITracker.DailyLimit))"
    }
    
    # Monthly budget warning
    $budgetPercentage = ($MonthlyCost / $global:AITracker.MonthlyBudget) * 100
    if ($budgetPercentage -gt 90) {
        Write-Warning "🔥 Monatsbudget zu $([math]::Round($budgetPercentage, 1))% ausgeschöpft!"
    }
    elseif ($budgetPercentage -gt 75) {
        Write-Host "⚠️ Monatsbudget zu $([math]::Round($budgetPercentage, 1))% verbraucht" -ForegroundColor Yellow
    }
}

# Live dashboard
function Show-CostDashboard {
    param([switch]$Detailed)
    
    if (-not (Test-Path $global:AITracker.DataFile)) {
        Write-Host "❌ Keine Tracking-Daten gefunden. Führen Sie zuerst Initialize-AITracker aus." -ForegroundColor Red
        return
    }
    
    $data = Get-Content $global:AITracker.DataFile -Encoding UTF8 | ConvertFrom-Json
    
    # Header
    Clear-Host
    Write-Host "📊 AI DEVELOPMENT COSTS - Live Dashboard" -ForegroundColor Cyan
    Write-Host "════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host ""
    
    # Current stats
    $today = Get-Date -Format "yyyy-MM-dd"
    $thisWeek = Get-WeeklyCosts $data
    $thisMonth = Get-Date -Format "yyyy-MM"
    
    $todayCost = if ($data.dailyStats.$today) { $data.dailyStats.$today.totalCost } else { 0 }
    $todaySessions = if ($data.dailyStats.$today) { $data.dailyStats.$today.sessions } else { 0 }
    
    $monthlyCost = if ($data.monthlyStats.$thisMonth) { $data.monthlyStats.$thisMonth.totalCost } else { 0 }
    $monthlySessions = if ($data.monthlyStats.$thisMonth) { $data.monthlyStats.$thisMonth.sessions } else { 0 }
    
    Write-Host "💰 HEUTE:        $($todayCost.ToString('F2')) USD   ($todaySessions Sessions)" -ForegroundColor Green
    Write-Host "📅 DIESE WOCHE:  $($thisWeek.ToString('F2')) USD   ($(Get-WeeklySessions $data) Sessions)" -ForegroundColor Cyan
    Write-Host "📆 DIESER MONAT: $($monthlyCost.ToString('F2')) USD   ($monthlySessions Sessions)" -ForegroundColor Blue
    Write-Host ""
    
    # Budget status
    $budgetPercentage = ($monthlyCost / $global:AITracker.MonthlyBudget) * 100
    $budgetColor = if ($budgetPercentage -gt 90) { "Red" } elseif ($budgetPercentage -gt 75) { "Yellow" } else { "Green" }
    Write-Host "💰 BUDGET STATUS: $([math]::Round($budgetPercentage, 1))% von $($global:AITracker.MonthlyBudget) USD verbraucht" -ForegroundColor $budgetColor
    Write-Host ""
    
    # Top cost drivers
    if ($data.monthlyStats.$thisMonth -and $data.monthlyStats.$thisMonth.features) {
        Write-Host "🔥 TOP KOSTENTREIBER (Dieser Monat):" -ForegroundColor Yellow
        $topFeatures = $data.monthlyStats.$thisMonth.features.PSObject.Properties | 
                      Sort-Object { $_.Value.cost } -Descending | 
                      Select-Object -First 5
        
        $rank = 1
        foreach ($feature in $topFeatures) {
            $cost = $feature.Value.cost.ToString('F2')
            $sessions = $feature.Value.sessions
            Write-Host "  $rank. $($feature.Name): $cost USD ($sessions Sessions)" -ForegroundColor White
            $rank++
        }
        Write-Host ""
    }
    
    # Trend analysis
    $forecast = Get-MonthlyForecast $data
    if ($forecast -gt $global:AITracker.MonthlyBudget) {
        Write-Host "📈 PROGNOSE: $($forecast.ToString('F0')) USD Monatsende ($([math]::Round(($forecast / $global:AITracker.MonthlyBudget) * 100, 0))% Budget)" -ForegroundColor Red
    } else {
        Write-Host "📈 PROGNOSE: $($forecast.ToString('F0')) USD Monatsende ($([math]::Round(($forecast / $global:AITracker.MonthlyBudget) * 100, 0))% Budget)" -ForegroundColor Green
    }
    
    if ($Detailed) {
        Show-DetailedStats $data
    }
    
    Write-Host ""
    Write-Host "Drücken Sie Enter zum Fortfahren..." -ForegroundColor Gray
    Read-Host
}

# Helper functions
function Get-WeeklyCosts {
    param($data)
    
    $weekStart = (Get-Date).AddDays(-7).ToString("yyyy-MM-dd")
    $total = 0
    
    foreach ($dayKey in $data.dailyStats.PSObject.Properties.Name) {
        if ($dayKey -ge $weekStart) {
            $total += $data.dailyStats.$dayKey.totalCost
        }
    }
    
    return $total
}

function Get-WeeklySessions {
    param($data)
    
    $weekStart = (Get-Date).AddDays(-7).ToString("yyyy-MM-dd")
    $total = 0
    
    foreach ($dayKey in $data.dailyStats.PSObject.Properties.Name) {
        if ($dayKey -ge $weekStart) {
            $total += $data.dailyStats.$dayKey.sessions
        }
    }
    
    return $total
}

function Get-MonthlyForecast {
    param($data)
    
    $currentMonth = Get-Date -Format "yyyy-MM"
    $currentDay = (Get-Date).Day
    $daysInMonth = [DateTime]::DaysInMonth((Get-Date).Year, (Get-Date).Month)
    
    if ($data.monthlyStats.$currentMonth) {
        $currentSpend = $data.monthlyStats.$currentMonth.totalCost
        $dailyAverage = $currentSpend / $currentDay
        return $dailyAverage * $daysInMonth
    }
    
    return 0
}

function Show-DetailedStats {
    param($data)
    
    Write-Host ""
    Write-Host "📈 DETAILLIERTE STATISTIKEN" -ForegroundColor Magenta
    Write-Host "═══════════════════════════" -ForegroundColor Magenta
    
    # Recent sessions
    Write-Host ""
    Write-Host "🕒 LETZTE SESSIONS (Top 10):" -ForegroundColor Yellow
    $recentSessions = $data.sessions | Sort-Object timestamp -Descending | Select-Object -First 10
    
    foreach ($session in $recentSessions) {
        $time = ([DateTime]$session.timestamp).ToString("HH:mm")
        $cost = $session.actualCost.ToString('F3')
        Write-Host "  $time | $($session.feature) | $cost USD | $($session.model)" -ForegroundColor Gray
    }
}

# Export functions
function Export-CostReport {
    param(
        [int]$Month = (Get-Date).Month,
        [int]$Year = (Get-Date).Year,
        [string]$Format = "JSON",
        [string]$OutputPath = ""
    )
    
    if (-not (Test-Path $global:AITracker.DataFile)) {
        Write-Error "Keine Tracking-Daten gefunden."
        return
    }
    
    $data = Get-Content $global:AITracker.DataFile -Encoding UTF8 | ConvertFrom-Json
    $monthKey = "$Year-$('{0:D2}' -f $Month)"
    
    if (-not $OutputPath) {
        $OutputPath = "ai-cost-report-$monthKey.$($Format.ToLower())"
    }
    
    $report = @{
        month = $monthKey
        generated = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        summary = if ($data.monthlyStats.$monthKey) { $data.monthlyStats.$monthKey } else { @{} }
        sessions = $data.sessions | Where-Object { $_.timestamp -like "$monthKey-*" }
        dailyBreakdown = @{}
    }
    
    # Daily breakdown for the month
    foreach ($dayKey in $data.dailyStats.PSObject.Properties.Name) {
        if ($dayKey -like "$monthKey-*") {
            $report.dailyBreakdown[$dayKey] = $data.dailyStats.$dayKey
        }
    }
    
    switch ($Format.ToUpper()) {
        "JSON" {
            $report | ConvertTo-Json -Depth 10 | Out-File $OutputPath -Encoding UTF8
        }
        "CSV" {
            $report.sessions | Export-Csv $OutputPath -NoTypeInformation -Encoding UTF8
        }
        default {
            Write-Error "Unsupported format: $Format. Use JSON or CSV."
            return
        }
    }
    
    Write-Host "✅ Report exported: $OutputPath" -ForegroundColor Green
}

# Budget management
function Set-MonthlyBudget {
    param([decimal]$Amount)
    
    $global:AITracker.MonthlyBudget = $Amount
    
    # Update config file
    if (Test-Path $global:AITracker.ConfigFile) {
        $config = Get-Content $global:AITracker.ConfigFile -Encoding UTF8 | ConvertFrom-Json
        $config.settings.MonthlyBudget = $Amount
        $config | ConvertTo-Json -Depth 5 | Out-File $global:AITracker.ConfigFile -Encoding UTF8
    }
    
    Write-Host "💰 Monatsbudget gesetzt: $Amount USD" -ForegroundColor Green
}

function Set-CostAlerts {
    param(
        [decimal]$DailyLimit = 20.00,
        [decimal]$OperationLimit = 2.00
    )
    
    $global:AITracker.DailyLimit = $DailyLimit
    $global:AITracker.OperationLimit = $OperationLimit
    
    Write-Host "⚠️ Kostenwarnungen konfiguriert:" -ForegroundColor Yellow
    Write-Host "   Tägliches Limit: $DailyLimit USD" -ForegroundColor Gray
    Write-Host "   Pro Operation: $OperationLimit USD" -ForegroundColor Gray
}

# Quick helpers for common use cases
function Start-AISession {
    param(
        [string]$Project = "default",
        [string]$Feature = "general"
    )
    
    Initialize-AITracker -ProjectName $Project
    
    Write-Host "🚀 AI Session gestartet: $Project / $Feature" -ForegroundColor Green
    Write-Host "💡 Verwenden Sie Track-AIOperation um Kosten zu tracken" -ForegroundColor Cyan
    
    # Show current budget status
    $data = Get-Content $global:AITracker.DataFile -Encoding UTF8 | ConvertFrom-Json
    $currentMonth = Get-Date -Format "yyyy-MM"
    if ($data.monthlyStats.$currentMonth) {
        $currentSpend = $data.monthlyStats.$currentMonth.totalCost
        $percentage = ($currentSpend / $global:AITracker.MonthlyBudget) * 100
        Write-Host "📊 Aktueller Monatsverbrauch: $($currentSpend.ToString('F2')) USD ($([math]::Round($percentage, 1))%)" -ForegroundColor Cyan
    }
}

function Get-QuickStats {
    if (-not (Test-Path $global:AITracker.DataFile)) {
        Write-Host "❌ Keine Daten gefunden. Starten Sie mit Start-AISession" -ForegroundColor Red
        return
    }
    
    $data = Get-Content $global:AITracker.DataFile -Encoding UTF8 | ConvertFrom-Json
    $currentMonth = Get-Date -Format "yyyy-MM"
    
    $stats = @{
        TotalSessions = $data.metadata.totalSessions
        TotalCost = $data.metadata.totalCost
        MonthlySpend = if ($data.monthlyStats.$currentMonth) { $data.monthlyStats.$currentMonth.totalCost } else { 0 }
        BudgetPercentage = if ($data.monthlyStats.$currentMonth) { 
            ($data.monthlyStats.$currentMonth.totalCost / $global:AITracker.MonthlyBudget) * 100 
        } else { 0 }
    }
    
    return $stats
}

# Example usage and help
function Show-AITrackerHelp {
    Write-Host "📊 AI PROMPT TRACKER - Hilfe" -ForegroundColor Cyan
    Write-Host "═══════════════════════════════" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "🚀 QUICK START:" -ForegroundColor Yellow
    Write-Host "  Start-AISession -Project 'MeinProjekt' -Feature 'UserAuth'" -ForegroundColor White
    Write-Host "  Track-AIOperation -Feature 'LoginSystem' -ActualTokens 8500 -ActualCost 0.85" -ForegroundColor White
    Write-Host "  Show-CostDashboard" -ForegroundColor White
    Write-Host ""
    Write-Host "📈 HAUPTFUNKTIONEN:" -ForegroundColor Yellow
    Write-Host "  Track-AIOperation      - AI-Operation tracken" -ForegroundColor White
    Write-Host "  Show-CostDashboard     - Live-Dashboard anzeigen" -ForegroundColor White
    Write-Host "  Export-CostReport      - Monatsreport exportieren" -ForegroundColor White
    Write-Host "  Set-MonthlyBudget      - Budget konfigurieren" -ForegroundColor White
    Write-Host "  Set-CostAlerts         - Warnungen konfigurieren" -ForegroundColor White
    Write-Host ""
    Write-Host "💡 BEISPIELE:" -ForegroundColor Yellow
    Write-Host "  # Teure Operation mit Warnung" -ForegroundColor Gray
    Write-Host "  Track-AIOperation -Feature 'ComplexGeneration' -ActualCost 3.50" -ForegroundColor White
    Write-Host ""
    Write-Host "  # Monatsreport als CSV" -ForegroundColor Gray
    Write-Host "  Export-CostReport -Month 6 -Year 2025 -Format CSV" -ForegroundColor White
    Write-Host ""
    Write-Host "  # Budget auf 500 USD setzen" -ForegroundColor Gray
    Write-Host "  Set-MonthlyBudget -Amount 500.00" -ForegroundColor White
}

# Module export (for importing as module)
Export-ModuleMember -Function @(
    'Initialize-AITracker',
    'Track-AIOperation', 
    'Show-CostDashboard',
    'Export-CostReport',
    'Set-MonthlyBudget',
    'Set-CostAlerts',
    'Start-AISession',
    'Get-QuickStats',
    'Show-AITrackerHelp'
)

# Auto-initialize if run directly
if ($MyInvocation.InvocationName -eq $MyInvocation.MyCommand.Name) {
    Write-Host "🔧 AI Prompt Tracker geladen - Verwenden Sie Show-AITrackerHelp für Hilfe" -ForegroundColor Green
}