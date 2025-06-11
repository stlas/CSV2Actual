# CSV2Actual - Test CSV Generator
# Version: 1.1.0
# Author: sTLAs (https://github.com/sTLAs)
# Creates test CSV files for Actual Budget import testing

param(
    [Parameter(Mandatory=$false)]
    [ValidateSet("minimal", "category-test", "transfer-test", "encoding-test", "all")]
    [string]$TestType = "minimal",
    
    [Alias("l")][string]$Language = "en",
    [switch]$Help
)

if ($Help) {
    Write-Host "CSV2ACTUAL - TEST CSV GENERATOR" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "USAGE:" -ForegroundColor Yellow
    Write-Host "  powershell -ExecutionPolicy Bypass -File create_test_csv.ps1 [options]"
    Write-Host ""
    Write-Host "OPTIONS:" -ForegroundColor Yellow
    Write-Host "  -TestType <type>    Type of test CSV to create:"
    Write-Host "                      minimal      - Basic 3-row test CSV"
    Write-Host "                      category-test - CSV to test category recognition"
    Write-Host "                      transfer-test - CSV to test transfer recognition"
    Write-Host "                      encoding-test - CSV with special characters"
    Write-Host "                      all          - Create all test types"
    Write-Host "  -Language <lang>    Language (en/de)"
    Write-Host "  -Help              Show this help"
    Write-Host ""
    Write-Host "EXAMPLES:" -ForegroundColor Yellow
    Write-Host "  create_test_csv.ps1 -TestType minimal"
    Write-Host "  create_test_csv.ps1 -TestType all -Language de"
    exit 0
}

# Load modules
. "$PSScriptRoot/modules/I18n.ps1"

# Initialize i18n
try {
    $global:i18n = [I18n]::new("$PSScriptRoot/lang", $Language)
} catch {
    Write-Host "WARNING: Could not load language files, using English fallback" -ForegroundColor Yellow
    $global:i18n = $null
}

function t {
    param([string]$key, [array]$args = @())
    if ($global:i18n) {
        if ($args.Length -gt 0) {
            return $global:i18n.Get($key, $args)
        }
        return $global:i18n.Get($key)
    }
    return $key
}

Write-Host "CSV2ACTUAL - TEST CSV GENERATOR" -ForegroundColor Cyan
Write-Host ""

# Ensure output directory exists
$outputDir = "actual_import"
if (-not (Test-Path $outputDir)) {
    New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
}

function New-MinimalTestCsv {
    $content = @"
date,account,payee,notes,category,amount
2025-06-01,Test-Account,Test Store,Test purchase,Groceries,-25.50
2025-06-02,Test-Account,Test Employer,Monthly salary,Salary,2500.00
2025-06-03,Test-Account,Test Transfer,Internal transfer,Transfer to Savings,-500.00
"@

    $fileName = "TEST_Minimal.csv"
    $filePath = Join-Path $outputDir $fileName
    $content | Out-File -FilePath $filePath -Encoding UTF8
    Write-Host "✅ Created: $fileName" -ForegroundColor Green
    return $filePath
}

function New-CategoryTestCsv {
    $content = @"
date,account,payee,notes,category,amount
2025-06-01,Test-Account,REWE Markt,Lebensmittel einkaufen,,45.67
2025-06-01,Test-Account,Shell Tankstelle,Benzin tanken,,65.00
2025-06-01,Test-Account,Telekom,Internet und Telefon,,49.99
2025-06-01,Test-Account,Allianz Versicherung,Hausratversicherung,,89.50
2025-06-01,Test-Account,Amazon,Online shopping,,29.99
2025-06-01,Test-Account,Netflix,Streaming subscription,,9.99
2025-06-01,Test-Account,Commerzbank,Kontoführungsgebühr,,12.00
2025-06-01,Test-Account,DB Regio,Bahnfahrt,,15.80
2025-06-01,Test-Account,TestPharmacy,Medikamente,,8.50
2025-06-01,Test-Account,Mustermann GmbH,Gehalt,,-2500.00
"@

    $fileName = "TEST_Categories.csv"
    $filePath = Join-Path $outputDir $fileName
    $content | Out-File -FilePath $filePath -Encoding UTF8
    Write-Host "✅ Created: $fileName" -ForegroundColor Green
    Write-Host "   Purpose: Test automatic categorization patterns" -ForegroundColor Gray
    return $filePath
}

function New-TransferTestCsv {
    $content = @"
date,account,payee,notes,category,amount
2025-06-01,Max-Checking,Anna TestUser,Haushaltsgeld überweisung,,500.00
2025-06-01,Max-Checking,TestUser2,Rückzahlung Darlehen,,200.00
2025-06-01,Max-Checking,Eigene Überweisung,Transfer zum Sparbuch,,-1000.00
2025-06-01,Anna-Checking,Max TestUser,Haushaltsbeitrag,,-500.00
2025-06-01,Household-Account,Max TestUser,Einzahlung Haushaltskasse,,1000.00
2025-06-01,Household-Account,Anna TestUser,Einzahlung Haushaltskasse,,800.00
"@

    $fileName = "TEST_Transfers.csv"
    $filePath = Join-Path $outputDir $fileName
    $content | Out-File -FilePath $filePath -Encoding UTF8
    Write-Host "✅ Created: $fileName" -ForegroundColor Green
    Write-Host "   Purpose: Test transfer recognition between accounts" -ForegroundColor Gray
    return $filePath
}

function New-EncodingTestCsv {
    $content = @"
date,account,payee,notes,category,amount
2025-06-01,Tëst-Áccöunt,Müller & Söhne GmbH,Geschäfte mit Umlauten,,123.45
2025-06-01,Test-Account,Café François,Coffee with special chars,,4.50
2025-06-01,Test-Account,Москва Store,Unicode test,,67.89
2025-06-01,Test-Account,Test"Quotes,CSV escaping test,,10.00
2025-06-01,Test-Account,Comma\, Test,Delimiter test,,20.00
"@

    $fileName = "TEST_Encoding.csv"
    $filePath = Join-Path $outputDir $fileName
    # Deliberately save with UTF-8 BOM to test BOM handling
    [System.IO.File]::WriteAllText($filePath, $content, [System.Text.UTF8Encoding]::new($true))
    Write-Host "✅ Created: $fileName (with UTF-8 BOM)" -ForegroundColor Green
    Write-Host "   Purpose: Test special character and encoding handling" -ForegroundColor Gray
    return $filePath
}

function New-AlternativeFormats {
    param([string]$basePath)
    
    # Read the base CSV
    $csvData = Import-Csv -Path $basePath -Encoding UTF8
    
    $baseName = (Get-Item $basePath).BaseName
    
    # Semicolon format
    $semicolonPath = Join-Path $outputDir "$baseName`_SEMICOLON.csv"
    $csvData | Export-Csv -Path $semicolonPath -NoTypeInformation -Encoding UTF8 -Delimiter ";"
    Write-Host "  📄 Alternative format: $baseName`_SEMICOLON.csv" -ForegroundColor Cyan
    
    # Tab format
    $tabPath = Join-Path $outputDir "$baseName`_TAB.csv"
    $csvData | Export-Csv -Path $tabPath -NoTypeInformation -Encoding UTF8 -Delimiter "`t"
    Write-Host "  📄 Alternative format: $baseName`_TAB.csv" -ForegroundColor Cyan
    
    # Manual format (no Export-Csv)
    $manualPath = Join-Path $outputDir "$baseName`_MANUAL.csv"
    $manualContent = "date,account,payee,notes,category,amount`n"
    foreach ($row in $csvData) {
        $manualContent += "$($row.date),$($row.account),$($row.payee),$($row.notes),$($row.category),$($row.amount)`n"
    }
    $manualContent | Out-File -FilePath $manualPath -Encoding ASCII
    Write-Host "  📄 Alternative format: $baseName`_MANUAL.csv (ASCII)" -ForegroundColor Cyan
}

# Create test CSVs based on type
$createdFiles = @()

switch ($TestType) {
    "minimal" {
        $createdFiles += New-MinimalTestCsv
    }
    "category-test" {
        $createdFiles += New-CategoryTestCsv
    }
    "transfer-test" {
        $createdFiles += New-TransferTestCsv
    }
    "encoding-test" {
        $createdFiles += New-EncodingTestCsv
    }
    "all" {
        Write-Host "Creating all test CSV types..." -ForegroundColor Yellow
        $createdFiles += New-MinimalTestCsv
        $createdFiles += New-CategoryTestCsv
        $createdFiles += New-TransferTestCsv
        $createdFiles += New-EncodingTestCsv
    }
}

Write-Host ""

# Optionally create alternative formats
if ($createdFiles.Count -gt 0) {
    $createAlternatives = Read-Host "Create alternative formats (semicolon, tab, manual) for testing? (y/n)"
    if ($createAlternatives -eq "y" -or $createAlternatives -eq "Y") {
        Write-Host ""
        Write-Host "Creating alternative formats..." -ForegroundColor Yellow
        foreach ($file in $createdFiles) {
            New-AlternativeFormats -basePath $file
        }
    }
}

Write-Host ""
Write-Host "📊 TESTING INSTRUCTIONS:" -ForegroundColor Cyan
Write-Host ""
Write-Host "1. Import test CSV files into Actual Budget" -ForegroundColor White
Write-Host "2. Check if categories are recognized correctly" -ForegroundColor White
Write-Host "3. Verify transfer recognition works" -ForegroundColor White
Write-Host "4. Test different format variants if created" -ForegroundColor White
Write-Host ""
Write-Host "📁 Test files location: $outputDir/" -ForegroundColor Yellow
Write-Host ""
Write-Host "🔍 WHAT TO CHECK:" -ForegroundColor Cyan
Write-Host "  ✅ Categories appear in import preview" -ForegroundColor Green
Write-Host "  ✅ Transfers are properly categorized" -ForegroundColor Green
Write-Host "  ✅ Special characters display correctly" -ForegroundColor Green
Write-Host "  ✅ Different delimiter formats work" -ForegroundColor Green
Write-Host ""
Write-Host "❌ IF CATEGORIES DON'T APPEAR:" -ForegroundColor Red
Write-Host "  → Actual Budget category mapping issue" -ForegroundColor Red
Write-Host "  → Try alternative format variants" -ForegroundColor Red
Write-Host "  → Check encoding with debug_csv_encoding.ps1" -ForegroundColor Red
Write-Host ""
Write-Host "Test CSV generation complete! 🎉" -ForegroundColor Green