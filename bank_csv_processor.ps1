# CSV2Actual - Bank CSV Processor
# Version: 1.0
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
. "$PSScriptRoot/modules/Config.ps1"
. "$PSScriptRoot/modules/I18n.ps1"
. "$PSScriptRoot/modules/CsvValidator.ps1"

# Initialize configuration and i18n
try {
    $global:config = [Config]::new("$PSScriptRoot/config.json")
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
    param([string]$key, [array]$args = @())
    if ($args.Length -eq 1) {
        return $global:i18n.Format($key, $args[0].ToString())
    } elseif ($args.Length -eq 0) {
        return $global:i18n.Get($key)
    } else {
        return $global:i18n.Get($key, $args)
    }
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
    Write-Host "  -AlternativeFormats    Create semicolon, tab, and manual CSV variants for compatibility"
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

# Logging Setup
$logFile = "csv_processor_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"
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
        Write-Host "DRY-RUN: Preview without writing files" -ForegroundColor Yellow
    }
    Write-Host ""
} else {
    Write-Host "CSV2Actual running in Silent Mode..." -ForegroundColor Gray
}

Write-Log "CSV2Actual Processor started" "INFO"
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
            Write-Host "    Alt: Semicolon format" -ForegroundColor Cyan
        }
        Write-LogOnly "  Alternative format created: $semicolonFile"
        
        # Tab format
        $tabFile = Join-Path $OutputDir "$BaseName`_TAB.csv"
        $Data | Export-Csv -Path $tabFile -NoTypeInformation -Encoding UTF8 -Delimiter "`t"
        if (-not $Silent) {
            Write-Host "    Alt: Tab-separated format" -ForegroundColor Cyan
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
            Write-Host "    Alt: Manual ASCII format" -ForegroundColor Cyan
        }
        Write-LogOnly "  Alternative format created: $manualFile"
        
    } catch {
        Write-Log "WARNING: Could not create alternative formats: $($_.Exception.Message)" "WARN"
    }
}

# ==========================================
# HAUPT-VERARBEITUNGSFUNKTION
# ==========================================

function Get-CleanAccountName {
    param([string]$fileName)
    
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
    $accountName = Get-CleanAccountName -fileName $fileName
    
    try {
        # Validate CSV and get column mapping
        $validator = [CsvValidator]::new($global:i18n)
        $validationResult = $validator.ValidateFile($FilePath)
        
        if (-not $validationResult.isValid) {
            Write-Log "WARNING: CSV validation issues for ${fileName}:" "WARN"
            foreach ($error in $validationResult.errors) {
                Write-Log "  - $error" "WARN"
            }
            # Try to load anyway with fallback method
        }
        
        # Load CSV with configured settings or validator fallback
        $delimiter = $csvSettings.delimiter
        $encoding = $csvSettings.encoding
        $csvData = Import-Csv -Path $FilePath -Delimiter $delimiter -Encoding $encoding
        
        if (-not $csvData) {
            # Use validator's TryReadCsv as fallback
            $csvData = $validator.TryReadCsv($FilePath)
        }
        
        if (-not $csvData) {
            Write-Log "ERROR: Could not read CSV file: $FilePath" "ERROR"
            return $null
        }
        
        # Get column mapping for this file
        $columnMapping = $validationResult.columnMapping
        
        if (-not $isSilent) {
            Write-Host "  $($fileName -replace ' seit .*', '') ($($csvData.Count))" -ForegroundColor White
        }
        Write-LogOnly "Processing: $fileName - Transactions: $($csvData.Count)"
        Write-LogOnly "Column mapping: $(($columnMapping.Keys | ForEach-Object { "$_->$($columnMapping[$_])" }) -join ', ')"
        
        $transferCount = 0
        $categorizedCount = 0
        $processedData = @()
        
        foreach ($row in $csvData) {
            # Get column values using dynamic mapping
            $dateColumn = $columnMapping["Date"]
            $amountColumn = $columnMapping["Amount"] 
            $payeeColumn = $columnMapping["Payee"]
            $purposeColumn = $columnMapping["Purpose"]
            $ibanColumn = $columnMapping["IBAN"]
            
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
        
        if (-not $isSilent) {
            Write-Host "    Transfer: $transferCount, Kategorien: $categorizedCount" -ForegroundColor Gray
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
        Write-Log (t "processor.folder_created" @($OutputDir))
    }
} else {
    Write-Log (t "processor.dry_run_folder" @($OutputDir))
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
    if (-not $isSilent) { Read-Host "Press Enter to exit" }
    exit 1
}

Write-Log ((t "processor.found_files") -replace '\{0\}', $csvFiles.Count)
if (-not $isSilent) {
    $msg = (t "processor.processing_files") -replace '\{0\}', $csvFiles.Count
    Write-Host $msg -ForegroundColor Yellow
}

# Statistiken
$totalTransactions = 0
$totalTransfers = 0
$totalCategorized = 0

# Alle CSV-Dateien verarbeiten
foreach ($file in $csvFiles) {
    $processedData = Process-BankCSV -FilePath $file.FullName
    
    if ($processedData.Count -gt 0) {
        # Statistiken aktualisieren
        $totalTransactions += $processedData.Count
        $totalTransfers += ($processedData | Where-Object { $_.category -match "Transfer" }).Count
        $totalCategorized += ($processedData | Where-Object { $_.category -and $_.category -ne "" }).Count
        
        # Output-Datei speichern (nicht im Dry-Run)
        $outputFile = Join-Path $OutputDir "$($file.BaseName).csv"
        
        if (-not $isDryRun) {
            $outputDelimiter = $csvSettings.outputDelimiter
            $processedData | Export-Csv -Path $outputFile -NoTypeInformation -Delimiter $outputDelimiter
            if (-not $isSilent) {
                Write-Host "    Saved" -ForegroundColor Green
            }
            Write-LogOnly "  Saved: $($outputFile)"
            
            # Create alternative formats if requested
            if ($AlternativeFormats) {
                Create-AlternativeFormats -Data $processedData -BaseName $file.BaseName -OutputDir $OutputDir -Silent $isSilent
            }
        } else {
            if (-not $isSilent) {
                Write-Host "    DRY-RUN: Would save" -ForegroundColor Cyan
            }
            Write-LogOnly "  DRY-RUN: Would save: $($outputFile)"
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
    Write-Host "CSV2Actual completed successfully!" -ForegroundColor Green
    Write-Host "$($csvFiles.Count) files, $totalTransactions transactions, $categorizedPercentage% categorized" -ForegroundColor White
    Write-Host "Output: $OutputDir/ folder" -ForegroundColor Yellow
    Write-Host "Log: $logFile" -ForegroundColor Gray
    Write-Host ""
    Write-Host "NEXT STEPS:" -ForegroundColor Cyan
    Write-Host "  1. Create 39 categories in Actual Budget" -ForegroundColor White
    Write-Host "  2. Import CSV files from '$OutputDir/' folder" -ForegroundColor White
    Write-Host "  3. Set starting balances (see starting_balances.txt)" -ForegroundColor White
    Write-Host ""
} else {
    Write-Host ""
    Write-Host "PROCESSING SUMMARY:" -ForegroundColor Cyan
    Write-Host "  Processed files: $($csvFiles.Count)" -ForegroundColor White
    Write-Host "  Total transactions: $totalTransactions" -ForegroundColor White
    Write-Host "  Transfer categories: $totalTransfers" -ForegroundColor Green
    Write-Host "  Other categories: $($totalCategorized - $totalTransfers)" -ForegroundColor Green
    Write-Host "  Categorization rate: $categorizedPercentage%" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "NEXT STEPS FOR ACTUAL BUDGET:" -ForegroundColor Cyan
    Write-Host "  1. Create categories in Actual Budget (see category list)" -ForegroundColor White
    Write-Host "  2. Import CSV files from '$OutputDir' folder" -ForegroundColor White
    Write-Host "  3. Mapping: date->Date, payee->Payee, category->Category, amount->Amount" -ForegroundColor White
    Write-Host "  4. Start import - categories should now be visible!" -ForegroundColor White
    Write-Host ""
    Write-Host "IMPORTANT: Categories must be created in Actual exactly as they" -ForegroundColor Yellow
    Write-Host "           appear in the CSV files!" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Processing completed!" -ForegroundColor Green
    if (-not $isDryRun -and -not $isSilent) {
        Read-Host "Press Enter to exit"
    }
}

# Log-Datei speichern
Save-LogFile
if ($isSilent) {
    Write-Log "Processing completed - Log saved to $logFile"
}

# Successful exit
exit 0