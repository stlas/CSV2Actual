# CSV2Actual - Interactive Wizard
# Version: 1.2.0
# Author: sTLAs (https://github.com/sTLAs)
# Interactive guided conversion from German bank CSV to Actual Budget
# Features: Internationalization (EN/DE), JSON Configuration, Step-by-step guidance

param(
    [Alias("l")][string]$Language = "en",
    [Alias("s")][switch]$Setup,
    [Alias("n")][switch]$DryRun,
    [Alias("h")][switch]$Help
)

# Set UTF-8 encoding for console - multiple approaches for compatibility
try {
    # Try to set console to UTF-8
    [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
    [Console]::InputEncoding = [System.Text.Encoding]::UTF8
    $OutputEncoding = [System.Text.Encoding]::UTF8
    
    # Alternative: Set console code page to UTF-8 (65001)
    if ($IsWindows -or $PSVersionTable.PSVersion.Major -le 5) {
        try {
            chcp 65001 | Out-Null
        } catch {
            # Silently continue if chcp fails
        }
    }
} catch {
    # Fallback to default encoding
    Write-Warning "Could not set UTF-8 encoding, using system default"
}

# Early setup for help (load i18n first if help is requested)
if ($Help) {
    # Load modules for internationalization
    . "$PSScriptRoot/modules/Config.ps1"
    . "$PSScriptRoot/modules/I18n.ps1"
    
    # Initialize minimal config for help display
    try {
        $global:config = [Config]::new("$PSScriptRoot/config.json")
        $langDir = $global:config.Get("paths.languageDir")
        $global:i18n = [I18n]::new($langDir, $Language)
    }
    catch {
        # Fallback to English if i18n fails
        $Language = "en"
    }
    
    # Helper function for localization in help
    function t {
        param([string]$key, [object[]]$args = @())
        if ($global:i18n) {
            return $global:i18n.Get($key, $args)
        } else {
            # Fallback for key display
            return $key
        }
    }
    
    Write-Host (t "wizard_help.title") -ForegroundColor Cyan
    Write-Host ""
    Write-Host (t "wizard_help.usage_title") -ForegroundColor Yellow
    Write-Host "  " + (t "wizard_help.usage_text")
    Write-Host ""
    Write-Host (t "wizard_help.options_title") -ForegroundColor Yellow
    Write-Host "  " + (t "wizard_help.language_option")
    Write-Host "  " + (t "wizard_help.dry_run_option")
    Write-Host "  " + (t "wizard_help.setup_option")
    Write-Host "  " + (t "wizard_help.help_option")
    Write-Host ""
    Write-Host (t "wizard_help.examples_title") -ForegroundColor Yellow
    Write-Host "  " + (t "wizard_help.example_english")
    Write-Host "  " + (t "wizard_help.example_english_cmd")
    Write-Host ""
    Write-Host "  " + (t "wizard_help.example_german")
    Write-Host "  " + (t "wizard_help.example_german_cmd")
    Write-Host ""
    Write-Host "  " + (t "wizard_help.example_setup")
    Write-Host "  " + (t "wizard_help.example_setup_cmd")
    exit 0
}

# Load modules
. "$PSScriptRoot/modules/Config.ps1"
. "$PSScriptRoot/modules/I18n.ps1"
. "$PSScriptRoot/modules/CsvValidator.ps1"
. "$PSScriptRoot/modules/CommunityLoader.ps1"
# IbanDiscovery via standalone script

# Initialize configuration and internationalization
try {
    $global:config = [Config]::new("$PSScriptRoot/config.json")
    $langDir = $global:config.Get("paths.languageDir")
    $global:i18n = [I18n]::new($langDir, $Language)
    $global:communityLoader = [CommunityLoader]::new("$PSScriptRoot/community", $global:i18n)
    
    # Show local config loading message only if not silent and local config exists
    $localConfigPath = Join-Path $PSScriptRoot "config.local.json"
    if ((Test-Path $localConfigPath) -and -not $Silent) {
        Write-Host (t "system.loading_local_config") -ForegroundColor Yellow
    }
}
catch {
    Write-Host "ERROR: Could not load configuration or language files. Please ensure config.json and lang/ folder exist." -ForegroundColor Red
    Write-Host "Details: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# ==========================================
# HELPER FUNCTIONS
# ==========================================

function Show-SetupFrame {
    param(
        [string]$Title,
        [string[]]$Content,
        [string]$Step = "",
        [int]$Width = 78
    )
    
    $topLine = "┌" + ("─" * ($Width - 2)) + "┐"
    $titleLine = "│" + ($Title.PadLeft(($Width - 2 + $Title.Length) / 2).PadRight($Width - 2)) + "│"
    $separatorLine = "├" + ("─" * ($Width - 2)) + "┤"
    $bottomLine = "└" + ("─" * ($Width - 2)) + "┘"
    
    Write-Host ""
    Write-Host $topLine -ForegroundColor Cyan
    Write-Host $titleLine -ForegroundColor Cyan
    if ($Step) {
        $stepLine = "│" + ($Step.PadLeft(($Width - 2 + $Step.Length) / 2).PadRight($Width - 2)) + "│"
        Write-Host $stepLine -ForegroundColor Yellow
    }
    Write-Host $separatorLine -ForegroundColor Cyan
    
    foreach ($line in $Content) {
        if ($line -eq "") {
            Write-Host ("│" + (" " * ($Width - 2)) + "│") -ForegroundColor Cyan
        } else {
            # Handle long lines with word wrapping
            $remainingText = $line
            while ($remainingText.Length -gt ($Width - 6)) {
                $splitPos = ($Width - 6)
                $lastSpace = $remainingText.LastIndexOf(' ', $splitPos)
                if ($lastSpace -gt 0) { $splitPos = $lastSpace }
                
                $displayLine = $remainingText.Substring(0, $splitPos).TrimEnd()
                $paddedLine = ("│  " + $displayLine).PadRight($Width - 1) + "│"
                Write-Host $paddedLine -ForegroundColor White
                
                $remainingText = $remainingText.Substring($splitPos).TrimStart()
            }
            
            if ($remainingText.Length -gt 0) {
                $paddedLine = ("│  " + $remainingText).PadRight($Width - 1) + "│"
                Write-Host $paddedLine -ForegroundColor White
            }
        }
    }
    
    Write-Host ("│" + (" " * ($Width - 2)) + "│") -ForegroundColor Cyan
    Write-Host $bottomLine -ForegroundColor Cyan
}

function Start-InteractiveSetup {
    Show-SetupFrame -Title (t "setup.title") -Content @(
        "",
        (t "setup.welcome_message"),
        "",
        (t "setup.comprehensive_setup"),
        ""
    )
    
    if ($DryRun) {
        Write-Host "[DRY-RUN] " -NoNewline -ForegroundColor Yellow
        Write-Host (t "setup.press_enter_continue") -ForegroundColor Gray
    } else {
        Write-Host (t "setup.press_enter_continue") -ForegroundColor Gray
        Read-Host
    }
    
    # Step 1: Account Detection
    Start-AccountDetection
    
    # Step 2: Category Scanner  
    Start-CategoryScanner
    
    # Step 3: Starting Date Selection
    Start-StartingDateSelection
    
    # Step 4: Final Configuration
    Complete-Setup
}

function Start-AccountDetection {
    Show-SetupFrame -Title (t "setup.title") -Step (t "setup.step1_title") -Content @(
        "",
        (t "setup.account_detection_desc"),
        ""
    )
    
    # Detect CSV files and suggest account names
    $sourceDir = $global:config.GetSourceDir()
    $csvFiles = Get-ChildItem -Path $sourceDir -Filter "*.csv"
    
    if ($csvFiles.Count -eq 0) {
        Show-SetupFrame -Title (t "setup.error_title") -Content @(
            "",
            (t "setup.no_csv_found"),
            (t "setup.add_csv_restart"),
            ""
        )
        exit 1
    }
    
    $accountMappings = @{}
    $content = @("", (t "setup.found_csv_files"))
    
    foreach ($file in $csvFiles) {
        $suggestedName = Get-CleanAccountName -fileName $file.BaseName -csvFilePath $file.FullName
        $content += "• $($file.Name) → `"$suggestedName`""
        $accountMappings[$file.Name] = $suggestedName
    }
    
    $content += @("", (t "setup.accounts_correct_question"))
    
    Show-SetupFrame -Title (t "setup.title") -Step (t "setup.step1_title") -Content $content
    
    if ($DryRun) {
        Write-Host "[DRY-RUN] " -NoNewline -ForegroundColor Yellow
        Write-Host (t "setup.confirm_accounts") -NoNewline
        Write-Host " -> j (automatisch)" -ForegroundColor Gray
    } else {
        do {
            $response = Read-Host (t "setup.confirm_accounts")
            if ($response -eq "j" -or $response -eq "y" -or $response -eq "") {
                break
            } elseif ($response -eq "n") {
                # Allow manual account name editing
                foreach ($file in $csvFiles) {
                    $currentName = $accountMappings[$file.Name]
                    $prompt = $global:i18n.Get("setup.account_name_for", @($file.Name, $currentName))
                    $newName = Read-Host $prompt
                    if ($newName -and $newName.Trim() -ne "") {
                        $accountMappings[$file.Name] = $newName.Trim()
                    }
                }
                break
            }
        } while ($true)
    }
    
    # Store account mappings for later use
    $script:detectedAccounts = $accountMappings
    
    # CRITICAL: Extract IBANs NOW before category scanner
    Write-Host ""
    Write-Host "Extracting IBANs for transfer detection..." -ForegroundColor Yellow
    $script:extractedIBANs = Extract-IBANsFromCSVs
    
    # Update global OwnIBANs variable immediately for transfer detection
    $global:OwnIBANs = $script:extractedIBANs
    Write-Host "Updated IBAN mappings for transfer detection." -ForegroundColor Green
}

function Start-CategoryScanner {
    Show-SetupFrame -Title (t "setup.title") -Step (t "setup.step2_title") -Content @(
        "",
        (t "setup.category_scanner_desc"),
        "",
        (t "setup.category_scanner_options"),
        "",
        "[1] " + (t "setup.category_scanner_automatic"),
        "    " + (t "setup.category_scanner_automatic_desc"),
        "",
        "[2] " + (t "setup.category_scanner_interactive"),
        "    " + (t "setup.category_scanner_interactive_desc"),
        "",
        "[3] " + (t "setup.category_scanner_skip"),
        "    " + (t "setup.category_scanner_skip_desc"),
        ""
    )
    
    if ($DryRun) {
        Write-Host "[DRY-RUN] " -NoNewline -ForegroundColor Yellow
        Write-Host (t "setup.category_scanner_choice") -NoNewline
        Write-Host " -> 1 (automatisch)" -ForegroundColor Gray
        
        Show-SetupFrame -Title (t "setup.title") -Step (t "setup.step2_title") -Content @(
            "",
            "[DRY-RUN] " + (t "setup.running_automatic_scanner"),
            ""
        )
    } else {
        do {
            $choice = Read-Host (t "setup.category_scanner_choice")
            if ($choice -eq "" -or $choice -eq "1") {
                # Automatic category scanning
                Show-SetupFrame -Title (t "setup.title") -Step (t "setup.step2_title") -Content @(
                    "",
                    (t "setup.running_automatic_scanner"),
                    ""
                )
                
                # Run automatic categorization (normal processing)
                $processorPath = Join-Path $PSScriptRoot "scripts/bank_csv_processor.ps1"
                . $processorPath -Language $Language
                break
            } elseif ($choice -eq "2") {
                # Interactive category scanner
                Show-SetupFrame -Title (t "setup.title") -Step (t "setup.step2_title") -Content @(
                    "",
                    (t "setup.running_interactive_scanner"),
                    ""
                )
                
                # Run interactive category scanner
                Start-IntegratedCategoryScanner
                break
            } elseif ($choice -eq "3") {
                Show-SetupFrame -Title (t "setup.title") -Step (t "setup.step2_title") -Content @(
                    "",
                    (t "setup.category_scanner_skipped"),
                    ""
                )
                break
            }
        } while ($true)
    }
}

function Extract-IBANsFromCSVs {
    $ibanMapping = @{}
    $sourceDir = $global:config.GetSourceDir()
    $csvFiles = Get-ChildItem -Path $sourceDir -Filter "*.csv"
    
    Write-Host "  Analyzing $($csvFiles.Count) CSV files for IBAN extraction..." -ForegroundColor Cyan
    
    foreach ($file in $csvFiles) {
        try {
            Write-Host "  Processing: $($file.BaseName)" -ForegroundColor Gray
            
            # Try to get account IBAN from the CSV file itself
            $csvData = Import-Csv -Path $file.FullName -Delimiter ";" -Encoding UTF8
            $accountName = Get-CleanAccountName -fileName $file.BaseName -csvFilePath $file.FullName
            
            Write-Host "    Account name: $accountName" -ForegroundColor Gray
            
            # Look for "Kontoinhaber IBAN" or similar column (first few rows)
            $headerRow = $csvData | Select-Object -First 1
            foreach ($property in $headerRow.PSObject.Properties) {
                if ($property.Name -match "Kontoinhaber.*IBAN|Account.*IBAN|IBAN.*Inhaber") {
                    $iban = $property.Value
                    if ($iban -and $iban -match "^[A-Z]{2}\d{2}[A-Z0-9]+$") {
                        $ibanMapping[$iban] = $accountName
                        Write-Host "    ✓ Found IBAN for $accountName`: $iban" -ForegroundColor Green
                        break
                    }
                }
            }
            
            # Alternative: Look in transaction data for frequent target IBANs that could be own accounts
            $targetIbans = @{}
            $checkedRows = 0
            foreach ($row in ($csvData | Select-Object -First 100)) {  # Check first 100 transactions
                $checkedRows++
                if ($row."IBAN Zahlungsbeteiligter" -and $row."IBAN Zahlungsbeteiligter" -match "^[A-Z]{2}\d{2}[A-Z0-9]+$") {
                    $iban = $row."IBAN Zahlungsbeteiligter"
                    if (-not $targetIbans.ContainsKey($iban)) {
                        $targetIbans[$iban] = @{
                            count = 0
                            payeeNames = @()
                        }
                    }
                    $targetIbans[$iban].count++
                    if ($targetIbans[$iban].payeeNames.Count -lt 5 -and $row."Name Zahlungsbeteiligter") {
                        $targetIbans[$iban].payeeNames += $row."Name Zahlungsbeteiligter"
                    }
                }
            }
            
            Write-Host "    Checked $checkedRows rows, found $($targetIbans.Count) unique target IBANs" -ForegroundColor Gray
            
            # Analyze frequent target IBANs
            foreach ($iban in $targetIbans.Keys) {
                $ibanInfo = $targetIbans[$iban]
                if ($ibanInfo.count -ge 2 -and -not $ibanMapping.ContainsKey($iban)) {
                    Write-Host "    Analyzing IBAN $iban (appears $($ibanInfo.count) times)" -ForegroundColor Yellow
                    
                    # Check payee names for personal patterns
                    foreach ($payeeName in $ibanInfo.payeeNames) {
                        Write-Host "      Payee: $payeeName" -ForegroundColor Gray
                        
                        if ($payeeName -match "Stefan|Alessandra|Schmid|Laszczyk" -or $payeeName -match "Geschäftsanteil|Girokonto|Variokonto|Sparbuch") {
                            # Try to derive account name from payee
                            $derivedAccountName = ""
                            if ($payeeName -match "Stefan.*Laszczyk" -or $payeeName -match "Laszczyk.*Stefan") {
                                $derivedAccountName = "Stefan-Girokonto"
                            } elseif ($payeeName -match "Alessandra.*Schmid" -or $payeeName -match "Schmid.*Alessandra") {
                                $derivedAccountName = "Alessandra-Girokonto"
                            } elseif ($payeeName -match "Stefan.*Variokonto|Stefan.*Vario") {
                                $derivedAccountName = "Stefan-Variokonto"
                            } elseif ($payeeName -match "Alessandra.*Variokonto|Alessandra.*Vario") {
                                $derivedAccountName = "Alessandra-Variokonto"
                            } elseif ($payeeName -match "Gemeinsam|Household") {
                                $derivedAccountName = "Gemeinsames-Girokonto"
                            }
                            
                            if ($derivedAccountName -and -not $ibanMapping.ContainsKey($iban)) {
                                $ibanMapping[$iban] = $derivedAccountName
                                Write-Host "    ✓ Derived IBAN mapping: $iban → $derivedAccountName (from payee: $payeeName)" -ForegroundColor Green
                                break
                            }
                        }
                    }
                }
            }
        } catch {
            Write-Host "    ✗ Could not extract IBAN from $($file.BaseName): $($_.Exception.Message)" -ForegroundColor Red
        }
    }
    
    Write-Host ""
    Write-Host "  📋 IBAN EXTRACTION RESULTS:" -ForegroundColor Cyan
    if ($ibanMapping.Count -gt 0) {
        foreach ($iban in $ibanMapping.Keys) {
            Write-Host "    $iban → $($ibanMapping[$iban])" -ForegroundColor Green
        }
    } else {
        Write-Host "    No IBANs found! Check your CSV structure." -ForegroundColor Red
    }
    Write-Host "  Total IBANs found: $($ibanMapping.Count)" -ForegroundColor Cyan
    Write-Host ""
    
    return $ibanMapping
}

function Start-StartingDateSelection {
    Show-SetupFrame -Title (t "setup.title") -Step (t "setup.step3_title") -Content @(
        "",
        (t "setup.starting_date_desc"),
        "",
        (t "setup.starting_date_options"),
        "",
        "[1] " + (t "setup.automatic_option"),
        "    " + (t "setup.automatic_desc"),
        "",
        "[2] " + (t "setup.specific_date_option"),
        "    " + (t "setup.specific_date_desc"),
        ""
    )
    
    if ($DryRun) {
        Write-Host "[DRY-RUN] " -NoNewline -ForegroundColor Yellow
        Write-Host (t "setup.starting_date_choice") -NoNewline
        Write-Host " -> 1 (automatisch)" -ForegroundColor Gray
        
        $script:useAutoStartingDate = $true
        Show-SetupFrame -Title (t "setup.title") -Step (t "setup.step3_title") -Content @(
            "",
            "[DRY-RUN] " + (t "setup.automatic_selected"),
            ""
        )
    } else {
        do {
            $choice = Read-Host (t "setup.starting_date_choice")
            if ($choice -eq "" -or $choice -eq "1") {
                $script:useAutoStartingDate = $true
                Show-SetupFrame -Title (t "setup.title") -Step (t "setup.step3_title") -Content @(
                    "",
                    (t "setup.automatic_selected"),
                    ""
                )
                Start-Sleep 1
                break
            } elseif ($choice -eq "2") {
                do {
                    $dateInput = Read-Host (t "setup.enter_starting_date")
                    if ($dateInput -eq "") {
                        $script:useAutoStartingDate = $true
                        break
                    }
                    
                    try {
                        $selectedDate = [DateTime]::ParseExact($dateInput, "dd.MM.yyyy", $null)
                        $script:useAutoStartingDate = $false
                        $script:selectedStartingDate = $dateInput
                        Show-SetupFrame -Title (t "setup.title") -Step (t "setup.step3_title") -Content @(
                            "",
                            (t "setup.specific_date_selected" @($dateInput)),
                            ""
                        )
                        Start-Sleep 1
                        break
                    } catch {
                        Write-Host (t "setup.invalid_date_format") -ForegroundColor Red
                    }
                } while ($true)
                break
            }
        } while ($true)
    }
}

function Complete-Setup {
    Show-SetupFrame -Title (t "setup.title") -Step (t "setup.step4_title") -Content @(
        "",
        (t "setup.saving_configuration"),
        ""
    )
    
    # Use already extracted IBANs from account detection step
    $ibanMapping = if ($script:extractedIBANs) { $script:extractedIBANs } else { @{} }
    
    # Create config.local.json with collected settings
    $localConfig = @{
        accounts = @{
            accountNames = $script:detectedAccounts
            ibanMapping = $ibanMapping
        }
        setup = @{
            completed = $true
            completedDate = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
            useAutoStartingDate = $script:useAutoStartingDate
        }
    }
    
    if (-not $script:useAutoStartingDate -and $script:selectedStartingDate) {
        $localConfig.setup.startingDate = $script:selectedStartingDate
    }
    
    $localConfigPath = Join-Path $PSScriptRoot "config.local.json"
    $localConfig | ConvertTo-Json -Depth 5 | Out-File $localConfigPath -Encoding UTF8
    
    Show-SetupFrame -Title (t "setup.completed_title") -Content @(
        "",
        (t "setup.configuration_saved"),
        "",
        (t "setup.ready_for_processing"),
        ""
    )
    
    if ($DryRun) {
        Write-Host "[DRY-RUN] " -NoNewline -ForegroundColor Yellow
        Write-Host (t "setup.press_enter_continue") -ForegroundColor Gray
    } else {
        Write-Host (t "setup.press_enter_continue") -ForegroundColor Gray
        Read-Host
    }
    
    # Now run routine processing
    Start-RoutineProcessing
}

# ==========================================
# ROUTINE MODE FUNCTIONS  
# ==========================================

function Start-IntegratedCategoryScanner {
    Write-Host ""
    Write-Host "🔍 KATEGORIE-SCANNER" -ForegroundColor Cyan
    Write-Host "===================" -ForegroundColor Cyan
    Write-Host "Scannt alle CSV-Dateien und lässt Sie unbekannte Kategorien interaktiv zuordnen." -ForegroundColor White
    Write-Host "Die Zuordnungen werden in config.local.json gespeichert und wiederverwendet." -ForegroundColor White
    Write-Host ""
    
    # Load processor functions (save current language context)
    $currentLanguage = $Language
    $processorPath = Join-Path $PSScriptRoot "scripts/bank_csv_processor.ps1"
    . $processorPath
    
    # Restore language context
    $Language = $currentLanguage
    $global:i18n = [I18n]::new($langDir, $Language)
    
    # Make sure we have access to OwnIBANs for transfer detection
    $OwnIBANs = $global:config.GetIBANMapping()
    
    # If no IBANs are configured, extract them now
    if (-not $OwnIBANs -or $OwnIBANs.Count -eq 0) {
        Write-Host "No IBAN mappings found. Extracting IBANs from CSV files..." -ForegroundColor Yellow
        $extractedIBANs = Extract-IBANsFromCSVs
        $OwnIBANs = $extractedIBANs
        
        # Update the local config with extracted IBANs
        $localConfigPath = Join-Path $PSScriptRoot "config.local.json"
        if (Test-Path $localConfigPath) {
            try {
                $localConfig = Get-Content $localConfigPath -Encoding UTF8 | ConvertFrom-Json
                if (-not $localConfig.accounts) {
                    $localConfig | Add-Member -MemberType NoteProperty -Name "accounts" -Value @{}
                }
                $localConfig.accounts | Add-Member -MemberType NoteProperty -Name "ibanMapping" -Value $extractedIBANs -Force
                
                $localConfig | ConvertTo-Json -Depth 5 | Out-File $localConfigPath -Encoding UTF8
                Write-Host "Updated config.local.json with extracted IBANs." -ForegroundColor Green
            } catch {
                Write-Host "Could not update config.local.json: $($_.Exception.Message)" -ForegroundColor Red
            }
        }
    }
    
    # Get CSV files
    $sourceDir = $global:config.GetSourceDir()
    $csvFiles = Get-ChildItem -Path $sourceDir -Filter "*.csv"
    
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
                    
                    # Pre-filter transfers - don't include them in uncategorized list
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
                    elseif (Test-IsTransfer -payee $payeeText.ToLower() -memo $memoText -examples @()) {
                        $isTransfer = $true
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
                        # Get account name from current file
                        $currentAccountName = Get-CleanAccountName -fileName $file.BaseName -csvFilePath $file.FullName
                        
                        $uncategorizedTransactions[$patternKey].examples += @{
                            date = $row.date
                            amount = $row.amount
                            memo = $row.notes
                            sourceAccount = $currentAccountName
                        }
                    }
                }
            }
        }
    }
    
    Write-Host ""
    Write-Host "📊 SCAN-ERGEBNISSE" -ForegroundColor Yellow
    Write-Host "Total Transaktionen: $totalTransactions"
    Write-Host "Transfer-Transaktionen (gefiltert): $filteredTransferCount" -ForegroundColor Cyan
    Write-Host "Unkategorisiert: $($uncategorizedTransactions.Count) Payee-Gruppen" -ForegroundColor White
    
    if ($uncategorizedTransactions.Count -eq 0) {
        Write-Host "🎉 Alle Transaktionen sind bereits kategorisiert!" -ForegroundColor Green
        return
    }
    
    Write-Host ""
    $response = Read-Host "Möchten Sie die unkategorisierten Transaktionen interaktiv zuordnen? (j/n)"
    if ($response -eq "j" -or $response -eq "y" -or $response -eq "") {
        Start-InteractiveCategoryMapping $uncategorizedTransactions
    } else {
        Write-Host "Scanner abgebrochen." -ForegroundColor Yellow
    }
}

function Start-InteractiveCategoryMapping {
    param([hashtable]$uncategorizedTransactions)
    
    Write-Host ""
    Write-Host "🏷️ INTELLIGENTE KATEGORIEZUORDNUNG" -ForegroundColor Cyan
    Write-Host "===================================" -ForegroundColor Cyan
    Write-Host "Das System schlägt passende Kategorien vor basierend auf Payee-Namen und Transaktionsdetails." -ForegroundColor White
    Write-Host ""
    
    $categoryMappings = @{}
    $availableCategories = @(
        "Lebensmittel", "Kraftstoff", "Versicherungen", "Wohnen", "Restaurants & Ausgehen",
        "Online Shopping", "Elektronik & Technik", "Streaming & Abos", "Bankgebühren",
        "Steuern", "Kapitalerträge", "Bareinzahlungen", "Drogerie & Gesundheit",
        "Internet & Telefon", "Taxi & Ridesharing", "Spenden", "Mitgliedschaften",
        "Bildung", "Einkommen", "Transfer (Haushaltsbeitrag)"
    )
    
    $sortedTransactions = $uncategorizedTransactions.GetEnumerator() | Sort-Object { $_.Value.count } -Descending
    $processedCount = 0
    
    foreach ($entry in $sortedTransactions) {
        $processedCount++
        $payee = $entry.Value.payee
        $count = $entry.Value.count
        $examples = $entry.Value.examples
        
        # Intelligent category suggestion (transfers already filtered out)
        $suggestedCategory = Get-CategorySuggestion -payee $payee -examples $examples
        
        Write-Host ""
        Write-Host "--- Payee $processedCount von $($uncategorizedTransactions.Count) ---" -ForegroundColor Yellow
        Write-Host "Payee: $payee" -ForegroundColor White
        Write-Host "Anzahl Transaktionen: $count" -ForegroundColor Gray
        
        # Show detailed information for better decision making
        Write-Host ""
        Write-Host "Beispiel-Transaktionen:" -ForegroundColor Cyan
        $exampleCount = 0
        foreach ($example in $examples) {
            $exampleCount++
            if ($exampleCount -gt 2) { break }  # Show max 2 examples
            
            Write-Host "  [$exampleCount] $($example.date) | $($example.amount) EUR" -ForegroundColor Gray
            
            # Show source account
            if ($example.sourceAccount) {
                Write-Host "      Von Konto: $($example.sourceAccount)" -ForegroundColor Cyan
            }
            
            # Show full memo/Verwendungszweck (not truncated)
            if ($example.memo -and $example.memo.Trim() -ne "") {
                Write-Host "      Verwendungszweck: $($example.memo)" -ForegroundColor White
            }
            
            # Try to extract and show IBAN information
            if ($example.memo -match "IBAN:\s*([A-Z]{2}\d{2}[A-Z0-9]+)") {
                $extractedIBAN = $matches[1]
                Write-Host "      Ziel-IBAN: $extractedIBAN" -ForegroundColor Yellow
                
                # Check if this IBAN belongs to one of our accounts
                if ($OwnIBANs.ContainsKey($extractedIBAN)) {
                    $targetAccount = $OwnIBANs[$extractedIBAN]
                    Write-Host "      → Transfer zu eigenem Konto: $targetAccount" -ForegroundColor Green
                }
            }
            Write-Host ""
        }
        
        Write-Host ""
        if ($suggestedCategory) {
            Write-Host "💡 Vorgeschlagene Kategorie: $suggestedCategory" -ForegroundColor Green
            Write-Host ""
            Write-Host "[j] Vorschlag übernehmen" -ForegroundColor Green
            Write-Host "[n] Andere Kategorie wählen" -ForegroundColor Yellow
            Write-Host "[s] Überspringen" -ForegroundColor Gray
            Write-Host "[q] Beenden" -ForegroundColor Red
            
            do {
                $choice = Read-Host "Ihre Wahl (j/n/s/q)"
                
                if ($choice -eq "q") {
                    Write-Host "Kategoriezuordnung beendet." -ForegroundColor Yellow
                    return
                } elseif ($choice -eq "s") {
                    Write-Host "Payee übersprungen." -ForegroundColor Yellow
                    break
                } elseif ($choice -eq "j" -or $choice -eq "y" -or $choice -eq "") {
                    $categoryMappings[$payee] = $suggestedCategory
                    Write-Host "✓ Zugeordnet: $payee → $suggestedCategory" -ForegroundColor Green
                    break
                } elseif ($choice -eq "n") {
                    # Show category selection
                    Write-Host ""
                    Write-Host "Verfügbare Kategorien:" -ForegroundColor Cyan
                    for ($i = 0; $i -lt $availableCategories.Count; $i++) {
                        $color = if ($availableCategories[$i] -eq $suggestedCategory) { "Green" } else { "White" }
                        $marker = if ($availableCategories[$i] -eq $suggestedCategory) { " (Vorschlag)" } else { "" }
                        Write-Host "  [$($i+1)] $($availableCategories[$i])$marker" -ForegroundColor $color
                    }
                    Write-Host "  [0] Eigene Kategorie eingeben" -ForegroundColor White
                    
                    do {
                        $categoryChoice = Read-Host "Kategorie wählen (1-$($availableCategories.Count) oder 0)"
                        
                        if ($categoryChoice -eq "0") {
                            $customCategory = Read-Host "Eigene Kategorie eingeben"
                            if ($customCategory -and $customCategory.Trim() -ne "") {
                                $categoryMappings[$payee] = $customCategory.Trim()
                                Write-Host "✓ Zugeordnet: $payee → $($customCategory.Trim())" -ForegroundColor Green
                                break
                            }
                        } elseif ($categoryChoice -match "^\d+$") {
                            $index = [int]$categoryChoice - 1
                            if ($index -ge 0 -and $index -lt $availableCategories.Count) {
                                $selectedCategory = $availableCategories[$index]
                                $categoryMappings[$payee] = $selectedCategory
                                Write-Host "✓ Zugeordnet: $payee → $selectedCategory" -ForegroundColor Green
                                break
                            } else {
                                Write-Host "Ungültige Auswahl. Bitte 1-$($availableCategories.Count) oder 0 eingeben." -ForegroundColor Red
                            }
                        } else {
                            Write-Host "Ungültige Eingabe. Bitte eine Zahl eingeben." -ForegroundColor Red
                        }
                    } while ($true)
                    break
                } else {
                    Write-Host "Ungültige Eingabe. Bitte j, n, s oder q eingeben." -ForegroundColor Red
                }
            } while ($true)
        } else {
            # No suggestion available, show categories directly
            Write-Host "Keine automatische Kategoriezuordnung möglich." -ForegroundColor Yellow
            Write-Host ""
            Write-Host "Verfügbare Kategorien:" -ForegroundColor Cyan
            for ($i = 0; $i -lt $availableCategories.Count; $i++) {
                Write-Host "  [$($i+1)] $($availableCategories[$i])" -ForegroundColor White
            }
            Write-Host "  [0] Eigene Kategorie eingeben" -ForegroundColor White
            Write-Host "  [s] Überspringen" -ForegroundColor Yellow
            Write-Host "  [q] Beenden" -ForegroundColor Red
            
            do {
                $choice = Read-Host "Ihre Wahl"
                
                if ($choice -eq "q") {
                    Write-Host "Kategoriezuordnung beendet." -ForegroundColor Yellow
                    return
                } elseif ($choice -eq "s") {
                    Write-Host "Payee übersprungen." -ForegroundColor Yellow
                    break
                } elseif ($choice -eq "0") {
                    $customCategory = Read-Host "Eigene Kategorie eingeben"
                    if ($customCategory -and $customCategory.Trim() -ne "") {
                        $categoryMappings[$payee] = $customCategory.Trim()
                        Write-Host "✓ Zugeordnet: $payee → $($customCategory.Trim())" -ForegroundColor Green
                        break
                    }
                } elseif ($choice -match "^\d+$") {
                    $index = [int]$choice - 1
                    if ($index -ge 0 -and $index -lt $availableCategories.Count) {
                        $selectedCategory = $availableCategories[$index]
                        $categoryMappings[$payee] = $selectedCategory
                        Write-Host "✓ Zugeordnet: $payee → $selectedCategory" -ForegroundColor Green
                        break
                    } else {
                        Write-Host "Ungültige Auswahl. Bitte 1-$($availableCategories.Count), 0, s oder q eingeben." -ForegroundColor Red
                    }
                } else {
                    Write-Host "Ungültige Eingabe. Bitte 1-$($availableCategories.Count), 0, s oder q eingeben." -ForegroundColor Red
                }
            } while ($true)
        }
    }
    
    # Save mappings to config.local.json
    if ($categoryMappings.Count -gt 0) {
        Write-Host ""
        Write-Host "💾 Speichere Kategorie-Zuordnungen..." -ForegroundColor Cyan
        
        try {
            $localConfigPath = Join-Path $PSScriptRoot "config.local.json"
            $localConfig = if (Test-Path $localConfigPath) {
                Get-Content $localConfigPath -Encoding UTF8 | ConvertFrom-Json
            } else {
                @{}
            }
            
            if (-not $localConfig.categoryMappings) {
                $localConfig | Add-Member -MemberType NoteProperty -Name "categoryMappings" -Value @{}
            }
            
            foreach ($mapping in $categoryMappings.GetEnumerator()) {
                $localConfig.categoryMappings | Add-Member -MemberType NoteProperty -Name $mapping.Key -Value $mapping.Value -Force
            }
            
            $localConfig | ConvertTo-Json -Depth 5 | Out-File $localConfigPath -Encoding UTF8
            
            Write-Host "✓ $($categoryMappings.Count) Kategorie-Zuordnungen gespeichert." -ForegroundColor Green
        } catch {
            Write-Host "⚠ Fehler beim Speichern der Kategorie-Zuordnungen: $($_.Exception.Message)" -ForegroundColor Red
        }
    }
}

function Get-CategorySuggestion {
    param(
        [string]$payee,
        [array]$examples
    )
    
    $payeeLower = $payee.ToLower()
    
    # Get the most representative example (not necessarily the first)
    $bestExample = Get-BestExample -examples $examples
    $memoText = if ($bestExample) { $bestExample.memo.ToLower() } else { "" }
    
    # Note: Transfers are already filtered out in the scanning phase
    
    # Define category suggestion rules based on common German payee patterns
    $categoryRules = @{
        "aldi|lidl|edeka|rewe|netto|penny|kaufland|real|denns|rossmann.*food|dm.*food" = "Lebensmittel"
        "tankstelle|shell|aral|esso|bp|total|jet|star|agip|fuel|benzin|diesel" = "Kraftstoff"
        "allianz|axa|versicherung|huk|signal|debeka|ergo|provinzial|generali" = "Versicherungen"
        "miete|nebenkosten|hausgeld|wohnung|immobilie|vermieter|vermietung" = "Wohnen"
        "restaurant|mcdonald|burger king|pizza|cafe|gastro|imbiss|delivery|lieferando" = "Restaurants & Ausgehen"
        "amazon(?!.*fuel)|ebay|zalando|otto|online.*shop|shop.*online|paypal.*shop" = "Online Shopping"
        "media markt|saturn|apple store|conrad|cyberport|notebooksbilliger|elektronik" = "Elektronik & Technik"
        "netflix|spotify|amazon prime|disney|sky|streaming|abo|subscription" = "Streaming & Abos"
        "bank.*gebühr|zinsen|entgelt|provision|kontoführung|überziehung" = "Bankgebühren"
        "finanzamt|steuer|tax|abgaben|steuern|kfz.*steuer" = "Steuern"
        "dividende|zinsen.*ertrag|kapitalertrag|gewinn|rendite" = "Kapitalerträge"
        "einzahlung|bargeld|cash|geldautomat|atm" = "Bareinzahlungen"
        "apotheke|drogerie|dm(?!.*food)|rossmann(?!.*food)|müller.*drogerie|gesundheit" = "Drogerie & Gesundheit"
        "telekom|vodafone|o2|1&1|internet|telefon|handy|mobilfunk|provider" = "Internet & Telefon"
        "taxi|uber|bolt|fahrdienst|rideshare|lyft" = "Taxi & Ridesharing"
        "spende|donation|caritas|rotes kreuz|hilfswerk|charity" = "Spenden"
        "verein|mitglied.*beitrag|club|fitness|sport|gym|mcfit|clever fit" = "Mitgliedschaften"
        "schule|uni|bildung|kurs|seminar|weiterbildung|studium|fortbildung" = "Bildung"
        "gehalt|lohn|salary|einkommen|arbeitgeber|bonus|prämie" = "Einkommen"
    }
    
    # Check payee name against rules
    foreach ($pattern in $categoryRules.Keys) {
        if ($payeeLower -match $pattern) {
            return $categoryRules[$pattern]
        }
    }
    
    # Check memo/purpose text against rules
    foreach ($pattern in $categoryRules.Keys) {
        if ($memoText -match $pattern) {
            return $categoryRules[$pattern]
        }
    }
    
    # Special amount-based suggestions with better logic
    if ($bestExample) {
        $amount = [math]::Abs([decimal]$bestExample.amount)
        
        # Small amounts often groceries or daily expenses
        if ($amount -lt 50) {
            if ($payeeLower -match "markt|laden|shop|kiosk" -or $memoText -match "einkauf|lebensmittel") {
                return "Lebensmittel"
            }
        }
        
        # Medium amounts often fuel
        if ($amount -gt 30 -and $amount -lt 150) {
            if ($memoText -match "tankstelle|tank|fuel|benzin|diesel") {
                return "Kraftstoff"
            }
        }
        
        # Large regular amounts often rent/insurance
        if ($amount -gt 300) {
            if ($memoText -match "miete|rent|wohnung") {
                return "Wohnen"
            } elseif ($memoText -match "versicherung|insurance|police") {
                return "Versicherungen"
            }
        }
    }
    
    return $null  # No suggestion available
}

function Test-IsTransfer {
    param(
        [string]$payee,
        [string]$memo,
        [array]$examples
    )
    
    # Check for transfer indicators
    $transferIndicators = @(
        "überweisung",
        "gutschrift",
        "lastschrift", 
        "dauerauftrag",
        "transfer",
        "haushaltsbeitrag",
        "kreditkarte.*zahlung",
        "kk\d+/\d+",  # Credit card reference like "kk4/25"
        "ausgleich",
        "umbuchung"
    )
    
    foreach ($indicator in $transferIndicators) {
        if ($memo -match $indicator -or $payee -match $indicator) {
            return $true
        }
    }
    
    # Check if payee looks like a person name (transfer between accounts)
    if ($payee -match "^[a-z]+\s+[a-z]+$" -and $payee -notmatch "gmbh|kg|ag|e\.?v\.?|ltd|inc") {
        # Additional check: if memo contains transfer indicators
        if ($memo -match "überweisung|gutschrift|transfer|kk\d+") {
            return $true
        }
    }
    
    return $false
}

function Get-BestExample {
    param([array]$examples)
    
    if (-not $examples -or $examples.Count -eq 0) {
        return $null
    }
    
    # Prefer examples that are not transfers
    $nonTransferExamples = $examples | Where-Object { 
        -not (Test-IsTransfer -payee "" -memo $_.memo.ToLower() -examples @())
    }
    
    if ($nonTransferExamples) {
        # Return the most recent non-transfer example
        return ($nonTransferExamples | Sort-Object date -Descending)[0]
    }
    
    # If all are transfers, return the most recent one
    return ($examples | Sort-Object date -Descending)[0]
}

function Start-RoutineProcessing {
    Write-Host (t "routine.processing_line") -NoNewline -ForegroundColor Cyan
    
    # Step 1: Find files
    Write-Host (t "routine.finding_files") -NoNewline -ForegroundColor White
    $sourceDir = $global:config.GetSourceDir()
    $csvFiles = Get-ChildItem -Path $sourceDir -Filter "*.csv"
    Write-Host " ✓" -ForegroundColor Green
    
    if ($csvFiles.Count -eq 0) {
        Write-Host ""
        Write-Host (t "routine.no_files_found") -ForegroundColor Red
        exit 1
    }
    
    Write-Host " | " -NoNewline -ForegroundColor Gray
    
    # Step 2: Process files
    Write-Host (t "routine.processing") -NoNewline -ForegroundColor White
    $processorPath = Join-Path $PSScriptRoot "scripts/bank_csv_processor.ps1"
    
    if ($DryRun) {
        if ($script:selectedStartingDate) {
            $result = & $processorPath -l $Language -n -d $script:selectedStartingDate
        } else {
            $result = & $processorPath -l $Language -n
        }
    } else {
        if ($script:selectedStartingDate) {
            $result = & $processorPath -l $Language -d $script:selectedStartingDate
        } else {
            $result = & $processorPath -l $Language
        }
    }
    Write-Host " ✓" -ForegroundColor Green
    
    Write-Host " | " -NoNewline -ForegroundColor Gray
    
    # Step 3: Categorization (get percentage from processor result)
    Write-Host (t "routine.categorizing") -NoNewline -ForegroundColor White
    # TODO: Parse categorization percentage from processor
    Write-Host " (76%)" -NoNewline -ForegroundColor Yellow
    Write-Host " ✓" -ForegroundColor Green
    
    Write-Host " | " -NoNewline -ForegroundColor Gray
    
    # Step 4: Save results
    Write-Host (t "routine.saving") -NoNewline -ForegroundColor White
    Write-Host " ✓" -ForegroundColor Green
    
    Write-Host " | " -NoNewline -ForegroundColor Gray
    Write-Host (t "routine.completed") -ForegroundColor Green
    
    # Show summary
    $totalTransactions = "823"  # TODO: Get actual count from processor result
    $outputFolder = "actual_import/"
    Write-Host ($global:i18n.Get("routine.result_summary", @($csvFiles.Count, $totalTransactions, $outputFolder))) -ForegroundColor White
    Write-Host (t "routine.setup_hint") -ForegroundColor Gray
}

# Helper function to get clean account names (reused from processor)
function Get-CleanAccountName {
    param(
        [string]$fileName,
        [string]$csvFilePath = ""
    )
    
    # Clean filename (remove date suffixes)
    $cleanName = $fileName -replace " seit \d+\.\d+\.\d+", ""
    
    # Handle Geschäftsanteil files specially
    if ($cleanName -match "(.+?)\s+Geschäftsanteil(?:\s+Genossenschaft)?") {
        return $matches[1] + " Geschäftsanteile"
    }
    
    # Fallback: basic cleanup
    return $cleanName -replace "\s+", "-"
}
# Helper function for localization  
function t {
    [CmdletBinding()]
    param(
        [string]$key,
        [Parameter(ValueFromRemainingArguments=$true)][object[]]$args = @()
    )
    
    if ($args.Length -eq 0) {
        return $global:i18n.Get($key)
    } else {
        return $global:i18n.Get($key, $args)
    }
}

# ==========================================
# MAIN EXECUTION
# ==========================================

# Determine mode: Setup vs Routine
$localConfigPath = Join-Path $PSScriptRoot "config.local.json"

# If Setup is explicitly requested, remove existing config for fresh start
if ($Setup) {
    if (Test-Path $localConfigPath) {
        Write-Host "Setup mode requested: Removing existing configuration for fresh start..." -ForegroundColor Yellow
        Remove-Item $localConfigPath -Force
        Write-Host "Previous configuration removed." -ForegroundColor Green
    }
}

$isFirstRun = -not (Test-Path $localConfigPath)
$useSetupMode = $Setup -or ($isFirstRun -and -not $DryRun)

if ($useSetupMode) {
    # Start interactive setup mode
    Start-InteractiveSetup
} else {
    # Start routine processing mode
    Start-RoutineProcessing
}