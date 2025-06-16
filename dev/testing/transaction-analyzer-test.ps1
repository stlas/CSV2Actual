# Test der TransactionAnalyzer-Funktionalität
# Vereinfachter Test mit Beispieldaten

param(
    [string]$Language = "de"
)

# Module laden
. "$PSScriptRoot/modules/Config.ps1"
. "$PSScriptRoot/modules/CategoryEngine.ps1"
. "$PSScriptRoot/modules/TransactionAnalyzer.ps1"

# Test-CSV-Daten erstellen
$testCsvDir = "$PSScriptRoot/test_data/analyzer_test"
if (-not (Test-Path $testCsvDir)) {
    New-Item -ItemType Directory -Path $testCsvDir -Force | Out-Null
}

# Test-CSV mit verschiedenen Transaktionstypen erstellen
$testCsvContent = @"
Datum;Empfänger/Zahlungspflichtige;Verwendungszweck;Betrag;IBAN
01.12.2024;REWE MARKT;Lebensmitteleinkauf;-45,67;DE12345678901234567890
02.12.2024;Shell Tankstelle;Kraftstoff tanken;-65,00;DE12345678901234567890
03.12.2024;Arbeitgeber;LOHN Dezember 2024;2500,00;DE12345678901234567890
04.12.2024;Amazon;Online-Bestellung;-89,99;DE12345678901234567890
05.12.2024;Gemeinde;Steuererstattung;150,00;DE12345678901234567890
06.12.2024;EDEKA;Lebensmittel;-38,45;DE12345678901234567890
07.12.2024;Aral;TANKEN;-52,30;DE12345678901234567890
08.12.2024;Unbekannter Händler;Mysterium Ausgabe;-25,00;DE12345678901234567890
09.12.2024;Netflix;Streaming Abo;-12,99;DE12345678901234567890
10.12.2024;Sparkasse;Kontoführungsgebühr;-8,90;DE12345678901234567890
"@

$testCsvPath = "$testCsvDir/test_transactions.csv"
$testCsvContent | Out-File -FilePath $testCsvPath -Encoding UTF8

Write-Host "=== TRANSAKTIONS-ANALYZER TEST ===" -ForegroundColor Cyan
Write-Host ""
Write-Host "Test-CSV erstellt: $testCsvPath" -ForegroundColor Yellow
Write-Host "Inhalt (10 Test-Transaktionen):" -ForegroundColor Yellow
Write-Host "- 2 Einkommen (Lohn, Steuererstattung)"
Write-Host "- 3 Lebensmittel/Tankstelle (sollten per Keywords erkannt werden)" 
Write-Host "- 5 Verschiedene Ausgaben (teilweise unbekannt)"
Write-Host ""

try {
    # Konfiguration laden
    $config = [Config]::new("$PSScriptRoot/config.json")
    
    # CategoryEngine initialisieren
    $categoryEngine = [CategoryEngine]::new("$PSScriptRoot/categories.json", $Language)
    
    # Analyzer erstellen und ausführen
    $analyzer = [TransactionAnalyzer]::new($categoryEngine, $config.data, $Language)
    $analyzer.AnalyzeAllTransactions($testCsvDir)
    
} catch {
    Write-Host "Fehler beim Test: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Details: $($_.Exception)" -ForegroundColor DarkRed
}

Write-Host ""
Write-Host "Test abgeschlossen!" -ForegroundColor Green
Write-Host "Test-Dateien können in '$testCsvDir' eingesehen werden." -ForegroundColor Gray