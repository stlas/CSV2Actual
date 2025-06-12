# CSV2Actual - Bank CSV Processor
# Version: 1.1.0
# Author: sTLAs (https://github.com/sTLAs)
# Converts German Bank CSVs to Actual Budget format with automatic categorization
# Features: Internationalization (EN/DE), JSON Configuration, PowerShell Core support

# Parameter mit Aliasing nach PowerShell Best Practices
param(
    [Alias("n")][switch]$DryRun,
    [Alias("q")][switch]$Silent,
    [Alias("h")][switch]$Help,
    [Alias("l")][string]$Language = "en",
    [switch]$AlternativeFormats
)

# Load modules
. "$PSScriptRoot/../modules/Config.ps1"
. "$PSScriptRoot/../modules/I18n.ps1"
. "$PSScriptRoot/../modules/CsvValidator.ps1"

# Initialize configuration and i18n
try {
    $global:config = [Config]::new("$PSScriptRoot/../config.json")
    $langDir = $global:config.Get("paths.languageDir")
    $global:i18n = [I18n]::new($langDir, $Language)
}
catch {
    Write-Host "ERROR: Could not load configuration or language files. Please ensure config.json and lang/ folder exist." -ForegroundColor Red
    Write-Host "Details: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# Helper function for localization
function t {
    param([string]$key, [object[]]$args = @())
    return $global:i18n.Get($key, $args)
}

if ($Help) {
    Write-Host (t "processor.help_title") -ForegroundColor Cyan
    Write-Host ""
    Write-Host (t "processor.usage") -ForegroundColor Yellow
    Write-Host "  " + (t "processor.usage_text")
    Write-Host ""
    Write-Host (t "processor.options") -ForegroundColor Yellow
    Write-Host "  " + (t "processor.dry_run_help")
    Write-Host "  " + (t "processor.silent_help")
    Write-Host "  " + (t "processor.help_help")
    Write-Host "  -AlternativeFormats    " + (t "processor.alternative_formats_help")
    Write-Host ""
    Write-Host (t "processor.examples") -ForegroundColor Yellow
    Write-Host "  " + (t "processor.example_normal")
    Write-Host "  " + (t "processor.example_normal_cmd")
    Write-Host ""
    Write-Host "  # Dry-Run (preview only):"
    Write-Host "  powershell -ExecutionPolicy Bypass -File bank_csv_processor.ps1 -DryRun"
    Write-Host "  powershell -ExecutionPolicy Bypass -File bank_csv_processor.ps1 -n"
    Write-Host ""
    Write-Host "  # Silent Mode (minimal output):"
    Write-Host "  powershell -ExecutionPolicy Bypass -File bank_csv_processor.ps1 -Silent"
    Write-Host "  powershell -ExecutionPolicy Bypass -File bank_csv_processor.ps1 -q"
    exit 0
}

$isDryRun = $DryRun.IsPresent
$isSilent = $Silent.IsPresent

# Load currency from configuration
$currency = $global:config.Get("defaults.currency")
if (-not $currency) { $currency = "EUR" }  # Fallback

# Logging Setup
$logsDir = Join-Path $PSScriptRoot "logs"
if (-not (Test-Path $logsDir)) {
    New-Item -ItemType Directory -Path $logsDir -Force | Out-Null
}
$logFile = Join-Path $logsDir "csv_processor_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"
$logContent = @()

function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$timestamp] [$Level] $Message"
    $script:logContent += $logEntry
    
    if (-not $isSilent) {
        Write-Host $Message
    }
}

function Write-LogVerbose {
    param([string]$Message, [string]$Color = "White")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$timestamp] [VERBOSE] $Message"
    $script:logContent += $logEntry
    
    if (-not $isSilent) {
        Write-Host $Message -ForegroundColor $Color
    }
}

function Write-LogOnly {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$timestamp] [$Level] $Message"
    $script:logContent += $logEntry
}

function Save-LogFile {
    $script:logContent | Out-File -FilePath $logFile -Encoding UTF8
}

if (-not $isSilent) {
    Write-Host (t "processor.title") -ForegroundColor Cyan
    if ($isDryRun) {
        Write-Host (t "processor.dry_run_preview") -ForegroundColor Yellow
    }
    Write-Host ""
} else {
    Write-Host (t "processor.silent_mode") -ForegroundColor Gray
}

Write-Log (t "processor.started") "INFO"
if ($isDryRun) { Write-Log "DRY-RUN mode enabled" "INFO" }
if ($isSilent) { Write-Log "Silent mode enabled - Log will be written to $logFile" "INFO" }

# ==========================================
# CONFIGURATION FROM CONFIG.JSON
# ==========================================

# Load configuration values
$OwnIBANs = $global:config.GetIBANMapping()
$csvSettings = $global:config.GetCSVSettings()
$ExcludePatterns = $csvSettings.excludePatterns
$OutputDir = $global:config.GetOutputDir()
$categorizationPatterns = $global:config.GetCategorizationPatterns()

# ==========================================
# KATEGORISIERUNGS-FUNKTIONEN
# ==========================================

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
        $salaryCategory = $global:config.CheckSalaryPattern($text, $Language)
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
    
    # EXPENSES - Configuration-based categorization
    $expenseCategories = @(
        @{patterns = $categorizationPatterns.expenses.groceries; category = "Groceries"},
        @{patterns = $categorizationPatterns.expenses.fuel; category = "Fuel"},
        @{patterns = $categorizationPatterns.expenses.housing; category = "Housing"},
        @{patterns = $categorizationPatterns.expenses.insurance; category = "Insurance"},
        @{patterns = $categorizationPatterns.expenses.internetPhone; category = "Internet & Phone"},
        @{patterns = $categorizationPatterns.expenses.publicTransport; category = "Public Transportation"},
        @{patterns = $categorizationPatterns.expenses.pharmacy; category = "Pharmacy & Health"},
        @{patterns = $categorizationPatterns.expenses.restaurants; category = "Restaurants & Dining"},
        @{patterns = $categorizationPatterns.expenses.onlineShopping; category = "Online Shopping"},
        @{patterns = $categorizationPatterns.expenses.electronics; category = "Electronics & Technology"},
        @{patterns = $categorizationPatterns.expenses.streaming; category = "Streaming & Subscriptions"},
        @{patterns = $categorizationPatterns.expenses.bankFees; category = "Bank Fees"},
        @{patterns = $categorizationPatterns.expenses.taxes; category = "Taxes"},
        @{patterns = $categorizationPatterns.expenses.health; category = "Health"},
        @{patterns = $categorizationPatterns.expenses.donations; category = "Donations"},
        @{patterns = $categorizationPatterns.expenses.memberships; category = "Memberships"},
        @{patterns = $categorizationPatterns.expenses.education; category = "Education"},
        @{patterns = $categorizationPatterns.expenses.clothing; category = "Clothing"},
        @{patterns = $categorizationPatterns.expenses.entertainment; category = "Entertainment"},
        @{patterns = $categorizationPatterns.expenses.consulting; category = "Consulting & Legal"},
        @{patterns = $categorizationPatterns.expenses.taxi; category = "Taxi & Ridesharing"}
    )
    
    foreach ($expenseCategory in $expenseCategories) {
        if ($expenseCategory.patterns -and (Test-PatternMatch $text $expenseCategory.patterns)) {
            return $expenseCategory.category
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
    
    # Fallback: Household keywords
    $householdPatterns = $categorizationPatterns.transfers.householdKeywords
    if ($householdPatterns -and ((Test-PatternMatch $notesLower $householdPatterns) -or (Test-PatternMatch $payeeLower $householdPatterns))) {
        return "Transfer (Household Contribution)"
    }
    
    # Fallback: General transfer recognition
    $transferPatterns = $categorizationPatterns.transfers.transferKeywords
    $minAmount = $categorizationPatterns.transfers.minTransferAmount
    if ($transferPatterns -and (Test-PatternMatch $notesLower $transferPatterns) -and $amount -gt $minAmount) {
        return "Internal Transfer"
    }
    
    return ""
}

# ==========================================
# ALTERNATIVE EXPORT FORMATS
# ==========================================

function Create-AlternativeFormats {
    param(
        [array]$Data,
        [string]$BaseName,
        [string]$OutputDir,
        [bool]$Silent
    )
    
    try {
        # Semicolon format (European CSV standard)
        $semicolonFile = Join-Path $OutputDir "$BaseName`_SEMICOLON.csv"
        $Data | Export-Csv -Path $semicolonFile -NoTypeInformation -Encoding UTF8 -Delimiter ";"
        if (-not $Silent) {
            Write-Host "    Alt: " + (t "processor.semicolon_format") -ForegroundColor Cyan
        }
        Write-LogOnly "  Alternative format created: $semicolonFile"
        
        # Tab format
        $tabFile = Join-Path $OutputDir "$BaseName`_TAB.csv"
        $Data | Export-Csv -Path $tabFile -NoTypeInformation -Encoding UTF8 -Delimiter "`t"
        if (-not $Silent) {
            Write-Host "    Alt: " + (t "processor.tab_format") -ForegroundColor Cyan
        }
        Write-LogOnly "  Alternative format created: $tabFile"
        
        # Manual format (ASCII, no Export-Csv overhead)
        $manualFile = Join-Path $OutputDir "$BaseName`_MANUAL.csv"
        $manualContent = "date,account,payee,notes,category,amount`n"
        foreach ($row in $Data) {
            $manualContent += "$($row.date),$($row.account),`"$($row.payee)`",`"$($row.notes)`",`"$($row.category)`",$($row.amount)`n"
        }
        [System.IO.File]::WriteAllText($manualFile, $manualContent, [System.Text.Encoding]::ASCII)
        if (-not $Silent) {
            Write-Host "    Alt: " + (t "processor.manual_format") -ForegroundColor Cyan
        }
        Write-LogOnly "  Alternative format created: $manualFile"
        
    } catch {
        Write-Log "WARNING: Could not create alternative formats: $($_.Exception.Message)" "WARN"
    }
}

function Test-BalanceConsistency {
    param(
        [object]$csvData,
        [string]$fileName,
        [bool]$isSilent
    )
    
    # Find amount, balance, and date columns
    $headers = $csvData[0].PSObject.Properties.Name
    $amountCol = $null
    $balanceCol = $null
    $dateCol = $null
    
    foreach ($header in $headers) {
        if ($header -match "Betrag|Amount") {
            $amountCol = $header
        }
        if ($header -match "Saldo.*nach.*Buchung|Balance") {
            $balanceCol = $header
        }
        if ($header -match "Buchungstag|Date|Datum") {
            $dateCol = $header
        }
    }
    
    if (-not $amountCol -or -not $balanceCol) {
        if (-not $isSilent) {
            Write-Host "    WARNUNG Saldo-Validierung uebersprungen: Benoetigte Spalten nicht gefunden" -ForegroundColor Yellow
        }
        return
    }
    
    # Detect chronological order by comparing first and last valid dates
    $chronologyDirection = "unknown"
    if ($dateCol) {
        $chronologyDirection = Get-ChronologyDirection -csvData $csvData -dateCol $dateCol
    }
    
    # Log chronology direction only to file for debugging
    if ($chronologyDirection -ne "unknown") {
        $directionText = if ($chronologyDirection -eq "descending") { "rueckwaerts chronologisch (neueste zuerst)" } else { "vorwaerts chronologisch (aelteste zuerst)" }
        Write-LogOnly "Chronology direction detected for $fileName`: $directionText" "INFO"
    }
    
    $balanceErrors = @()
    $validatedTransactions = 0
    
    # Process data based on chronological direction
    if ($chronologyDirection -eq "descending") {
        # Reverse chronological: validate from current row to next row
        for ($i = 0; $i -lt ($csvData.Count - 1); $i++) {
            $currentRow = $csvData[$i]
            $nextRow = $csvData[$i + 1]
            
            $error = Test-BalanceTransition -currentRow $currentRow -nextRow $nextRow -amountCol $amountCol -balanceCol $balanceCol -rowNumber ($i + 2) -direction "descending"
            if ($error) {
                $balanceErrors += $error
            }
            $validatedTransactions++
        }
    } else {
        # Forward chronological or unknown: validate from previous row to current row  
        for ($i = 1; $i -lt $csvData.Count; $i++) {
            $previousRow = $csvData[$i - 1]
            $currentRow = $csvData[$i]
            
            $error = Test-BalanceTransition -currentRow $previousRow -nextRow $currentRow -amountCol $amountCol -balanceCol $balanceCol -rowNumber ($i + 1) -direction "ascending"
            if ($error) {
                $balanceErrors += $error
            }
            $validatedTransactions++
        }
    }
    
    # Show balance validation results
    if ($balanceErrors.Count -gt 0) {
        if (-not $isSilent) {
            Write-Host "    FEHLER Saldo-Inkonsistenzen gefunden ($($balanceErrors.Count)):" -ForegroundColor Red
            foreach ($error in $balanceErrors[0..4]) {  # Show max 5 errors
                Write-Host "       $error" -ForegroundColor Yellow
            }
            if ($balanceErrors.Count -gt 5) {
                Write-Host "       ... und $($balanceErrors.Count - 5) weitere" -ForegroundColor Yellow
            }
        }
        Write-LogOnly "Balance validation errors for $fileName`: $($balanceErrors.Count) inconsistencies found" "WARN"
        foreach ($error in $balanceErrors) {
            Write-LogOnly "  $error" "WARN"
        }
    } else {
        if ($validatedTransactions -gt 0) {
            Write-LogOnly "Balance validation successful for $fileName`: All $validatedTransactions transactions are mathematically correct" "INFO"
        }
    }
}

function Get-ChronologyDirection {
    param(
        [object]$csvData,
        [string]$dateCol
    )
    
    $firstDate = $null
    $lastDate = $null
    
    # Find first valid date
    foreach ($row in $csvData) {
        $dateText = $row.$dateCol
        if ($dateText) {
            try {
                $firstDate = [DateTime]::ParseExact($dateText, "dd.MM.yyyy", $null)
                break
            }
            catch {
                # Try different formats
                try {
                    $firstDate = [DateTime]::Parse($dateText)
                    break
                }
                catch { continue }
            }
        }
    }
    
    # Find last valid date
    for ($i = $csvData.Count - 1; $i -ge 0; $i--) {
        $dateText = $csvData[$i].$dateCol
        if ($dateText) {
            try {
                $lastDate = [DateTime]::ParseExact($dateText, "dd.MM.yyyy", $null)
                break
            }
            catch {
                try {
                    $lastDate = [DateTime]::Parse($dateText)
                    break
                }
                catch { continue }
            }
        }
    }
    
    if ($firstDate -and $lastDate) {
        if ($firstDate -gt $lastDate) {
            return "descending"  # Newest first
        } else {
            return "ascending"   # Oldest first
        }
    }
    
    return "unknown"
}

function Test-BalanceTransition {
    param(
        [object]$currentRow,
        [object]$nextRow,
        [string]$amountCol,
        [string]$balanceCol,
        [int]$rowNumber,
        [string]$direction
    )
    
    # Parse current balance
    $currentBalanceText = $currentRow.$balanceCol
    if (-not $currentBalanceText) { return $null }
    
    $cleanCurrentBalance = $currentBalanceText -replace '\.', '' -replace ',', '.'
    try {
        $currentBalance = [decimal]$cleanCurrentBalance
    }
    catch {
        return $null
    }
    
    # Parse current amount (the transaction that led to the current balance)
    $currentAmountText = $currentRow.$amountCol
    if (-not $currentAmountText) { return $null }
    
    $cleanCurrentAmount = $currentAmountText -replace '\.', '' -replace ',', '.'
    try {
        $currentAmount = [decimal]$cleanCurrentAmount
    }
    catch {
        return $null
    }
    
    # Parse next balance
    $nextBalanceText = $nextRow.$balanceCol
    if (-not $nextBalanceText) { return $null }
    
    $cleanNextBalance = $nextBalanceText -replace '\.', '' -replace ',', '.'
    try {
        $nextBalance = [decimal]$cleanNextBalance
    }
    catch {
        return $null
    }
    
    # Calculate expected balance for next row
    # For descending order: nextBalance = currentBalance - currentAmount (going backwards in time)
    # For ascending order: nextBalance = currentBalance + currentAmount (going forwards in time)
    if ($direction -eq "descending") {
        $expectedBalance = $currentBalance - $currentAmount
    } else {
        $expectedBalance = $currentBalance + $currentAmount
    }
    
    # Check if calculated balance matches reported balance (with small tolerance for rounding)
    $difference = [Math]::Abs($expectedBalance - $nextBalance)
    if ($difference -gt 0.01) {  # Allow 1 cent tolerance
        return "Zeile $rowNumber`: Erwartet: $($expectedBalance.ToString('N2')) EUR, Gemeldet: $($nextBalance.ToString('N2')) EUR, Diff: $($difference.ToString('N2')) EUR"
    }
    
    return $null
}

function Get-AccountNameFromCSVData {
    param([string]$FilePath)
    
    try {
        # Try different encodings to read the file
        $encodings = @([System.Text.Encoding]::UTF8, [System.Text.Encoding]::Default, [System.Text.Encoding]::GetEncoding(1252))
        $bestContent = $null
        
        foreach ($encoding in $encodings) {
            try {
                $content = Get-Content -Path $FilePath -Encoding $encoding -TotalCount 3
                if ($content -and $content.Count -ge 2) {
                    $bestContent = $content
                    break
                }
            } catch { }
        }
        
        if (-not $bestContent) { return "" }
        
        # Detect delimiter
        $delimiter = if ($bestContent[0] -match ";") { ";" } else { "," }
        $headers = $bestContent[0] -split $delimiter
        $dataRow = $bestContent[1] -split $delimiter
        
        # Look for account name columns (German and English patterns)
        $accountNamePatterns = @(
            "Bezeichnung.*Auftrag",
            "Account.*Name", 
            "Account.*Description",
            "Kontobezeichnung",
            "Kontoname"
        )
        
        for ($i = 0; $i -lt $headers.Count; $i++) {
            $header = $headers[$i].Trim()
            foreach ($pattern in $accountNamePatterns) {
                if ($header -match $pattern) {
                    if ($i -lt $dataRow.Count) {
                        $accountName = $dataRow[$i].Trim()
                        # Clean up the account name
                        $accountName = $accountName -replace '^"', '' -replace '"$', ''
                        if ($accountName -and $accountName -ne "" -and $accountName.Length -le 50) {
                            # Remove common bank suffixes and clean up
                            $accountName = $accountName -replace " seit \d+\.\d+\.\d+", ""
                            $accountName = $accountName -replace " Kontoauszug.*", ""
                            $accountName = $accountName -replace " Export.*", ""
                            return $accountName
                        }
                    }
                    break
                }
            }
        }
    } catch {
        # Silently fail and return empty string
    }
    
    return ""
}

# ==========================================
# HAUPT-VERARBEITUNGSFUNKTION
# ==========================================

function Get-CleanAccountName {
    param(
        [string]$fileName,
        [string]$csvFilePath = ""
    )
    
    # Try to extract account name from CSV data first
    if ($csvFilePath -and (Test-Path $csvFilePath)) {
        $csvAccountName = Get-AccountNameFromCSVData -FilePath $csvFilePath
        if ($csvAccountName) {
            return $csvAccountName
        }
    }
    
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

function Process-BankCSV {
    param([string]$FilePath)
    
    $fileName = (Get-Item $FilePath).BaseName
    $accountName = Get-CleanAccountName -fileName $fileName -csvFilePath $FilePath
    
    try {
        # Validate CSV and get column mapping
        $validator = [CsvValidator]::new($global:i18n)
        $validationResult = $validator.ValidateFile($FilePath)
        
        # Load CSV with configured settings or validator fallback
        $delimiter = $csvSettings.delimiter
        $encoding = $csvSettings.encoding
        $csvData = Import-Csv -Path $FilePath -Delimiter $delimiter -Encoding $encoding
        
        if (-not $csvData) {
            # Use validator's TryReadCsv as fallback
            $csvData = $validator.TryReadCsv($FilePath)
        }
        
        if (-not $csvData) {
            # Only show warnings if file really cannot be read
            if (-not $isSilent) {
                Write-Log "ERROR: Could not read CSV file: ${fileName}" "ERROR"
                if ($validationResult.errors.Count -gt 0) {
                    Write-Log "Validation errors:" "ERROR"
                    foreach ($error in $validationResult.errors) {
                        Write-Log "  - $error" "ERROR"
                    }
                }
            } else {
                Write-LogOnly "ERROR: Could not read CSV file: ${fileName}" "ERROR"
                foreach ($error in $validationResult.errors) {
                    Write-LogOnly "  - $error" "ERROR"
                }
            }
            return $null
        }
        
        # Only log validation issues to file for debugging, not to console
        if (-not $validationResult.isValid) {
            Write-LogOnly "INFO: CSV validation issues for ${fileName} (but file was successfully read):" "INFO"
            foreach ($error in $validationResult.errors) {
                Write-LogOnly "  - $error" "INFO"
            }
        }
        
        
        # Get column mapping for this file
        $columnMapping = $validationResult.columnMapping
        
        # File processing info logged only
        Write-LogOnly "Processing: $fileName - Transactions: $($csvData.Count)"
        
        # Perform balance validation on actual data
        $balanceValidation = Test-BalanceConsistency -csvData $csvData -fileName $fileName -isSilent $isSilent
        
        $transferCount = 0
        $categorizedCount = 0
        $processedData = @()
        
        foreach ($row in $csvData) {
            # Get column values using dynamic mapping with fallbacks
            $dateColumn = $columnMapping["Date"]
            $amountColumn = $columnMapping["Amount"] 
            $payeeColumn = $columnMapping["Payee"]
            $purposeColumn = $columnMapping["Purpose"]
            $ibanColumn = $columnMapping["IBAN"]
            
            # Fallback to standard German column names if mapping failed
            if (-not $dateColumn) { $dateColumn = "Buchungstag" }
            if (-not $amountColumn) { $amountColumn = "Betrag" }
            if (-not $payeeColumn) { $payeeColumn = "Name Zahlungsbeteiligter" }
            if (-not $purposeColumn) { $purposeColumn = "Verwendungszweck" }
            if (-not $ibanColumn) { $ibanColumn = "IBAN Zahlungsbeteiligter" }
            
            # Convert date (DD.MM.YYYY to YYYY-MM-DD)
            $rawDate = if ($dateColumn -and $row.$dateColumn) { $row.$dateColumn.Trim() } else { '' }
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
            $rawAmount = if ($amountColumn -and $row.$amountColumn) { $row.$amountColumn.Trim() } else { '' }
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
            
            # Payee bestimmen - using dynamic column mapping
            $payee = ''
            if ($payeeColumn -and $row.$payeeColumn) {
                $payee = $row.$payeeColumn.Trim()
            } else {
                # Fallback: try common alternative column names
                $alternativePayeeColumns = @('Empfaenger', 'Zahlungspflichtige', 'Name Zahlungsbeteiligter', 'Payee', 'Merchant')
                foreach ($altCol in $alternativePayeeColumns) {
                    if ($row.PSObject.Properties.Name -contains $altCol -and $row.$altCol -and $row.$altCol.Trim() -ne '') {
                        $payee = $row.$altCol.Trim()
                        break
                    }
                }
            }
            
            # Credit card specific payee extraction from Verwendungszweck
            if (-not $payee -or $payee -eq '') {
                if ($purposeColumn -and $row.$purposeColumn) {
                    $purpose = $row.$purposeColumn.Trim()
                    # Extract merchant name from credit card transaction format
                    # Pattern: "MERCHANT NAME DEU City EUR Amount ..."
                    if ($purpose -match '^([A-Za-z0-9\s\*\.\-]+)\s+DEU\s+') {
                        $extractedPayee = $matches[1].Trim()
                        # Clean up common patterns
                        $extractedPayee = $extractedPayee -replace '\s+', ' '  # Normalize spaces
                        $extractedPayee = $extractedPayee -replace '^\*', ''   # Remove leading asterisk
                        $payee = $extractedPayee
                    }
                }
            }
            
            # Notes zusammenfuegen - using dynamic column mapping
            $notes = ''
            if ($purposeColumn -and $row.$purposeColumn) {
                $notes += $row.$purposeColumn
            }
            
            # Add additional purpose/memo columns if available
            $additionalMemoColumns = @('Verwendungszweck 2', 'Buchungstext', 'Description', 'Memo', 'Notes')
            foreach ($memoCol in $additionalMemoColumns) {
                if ($row.PSObject.Properties.Name -contains $memoCol -and $row.$memoCol -and $row.$memoCol.Trim() -ne '') {
                    if ($notes.Trim() -ne '') {
                        $notes += ' ' + $row.$memoCol.Trim()
                    } else {
                        $notes = $row.$memoCol.Trim()
                    }
                }
            }
            $notes = $notes.Trim()
            
            # IBAN Zahlungsbeteiligter extrahieren - using dynamic column mapping
            $targetIBAN = ''
            if ($ibanColumn -and $row.$ibanColumn) {
                $targetIBAN = $row.$ibanColumn.Trim()
            } else {
                # Fallback: try common IBAN column names
                $alternativeIbanColumns = @('IBAN Zahlungsbeteiligter', 'IBAN', 'Payee IBAN', 'Account')
                foreach ($ibanCol in $alternativeIbanColumns) {
                    if ($row.PSObject.Properties.Name -contains $ibanCol -and $row.$ibanCol -and $row.$ibanCol.Trim() -ne '') {
                        $targetIBAN = $row.$ibanCol.Trim()
                        break
                    }
                }
            }
            
            # Kategorie ermitteln
            $category = ""
            
            # 1. Transfer-Kategorien haben Vorrang
            $transferCategory = Get-TransferCategory -payee $payee -memo $notes -amount $amount -targetIBAN $targetIBAN
            if ($transferCategory) {
                $category = $transferCategory
                $transferCount++
            }
            # 2. Auto-Kategorisierung
            else {
                $autoCategory = Get-AutoCategory -payee $payee -memo $notes -amount $amount
                if ($autoCategory) {
                    $category = $autoCategory
                    $categorizedCount++
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
        
Write-LogOnly "  Transfer-Kategorien: $transferCount, Auto-Kategorien: $categorizedCount"
        
        return $processedData
        
    } catch {
        Write-Log "  ERROR: $($_.Exception.Message)" "ERROR"
        return @()
    }
}

# ==========================================
# HAUPTPROGRAMM
# ==========================================

# Output-Ordner erstellen (nicht im Dry-Run)
if (-not $isDryRun) {
    if (-not (Test-Path $OutputDir)) {
        New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
        Write-Log ($global:i18n.Get("processor.folder_created", @($OutputDir)))
    }
} else {
    Write-Log ($global:i18n.Get("processor.dry_run_folder", @($OutputDir)))
}

# Find CSV files
$sourceDir = $global:config.GetSourceDir()
$csvFiles = Get-ChildItem -Path $sourceDir -Filter "*.csv" | Where-Object { 
    $exclude = $false
    foreach ($pattern in $ExcludePatterns) {
        if ($_.Name -match $pattern) {
            $exclude = $true
            break
        }
    }
    -not $exclude
}

if ($csvFiles.Count -eq 0) {
    Write-Log "No CSV files found!" "ERROR"
    Save-LogFile
    if (-not $isSilent) { Read-Host (t "common.press_enter_exit") }
    exit 1
}

Write-Log ($global:i18n.Get("processor.found_files", @($csvFiles.Count)))
if (-not $isSilent) {
    Write-Host ""
    Write-Host "+-------------------------------------------------------------+" -ForegroundColor Cyan
    Write-Host "|                   CSV BEARBEITUNG                          |" -ForegroundColor Cyan
    Write-Host "+-------------------------------------------------------------+" -ForegroundColor Cyan
}

# Statistiken
$totalTransactions = 0
$totalTransfers = 0
$totalCategorized = 0

# Alle CSV-Dateien verarbeiten
$fileStats = @()
foreach ($file in $csvFiles) {
    $processedData = Process-BankCSV -FilePath $file.FullName
    
    if ($processedData.Count -gt 0) {
        # Statistiken aktualisieren
        $totalTransactions += $processedData.Count
        $transfersInFile = ($processedData | Where-Object { $_.category -match "Transfer" }).Count
        $categorizedInFile = ($processedData | Where-Object { $_.category -and $_.category -ne "" }).Count
        $totalTransfers += $transfersInFile
        $totalCategorized += $categorizedInFile
        
        # File stats sammeln
        $fileStats += [PSCustomObject]@{
            Datei = ($file.BaseName -replace ' seit .*', '')
            Buchungen = $processedData.Count
            Transfers = $transfersInFile
            Kategorisiert = $categorizedInFile
            Rate = if ($processedData.Count -gt 0) { [math]::Round(($categorizedInFile / $processedData.Count) * 100, 1) } else { 0 }
        }
        
        # Output-Datei speichern (nicht im Dry-Run)
        $outputFile = Join-Path $OutputDir "$($file.BaseName).csv"
        
        if (-not $isDryRun) {
            $outputDelimiter = $csvSettings.outputDelimiter
            $processedData | Export-Csv -Path $outputFile -NoTypeInformation -Delimiter $outputDelimiter
            $relativePath = $outputFile -replace [regex]::Escape($PSScriptRoot + [System.IO.Path]::DirectorySeparatorChar), ""
            Write-LogOnly "  Saved: $relativePath"
            
            # Create alternative formats if requested
            if ($AlternativeFormats) {
                Create-AlternativeFormats -Data $processedData -BaseName $file.BaseName -OutputDir $OutputDir -Silent $isSilent
            }
        } else {
            $relativePath = $outputFile -replace [regex]::Escape($PSScriptRoot + [System.IO.Path]::DirectorySeparatorChar), ""
            Write-LogOnly "  DRY-RUN: Would save: $relativePath"
            if (-not $isSilent) {
                Write-Host "  DRY-RUN: Sample rows:" -ForegroundColor Cyan
                $processedData | Select-Object -First 3 | ForEach-Object {
                    Write-Host "    $($_.date) | $($_.account) | $($_.payee) | $($_.category) | $($_.amount)" -ForegroundColor Gray
                }
                if ($processedData.Count -gt 3) {
                    Write-Host "    ... and $($processedData.Count - 3) more rows" -ForegroundColor Gray
                }
            }
        }
    }
}

# Statistik-Tabelle anzeigen (nicht im Silent-Modus)
if (-not $isSilent -and $fileStats.Count -gt 0) {
    Write-Host ""
    Write-Host "+-------------------------------------------------------------+" -ForegroundColor Green
    Write-Host "|                      STATISTIK                              |" -ForegroundColor Green  
    Write-Host "+-------------------------------------------------------------+" -ForegroundColor Green
    Write-Host ""
    
    # Tabellen-Header
    Write-Host ("  {0,-25} {1,8} {2,8} {3,8} {4,8}" -f "Datei", "Buchungen", "Transfer", "Kategor.", "Rate %") -ForegroundColor Yellow
    Write-Host "  " + ("-" * 59) -ForegroundColor Gray
    
    # Zeilen
    foreach ($stat in $fileStats) {
        $color = if ($stat.Rate -ge 50) { "Green" } elseif ($stat.Rate -ge 30) { "Yellow" } else { "Red" }
        Write-Host ("  {0,-25} {1,8} {2,8} {3,8} {4,6}%" -f $stat.Datei, $stat.Buchungen, $stat.Transfers, $stat.Kategorisiert, $stat.Rate.ToString("F1")) -ForegroundColor $color
    }
    
    # Gesamt-Zeile
    $totalRate = if ($totalTransactions -gt 0) { [math]::Round(($totalCategorized / $totalTransactions) * 100, 1) } else { 0 }
    Write-Host "  " + ("-" * 59) -ForegroundColor Gray
    Write-Host ("  {0,-25} {1,8} {2,8} {3,8} {4,6}%" -f "GESAMT", $totalTransactions, $totalTransfers, $totalCategorized, $totalRate.ToString("F1")) -ForegroundColor Cyan
    Write-Host ""
}

# ==========================================
# STARTING BALANCE CALCULATION
# ==========================================

if (-not $isDryRun) {
    if (-not $isSilent) {
        Write-Host (t "balance.calculating_balances") -ForegroundColor White
    }
    Write-LogOnly (t "balance.calculating_balances") "INFO"
    $accountBalances = @{}
    
    foreach ($file in $csvFiles) {
        $fileName = $file.BaseName
        
        try {
            # Load CSV with same settings as main processing
            $csvData = Import-Csv -Path $file.FullName -Delimiter $csvSettings.delimiter -Encoding $csvSettings.encoding
            
            if ($csvData.Count -gt 0) {
                # Get the first (oldest) entry by date - handle files with only one transaction
                $firstEntry = if ($csvData.Count -eq 1) {
                    $csvData[0]
                } else {
                    $csvData | Sort-Object {
                        try {
                            if ($_.PSObject.Properties.Name -contains "Buchungstag") {
                                [DateTime]::ParseExact($_."Buchungstag", "dd.MM.yyyy", $null)
                            } else {
                                [DateTime]::MaxValue
                            }
                        } catch {
                            [DateTime]::MaxValue
                        }
                    } | Select-Object -First 1
                }
                
                if ($firstEntry -and $firstEntry.PSObject.Properties.Name -contains "Saldo nach Buchung" -and $firstEntry."Saldo nach Buchung") {
                    # Convert German decimal format to English
                    $balanceAfterText = $firstEntry."Saldo nach Buchung" -replace '\.', '' -replace ',', '.'
                    $amountText = if ($firstEntry.PSObject.Properties.Name -contains "Betrag") { 
                        $firstEntry."Betrag" -replace '\.', '' -replace ',', '.' 
                    } else { '0' }
                    
                    try {
                        $balanceAfter = [decimal]$balanceAfterText
                        $amount = [decimal]$amountText
                        # For accounts with zero transaction amounts (like Startsaldo entries), use the balance directly
                        if ($amount -eq 0) {
                            $startingBalance = $balanceAfter
                        } else {
                            # Starting balance = Balance after transaction - Transaction amount
                            $startingBalance = $balanceAfter - $amount
                        }
                        
                        # Derive account name from filename
                        $accountName = $fileName
                        if ($fileName -match "(.+?)(?:\s+seit|\s+Kontoauszug|\s+Export)") {
                            $accountName = $matches[1]
                        }
                        
                        $accountBalances[$accountName] = @{
                            balance = $startingBalance
                            date = if ($firstEntry.PSObject.Properties.Name -contains "Buchungstag") { $firstEntry."Buchungstag" } else { 'Unknown' }
                            file = $fileName
                        }
                        
                        $displayMessage = (t "balance.starting_balance_for" @($accountName, $startingBalance.ToString('N2')))
                        $logMessage = (t "balance.starting_balance_for" @($accountName, $startingBalance.ToString('N2')))
                        if (-not $isSilent) {
                            Write-Host $displayMessage -ForegroundColor White
                        }
                        Write-LogOnly $logMessage "INFO"
                        
                    } catch {
                        Write-Log "Failed to calculate starting balance for $fileName`: $($_.Exception.Message)" "WARNING"
                        # Add to missing balances list for manual input
                        if (-not $script:missingBalances) { $script:missingBalances = @() }
                        $script:missingBalances += @{
                            fileName = $fileName
                            accountName = $fileName
                            reason = "Calculation failed: $($_.Exception.Message)"
                        }
                    }
                } else {
                    # No balance column found or empty balance
                    Write-Log "No starting balance found for $fileName - missing 'Saldo nach Buchung' column or empty balance" "WARNING"
                    if (-not $script:missingBalances) { $script:missingBalances = @() }
                    $script:missingBalances += @{
                        fileName = $fileName
                        accountName = $fileName
                        reason = "No 'Saldo nach Buchung' column or empty balance"
                    }
                }
            }
        } catch {
            Write-Log "Error processing file $fileName for starting balance: $($_.Exception.Message)" "WARNING"
        }
    }
    
    # Handle missing balances with manual input
    if ($script:missingBalances -and $script:missingBalances.Count -gt 0 -and -not $isSilent) {
        Write-Host ""
        Write-Host (t "balance.missing_balances_title") -ForegroundColor Yellow
        Write-Host (t "balance.missing_balances_desc") -ForegroundColor White
        Write-Host ""
        
        foreach ($missing in $script:missingBalances) {
            $cleanAccountName = $missing.accountName
            if ($missing.fileName -match "(.+?)(?:\s+seit|\s+Kontoauszug|\s+Export)") {
                $cleanAccountName = $matches[1]
            }
            
            Write-Host "Konto: " -NoNewline -ForegroundColor White
            Write-Host $cleanAccountName -ForegroundColor Cyan
            Write-Host "Grund: " -NoNewline -ForegroundColor Gray
            Write-Host $missing.reason -ForegroundColor Yellow
            
            do {
                $input = Read-Host (t "balance.manual_input_prompt" @($currency))
                if ($input -eq "") {
                    Write-Host (t "balance.skipping_account") -ForegroundColor Gray
                    break
                }
                
                $cleanInput = $input -replace '\.', '' -replace ',', '.'
                try {
                    $manualBalance = [decimal]$cleanInput
                    
                    $accountBalances[$cleanAccountName] = @{
                        balance = $manualBalance
                        date = "Manual Input"
                        file = $missing.fileName
                    }
                    
                    Write-Host (t "balance.manual_balance_added" @($cleanAccountName, $manualBalance, $currency)) -ForegroundColor Green
                    Write-Log ($global:i18n.Get("balance.starting_balance", @($cleanAccountName, $manualBalance, $currency))) "INFO"
                    break
                } catch {
                    Write-Host (t "balance.invalid_input") -ForegroundColor Red
                }
            } while ($true)
            
            Write-Host ""
        }
    }
    
    # Save starting balances to logs directory
    if ($accountBalances.Count -gt 0) {
        $balanceOutput = @()
        $balanceOutput += "# STARTING BALANCES FOR ACTUAL BUDGET"
        $balanceOutput += "# Generated on: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
        $balanceOutput += "# Formula: Oldest balance in CSV - transaction amount"
        $balanceOutput += ""
        $balanceOutput += "ACCOUNT SETUP FOR ACTUAL BUDGET:"
        $balanceOutput += "================================"
        $balanceOutput += ""
        
        $sortedAccounts = $accountBalances.GetEnumerator() | Sort-Object Name
        $totalBalance = 0
        
        foreach ($account in $sortedAccounts) {
            $name = $account.Key
            $data = $account.Value
            $balance = $data.balance
            $date = $data.date
            $totalBalance += $balance
            
            $balanceFormatted = "{0:N2}" -f $balance
            $balanceOutput += "Account: $name"
            $balanceOutput += "  Starting Balance: $balanceFormatted $currency"
            $balanceOutput += "  Date: $date"
            $balanceOutput += ""
        }
        
        $balanceOutput += "================================"
        $balanceOutput += "TOTAL STARTING BALANCE: $('{0:N2}' -f $totalBalance) $currency"
        $balanceOutput += ""
        $balanceOutput += "INSTRUCTIONS:"
        $balanceOutput += "1. Create these accounts in Actual Budget"
        $balanceOutput += "2. Set the starting balances as shown above"
        $balanceOutput += "3. Import CSV files from actual_import/ folder"
        
        $balanceFile = Join-Path $logsDir "starting_balances_$(Get-Date -Format 'yyyyMMdd_HHmmss').txt"
        $balanceOutput | Out-File -FilePath $balanceFile -Encoding UTF8
        
        $relativeBalanceFile = $balanceFile -replace [regex]::Escape($PSScriptRoot + [System.IO.Path]::DirectorySeparatorChar), ""
        Write-Log "Starting balances saved to: $relativeBalanceFile" "INFO"
        Write-Log (t "balance.total_accounts_balance" @($accountBalances.Count, $totalBalance.ToString('N2'))) "INFO"
    } else {
        Write-Log "No starting balances could be calculated" "WARNING"
    }
}

# ==========================================
# CREATE CATEGORIES LIST
# ==========================================

if (-not $isDryRun) {
    # Create a categories list for the user
    $categoriesFile = Join-Path $OutputDir "_KATEGORIEN_LISTE.txt"
    $categoriesContent = @()
    $categoriesContent += "KATEGORIEN FÜR ACTUAL BUDGET"
    $categoriesContent += "=================================="
    $categoriesContent += "Diese Kategorien wurden in Ihren CSV-Dateien gefunden."
    $categoriesContent += "Erstellen Sie diese exakt so in Actual Budget für optimale Zuordnung."
    $categoriesContent += ""
    $categoriesContent += "TRANSFER-KATEGORIEN:"
    $categoriesContent += "• Transfer to Haushaltskasse"
    $categoriesContent += "• Transfer from Haushaltskasse"
    $categoriesContent += "• Transfer to Geschäftsanteile"
    $categoriesContent += "• Transfer from Geschäftsanteile"
    $categoriesContent += "• Transfer (Household Contribution)"
    $categoriesContent += "• Internal Transfer"
    $categoriesContent += ""
    $categoriesContent += "EINNAHMEN-KATEGORIEN:"
    $categoriesContent += "• Income"
    $categoriesContent += "• Other Income"
    $categoriesContent += "• Tax Refunds"
    $categoriesContent += "• Cash Deposits"
    $categoriesContent += "• Capital Gains"
    $categoriesContent += ""
    $categoriesContent += "AUSGABEN-KATEGORIEN:"
    $categoriesContent += "• Groceries"
    $categoriesContent += "• Fuel"
    $categoriesContent += "• Housing"
    $categoriesContent += "• Insurance"
    $categoriesContent += "• Internet & Phone"
    $categoriesContent += "• Public Transportation"
    $categoriesContent += "• Pharmacy & Health"
    $categoriesContent += "• Restaurants & Dining"
    $categoriesContent += "• Online Shopping"
    $categoriesContent += "• Electronics & Technology"
    $categoriesContent += "• Streaming & Subscriptions"
    $categoriesContent += "• Bank Fees"
    $categoriesContent += "• Taxes"
    $categoriesContent += "• Health"
    $categoriesContent += "• Donations"
    $categoriesContent += "• Memberships"
    $categoriesContent += "• Education"
    $categoriesContent += "• Clothing"
    $categoriesContent += "• Entertainment"
    $categoriesContent += "• Consulting & Legal"
    $categoriesContent += "• Taxi & Ridesharing"
    $categoriesContent += ""
    $categoriesContent += "ANLEITUNG:"
    $categoriesContent += "1. Öffnen Sie Actual Budget"
    $categoriesContent += "2. Gehen Sie zu 'Kategorien'"
    $categoriesContent += "3. Erstellen Sie diese Kategorien exakt wie oben aufgelistet"
    $categoriesContent += "4. Importieren Sie dann die CSV-Dateien aus diesem Ordner"
    
    $categoriesContent | Out-File -FilePath $categoriesFile -Encoding UTF8
    $relativeCategoriesFile = $categoriesFile -replace [regex]::Escape($PSScriptRoot + [System.IO.Path]::DirectorySeparatorChar), ""
    Write-Log ("Kategorien-Liste erstellt: $relativeCategoriesFile") "INFO"
}

# ==========================================
# SUMMARY
# ==========================================

$categorizedPercentage = if ($totalTransactions -gt 0) { [math]::Round(($totalCategorized / $totalTransactions) * 100, 1) } else { 0 }

# Log summary only to log file
$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
$script:logContent += "[$timestamp] [INFO] VERARBEITUNGS-ZUSAMMENFASSUNG:"
$script:logContent += "[$timestamp] [INFO]   Verarbeitete Dateien: $($csvFiles.Count)"
$script:logContent += "[$timestamp] [INFO]   Total Transaktionen: $totalTransactions"
$script:logContent += "[$timestamp] [INFO]   Transfer-Kategorien: $totalTransfers"
$script:logContent += "[$timestamp] [INFO]   Andere Kategorien: $($totalCategorized - $totalTransfers)"
$script:logContent += "[$timestamp] [INFO]   Kategorisierung: $categorizedPercentage%"

if ($isSilent) {
    # Silent Mode: Brief summary on console (ASCII-safe)
    Write-Host ""
    Write-Host (t "processor.completed_successfully") -ForegroundColor Green
    $summaryText = $global:i18n.Get("processor.files_transactions_categorized", @($csvFiles.Count, $totalTransactions, $categorizedPercentage))
    Write-Host $summaryText -ForegroundColor White
    if ($accountBalances -and $accountBalances.Count -gt 0) {
        $totalStartingBalance = ($accountBalances.GetEnumerator() | ForEach-Object { $_.Value.balance } | Measure-Object -Sum).Sum
        $balanceText = $global:i18n.Get("processor.accounts_balance", @($accountBalances.Count, ('{0:N2}' -f $totalStartingBalance), $currency))
        Write-Host $balanceText -ForegroundColor Green
    }
    $relativeOutputDir = $OutputDir -replace [regex]::Escape($PSScriptRoot + [System.IO.Path]::DirectorySeparatorChar), ""
    $outputText = $global:i18n.Get("processor.output_folder", @($relativeOutputDir))
    Write-Host $outputText -ForegroundColor Yellow
    $logText = $global:i18n.Get("processor.log_file", @($logFile))
    Write-Host $logText -ForegroundColor Gray
    Write-Host ""
    Write-Host (t "processor.next_steps_title") -ForegroundColor Cyan
    Write-Host "  " + (t "processor.step1_balances") -ForegroundColor White
    Write-Host "  " + (t "processor.step2_categories") -ForegroundColor White
    $step3Text = $global:i18n.Get("processor.step3_import", @($OutputDir))
    Write-Host "  $step3Text" -ForegroundColor White
    Write-Host ""
} else {
    Write-Host ""
    Write-Host (t "processor.summary") -ForegroundColor Cyan
    $processedText = $global:i18n.Get("processor.processed_files", @($csvFiles.Count))
    Write-Host "  $processedText" -ForegroundColor White
    $transactionsText = $global:i18n.Get("processor.total_transactions", @($totalTransactions))
    Write-Host "  $transactionsText" -ForegroundColor White
    $transferText = $global:i18n.Get("processor.transfer_categories", @($totalTransfers))
    Write-Host "  $transferText" -ForegroundColor Green
    $otherText = $global:i18n.Get("processor.other_categories", @($totalCategorized - $totalTransfers))
    Write-Host "  $otherText" -ForegroundColor Green
    $rateText = $global:i18n.Get("processor.categorization_rate", @($categorizedPercentage))
    Write-Host "  $rateText" -ForegroundColor Yellow
    Write-Host ""
    Write-Host (t "instructions.next_steps") -ForegroundColor Cyan
    Write-Host "  $(t 'instructions.create_categories')" -ForegroundColor White
    $importMsg = $global:i18n.Get('instructions.import_files', @($OutputDir))
    Write-Host "  $importMsg" -ForegroundColor White
    Write-Host "  $(t 'instructions.set_mapping')" -ForegroundColor White
    Write-Host "  $(t 'instructions.start_import')" -ForegroundColor White
    Write-Host ""
    Write-Host (t "processor.important") -ForegroundColor Yellow
    Write-Host ""
    Write-Host (t "processor.completed") -ForegroundColor Green
    if (-not $isDryRun -and -not $isSilent) {
        Read-Host (t "common.press_enter_exit")
    }
}

# Log-Datei speichern
Save-LogFile
if ($isSilent) {
    Write-Log "Processing completed - Log saved to $logFile"
}

# Automatic log cleanup (configurable retention)
try {
    $logRetentionDays = $global:config.Get("defaults.logRetentionDays")
    if (-not $logRetentionDays) { $logRetentionDays = 7 }  # Fallback
    $cutoffDate = (Get-Date).AddDays(-$logRetentionDays)
    $oldLogs = Get-ChildItem -Path $logsDir -Filter "*.log" -File | 
               Where-Object { $_.LastWriteTime -lt $cutoffDate }
    
    if ($oldLogs.Count -gt 0) {
        foreach ($oldLog in $oldLogs) {
            Remove-Item -Path $oldLog.FullName -Force
        }
        Write-Log "Cleaned up $($oldLogs.Count) old log files (older than $logRetentionDays days)" "INFO"
    }
} catch {
    Write-Log "Log cleanup failed: $($_.Exception.Message)" "WARNING"
}

# Successful exit
exit 0