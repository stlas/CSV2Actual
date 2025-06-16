# Debug-Script mit korrekter Encoding-Behandlung
$OutputEncoding = [System.Text.Encoding]::UTF8
$PSDefaultParameterValues['Out-File:Encoding'] = 'utf8'

$DebugLogFile = "debug_utf8_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"

Write-Host "🔍 Debug mit UTF-8 Encoding - Log: $DebugLogFile"

# Führe CSV2Actual aus und erfasse Ausgabe korrekt
try {
    $output = & ".\CSV2Actual.ps1" -Language de -DryRun 2>&1
    $output | Out-File -FilePath $DebugLogFile -Encoding UTF8
    Write-Host "✅ Ausführung abgeschlossen"
} catch {
    "FEHLER: $($_.Exception.Message)" | Out-File -FilePath $DebugLogFile -Append -Encoding UTF8
}

Write-Host "📝 Log-Datei: $DebugLogFile"