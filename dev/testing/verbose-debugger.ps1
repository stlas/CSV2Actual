# Ausführliches Debug-Script mit maximaler Fehlererfassung
# Verwendung: pwsh -File debug_run_verbose.ps1

$DebugLogFile = "debug_verbose_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"

Write-Host "🔍 VERBOSE DEBUG-MODUS AKTIVIERT" -ForegroundColor Yellow
Write-Host "📝 Alle Ausgaben und Fehler werden erfasst in: $DebugLogFile" -ForegroundColor Cyan
Write-Host ""

# Alle Ausgaben in Log-Datei umleiten
Start-Transcript -Path $DebugLogFile -Force

Write-Host "=== DEBUG SESSION START: $(Get-Date) ===" -ForegroundColor Magenta
Write-Host "PowerShell Version: $($PSVersionTable.PSVersion)" -ForegroundColor Gray
Write-Host "Arbeitsverzeichnis: $(Get-Location)" -ForegroundColor Gray
Write-Host "Benutzer: $env:USERNAME" -ForegroundColor Gray
Write-Host ""

try {
    # Verbose und Debug-Output aktivieren
    $VerbosePreference = "Continue"
    $DebugPreference = "Continue"
    $ErrorActionPreference = "Continue"
    $WarningPreference = "Continue"
    
    Write-Host "🔧 Prüfe Hauptskript..." -ForegroundColor Green
    if (-not (Test-Path "CSV2Actual.ps1")) {
        throw "CSV2Actual.ps1 nicht gefunden im Verzeichnis $(Get-Location)"
    }
    
    Write-Host "🔧 Prüfe Module..." -ForegroundColor Green
    $modules = @("Config.ps1", "I18n.ps1", "CategoryManager.ps1")
    foreach ($module in $modules) {
        $modulePath = "modules/$module"
        if (Test-Path $modulePath) {
            Write-Host "✅ $module gefunden" -ForegroundColor Green
        } else {
            Write-Host "⚠️ $module FEHLT" -ForegroundColor Red
        }
    }
    
    Write-Host ""
    Write-Host "⏳ STARTE CSV2ACTUAL..." -ForegroundColor Yellow
    Write-Host "========================================" -ForegroundColor Yellow
    
    # CSV2Actual mit maximaler Fehlererfassung starten
    try {
        . ".\CSV2Actual.ps1" -Language de -DryRun
    } catch {
        Write-Host ""
        Write-Host "🚨 FEHLER BEI DER AUSFÜHRUNG:" -ForegroundColor Red
        Write-Host "Nachricht: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "Typ: $($_.Exception.GetType().Name)" -ForegroundColor Red
        Write-Host "Stack Trace:" -ForegroundColor Red
        Write-Host $_.Exception.StackTrace -ForegroundColor Gray
        Write-Host ""
        Write-Host "Fehler-Details:" -ForegroundColor Red
        Write-Host $_ | Format-List * -Force
        
        # Inner Exception prüfen
        if ($_.Exception.InnerException) {
            Write-Host ""
            Write-Host "Inner Exception:" -ForegroundColor Red
            Write-Host $_.Exception.InnerException.Message -ForegroundColor Red
        }
    }
    
} catch {
    Write-Host ""
    Write-Host "🔥 KRITISCHER FEHLER IM DEBUG-SCRIPT:" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    Write-Host $_.Exception.StackTrace -ForegroundColor Gray
} finally {
    Write-Host ""
    Write-Host "=== DEBUG SESSION END: $(Get-Date) ===" -ForegroundColor Magenta
    Stop-Transcript
}

Write-Host ""
Write-Host "📊 DEBUG ABGESCHLOSSEN" -ForegroundColor Cyan
Write-Host "📝 Vollständiger Log: $DebugLogFile" -ForegroundColor White
Write-Host ""
Write-Host "📖 Log anzeigen mit:" -ForegroundColor Yellow
Write-Host "   Get-Content $DebugLogFile | More" -ForegroundColor White
Write-Host "   # oder"
Write-Host "   notepad $DebugLogFile" -ForegroundColor White