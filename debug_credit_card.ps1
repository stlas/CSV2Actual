# Debug script for credit card processing

# Load modules
. "$PSScriptRoot/modules/Config.ps1"
. "$PSScriptRoot/modules/I18n.ps1"
. "$PSScriptRoot/modules/CsvValidator.ps1"

# Initialize
$global:config = [Config]::new("$PSScriptRoot/config.json")
$global:i18n = [I18n]::new("$PSScriptRoot/lang", "de")

# Test file
$filePath = "$PSScriptRoot/source/Kreditkarte.csv"

Write-Host "Testing file: $filePath" -ForegroundColor Cyan

# Test 1: Import CSV directly
Write-Host "`nTest 1: Direct CSV import" -ForegroundColor Yellow
try {
    $csvData = Import-Csv -Path $filePath -Delimiter ";" -Encoding UTF8
    Write-Host "Rows: $($csvData.Count)" -ForegroundColor Green
    Write-Host "Headers: $($csvData[0].PSObject.Properties.Name -join ', ')" -ForegroundColor Green
    Write-Host "First row data:" -ForegroundColor Green
    $csvData[0] | Format-List | Out-String | Write-Host
} catch {
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
}

# Test 2: Validator
Write-Host "`nTest 2: CsvValidator" -ForegroundColor Yellow
try {
    $validator = [CsvValidator]::new($global:i18n)
    $validationResult = $validator.ValidateFile($filePath)
    Write-Host "Valid: $($validationResult.isValid)" -ForegroundColor Green
    Write-Host "Column mapping: $($validationResult.columnMapping | ConvertTo-Json)" -ForegroundColor Green
    Write-Host "Errors: $($validationResult.errors -join ', ')" -ForegroundColor Red
} catch {
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
}

# Test 3: Credit card payee extraction
Write-Host "`nTest 3: Credit card payee extraction" -ForegroundColor Yellow
$testStrings = @(
    "Baeckerei Pfrommer         DEU Pforzheim              EUR             12,95      Umsatz vom 26.05.2025      MC Hauptkarte",
    "ALDI SUeD                  DEU Calw                   EUR             34,03      Umsatz vom 26.05.2025      MC Hauptkarte",
    "PAYPAL *HELLOFRESH         DEU 35314369001            EUR             60,57      Umsatz vom 23.05.2025      MC Hauptkarte"
)

foreach ($testString in $testStrings) {
    if ($testString -match '^([A-Za-z0-9\s\*\.\-]+)\s+DEU\s+') {
        $extractedPayee = $matches[1].Trim()
        $extractedPayee = $extractedPayee -replace '\s+', ' '
        $extractedPayee = $extractedPayee -replace '^\*', ''
        Write-Host "Input: $testString" -ForegroundColor Gray
        Write-Host "Extracted: '$extractedPayee'" -ForegroundColor Green
    } else {
        Write-Host "NO MATCH: $testString" -ForegroundColor Red
    }
}