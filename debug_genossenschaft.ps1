# Debug script for Genossenschaftsanteil CSV processing

# Load modules
. "$PSScriptRoot/modules/Config.ps1"
. "$PSScriptRoot/modules/I18n.ps1"
. "$PSScriptRoot/modules/CsvValidator.ps1"

# Initialize configuration
try {
    $global:config = [Config]::new("$PSScriptRoot/config.json")
    $langDir = $global:config.Get("paths.languageDir")
    $global:i18n = [I18n]::new($langDir, "de")
}
catch {
    Write-Host "ERROR: Could not load configuration. Details: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# Get configuration values
$ExcludePatterns = $global:config.GetCSVSettings().excludePatterns
$sourceDir = $global:config.GetSourceDir()

Write-Host "=== DEBUG: Genossenschaftsanteil CSV Processing ===" -ForegroundColor Cyan
Write-Host ""

# Find all CSV files
$allCsvFiles = Get-ChildItem -Path $sourceDir -Filter "*.csv"
Write-Host "All CSV files found:" -ForegroundColor Yellow
foreach ($file in $allCsvFiles) {
    Write-Host "  - $($file.Name)" -ForegroundColor White
}
Write-Host ""

# Apply exclude patterns
$csvFiles = $allCsvFiles | Where-Object { 
    $exclude = $false
    foreach ($pattern in $ExcludePatterns) {
        if ($_.Name -match $pattern) {
            $exclude = $true
            Write-Host "EXCLUDED by pattern '$pattern': $($_.Name)" -ForegroundColor Red
            break
        }
    }
    -not $exclude
}

Write-Host "Files after exclude patterns:" -ForegroundColor Yellow
foreach ($file in $csvFiles) {
    Write-Host "  - $($file.Name)" -ForegroundColor Green
}
Write-Host ""

# Focus on Genossenschaftsanteil files
$genossenschaftFiles = $csvFiles | Where-Object { $_.Name -match "Geschäftsanteil" }

Write-Host "Genossenschaftsanteil files:" -ForegroundColor Yellow
foreach ($file in $genossenschaftFiles) {
    Write-Host "  Processing: $($file.Name)" -ForegroundColor Cyan
    
    try {
        # Try to read the CSV
        $csvData = Import-Csv -Path $file.FullName -Delimiter ";" -Encoding UTF8
        Write-Host "    ✓ CSV read successfully. Rows: $($csvData.Count)" -ForegroundColor Green
        
        # Show first few rows
        if ($csvData.Count -gt 0) {
            Write-Host "    Headers:" -ForegroundColor White
            $headers = $csvData[0].PSObject.Properties.Name
            foreach ($header in $headers) {
                Write-Host "      - $header" -ForegroundColor Gray
            }
            
            Write-Host "    Data rows:" -ForegroundColor White
            for ($i = 0; $i -lt [Math]::Min(3, $csvData.Count); $i++) {
                $row = $csvData[$i]
                Write-Host "      Row $($i+1):" -ForegroundColor Gray
                Write-Host "        Buchungstag: $($row.Buchungstag)" -ForegroundColor Gray
                Write-Host "        Betrag: $($row.Betrag)" -ForegroundColor Gray
                Write-Host "        Name: $($row.'Name Zahlungsbeteiligter')" -ForegroundColor Gray
                Write-Host "        Verwendungszweck: $($row.Verwendungszweck)" -ForegroundColor Gray
                Write-Host "        Saldo: $($row.'Saldo nach Buchung')" -ForegroundColor Gray
            }
        }
        
        # Check what the processor would return
        $processedRows = 0
        foreach ($row in $csvData) {
            # Skip rows with 0 amount?
            $amount = 0
            if ($row.Betrag) {
                $cleanAmount = $row.Betrag -replace '\.', '' -replace ',', '.'
                try {
                    $amount = [decimal]$cleanAmount
                } catch { }
            }
            
            if ($amount -ne 0) {
                $processedRows++
            }
            
            Write-Host "    Row with amount $amount would be " -NoNewline -ForegroundColor Gray
            if ($amount -eq 0) {
                Write-Host "SKIPPED" -ForegroundColor Red
            } else {
                Write-Host "PROCESSED" -ForegroundColor Green
            }
        }
        
        Write-Host "    Result: $processedRows rows would be processed" -ForegroundColor $(if ($processedRows -gt 0) { "Green" } else { "Red" })
        
    } catch {
        Write-Host "    ✗ Error reading CSV: $($_.Exception.Message)" -ForegroundColor Red
    }
    Write-Host ""
}

Write-Host "=== END DEBUG ===" -ForegroundColor Cyan