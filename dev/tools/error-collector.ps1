# Debug-Script um alle Fehler zu erfassen
Write-Host "Starte Debug-Erfassung..."

# Starte das Script und erfasse sowohl stdout als auch stderr
$ErrorActionPreference = "Continue"

try {
    $result = & pwsh -ExecutionPolicy Bypass -File "CSV2Actual.ps1" -Language de -DryRun 2>&1
    
    # Schreibe alles in eine Log-Datei
    $result | Out-File "full_debug_output.log" -Encoding UTF8
    
    # Filtere nur Fehler
    $errors = $result | Where-Object { $_ -is [System.Management.Automation.ErrorRecord] -or $_.ToString() -match "Error|Exception|Fehler" }
    
    if ($errors) {
        Write-Host "FEHLER GEFUNDEN:" -ForegroundColor Red
        $errors | Out-File "errors_only.log" -Encoding UTF8
        $errors
    } else {
        Write-Host "Keine expliziten Fehler gefunden" -ForegroundColor Green
    }
    
    Write-Host "`nVollständige Ausgabe in: full_debug_output.log"
    Write-Host "Nur Fehler in: errors_only.log"
    
} catch {
    Write-Host "EXCEPTION: $($_.Exception.Message)" -ForegroundColor Red
    $_.Exception | Out-File "exception.log" -Encoding UTF8
}