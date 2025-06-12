# CSV2Actual - Bank CSV Processor
# Version: 1.2.1
# Author: sTLAs (https://github.com/sTLAs)
# Converts German Bank CSVs to Actual Budget format with automatic categorization
# Features: Internationalization (EN/DE), JSON Configuration, PowerShell Core support

# Parameter mit Aliasing nach PowerShell Best Practices
param(
    [Alias("n")][switch]$DryRun,
    [Alias("q")][switch]$Silent,
    [Alias("h")][switch]$Help,
    [Alias("l")][string]$Language = "en",
    [switch]$AlternativeFormats,
    [Alias("d")][string]$StartingDate = "",
    [switch]$AskStartingDate,
    [Alias("s")][switch]$ScanCategories
)

# Load modules
. "$PSScriptRoot/../modules/Config.ps1"
. "$PSScriptRoot/../modules/I18n.ps1"
. "$PSScriptRoot/../modules/CsvValidator.ps1"

# Initialize configuration and i18n
try {
    $global:config = [Config]::new("$PSScriptRoot/../config.json")
    $langDir = $global:config.Get("paths.languageDir")
    # Make langDir absolute relative to project root
    $projectRoot = Split-Path $PSScriptRoot -Parent
    $absoluteLangDir = Join-Path $projectRoot $langDir
    $global:i18n = [I18n]::new($absoluteLangDir, $Language)
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
    Write-Host "  " + (t "processor.language_help")
    Write-Host "  " + (t "processor.alternative_formats_help")
    Write-Host "  " + (t "processor.scan_categories_help")
    Write-Host "  " + (t "processor.starting_date_help")
    Write-Host "  " + (t "processor.ask_starting_date_help")
    Write-Host ""
    Write-Host (t "processor.examples") -ForegroundColor Yellow
    Write-Host "  " + (t "processor.example_normal")
    Write-Host "  " + (t "processor.example_normal_cmd")
    Write-Host ""
    Write-Host "  " + (t "processor.example_dry_run")
    Write-Host "  " + (t "processor.example_dry_run_cmd1")
    Write-Host "  " + (t "processor.example_dry_run_cmd2")
    Write-Host ""
    Write-Host "  " + (t "processor.example_silent")
    Write-Host "  " + (t "processor.example_silent_cmd1")
    Write-Host "  " + (t "processor.example_silent_cmd2")
    Write-Host ""
    Write-Host "  " + (t "processor.example_scanner")
    Write-Host "  " + (t "processor.example_scanner_cmd1")
    Write-Host "  " + (t "processor.example_scanner_cmd2")
    Write-Host ""
    Write-Host "  " + (t "processor.example_language")
    Write-Host "  " + (t "processor.example_language_cmd1")
    Write-Host "  " + (t "processor.example_language_cmd2")
    Write-Host ""
    Write-Host "  " + (t "processor.example_date")
    Write-Host "  " + (t "processor.example_date_cmd1")
    Write-Host "  " + (t "processor.example_date_cmd2")
    Write-Host ""
    Write-Host "  " + (t "processor.example_formats")
    Write-Host "  " + (t "processor.example_formats_cmd")
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

function Get-TruncatedPurpose {
    param([string]$purpose)
    
    if (-not $purpose -or $purpose.Trim() -eq '') {
        return ''
    }
    
    $purpose = $purpose.Trim()
    
    # Pattern 1: Credit card transactions - remove EUR amount and trailing details
    # Example: "Baeckerei Pfrommer         DEU Pforzheim              EUR             12,95      Umsatz vom 26.05.2025      MC Hauptkarte"
    if ($purpose -match '(.+?)\s+EUR\s+[\d\s,\.]+\s+Umsatz\s+vom\s+') {
        return $matches[1].Trim()
    }
    
    # Pattern 2: Credit card with multiple spaces before EUR
    # Example: "ALDI SUeD                  DEU Calw                   EUR             34,03"
    if ($purpose -match '(.+?)\s{2,}EUR\s+[\d\s,\.]+') {
        return $matches[1].Trim()
    }
    
    # Pattern 3: Remove common trailing patterns with amounts and dates
    # Example: "MERCHANT NAME DEU City EUR 34,03 something"
    if ($purpose -match '(.+?)\s+EUR\s+[\d,\.]+\s+.*') {
        return $matches[1].Trim()
    }
    
    # Pattern 3: German Lastschrift/SEPA - keep only meaningful part
    # Example: "Lastschrift NETFLIX.COM Monthly Subscription Reference: 123456"
    if ($purpose -match '^(?:Lastschrift|SEPA|Basislastschrift)\s+(.+?)(?:\s+(?:Reference|Ref|Mandatsref)[:.].*|$)') {
        return $matches[1].Trim()
    }
    
    # Pattern 4: Remove trailing technical information
    # Example: "Amazon Payment Reference ABC123 Mandate DEF456"
    if ($purpose -match '(.+?)(?:\s+(?:Reference|Ref|Mandate|Mandatsref|Glaeubiger)[:.].*|$)') {
        $truncated = $matches[1].Trim()
        if ($truncated.Length -ge 10) {  # Only use if result is meaningful
            return $truncated
        }
    }
    
    # Pattern 5: Limit extremely long purposes to first meaningful section
    if ($purpose.Length -gt 80) {
        # Find natural break points (spaces, common separators)
        $breakPoints = @()
        
        # Look for EUR amount as break point
        if ($purpose -match '(.{20,60}?)\s+EUR\s+') {
            return $matches[1].Trim()
        }
        
        # Look for repeating spaces or multiple whitespace as break point
        if ($purpose -match '(.{20,60}?)\s{3,}') {
            return $matches[1].Trim()
        }
        
        # Look for date patterns as break point
        if ($purpose -match '(.{20,60}?)\s+\d{2}\.\d{2}\.\d{4}') {
            return $matches[1].Trim()
        }
        
        # Fallback: Take first 60 chars at word boundary
        if ($purpose.Length -gt 60) {
            $truncated = $purpose.Substring(0, 60)
            $lastSpace = $truncated.LastIndexOf(' ')
            if ($lastSpace -gt 20) {
                return $truncated.Substring(0, $lastSpace).Trim()
            }
        }
    }
    
    # Return original if no patterns match and length is reasonable
    return $purpose
}

function Get-CategoryMapping {
    param([string]$text, [decimal]$amount)
    
    # Check custom category mappings from config first
    $customMappings = $global:config.Get("categorization.customMappings")
    if ($customMappings) {
        foreach ($mapping in $customMappings.PSObject.Properties) {
            $patterns = $mapping.Value.patterns
            if ($patterns -and (Test-PatternMatch $text $patterns)) {
                return $mapping.Value.category
            }
        }
    }
    
    return $null
}

function Save-CategoryMapping {
    param(
        [string]$pattern,
        [string]$category,
        [string]$payee = "",
        [string]$memo = ""
    )
    
    try {
        # Load current config
        $configPath = "$PSScriptRoot/../config.local.json"
        $localConfig = @{}
        
        if (Test-Path $configPath) {
            $localConfig = Get-Content $configPath -Raw | ConvertFrom-Json -AsHashtable
        }
        
        # Ensure categorization.customMappings exists
        if (-not $localConfig.categorization) {
            $localConfig.categorization = @{}
        }
        if (-not $localConfig.categorization.customMappings) {
            $localConfig.categorization.customMappings = @{}
        }
        
        # Create unique key for this mapping
        $key = "custom_" + ([System.Guid]::NewGuid().ToString().Substring(0,8))
        
        $localConfig.categorization.customMappings[$key] = @{
            patterns = @($pattern)
            category = $category
            payee = $payee
            memo = $memo
            dateAdded = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
        }
        
        # Save back to file
        $localConfig | ConvertTo-Json -Depth 10 | Out-File $configPath -Encoding UTF8
        Write-LogOnly "Saved custom category mapping: '$pattern' -> '$category'" "INFO"
        
    } catch {
        Write-Log "Could not save category mapping: $($_.Exception.Message)" "WARNING"
    }
}

function Start-CategoryScanner {
    if ($isSilent) {
        Write-Host "Category scanner requires interactive mode. Please run without -Silent." -ForegroundColor Red
        return
    }
    
    Write-Host ""
    Write-Host "🔍 KATEGORIE-SCANNER" -ForegroundColor Cyan
    Write-Host "===================" -ForegroundColor Cyan
    Write-Host "Scannt alle CSV-Dateien und lässt Sie unbekannte Kategorien interaktiv zuordnen." -ForegroundColor White
    Write-Host "Die Zuordnungen werden in config.local.json gespeichert und wiederverwendet." -ForegroundColor White
    Write-Host ""
    
    # Collect all unique transactions that don't have categories (excluding transfers)
    $uncategorizedTransactions = @{}
    $totalTransactions = 0
    $filteredTransferCount = 0
    
    foreach ($file in $csvFiles) {
        Write-Host "Scanning: $($file.BaseName)..." -ForegroundColor Gray
        $processedData = Process-BankCSV -FilePath $file.FullName
        
        $processedCount = if ($processedData -is [array]) { $processedData.Count } elseif ($processedData) { 1 } else { 0 }
        $totalTransactions += $processedCount
        
        if ($processedCount -gt 0) {
            foreach ($row in $processedData) {
                if (-not $row.category -or $row.category.Trim() -eq "") {
                    # Create a pattern key for similar transactions - handle NULL payee
                    $payeeText = if ($row.payee -and $row.payee.ToString().Trim() -ne "") { 
                        $row.payee.ToString().Trim() 
                    } else { 
                        "UNKNOWN_PAYEE" 
                    }
                    
                    # Pre-filter transfers using same logic as main categorization
                    $memoText = if ($row.notes) { $row.notes.ToLower() } else { "" }
                    
                    # Check for IBAN-based transfers first (most accurate)
                    $targetIBAN = ""
                    if ($row.PSObject.Properties.Name -contains "IBAN Zahlungsbeteiligter" -and $row."IBAN Zahlungsbeteiligter") {
                        $targetIBAN = $row."IBAN Zahlungsbeteiligter".Trim()
                    }
                    
                    $isTransfer = $false
                    
                    # 1. IBAN-based transfer recognition (highest priority)
                    if ($targetIBAN -and $OwnIBANs.ContainsKey($targetIBAN)) {
                        $isTransfer = $true
                    }
                    # 2. Fallback: keyword-based transfer recognition
                    else {
                        $transferIndicators = @(
                            "überweisung", "gutschrift", "lastschrift", "dauerauftrag", "transfer",
                            "haushaltsbeitrag", "kreditkarte.*zahlung", "kk\\d+/\\d+", "ausgleich", "umbuchung"
                        )
                        
                        foreach ($indicator in $transferIndicators) {
                            if ($memoText -match $indicator -or $payeeText.ToLower() -match $indicator) {
                                $isTransfer = $true
                                break
                            }
                        }
                        
                        # Also check if payee looks like a person name with transfer indicators
                        if (-not $isTransfer -and $payeeText -match "^[a-z]+\\s+[a-z]+$" -and $payeeText -notmatch "gmbh|kg|ag|e\\.?v\\.?|ltd|inc") {
                            if ($memoText -match "überweisung|gutschrift|transfer|kk\\d+") {
                                $isTransfer = $true
                            }
                        }
                    }
                    
                    if ($isTransfer) {
                        $filteredTransferCount++
                        continue  # Skip transfer transactions completely
                    }
                    
                    $patternKey = $payeeText.ToLower()
                    
                    if (-not $uncategorizedTransactions.ContainsKey($patternKey)) {
                        $uncategorizedTransactions[$patternKey] = @{
                            payee = $payeeText
                            memo = $row.notes
                            amount = $row.amount
                            count = 0
                            examples = @()
                        }
                    }
                    
                    $uncategorizedTransactions[$patternKey].count++
                    if ($uncategorizedTransactions[$patternKey].examples.Count -lt 3) {
                        $uncategorizedTransactions[$patternKey].examples += @{
                            date = $row.date
                            amount = $row.amount
                            memo = $row.notes
                        }
                    }
                }
            }
        }
    }
    
    Write-Host ""
    Write-Host "📊 SCAN-ERGEBNISSE" -ForegroundColor Yellow
    Write-Host "Total Transaktionen: $totalTransactions" -ForegroundColor White
    Write-Host "Transfer-Transaktionen (gefiltert): $filteredTransferCount" -ForegroundColor Cyan
    Write-Host "Unkategorisiert: $($uncategorizedTransactions.Count) Payee-Gruppen" -ForegroundColor White
    
    if ($uncategorizedTransactions.Count -eq 0) {
        Write-Host "🎉 Alle Transaktionen sind bereits kategorisiert!" -ForegroundColor Green
        return
    }
    
    Write-Host ""
    Write-Host "Möchten Sie die unkategorisierten Transaktionen interaktiv zuordnen? (j/n)" -ForegroundColor Cyan
    $response = Read-Host
    
    if ($response -ne "j" -and $response -ne "y" -and $response -ne "ja" -and $response -ne "yes") {
        Write-Host "Scanner abgebrochen." -ForegroundColor Gray
        return
    }
    
    # Sort by count (most frequent first)
    $sortedTransactions = $uncategorizedTransactions.GetEnumerator() | Sort-Object { $_.Value.count } -Descending
    
    $processed = 0
    $skipped = 0
    $categorized = 0
    
    Write-Host ""
    Write-Host "🏷️  INTERAKTIVE KATEGORISIERUNG" -ForegroundColor Cyan
    Write-Host "=================================" -ForegroundColor Cyan
    Write-Host "Geben Sie 's' ein um zu überspringen, 'q' um zu beenden." -ForegroundColor Gray
    Write-Host ""
    
    foreach ($transaction in $sortedTransactions) {
        $data = $transaction.Value
        $processed++
        
        Write-Host "[$processed/$($sortedTransactions.Count)] " -NoNewline -ForegroundColor Gray
        Write-Host "$($data.payee)" -ForegroundColor Yellow
        Write-Host "  Häufigkeit: $($data.count) Transaktionen" -ForegroundColor White
        Write-Host "  Beispiele:" -ForegroundColor Gray
        
        foreach ($example in $data.examples) {
            $amountColor = if ($example.amount -gt 0) { "Green" } else { "Red" }
            Write-Host "    $($example.date): " -NoNewline -ForegroundColor Gray
            Write-Host "$($example.amount) EUR " -NoNewline -ForegroundColor $amountColor
            if ($example.memo) {
                Write-Host "- $($example.memo.Substring(0, [Math]::Min($example.memo.Length, 50)))" -ForegroundColor Gray
            } else {
                Write-Host "" 
            }
        }
        
        Write-Host ""
        Write-Host "Kategorie eingeben (oder 's' überspringen, 'q' beenden): " -NoNewline -ForegroundColor Cyan
        $category = Read-Host
        
        if ($category -eq "q") {
            Write-Host "Scanner beendet." -ForegroundColor Gray
            break
        }
        
        if ($category -eq "s" -or $category -eq "") {
            $skipped++
            Write-Host "Übersprungen." -ForegroundColor Gray
            Write-Host ""
            continue
        }
        
        # Save the mapping
        $pattern = $data.payee.ToLower().Trim()
        Save-CategoryMapping -pattern $pattern -category $category -payee $data.payee -memo $data.memo
        $categorized++
        
        Write-Host "✅ Gespeichert: '$($data.payee)' -> '$category'" -ForegroundColor Green
        Write-Host ""
    }
    
    Write-Host ""
    Write-Host "🎯 SCANNER-ZUSAMMENFASSUNG" -ForegroundColor Cyan
    Write-Host "Verarbeitet: $processed" -ForegroundColor White
    Write-Host "Kategorisiert: $categorized" -ForegroundColor Green
    Write-Host "Übersprungen: $skipped" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Die neuen Kategorie-Zuordnungen werden beim nächsten normalen Lauf verwendet." -ForegroundColor White
    Write-Host ""
}

function Get-AutoCategory {
    param(
        [string]$payee, 
        [string]$memo, 
        [decimal]$amount
    )
    
    $text = "$payee $memo".ToLower()
    
    # Check custom category mappings first
    $customCategory = Get-CategoryMapping -text $text -amount $amount
    if ($customCategory) {
        return $customCategory
    }
    
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
            return $global:i18n.Get("categories.tax_refunds")
        }
        
        # Cash deposits
        $patterns = $categorizationPatterns.income.cashDeposits
        if ($patterns -and (Test-PatternMatch $text $patterns)) {
            return $global:i18n.Get("categories.cash_deposits")
        }
        
        # Capital gains
        $patterns = $categorizationPatterns.income.capitalGains
        if ($patterns -and (Test-PatternMatch $text $patterns)) {
            return $global:i18n.Get("categories.capital_gains")
        }
        
        # General income
        $patterns = $categorizationPatterns.income.generalIncome
        if ($patterns -and (Test-PatternMatch $text $patterns)) {
            return $global:i18n.Get("categories.income")
        }
        
        # Other income (for larger amounts)
        if ($amount -gt 50 -and ($text -match "gutschrift|eingang|erstattung|rueckzahlung|bonus|praemie|refund|bonus|premium")) {
            return $global:i18n.Get("categories.other_income")
        }
    }
    
    # EXPENSES - Configuration-based categorization with localized names
    $expenseCategories = @(
        @{patterns = $categorizationPatterns.expenses.groceries; category = $global:i18n.Get("categories.groceries")},
        @{patterns = $categorizationPatterns.expenses.fuel; category = $global:i18n.Get("categories.fuel")},
        @{patterns = $categorizationPatterns.expenses.housing; category = $global:i18n.Get("categories.housing")},
        @{patterns = $categorizationPatterns.expenses.insurance; category = $global:i18n.Get("categories.insurance")},
        @{patterns = $categorizationPatterns.expenses.internetPhone; category = $global:i18n.Get("categories.internet_phone")},
        @{patterns = $categorizationPatterns.expenses.publicTransport; category = $global:i18n.Get("categories.public_transport")},
        @{patterns = $categorizationPatterns.expenses.pharmacy; category = $global:i18n.Get("categories.pharmacy_health")},
        @{patterns = $categorizationPatterns.expenses.restaurants; category = $global:i18n.Get("categories.restaurants")},
        @{patterns = $categorizationPatterns.expenses.onlineShopping; category = $global:i18n.Get("categories.online_shopping")},
        @{patterns = $categorizationPatterns.expenses.electronics; category = $global:i18n.Get("categories.electronics")},
        @{patterns = $categorizationPatterns.expenses.streaming; category = $global:i18n.Get("categories.streaming")},
        @{patterns = $categorizationPatterns.expenses.bankFees; category = $global:i18n.Get("categories.bank_fees")},
        @{patterns = $categorizationPatterns.expenses.taxes; category = $global:i18n.Get("categories.taxes")},
        @{patterns = $categorizationPatterns.expenses.health; category = $global:i18n.Get("categories.health")},
        @{patterns = $categorizationPatterns.expenses.donations; category = $global:i18n.Get("categories.donations")},
        @{patterns = $categorizationPatterns.expenses.memberships; category = $global:i18n.Get("categories.memberships")},
        @{patterns = $categorizationPatterns.expenses.education; category = $global:i18n.Get("categories.education")},
        @{patterns = $categorizationPatterns.expenses.clothing; category = $global:i18n.Get("categories.clothing")},
        @{patterns = $categorizationPatterns.expenses.entertainment; category = $global:i18n.Get("categories.entertainment")},
        @{patterns = $categorizationPatterns.expenses.consulting; category = $global:i18n.Get("categories.consulting_legal")},
        @{patterns = $categorizationPatterns.expenses.taxi; category = $global:i18n.Get("categories.taxi_ridesharing")}
    )
    
    foreach ($expenseCategory in $expenseCategories) {
        if ($expenseCategory.patterns -and (Test-PatternMatch $text $expenseCategory.patterns)) {
            return $expenseCategory.category
        }
    }
    
    return ""
}

function Get-UniqueTransferName {
    param(
        [string]$accountName,
        [string]$payee,
        [string]$currentAccount = ""
    )
    
    # Clean up account name  
    $cleanAccountName = $accountName -replace "Geschäftsanteil$", "Geschäftsanteile"
    
    # Account names should already be unique from configuration, but add person name as backup for generic names
    if ($cleanAccountName -match "Geschäftsanteile$" -and $payee) {
        # Extract person name from payee dynamically (using Unicode categories for broader compatibility)
        if ($payee -match "([A-Za-z\p{L}]+),?\s*([A-Za-z\p{L}]+)") {
            # Format: "LastName, FirstName" or "LastName,FirstName"
            $firstName = $matches[2]
            return "$cleanAccountName ($firstName)"
        } elseif ($payee -match "([A-Za-z\p{L}]+)\s+([A-Za-z\p{L}]+)") {
            # Format: "FirstName LastName"
            $firstName = $matches[1]
            return "$cleanAccountName ($firstName)"
        } elseif ($payee -match "([A-Za-z\p{L}]+)") {
            # Single name
            $name = $matches[1]
            return "$cleanAccountName ($name)"
        }
    }
    
    # For other accounts, extract any person name from payee for disambiguation
    if ($payee -and $payee -match "([A-Za-z\p{L}]{3,})" -and $cleanAccountName -notmatch "([A-Za-z\p{L}]{3,})") {
        $personName = $matches[1]
        # Only add if it looks like a person name (not a bank/company name)
        if ($personName -notmatch "(Bank|AG|GmbH|eG|Kredit|Konto|Spar)") {
            return "$cleanAccountName ($personName)"
        }
    }
    
    return $cleanAccountName
}

function Get-TransferCategory {
    param(
        [string]$payee, 
        [string]$memo, 
        [decimal]$amount,
        [string]$targetIBAN = "",
        [string]$currentAccount = ""
    )
    
    $payeeLower = $payee.ToLower()
    $notesLower = $memo.ToLower()
    
    # IBAN-based transfer recognition (main logic)
    if ($targetIBAN -and $OwnIBANs.ContainsKey($targetIBAN)) {
        $targetAccountName = $OwnIBANs[$targetIBAN]
        
        # Create unique transfer names by combining account name with payee for disambiguation
        $uniqueTargetName = Get-UniqueTransferName -accountName $targetAccountName -payee $payee -currentAccount $currentAccount
        
        if ($amount -gt 0) {
            return "Transfer von $uniqueTargetName"
        } else {
            return "Transfer nach $uniqueTargetName"
        }
    }
    
    # Fallback: Household keywords
    $householdPatterns = $categorizationPatterns.transfers.householdKeywords
    if ($householdPatterns -and ((Test-PatternMatch $notesLower $householdPatterns) -or (Test-PatternMatch $payeeLower $householdPatterns))) {
        return $global:i18n.Get("categories.transfer_household_contribution")
    }
    
    # Fallback: General transfer recognition
    $transferPatterns = $categorizationPatterns.transfers.transferKeywords
    $minAmount = $categorizationPatterns.transfers.minTransferAmount
    if ($transferPatterns -and (Test-PatternMatch $notesLower $transferPatterns) -and $amount -gt $minAmount) {
        return $global:i18n.Get("categories.internal_transfer")
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
    
    # Handle Geschäftsanteil files specially
    if ($cleanName -match "(.+?)\s+Geschäftsanteil(?:\s+Genossenschaft)?") {
        return $matches[1] + " Geschäftsanteile"
    }
    
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
        $transactionCount = if ($csvData) { $csvData.Count } else { 0 }
        Write-LogOnly "Processing: $fileName - Transactions: $transactionCount"
        
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
                    
                    # Try multiple credit card transaction patterns
                    $extractedPayee = $null
                    
                    # Pattern 1: "MERCHANT NAME DEU City EUR Amount ..." or "MERCHANT NAME DEU City 123456 Date"
                    if ($purpose -match '^([A-Za-z0-9\s\*\.\-]+?)\s+DEU(?:\s+[A-Z]+|\s+\d|\s+EUR|\s*$)') {
                        $extractedPayee = $matches[1].Trim()
                        Write-LogOnly "Credit card pattern 1 matched: '$extractedPayee' from '$purpose'" "DEBUG"
                    }
                    # Pattern 2: "MERCHANT NAME CITY 123456 2024-01-15T14:30:00"
                    elseif ($purpose -match '^([A-Z][A-Z\s\d\.\-]+?)\s+[A-Z]+\s+\d{4,6}\s+\d{4}-\d{2}-\d{2}T') {
                        $extractedPayee = $matches[1].Trim()
                        Write-LogOnly "Credit card pattern 2 matched: '$extractedPayee' from '$purpose'" "DEBUG"
                    }
                    # Pattern 3: "MERCHANT-NAME*CITY*COUNTRY" or "AMAZON MARKETPLACE*TECH STORE"
                    elseif ($purpose -match '^([A-Z][A-Z\d\s\-\*]+?)\*[A-Z\s]+\*(?:[A-Z]{2,3}|[A-Z\s]+)') {
                        $extractedPayee = $matches[1].Trim()
                        $extractedPayee = $extractedPayee -replace '\*$', ''  # Remove trailing asterisk
                        Write-LogOnly "Credit card pattern 3 matched: '$extractedPayee' from '$purpose'" "DEBUG"
                    }
                    # Pattern 4: "PP*PAYPAL MERCHANT*ITEM" (PayPal transactions)
                    elseif ($purpose -match '^PP\*PAYPAL\s+(.+?)(?:\*|$)') {
                        $extractedPayee = $matches[1].Trim()
                        Write-LogOnly "Credit card pattern 4 (PayPal) matched: '$extractedPayee' from '$purpose'" "DEBUG"
                    }
                    # Pattern 5: "NETFLIX.COM*DESCRIPTION" or "SPOTIFY*DESCRIPTION"
                    elseif ($purpose -match '^([A-Z][A-Z\d\.]+)\*') {
                        $extractedPayee = $matches[1].Trim()
                        Write-LogOnly "Credit card pattern 5 (streaming) matched: '$extractedPayee' from '$purpose'" "DEBUG"
                    }
                    # Pattern 6: "KAUF DATE TIME MERCHANT" (German card transactions)
                    elseif ($purpose -match '^KAUF\s+\d{2}\.\d{2}\.\d{4}\s+\d{2}:\d{2}\s+(.+?)(?:\s+[A-Z]{2,3}|$)') {
                        $extractedPayee = $matches[1].Trim()
                        Write-LogOnly "Credit card pattern 6 (KAUF) matched: '$extractedPayee' from '$purpose'" "DEBUG"
                    }
                    # Pattern 7: "Kartenzahlung MERCHANT NAME" 
                    elseif ($purpose -match 'Kartenzahlung\s+(.+?)(?:\s+\d{4}-\d{2}-\d{2}|\s+[A-Z]{2,3}\s+\d|\s+#\d|$)') {
                        $extractedPayee = $matches[1].Trim()
                        Write-LogOnly "Credit card pattern 7 (Kartenzahlung) matched: '$extractedPayee' from '$purpose'" "DEBUG"
                    }
                    # Pattern 8: "MERCHANT #1234 CITY" (restaurant/retail with location number)
                    elseif ($purpose -match '^([A-Z][A-Z\s]+?)\s+#\d+\s+[A-Z]+') {
                        $extractedPayee = $matches[1].Trim()
                        Write-LogOnly "Credit card pattern 8 (location #) matched: '$extractedPayee' from '$purpose'" "DEBUG"
                    }
                    # Pattern 9: First meaningful word(s) before numbers/dates/special chars (fallback)
                    elseif ($purpose -match '^([A-Za-z][A-Za-z\s\.\-]{2,25}?)(?:\s+\d|\s+[A-Z]{3}\s+\d|\*|$)') {
                        $extractedPayee = $matches[1].Trim()
                        Write-LogOnly "Credit card pattern 9 (fallback) matched: '$extractedPayee' from '$purpose'" "DEBUG"
                    }
                    
                    if ($extractedPayee) {
                        # Clean up common patterns and normalize
                        $extractedPayee = $extractedPayee -replace '\s+', ' '  # Normalize spaces
                        $extractedPayee = $extractedPayee -replace '^\*', ''   # Remove leading asterisk
                        $extractedPayee = $extractedPayee -replace '\*$', ''   # Remove trailing asterisk
                        $extractedPayee = $extractedPayee -replace '^KAUF\s+', ''  # Remove "KAUF " prefix
                        $extractedPayee = $extractedPayee -replace '\s+DEU$', ''   # Remove trailing "DEU"
                        $extractedPayee = $extractedPayee -replace '\s+MARKT$', ' MARKT'  # Normalize "MARKT"
                        $extractedPayee = $extractedPayee -replace '\s+TANKSTELLE$', ' TANKSTELLE'  # Normalize "TANKSTELLE"
                        
                        # Convert common merchant formats to more readable names
                        if ($extractedPayee -match '^EDEKA') { $extractedPayee = "EDEKA" }
                        elseif ($extractedPayee -match '^REWE') { $extractedPayee = "REWE" }
                        elseif ($extractedPayee -match '^AMAZON') { $extractedPayee = "Amazon" }
                        elseif ($extractedPayee -match '^SPOTIFY') { $extractedPayee = "Spotify" }
                        elseif ($extractedPayee -match '^NETFLIX') { $extractedPayee = "Netflix" }
                        elseif ($extractedPayee -match '^SHELL') { $extractedPayee = "Shell" }
                        elseif ($extractedPayee -match '^BURGER KING') { $extractedPayee = "Burger King" }
                        elseif ($extractedPayee -match '^MEDIA MARKT') { $extractedPayee = "Media Markt" }
                        elseif ($extractedPayee -match '^ZARA') { $extractedPayee = "Zara" }
                        
                        $payee = $extractedPayee.Trim()
                        Write-LogOnly "Final extracted payee: '$payee'" "DEBUG"
                    }
                }
            }
            
            # Final fallback: use Verwendungszweck as payee if still empty
            if (-not $payee -or $payee -eq '') {
                if ($purposeColumn -and $row.$purposeColumn) {
                    $purpose = $row.$purposeColumn.Trim()
                    # Take first 30 chars and clean it up
                    $payee = $purpose.Substring(0, [Math]::Min($purpose.Length, 30))
                    $payee = $payee -replace '[^\w\s\.\-]', ' '  # Replace special chars with spaces
                    $payee = $payee -replace '\s+', ' '         # Normalize spaces
                    $payee = $payee.Trim()
                }
            }
            
            # Notes zusammenfuegen - using dynamic column mapping with intelligent truncation
            $notes = ''
            if ($purposeColumn -and $row.$purposeColumn) {
                $fullPurpose = $row.$purposeColumn.Trim()
                # Intelligent truncation for credit card and common transactions
                $notes += Get-TruncatedPurpose -purpose $fullPurpose
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
            $transferCategory = Get-TransferCategory -payee $payee -memo $notes -amount $amount -targetIBAN $targetIBAN -currentAccount $accountName
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

# Check if category scanner mode is enabled
if ($ScanCategories) {
    Start-CategoryScanner
    Save-LogFile
    exit 0
}

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
    
    # PowerShell 5.1 compatibility: Handle single objects vs arrays  
    $processedCount = if ($processedData -is [array]) { $processedData.Count } elseif ($processedData) { 1 } else { 0 }
    
    # Statistiken aktualisieren
    $totalTransactions += $processedCount
    $transfersInFile = ($processedData | Where-Object { $_.category -match "Transfer" }).Count
    $categorizedInFile = ($processedData | Where-Object { $_.category -and $_.category -ne "" }).Count
    $totalTransfers += $transfersInFile
    $totalCategorized += $categorizedInFile
    
    
    # File stats sammeln - auch für Dateien ohne verarbeitete Transaktionen
    $fileStats += [PSCustomObject]@{
        Datei = ($file.BaseName -replace ' seit .*', '')
        Buchungen = $processedCount
        Transfers = $transfersInFile
        Kategorisiert = $categorizedInFile
        Rate = if ($processedCount -gt 0) { [math]::Round(($categorizedInFile / $processedCount) * 100, 1) } else { 0 }
    }
    
    if ($processedCount -gt 0) {
        
        # Output-Datei speichern (nicht im Dry-Run)
        $outputFile = Join-Path $OutputDir "$($file.BaseName).csv"
        
        if (-not $isDryRun) {
            $outputDelimiter = $csvSettings.outputDelimiter
            $processedData | Export-Csv -Path $outputFile -NoTypeInformation -Delimiter $outputDelimiter -Encoding UTF8
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
    # ==========================================
    # STARTING BALANCE DATE SELECTION
    # ==========================================
    
    $selectedStartingDate = $null
    
    # Check if user provided date via parameter
    if ($StartingDate) {
        try {
            $selectedStartingDate = [DateTime]::ParseExact($StartingDate, "dd.MM.yyyy", $null)
            Write-LogOnly "Using starting balance date from parameter: $StartingDate" "INFO"
        } catch {
            Write-Log "Invalid starting date format '$StartingDate'. Expected format: DD.MM.YYYY" "WARNING"
            $selectedStartingDate = $null
        }
    }
    
    # Check configuration for fixed date or ask setting
    if (-not $selectedStartingDate) {
        $configDate = $global:config.Get("defaults.startingBalanceDate")
        $askForDate = $AskStartingDate -or $global:config.Get("defaults.askForStartingDate")
        
        if ($configDate) {
            try {
                $selectedStartingDate = [DateTime]::ParseExact($configDate, "dd.MM.yyyy", $null)
                Write-LogOnly "Using starting balance date from config: $configDate" "INFO"
            } catch {
                Write-Log "Invalid starting date in config '$configDate'. Using automatic detection." "WARNING"
            }
        }
        
        # Ask user for starting date if configured or parameter was set
        if ((-not $selectedStartingDate) -and $askForDate -and (-not $isSilent)) {
            Write-Host ""
            Write-Host (t "balance.starting_date_selection") -ForegroundColor Yellow
            Write-Host (t "balance.starting_date_desc") -ForegroundColor White
            Write-Host ""
            
            do {
                $input = Read-Host (t "balance.starting_date_prompt")
                if ($input -eq "") {
                    Write-Host (t "balance.using_automatic_detection") -ForegroundColor Cyan
                    break
                }
                
                try {
                    $selectedStartingDate = [DateTime]::ParseExact($input, "dd.MM.yyyy", $null)
                    Write-Host (t "balance.starting_date_confirmed" @($input)) -ForegroundColor Green
                    break
                } catch {
                    Write-Host (t "balance.invalid_date_format") -ForegroundColor Red
                }
            } while ($true)
        }
    }
    
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
            
            # PowerShell 5.1 compatibility: Handle single objects vs arrays
            $csvCount = if ($csvData -is [array]) { $csvData.Count } elseif ($csvData) { 1 } else { 0 }
            if ($csvCount -gt 0) {
                # Get entry for starting balance calculation
                $firstEntry = $null
                
                if ($selectedStartingDate) {
                    # Use specific date for starting balance
                    $targetEntries = $csvData | Where-Object {
                        try {
                            if ($_.PSObject.Properties.Name -contains "Buchungstag") {
                                $entryDate = [DateTime]::ParseExact($_."Buchungstag", "dd.MM.yyyy", $null)
                                return $entryDate -eq $selectedStartingDate
                            }
                        } catch { }
                        return $false
                    }
                    
                    if ($targetEntries) {
                        $firstEntry = $targetEntries | Select-Object -First 1
                        Write-LogOnly "Using entry from selected date $($selectedStartingDate.ToString('dd.MM.yyyy')) for $fileName" "INFO"
                    } else {
                        # Find closest entry before the selected date
                        $closestEntry = $csvData | Where-Object {
                            try {
                                if ($_.PSObject.Properties.Name -contains "Buchungstag") {
                                    $entryDate = [DateTime]::ParseExact($_."Buchungstag", "dd.MM.yyyy", $null)
                                    return $entryDate -le $selectedStartingDate
                                }
                            } catch { }
                            return $false
                        } | Sort-Object {
                            try {
                                [DateTime]::ParseExact($_."Buchungstag", "dd.MM.yyyy", $null)
                            } catch {
                                [DateTime]::MinValue
                            }
                        } -Descending | Select-Object -First 1
                        
                        if ($closestEntry) {
                            $firstEntry = $closestEntry
                            $closestDate = $closestEntry."Buchungstag"
                            Write-LogOnly "No entry found for $($selectedStartingDate.ToString('dd.MM.yyyy')), using closest entry from $closestDate for $fileName" "INFO"
                        } else {
                            Write-LogOnly "No suitable entry found for selected starting date for $fileName" "WARNING"
                        }
                    }
                } else {
                    # Automatic detection: use oldest entry
                    # PowerShell 5.1 compatibility: Handle single object vs array
                    if ($csvCount -eq 1 -and $csvData -isnot [array]) {
                        $firstEntry = $csvData
                    } else {
                        $firstEntry = $csvData | Sort-Object {
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
                        # Calculate starting balance correctly:
                        # Starting balance = Balance after transaction - Transaction amount
                        # This gives us the account balance BEFORE this (oldest) transaction
                        if ($amount -eq 0) {
                            # For zero-amount entries (like initial balance entries), use balance directly
                            $startingBalance = $balanceAfter
                        } else {
                            # For normal transactions: Starting balance = Balance after - Transaction amount
                            $startingBalance = $balanceAfter - $amount
                        }
                        
                        # Derive account name from filename
                        $accountName = $fileName
                        if ($fileName -match "(.+?)(?:\s+seit|\s+Kontoauszug|\s+Export)") {
                            $accountName = $matches[1]
                        }
                        # Also handle Geschäftsanteil files specially
                        if ($fileName -match "(.+?)\s+Geschäftsanteil(?:\s+Genossenschaft)?") {
                            $accountName = $matches[1] + " Geschäftsanteile"
                        }
                        
                        
                        $accountBalances[$accountName] = @{
                            balance = $startingBalance
                            date = if ($firstEntry.PSObject.Properties.Name -contains "Buchungstag") { $firstEntry."Buchungstag" } else { 'Unknown' }
                            file = $fileName
                        }
                        
                        
                        # Store for summary display later
                        Write-LogOnly "Calculated starting balance for $accountName`: $($startingBalance.ToString('N2')) $currency" "INFO"
                        
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
        Write-Host ($global:i18n.Get("balance.missing_balances_title")) -ForegroundColor Yellow
        Write-Host ($global:i18n.Get("balance.missing_balances_desc")) -ForegroundColor White
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
                $input = Read-Host ($global:i18n.Get("balance.manual_input_prompt", @($currency)))
                if ($input -eq "") {
                    Write-Host ($global:i18n.Get("balance.skipping_account")) -ForegroundColor Gray
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
                    
                    Write-Host ($global:i18n.Get("balance.manual_balance_added", @($cleanAccountName, $manualBalance, $currency))) -ForegroundColor Green
                    Write-Log ($global:i18n.Get("balance.starting_balance", @($cleanAccountName, $manualBalance, $currency))) "INFO"
                    break
                } catch {
                    Write-Host ($global:i18n.Get("balance.invalid_input")) -ForegroundColor Red
                }
            } while ($true)
            
            Write-Host ""
        }
    }
    
    # Save starting balances to actual_import directory
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
        
        $balanceFile = Join-Path $OutputDir "starting_balances.txt"
        $balanceOutput | Out-File -FilePath $balanceFile -Encoding UTF8
        
        $relativeBalanceFile = $balanceFile -replace [regex]::Escape($PSScriptRoot + [System.IO.Path]::DirectorySeparatorChar), ""
        Write-LogOnly "Starting balances saved to: $relativeBalanceFile" "INFO"
        
        # Display formatted starting balance summary
        if (-not $isSilent) {
            Write-Host ""
            $sortedAccounts = $accountBalances.GetEnumerator() | Sort-Object Name
            $totalBalance = 0
            
            foreach ($account in $sortedAccounts) {
                $name = $account.Key
                $data = $account.Value
                $balance = $data.balance
                $totalBalance += $balance
                
                $balanceStr = $balance.ToString('N2')
                $displayMessage = $global:i18n.Get("balance.starting_balance_for", @($name, $balanceStr))
                Write-Host $displayMessage -ForegroundColor White
            }
            
            # Show summary statistics
            Write-Host ("-" * 60) -ForegroundColor Gray
            $totalBalanceStr = $totalBalance.ToString('N2')
            $totalMessage = $global:i18n.Get("balance.total_accounts_balance", @($accountBalances.Count, $totalBalanceStr))
            Write-Host $totalMessage -ForegroundColor Cyan
        } else {
            $totalBalanceStr = $totalBalance.ToString('N2')
            $totalMessage = $global:i18n.Get("balance.total_accounts_balance", @($accountBalances.Count, $totalBalanceStr))
            Write-LogOnly $totalMessage "INFO"
        }
    } else {
        Write-Log "No starting balances could be calculated" "WARNING"
    }
}

# ==========================================
# CREATE DYNAMIC CATEGORIES LIST
# ==========================================

if (-not $isDryRun) {
    # Collect all categories actually used across all processed CSV files
    $allUsedCategories = @{}
    
    foreach ($file in $csvFiles) {
        $processedData = Process-BankCSV -FilePath $file.FullName
        
        # PowerShell 5.1 compatibility: Handle single objects vs arrays
        $processedCount = if ($processedData -is [array]) { $processedData.Count } elseif ($processedData) { 1 } else { 0 }
        
        if ($processedCount -gt 0) {
            foreach ($row in $processedData) {
                if ($row.category -and $row.category.Trim() -ne "") {
                    $category = $row.category.Trim()
                    if (-not $allUsedCategories.ContainsKey($category)) {
                        $allUsedCategories[$category] = 0
                    }
                    $allUsedCategories[$category]++
                }
            }
        }
    }
    
    # Categorize the found categories
    $transferCategories = @()
    $incomeCategories = @()
    $expenseCategories = @()
    
    foreach ($category in $allUsedCategories.Keys | Sort-Object) {
        if ($category -match "Transfer") {
            $transferCategories += $category
        } elseif ($category -match "Income|Refund|Deposit|Gains|Einkommen|Kapitalerträge|Steuer.*Rückerstattung|Bareinzahlung") {
            $incomeCategories += $category
        } else {
            $expenseCategories += $category
        }
    }
    
    # Create dynamic categories list
    $categoriesFile = Join-Path $OutputDir "KATEGORIEN_LISTE.txt"
    $categoriesContent = @()
    $categoriesContent += (t "processor.categories_file_header")
    $categoriesContent += (t "processor.categories_file_separator")
    $categoriesContent += (t "processor.categories_file_intro")
    $categoriesContent += (t "processor.categories_file_instruction")
    $categoriesContent += ""
    $categoriesContent += "# " + (t "processor.categories_generated_note")
    $categoriesContent += "# Anzahl verwendeter Kategorien: $($allUsedCategories.Count)"
    $categoriesContent += "# Gesamtverwendungen: $(($allUsedCategories.Values | Measure-Object -Sum).Sum)"
    $categoriesContent += ""
    
    # Transfer categories (dynamically found)
    if ($transferCategories.Count -gt 0) {
        $categoriesContent += (t "processor.categories_transfer")
        foreach ($category in $transferCategories) {
            $usageCount = $allUsedCategories[$category]
            $categoriesContent += "- $category ($usageCount Verwendungen)"
        }
        $categoriesContent += ""
    }
    
    # Income categories (dynamically found)
    if ($incomeCategories.Count -gt 0) {
        $categoriesContent += (t "processor.categories_income")
        foreach ($category in $incomeCategories) {
            $usageCount = $allUsedCategories[$category]
            $categoriesContent += "- $category ($usageCount Verwendungen)"
        }
        $categoriesContent += ""
    }
    
    # Expense categories (dynamically found)
    if ($expenseCategories.Count -gt 0) {
        $categoriesContent += (t "processor.categories_expense")
        foreach ($category in $expenseCategories) {
            $usageCount = $allUsedCategories[$category]
            $categoriesContent += "- $category ($usageCount Verwendungen)"
        }
        $categoriesContent += ""
    }
    
    $categoriesContent += (t "processor.categories_instructions")
    $categoriesContent += (t "processor.categories_step1")
    $categoriesContent += (t "processor.categories_step2")
    $categoriesContent += (t "processor.categories_step3")
    $categoriesContent += (t "processor.categories_step4")
    
    [System.IO.File]::WriteAllLines($categoriesFile, $categoriesContent, [System.Text.Encoding]::UTF8)
    $relativeCategoriesFile = $categoriesFile -replace [regex]::Escape($PSScriptRoot + [System.IO.Path]::DirectorySeparatorChar), ""
    Write-Log ("Dynamische Kategorien-Liste erstellt:`n$relativeCategoriesFile ($(($allUsedCategories.Keys | Measure-Object).Count) Kategorien)") "INFO"
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
    # Show quick access links to important files
    if (-not $isDryRun) {
        Write-Host ""
        Write-Host (t "processor.quick_access") -ForegroundColor Cyan
        
        $actualImportPath = (Resolve-Path "actual_import").Path
        $categoriesFile = Join-Path $actualImportPath "KATEGORIEN_LISTE.txt"
        $latestBalanceFile = Get-Item (Join-Path $OutputDir "starting_balances.txt") -ErrorAction SilentlyContinue
        
        $importFolderMessage = $global:i18n.Get("processor.open_import_folder", @($actualImportPath))
        Write-Host $importFolderMessage -ForegroundColor White
        if (Test-Path $categoriesFile) {
            $categoriesMessage = $global:i18n.Get("processor.view_categories", @($categoriesFile))
            Write-Host $categoriesMessage -ForegroundColor White
        }
        if ($latestBalanceFile) {
            $balancesMessage = $global:i18n.Get("processor.view_balances", @($latestBalanceFile.FullName))
            Write-Host $balancesMessage -ForegroundColor White
        }
        Write-Host (t "processor.click_to_open") -ForegroundColor Gray
        Write-Host ""
    }
    
    Write-Host (t "processor.completed") -ForegroundColor Green
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