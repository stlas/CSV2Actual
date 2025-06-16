# CSV2Actual - Simple Transaction Analyzer
# Version: 1.0.0
# Vereinfachte Analyse ohne komplexe Klassen

function Invoke-SimpleTransactionAnalysis {
    param(
        [string]$CsvDirectory = ".",
        [string]$Language = "de"
    )
    
    Write-Host ""
    if ($Language -eq "de") {
        Write-Host "=== TRANSAKTIONS-ANALYSE ===" -ForegroundColor Cyan
    } else {
        Write-Host "=== TRANSACTION ANALYSIS ===" -ForegroundColor Cyan
    }
    Write-Host ""
    
    # Load CategoryEngine
    if (-not $global:categoryEngine) {
        if ($Language -eq "de") {
            Write-Host "CategoryEngine nicht verfügbar" -ForegroundColor Red
        } else {
            Write-Host "CategoryEngine not available" -ForegroundColor Red
        }
        return
    }
    
    # Load configuration
    $localConfigPath = "config.local.json"
    $categoryMappings = @{}
    if (Test-Path $localConfigPath) {
        try {
            $localConfig = Get-Content -Path $localConfigPath -Raw -Encoding UTF8 | ConvertFrom-Json
            if ($localConfig.categoryMappings) {
                $localConfig.categoryMappings.PSObject.Properties | ForEach-Object {
                    $categoryMappings[$_.Name] = $_.Value
                }
            }
        } catch {
            if ($Language -eq "de") {
                Write-Warning "Fehler beim Laden der Konfiguration"
            } else {
                Write-Warning "Error loading configuration"
            }
        }
    }
    
    # Find CSV files
    $csvFiles = Get-ChildItem -Path $CsvDirectory -Filter "*.csv" | Where-Object { $_.Name -notlike "*actual*" }
    
    # PowerShell 5.1 compatibility: Handle single objects without .Count property
    $csvFileCount = if ($csvFiles) { 
        if ($csvFiles.GetType().IsArray -or $csvFiles.Count) { 
            $csvFiles.Count 
        } else { 
            1 
        }
    } else { 
        0 
    }
    
    if ($csvFileCount -eq 0) {
        if ($Language -eq "de") {
            Write-Host "Keine CSV-Dateien gefunden in $CsvDirectory" -ForegroundColor Yellow
        } else {
            Write-Host "No CSV files found in $CsvDirectory" -ForegroundColor Yellow
        }
        return
    }
    
    # Statistics
    $totalTransactions = 0
    $categorizedCount = 0
    $transferCount = 0
    $incomeCount = 0
    $uncategorizedPayees = @{}
    
    if ($Language -eq "de") {
        Write-Host "Analysiere CSV-Dateien..." -ForegroundColor Gray
    } else {
        Write-Host "Analyzing CSV files..." -ForegroundColor Gray
    }
    
    foreach ($file in $csvFiles) {
        Write-Host "  -> $($file.Name)" -ForegroundColor Gray
        
        try {
            $csvData = Import-Csv -Path $file.FullName -Delimiter ';' -Encoding UTF8
            
            foreach ($row in $csvData) {
                $totalTransactions++
                
                # Extract payee
                $payee = if ($row."Name Zahlungsbeteiligter") { 
                    $row."Name Zahlungsbeteiligter".Trim() 
                } else { 
                    "UNKNOWN_PAYEE" 
                }
                
                # Check if already categorized
                $isAlreadyCategorized = $false
                if ($categoryMappings.Keys -contains $payee) {
                    $isAlreadyCategorized = $true
                    $categorizedCount++
                }
                
                # Check if transfer (simplified)
                $amount = if ($row."Betrag") { $row."Betrag" } else { "0" }
                $memo = if ($row."Verwendungszweck") { $row."Verwendungszweck" } else { "" }
                
                if (-not $isAlreadyCategorized) {
                    # Check CategoryEngine
                    $transaction = @{
                        payee = $payee
                        memo = $memo
                        buchungstext = if ($row."Buchungstext") { $row."Buchungstext" } else { "" }
                        amount = $amount
                    }
                    
                    $category = $global:categoryEngine.CategorizeTransaction($transaction)
                    if ($category -and $category.Trim() -ne "") {
                        $categorizedCount++
                        $isAlreadyCategorized = $true
                    }
                }
                
                # Check if income (positive amount)
                if (-not $isAlreadyCategorized -and $amount -match '^[0-9]+' -and $amount -notmatch '^-') {
                    $incomeCount++
                    $isAlreadyCategorized = $true
                }
                
                # Add to uncategorized if not categorized
                if (-not $isAlreadyCategorized) {
                    if (-not ($uncategorizedPayees.Keys -contains $payee)) {
                        $uncategorizedPayees[$payee] = @()
                    }
                    $uncategorizedPayees[$payee] += @{
                        date = if ($row."Buchungstag") { $row."Buchungstag" } else { "UNKNOWN" }
                        amount = $amount
                        memo = $memo
                    }
                }
            }
        } catch {
            Write-Host "    Fehler bei $($file.Name): $($_.Exception.Message)" -ForegroundColor Yellow
        }
    }
    
    # Results
    Write-Host ""
    if ($Language -eq "de") {
        Write-Host "=== ERGEBNISSE ===" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "Gesamt-Transaktionen: $totalTransactions" -ForegroundColor White
        Write-Host "Kategorisiert: $categorizedCount" -ForegroundColor Green
        Write-Host "Einkommen (automatisch): $incomeCount" -ForegroundColor Green
    } else {
        Write-Host "=== RESULTS ===" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "Total transactions: $totalTransactions" -ForegroundColor White
        Write-Host "Categorized: $categorizedCount" -ForegroundColor Green
        Write-Host "Income (automatic): $incomeCount" -ForegroundColor Green
    }
    
    $categorizedTotal = $categorizedCount + $incomeCount
    $percentage = if ($totalTransactions -gt 0) { 
        [math]::Round(($categorizedTotal / $totalTransactions) * 100, 1) 
    } else { 0 }
    
    Write-Host ""
    if ($Language -eq "de") {
        Write-Host "Kategorisierungsrate: $percentage%" -ForegroundColor $(if ($percentage -ge 90) { "Green" } elseif ($percentage -ge 70) { "Yellow" } else { "Red" })
    } else {
        Write-Host "Categorization rate: $percentage%" -ForegroundColor $(if ($percentage -ge 90) { "Green" } elseif ($percentage -ge 70) { "Yellow" } else { "Red" })
    }
    
    # Uncategorized payees
    # PowerShell 5.1 compatibility: Handle hashtable count
    $uncategorizedCount = if ($uncategorizedPayees) { 
        $uncategorizedPayees.Keys.Count 
    } else { 
        0 
    }
    
    if ($uncategorizedCount -gt 0) {
        Write-Host ""
        if ($Language -eq "de") {
            Write-Host "=== NICHT KATEGORISIERTE ZAHLUNGSEMPFAENGER ===" -ForegroundColor Red
        } else {
            Write-Host "=== UNCATEGORIZED PAYEES ===" -ForegroundColor Red
        }
        Write-Host ""
        
        foreach ($payee in $uncategorizedPayees.Keys) {
            $transactions = $uncategorizedPayees[$payee]
            # PowerShell 5.1 compatibility: Handle transaction count
            $transactionCount = if ($transactions) { 
                if ($transactions.GetType().IsArray -or $transactions.Count) { 
                    $transactions.Count 
                } else { 
                    1 
                }
            } else { 
                0 
            }
            
            if ($Language -eq "de") {
                Write-Host "$payee ($transactionCount Transaktionen)" -ForegroundColor Yellow
            } else {
                Write-Host "$payee ($transactionCount transactions)" -ForegroundColor Yellow
            }
            
            # Show first transaction as example
            if ($transactionCount -gt 0) {
                $example = $transactions[0]
                if ($Language -eq "de") {
                    Write-Host "  Beispiel: $($example.date) | $($example.amount) EUR" -ForegroundColor Gray
                } else {
                    Write-Host "  Example: $($example.date) | $($example.amount) EUR" -ForegroundColor Gray
                }
                if ($example.memo) {
                    Write-Host "  Memo: $($example.memo)" -ForegroundColor Gray
                }
            }
            Write-Host ""
        }
    } else {
        Write-Host ""
        if ($Language -eq "de") {
            Write-Host "Alle Transaktionen sind kategorisiert!" -ForegroundColor Green
        } else {
            Write-Host "All transactions are categorized!" -ForegroundColor Green
        }
    }
    
    Write-Host ""
    if ($Language -eq "de") {
        Write-Host "Analyse abgeschlossen." -ForegroundColor Cyan
    } else {
        Write-Host "Analysis completed." -ForegroundColor Cyan
    }
}