# Debug script that uses the actual Process-BankCSV function

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

# Get configuration values (same as in bank_csv_processor.ps1)
$OwnIBANs = $global:config.GetIBANMapping()
$csvSettings = $global:config.GetCSVSettings()
$ExcludePatterns = $csvSettings.excludePatterns
$OutputDir = $global:config.GetOutputDir()
$categorizationPatterns = $global:config.GetCategorizationPatterns()

# Include all functions from bank_csv_processor.ps1
function Test-PatternMatch {
    param(
        [string]$text,
        [array]$patterns
    )
    
    if (-not $patterns) {
        return $false
    }
    
    foreach ($pattern in $patterns) {
        if ($text -match $pattern) {
            return $true
        }
    }
    
    return $false
}

function Get-AutoCategory {
    param(
        [string]$payee, 
        [string]$memo, 
        [decimal]$amount
    )
    
    $text = "$payee $memo".ToLower()
    
    # INCOME - Detailed categorization
    if ($amount -gt 0) {
        # Check salary patterns from config
        $salaryCategory = $global:config.CheckSalaryPattern($text, "de")
        if ($salaryCategory) {
            return $salaryCategory
        }
        
        # Tax refunds
        $patterns = $categorizationPatterns.income.taxRefunds
        if ($patterns -and (Test-PatternMatch $text $patterns)) {
            return "Tax Refunds"
        }
        
        # Cash deposits
        $patterns = $categorizationPatterns.income.cashDeposits
        if ($patterns -and (Test-PatternMatch $text $patterns)) {
            return "Cash Deposits"
        }
        
        # Capital gains
        $patterns = $categorizationPatterns.income.capitalGains
        if ($patterns -and (Test-PatternMatch $text $patterns)) {
            return "Capital Gains"
        }
        
        # General income
        $patterns = $categorizationPatterns.income.generalIncome
        if ($patterns -and (Test-PatternMatch $text $patterns)) {
            return "Income"
        }
        
        # Other income (for larger amounts)
        if ($amount -gt 50 -and ($text -match "gutschrift|eingang|erstattung|rueckzahlung|bonus|praemie|refund|bonus|premium")) {
            return "Other Income"
        }
    }
    
    return ""
}

function Get-TransferCategory {
    param(
        [string]$payee, 
        [string]$memo, 
        [decimal]$amount,
        [string]$targetIBAN = ""
    )
    
    $payeeLower = $payee.ToLower()
    $notesLower = $memo.ToLower()
    
    # IBAN-based transfer recognition (main logic)
    if ($targetIBAN -and $OwnIBANs.ContainsKey($targetIBAN)) {
        $targetAccountName = $OwnIBANs[$targetIBAN]
        if ($amount -gt 0) {
            return "Transfer from $targetAccountName"
        } else {
            return "Transfer to $targetAccountName"
        }
    }
    
    return ""
}

function Get-CleanAccountName {
    param(
        [string]$fileName,
        [string]$csvFilePath = ""
    )
    
    # Clean filename (remove date suffixes)
    $cleanName = $fileName -replace " seit \d+\.\d+\.\d+", ""
    
    # Try to map to configured account names
    $accountNames = $global:config.Get("accounts.accountNames")
    if ($accountNames) {
        foreach ($accountKey in $accountNames.Keys) {
            $configuredName = $global:config.GetAccountName($accountKey)
            # Try to match common patterns
            if ($cleanName -match ($configuredName -replace "-", ".*")) {
                return $configuredName
            }
        }
    }
    
    # Fallback: basic cleanup
    return $cleanName -replace "\s+", "-"
}

# Simplified version of Process-BankCSV for debugging
function Process-BankCSV-Debug {
    param([string]$FilePath)
    
    $fileName = (Get-Item $FilePath).BaseName
    $accountName = Get-CleanAccountName -fileName $fileName -csvFilePath $FilePath
    
    Write-Host "=== Processing: $fileName ===" -ForegroundColor Cyan
    Write-Host "Account Name: $accountName" -ForegroundColor White
    
    try {
        # Load CSV with configured settings
        $delimiter = $csvSettings.delimiter
        $encoding = $csvSettings.encoding
        $csvData = Import-Csv -Path $FilePath -Delimiter $delimiter -Encoding $encoding
        
        if (-not $csvData) {
            Write-Host "Could not read CSV file" -ForegroundColor Red
            return $null
        }
        
        Write-Host "CSV loaded successfully. Rows: $($csvData.Count)" -ForegroundColor Green
        
        $transferCount = 0
        $categorizedCount = 0
        $processedData = @()
        
        foreach ($row in $csvData) {
            Write-Host "  Processing row..." -ForegroundColor Gray
            
            # Get column values
            $dateColumn = "Buchungstag"
            $amountColumn = "Betrag"
            $payeeColumn = "Name Zahlungsbeteiligter"
            $purposeColumn = "Verwendungszweck"
            $ibanColumn = "IBAN Zahlungsbeteiligter"
            
            # Convert date (DD.MM.YYYY to YYYY-MM-DD)
            $rawDate = if ($row.$dateColumn) { $row.$dateColumn.Trim() } else { '' }
            if ($rawDate -ne '') {
                $dateParts = $rawDate.Split('.')
                if ($dateParts.Length -eq 3) {
                    $formattedDate = "$($dateParts[2])-$($dateParts[1].PadLeft(2,'0'))-$($dateParts[0].PadLeft(2,'0'))"
                } else {
                    $formattedDate = $rawDate
                }
            } else {
                $formattedDate = ''
            }
            
            # Convert amount (German to English format)
            $rawAmount = if ($row.$amountColumn) { $row.$amountColumn.Trim() } else { '' }
            if ($rawAmount -ne '') {
                $amount = $rawAmount -replace '\.', '' -replace ',', '.'
                try {
                    $amount = [decimal]$amount
                } catch {
                    $amount = 0
                }
            } else {
                $amount = 0
            }
            
            # Payee
            $payee = if ($row.$payeeColumn) { $row.$payeeColumn.Trim() } else { '' }
            
            # Notes
            $notes = if ($row.$purposeColumn) { $row.$purposeColumn.Trim() } else { '' }
            
            # IBAN
            $targetIBAN = if ($row.$ibanColumn) { $row.$ibanColumn.Trim() } else { '' }
            
            Write-Host "    Date: $formattedDate, Amount: $amount, Payee: $payee" -ForegroundColor Gray
            
            # Kategorie ermitteln
            $category = ""
            
            # 1. Transfer-Kategorien haben Vorrang
            $transferCategory = Get-TransferCategory -payee $payee -memo $notes -amount $amount -targetIBAN $targetIBAN
            if ($transferCategory) {
                $category = $transferCategory
                $transferCount++
                Write-Host "    -> Transfer category: $category" -ForegroundColor Yellow
            }
            # 2. Auto-Kategorisierung
            else {
                $autoCategory = Get-AutoCategory -payee $payee -memo $notes -amount $amount
                if ($autoCategory) {
                    $category = $autoCategory
                    $categorizedCount++
                    Write-Host "    -> Auto category: $category" -ForegroundColor Green
                } else {
                    Write-Host "    -> No category assigned" -ForegroundColor Red
                }
            }
            
            # Actual Budget Format
            $processedRow = [PSCustomObject]@{
                date = $formattedDate
                account = $accountName
                payee = $payee
                notes = $notes
                category = $category
                amount = $amount
            }
            
            $processedData += $processedRow
        }
        
        Write-Host "Transfer-Kategorien: $transferCount, Auto-Kategorien: $categorizedCount" -ForegroundColor White
        Write-Host "Total processed rows: $($processedData.Count)" -ForegroundColor $(if ($processedData.Count -gt 0) { "Green" } else { "Red" })
        
        return $processedData
        
    } catch {
        Write-Host "ERROR: $($_.Exception.Message)" -ForegroundColor Red
        return @()
    }
}

Write-Host "=== DEBUG: Actual Processing Function Test ===" -ForegroundColor Cyan
Write-Host ""

# Find Genossenschaftsanteil files
$sourceDir = $global:config.GetSourceDir()
$genossenschaftFiles = Get-ChildItem -Path $sourceDir -Filter "*Geschäftsanteil*"

foreach ($file in $genossenschaftFiles) {
    $result = Process-BankCSV-Debug -FilePath $file.FullName
    
    Write-Host ""
    Write-Host "Result for $($file.Name):" -ForegroundColor Yellow
    if ($result -and $result.Count -gt 0) {
        Write-Host "  ✓ Would be included in statistics table" -ForegroundColor Green
        Write-Host "  Processed rows: $($result.Count)" -ForegroundColor Green
        foreach ($row in $result) {
            Write-Host "    - $($row.date) | $($row.payee) | $($row.category) | $($row.amount)" -ForegroundColor Gray
        }
    } else {
        Write-Host "  ✗ Would NOT be included in statistics table" -ForegroundColor Red
        Write-Host "  Reason: No processed rows returned" -ForegroundColor Red
    }
    Write-Host ""
}

Write-Host "=== END DEBUG ===" -ForegroundColor Cyan