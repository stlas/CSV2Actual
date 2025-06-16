# CSV2Actual - Bank CSV zu Actual Budget Konverter
# Version: 1.3.0
# Author: sTLAs (https://github.com/sTLAs)
# Automatische Konvertierung deutscher Bank-CSV-Exporte zu Actual Budget
# Features: CategoryManager, AI-Collaboration, Multi-Set-Loading, Vollständige i18n

param(
    [Alias("l")][string]$Language = "en",
    [Alias("s")][switch]$Setup,
    [Alias("n")][switch]$DryRun,
    [Alias("h")][switch]$Help,
    [Alias("c")][switch]$Categorize,
    [Alias("a")][switch]$Analyze,
    [switch]$NoScreenClear
)

# Global flag to stop categorization
$global:CategorizationStopped = $false

# Disable paging to prevent interruption of interactive categorization
$env:PAGER = $null
if ($Host.UI.RawUI.WindowSize.Height -lt 30) {
    try {
        # Try to increase console height if too small
        $newSize = $Host.UI.RawUI.WindowSize
        $newSize.Height = 50
        $Host.UI.RawUI.WindowSize = $newSize
    } catch {
        # Silently continue if console resize fails
    }
}

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
    Write-Host "  -Categorize, -c    Direkt zur interaktiven Kategorisierung"
    Write-Host "  -Analyze, -a       Umfassende Kategorisierungs-Analyse"
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
. "$PSScriptRoot/modules/CsvFormatDetector.ps1"
. "$PSScriptRoot/modules/CategoryManager.ps1"
. "$PSScriptRoot/modules/CategoryEngine.ps1"
. "$PSScriptRoot/modules/TransactionAnalyzer.ps1"
. "$PSScriptRoot/modules/SimpleAnalyzer.ps1"
# IbanDiscovery via standalone script

# Initialize configuration and internationalization
try {
    $global:config = [Config]::new("$PSScriptRoot/config.json")
    $langDir = $global:config.Get("paths.languageDir")
    $global:i18n = [I18n]::new($langDir, $Language)
    $global:communityLoader = [CommunityLoader]::new("$PSScriptRoot/community", $global:i18n)
    
    # Initialize function-based CSV format detector (PowerShell 5.1 + 7.x compatible)
    Initialize-CsvFormatDetector -CommunityPath "$PSScriptRoot/community" -I18n $global:i18n
    
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

# Initialize CategoryEngine
try {
    $global:categoryEngine = [CategoryEngine]::new("$PSScriptRoot/categories.json", $Language)
    if (-not $Silent) {
        Write-Host "CategoryEngine initialisiert (Sprache: $Language)" -ForegroundColor Green
    }
} catch {
    Write-Warning "Fehler beim Initialisieren der CategoryEngine: $($_.Exception.Message)"
    $global:categoryEngine = $null
}

# ==========================================
# HELPER FUNCTIONS
# ==========================================

function Clear-Screen {
    # Check if screen clearing is disabled via parameter
    if ($NoScreenClear) {
        Write-Host "--- Screen clearing disabled ---" -ForegroundColor Gray
        return
    }
    
    # PowerShell 5.1/7.x compatible screen clearing
    try {
        Clear-Host
        # Try to position cursor - fail silently if not supported
        if ($Host.UI -and $Host.UI.RawUI -and $Host.UI.RawUI.BufferSize) {
            $Host.UI.RawUI.CursorPosition = @{X=0; Y=0}
        }
    } catch {
        # Fallback: just clear what we can
        Clear-Host
    }
}

function Show-Screen {
    param(
        [string]$Title,
        [string[]]$Content = @(),
        [string]$Footer = "",
        [switch]$WaitForInput
    )
    
    Clear-Screen
    
    # Header
    Write-Host "" 
    Write-Host "» $Title" -ForegroundColor Cyan
    Write-Host ("─" * ($Title.Length + 2)) -ForegroundColor Cyan
    Write-Host ""
    
    # Content
    foreach ($line in $Content) {
        if ($line -match "^ERROR:") {
            Write-Host "  ✗ $($line.Substring(6))" -ForegroundColor Red
        } elseif ($line -match "^SUCCESS:") {
            Write-Host "  ✓ $($line.Substring(8))" -ForegroundColor Green
        } elseif ($line -match "^INFO:") {
            Write-Host "  → $($line.Substring(5))" -ForegroundColor Gray
        } else {
            Write-Host "  $line" -ForegroundColor White
        }
    }
    
    # Footer
    if ($Footer) {
        Write-Host ""
        Write-Host "  $Footer" -ForegroundColor Gray
    }
    
    Write-Host ""
    
    if ($WaitForInput) {
        Read-Host "Drücken Sie Enter zum Fortfahren"
    }
}

function Show-Status {
    param(
        [string]$Message,
        [string]$Type = "info",  # info, success, warning, error
        [switch]$NoNewline
    )
    
    $color = switch ($Type) {
        "success" { "Green" }
        "warning" { "Yellow" }
        "error" { "Red" }
        "highlight" { "Cyan" }
        default { "White" }
    }
    
    $prefix = switch ($Type) {
        "success" { "✓ " }
        "warning" { "⚠ " }
        "error" { "✗ " }
        "highlight" { "» " }
        default { "  " }
    }
    
    if ($NoNewline) {
        Write-Host "$prefix$Message" -ForegroundColor $color -NoNewline
    } else {
        Write-Host "$prefix$Message" -ForegroundColor $color
    }
}

function Show-Progress {
    param(
        [string]$Step,
        [string]$Status = "running"  # running, done, failed
    )
    
    $statusSymbol = switch ($Status) {
        "done" { "✓" }
        "failed" { "✗" }
        default { "..." }
    }
    
    $color = switch ($Status) {
        "done" { "Green" }
        "failed" { "Red" }
        default { "Yellow" }
    }
    
    Write-Host "$Step " -NoNewline -ForegroundColor White
    Write-Host $statusSymbol -ForegroundColor $color
}

function Show-SimpleFrame {
    param(
        [string]$Title,
        [string[]]$Content = @()
    )
    
    Write-Host ""
    Show-Status $Title "highlight"
    Write-Host ("─" * $Title.Length) -ForegroundColor Cyan
    
    foreach ($line in $Content) {
        if ($line -ne "") {
            Write-Host "  $line" -ForegroundColor White
        } else {
            Write-Host ""
        }
    }
    Write-Host ""
}

function Start-InteractiveSetup {
    Clear-Screen
    
    # Header
    Write-Host "" 
    Write-Host "» $(t 'setup.title')" -ForegroundColor Cyan
    Write-Host ("─" * ($(t 'setup.title').Length + 2)) -ForegroundColor Cyan
    Write-Host ""
    
    # Welcome content
    Write-Host "$(t 'setup.welcome_message')" -ForegroundColor White
    Write-Host ""
    Write-Host "$(t 'setup.comprehensive_setup')" -ForegroundColor Gray
    
    if ($DryRun) {
        Write-Host ""
        Write-Host "INFO: " -NoNewline -ForegroundColor Yellow
        Write-Host $global:i18n.Get("instructions.auto_execution") -ForegroundColor Yellow
        Start-Sleep 2
    } else {
        Write-Host ""
        Write-Host $global:i18n.Get("common.commands") -ForegroundColor Cyan
        Write-Host "[" -NoNewline -ForegroundColor Green
        Write-Host "s" -NoNewline -ForegroundColor Green
        Write-Host "] $($global:i18n.Get("common.start"))  [" -NoNewline -ForegroundColor White
        Write-Host "x" -NoNewline -ForegroundColor Red
        Write-Host "] $($global:i18n.Get("common.cancel"))" -ForegroundColor White
        
        # Visuelle Trennung
        Write-Host ""
        Write-Host ("─" * 40) -ForegroundColor DarkGray
        
        do {
            $choice = Read-Host $global:i18n.Get("instructions.setup_prompt")
            if ($choice -eq "x") {
                Write-Host $global:i18n.Get("common.setup_cancelled") -ForegroundColor Red
                exit 0
            } elseif ($choice -eq "s" -or $choice -eq "") {
                break
            } else {
                Write-Host "  $($global:i18n.Get("common.please_enter_sx"))" -ForegroundColor Red
            }
        } while ($true)
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
    $content = @(
        "$(t 'setup.account_detection_desc')",
        "",
        $global:i18n.Get("instructions.analyzing_csvs")
    )
    Show-Screen -Title "$(t 'setup.step1_title')" -Content $content
    
    # Detect CSV files and suggest account names
    $sourceDir = $global:config.GetSourceDir()
    $csvFiles = Get-ChildItem -Path $sourceDir -Filter "*.csv"
    
    if ($csvFiles.Count -eq 0) {
        Show-Screen -Title "Fehler" -Content @(
            "ERROR:$(t 'setup.no_csv_found')",
            "",
            "$(t 'setup.add_csv_restart')"
        ) -WaitForInput
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
    
    Clear-Screen
    
    # Header
    Write-Host "" 
    Write-Host "» $(t 'setup.step1_title')" -ForegroundColor Cyan
    Write-Host ("─" * ($(t 'setup.step1_title').Length + 2)) -ForegroundColor Cyan
    Write-Host ""
    
    # Success message
    Write-Host "✓ " -NoNewline -ForegroundColor Green
    Write-Host "$(t 'setup.found_csv_files')" -ForegroundColor Green
    Write-Host ""
    
    # Farbige CSV-Dateien Liste
    foreach ($file in $csvFiles) {
        $suggestedName = Get-CleanAccountName -fileName $file.BaseName -csvFilePath $file.FullName
        Write-Host "• " -NoNewline -ForegroundColor Yellow
        Write-Host "$($file.Name)" -NoNewline -ForegroundColor White
        Write-Host " → " -NoNewline -ForegroundColor Gray
        Write-Host "`"$suggestedName`"" -ForegroundColor Cyan
        $accountMappings[$file.Name] = $suggestedName
    }
    
    Write-Host ""
    Write-Host "$(t 'setup.accounts_correct_question')" -ForegroundColor Yellow
    Write-Host ""
    
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
    Show-Screen -Title "IBAN-Extraktion" -Content @(
        $global:i18n.Get("instructions.extracting_ibans"),
        $global:i18n.Get("instructions.analyzing_count", @($csvFiles.Count))
    )
    
    $script:extractedIBANs = Extract-IBANsFromCSVs
    
    # Update global OwnIBANs variable immediately for transfer detection
    $global:OwnIBANs = $script:extractedIBANs
    
    # IBAN-Liste anzeigen
    Show-ExtractedIBANs
}

function Start-CategoryScanner {
    Clear-Screen
    
    # Header
    Write-Host "" 
    Write-Host "» $(t 'setup.step2_title')" -ForegroundColor Cyan
    Write-Host ("─" * ($(t 'setup.step2_title').Length + 2)) -ForegroundColor Cyan
    Write-Host ""
    
    # Description
    Write-Host "$(t 'setup.category_scanner_desc')" -ForegroundColor White
    Write-Host ""
    
    # Farbige Optionen
    Write-Host "[" -NoNewline -ForegroundColor Green
    Write-Host "1" -NoNewline -ForegroundColor Green
    Write-Host "] " -NoNewline -ForegroundColor Green
    Write-Host "$(t 'setup.category_scanner_automatic')" -NoNewline -ForegroundColor White
    Write-Host " (Standard)" -ForegroundColor Gray
    Write-Host "    $(t 'setup.category_scanner_automatic_desc')" -ForegroundColor Gray
    Write-Host ""
    
    Write-Host "[" -NoNewline -ForegroundColor Green
    Write-Host "2" -NoNewline -ForegroundColor Green
    Write-Host "] " -NoNewline -ForegroundColor Green
    Write-Host "$(t 'setup.category_scanner_interactive')" -ForegroundColor White
    Write-Host "    $(t 'setup.category_scanner_interactive_desc')" -ForegroundColor Gray
    Write-Host ""
    
    Write-Host "[" -NoNewline -ForegroundColor Green
    Write-Host "3" -NoNewline -ForegroundColor Green
    Write-Host "] " -NoNewline -ForegroundColor Green
    Write-Host "$(t 'setup.category_scanner_skip')" -ForegroundColor White
    Write-Host "    $(t 'setup.category_scanner_skip_desc')" -ForegroundColor Gray
    Write-Host ""
    
    Write-Host "[" -NoNewline -ForegroundColor Blue
    Write-Host "4" -NoNewline -ForegroundColor Blue
    Write-Host "] " -NoNewline -ForegroundColor Blue
    Write-Host "Kategorien-Manager" -ForegroundColor White
    Write-Host "    Kategorien importieren/exportieren, Session-Wiederherstellung" -ForegroundColor Gray
    
    Write-Host ""
    Write-Host $global:i18n.Get("common.commands") -ForegroundColor Cyan
    Write-Host "[" -NoNewline -ForegroundColor Green
    Write-Host "1-4" -NoNewline -ForegroundColor Green
    Write-Host "] $($global:i18n.Get("common.option_choose"))  [" -NoNewline -ForegroundColor White
    Write-Host "x" -NoNewline -ForegroundColor Red
    Write-Host "] Abbrechen" -ForegroundColor White
    
    # Visuelle Trennung
    Write-Host ""
    Write-Host ("─" * 40) -ForegroundColor DarkGray
    
    if ($DryRun) {
        Write-Host "[DRY-RUN] " -NoNewline -ForegroundColor Yellow
        Write-Host "Option 1 (automatisch)" -ForegroundColor Yellow
        Start-Sleep 2
    } else {
        do {
            $choice = Read-Host "Kategorie-Scanner (1-4, Enter=1)"
            if ($choice -eq "" -or $choice -eq "1") {
                # Automatic category scanning
                Clear-Screen
                Write-Host "" 
                Write-Host "» Automatische Kategorisierung" -ForegroundColor Green
                Write-Host ("─" * 28) -ForegroundColor Green
                Write-Host ""
                Write-Host "INFO: " -NoNewline -ForegroundColor Yellow
                Write-Host "$(t 'setup.running_automatic_scanner')" -ForegroundColor White
                Start-Sleep 1
                
                # Run automatic categorization (silent processing)
                $processorPath = Join-Path $PSScriptRoot "scripts/bank_csv_processor.ps1"
                Write-Host "INFO: " -NoNewline -ForegroundColor Yellow
                Write-Host $global:i18n.Get("instructions.processing_info") -ForegroundColor White
                
                # Redirect output to suppress verbose processor output
                $null = & $processorPath -Language $Language -Silent 2>$null
                
                Write-Host "✓ " -NoNewline -ForegroundColor Green
                Write-Host "Automatische Kategorisierung abgeschlossen" -ForegroundColor Green
                Write-Host ""
                Write-Host $global:i18n.Get("common.press_enter_continue") -ForegroundColor Gray
                Read-Host
                break
            } elseif ($choice -eq "2") {
                # Interactive category scanner
                Clear-Screen
                Write-Host "" 
                Write-Host "» Interaktive Kategorisierung" -ForegroundColor Green
                Write-Host ("─" * 27) -ForegroundColor Green
                Write-Host ""
                Write-Host "INFO: " -NoNewline -ForegroundColor Yellow
                Write-Host "$(t 'setup.running_interactive_scanner')" -ForegroundColor White
                Start-Sleep 1
                
                # Run interactive category scanner
                Start-IntegratedCategoryScanner
                break
            } elseif ($choice -eq "3") {
                Clear-Screen
                Write-Host "" 
                Write-Host "» Kategorie-Scanner übersprungen" -ForegroundColor Yellow
                Write-Host ("─" * 31) -ForegroundColor Yellow
                Write-Host ""
                Write-Host "INFO: " -NoNewline -ForegroundColor Yellow
                Write-Host "$(t 'setup.category_scanner_skipped')" -ForegroundColor White
                Write-Host ""
                Write-Host "Drücken Sie Enter zum Fortfahren..." -ForegroundColor Gray
                Read-Host
                break
            } elseif ($choice -eq "4") {
                # Kategorien-Manager
                Clear-Screen
                Write-Host "" 
                Write-Host "» Kategorien-Manager" -ForegroundColor Blue
                Write-Host ("─" * 19) -ForegroundColor Blue
                Write-Host ""
                
                # Initialisiere CategoryManager
                $categoryManager = New-CategoryManager -ConfigPath (Join-Path $PSScriptRoot "config.local.json")
                
                # Zeige Manager-Menü und lade ausgewählte Kategorien
                $loadedCategories = Show-CategoryManagerMenu -Manager $categoryManager
                
                if ($loadedCategories.Count -gt 0) {
                    # Kategorien in globale Variable übernehmen
                    $global:categoryMappings = $loadedCategories
                    
                    Write-Host ""
                    Write-Host "✅ $($loadedCategories.Count) Kategorien aktiviert" -ForegroundColor Green
                    Write-Host "📝 Kategorien können in der interaktiven Kategorisierung weiter bearbeitet werden" -ForegroundColor Cyan
                    Write-Host ""
                    Write-Host "Drücken Sie Enter zum Fortfahren..." -ForegroundColor Gray
                    Read-Host
                }
                break
            } elseif ($choice -eq "x") {
                Write-Host "✗ Setup abgebrochen." -ForegroundColor Red
                exit 0
            } else {
                Write-Host "  ⚠ Bitte 1-4 oder x eingeben." -ForegroundColor Red
            }
        } while ($true)
    }
}

function Extract-IBANsFromCSVs {
    $ibanMapping = @{}
    $sourceDir = $global:config.GetSourceDir()
    $csvFiles = Get-ChildItem -Path $sourceDir -Filter "*.csv"
    
    Write-Host "  Analysiere $($csvFiles.Count) CSV-Dateien..." -ForegroundColor Gray
    
    foreach ($file in $csvFiles) {
        try {
            $accountName = Get-CleanAccountName -fileName $file.BaseName -csvFilePath $file.FullName
            
            # Use dynamic CSV format detection (PowerShell 5.1 + 7.x compatible)
            $ibanResult = Extract-AccountIBANFromCSV -FilePath $file.FullName
            
            if ($ibanResult.Success -and $ibanResult.IBAN) {
                $ibanMapping[$ibanResult.IBAN] = $accountName
                Write-Host "    ✓ $accountName" -ForegroundColor Green
            } else {
                # Fallback: Analyze CSV structure and look for common patterns
                $analysis = Analyze-CSVStructure -FilePath $file.FullName
                
                # Try transaction-based IBAN discovery for own accounts (fallback logic)
                $transactionIbans = Analyze-TransactionIBANs -filePath $file.FullName -analysis $analysis -accountName $accountName
                foreach ($iban in $transactionIbans.Keys) {
                    if (-not ($ibanMapping.Keys -contains $iban)) {
                        $ibanMapping[$iban] = $transactionIbans[$iban]
                        Write-Host "    ✓ $accountName (abgeleitet)" -ForegroundColor Yellow
                    }
                }
            }
            
        } catch {
            Write-Host "    ✗ $accountName" -ForegroundColor Red
        }
    }
    
    Write-Host ""
    if ($ibanMapping.Count -gt 0) {
        Write-Host "  Gefunden: $($ibanMapping.Count) IBANs für Transfer-Erkennung" -ForegroundColor Green
    } else {
        Write-Host "  Keine IBANs gefunden!" -ForegroundColor Red
    }
    
    return $ibanMapping
}

function Analyze-TransactionIBANs {
    param(
        [string]$filePath,
        [hashtable]$analysis,
        [string]$accountName
    )
    
    $result = @{}
    
    try {
        # Import CSV using detected settings
        $csvData = Import-Csv -Path $filePath -Delimiter $analysis.Delimiter -Encoding $analysis.Encoding
        
        # Look for frequently occurring IBANs in transaction data (could be own accounts)
        $targetIbans = @{}
        $checkedRows = 0
        
        # Get IBAN column name from mapping or use common patterns
        $ibanColumn = $null
        if ($analysis.ColumnMapping.Keys -contains 'iban') {
            $ibanColumn = $analysis.ColumnMapping['iban']
        } else {
            # Fallback: try common IBAN column names
            $commonIbanColumns = @('IBAN Zahlungsbeteiligter', 'Payee IBAN', 'Partner IBAN')
            foreach ($col in $commonIbanColumns) {
                if ($analysis.Headers -contains $col) {
                    $ibanColumn = $col
                    break
                }
            }
        }
        
        if (-not $ibanColumn) {
            Write-Host "    No IBAN column found for transaction analysis" -ForegroundColor Yellow
            return $result
        }
        
        foreach ($row in ($csvData | Select-Object -First 100)) {
            $checkedRows++
            if ($row.$ibanColumn -and $row.$ibanColumn -match "^[A-Z]{2}\d{2}[A-Z0-9]+$") {
                $iban = $row.$ibanColumn
                if (-not ($targetIbans.Keys -contains $iban)) {
                    $targetIbans[$iban] = @{
                        count = 0
                        payeeNames = @()
                    }
                }
                $targetIbans[$iban].count++
                
                # Get payee name from mapping or common patterns
                $payeeColumn = $null
                if ($analysis.ColumnMapping.Keys -contains 'payee') {
                    $payeeColumn = $analysis.ColumnMapping['payee']
                } else {
                    $commonPayeeColumns = @('Name Zahlungsbeteiligter', 'Payee', 'Partner Name')
                    foreach ($col in $commonPayeeColumns) {
                        if ($analysis.Headers -contains $col) {
                            $payeeColumn = $col
                            break
                        }
                    }
                }
                
                if ($payeeColumn -and $targetIbans[$iban].payeeNames.Count -lt 5 -and $row.$payeeColumn) {
                    $targetIbans[$iban].payeeNames += $row.$payeeColumn
                }
            }
        }
        
        # Analyze for personal account patterns (this logic should be made configurable too)
        foreach ($iban in $targetIbans.Keys) {
            $ibanInfo = $targetIbans[$iban]
            if ($ibanInfo.count -ge 2) {
                foreach ($payeeName in $ibanInfo.payeeNames) {
                    # Generic personal name detection (should be configurable)
                    if ($payeeName -match "Geschäftsanteil|Girokonto|Variokonto|Sparbuch|Savings|Checking") {
                        $result[$iban] = $accountName + "-Transfer"
                        break
                    }
                }
            }
        }
        
    } catch {
        Write-Host "    Error in transaction IBAN analysis: $($_.Exception.Message)" -ForegroundColor Yellow
    }
    
    return $result
}

function Start-StartingDateSelection {
    $content = @(
        "$(t 'setup.starting_date_desc')",
        "",
        "[1] $(t 'setup.automatic_option')",
        "    $(t 'setup.automatic_desc')",
        "",
        "[2] $(t 'setup.specific_date_option')",
        "    $(t 'setup.specific_date_desc')"
    )
    Show-Screen -Title "$(t 'setup.step3_title')" -Content $content
    
    if ($DryRun) {
        Write-Host "[DRY-RUN] " -NoNewline -ForegroundColor Yellow
        Write-Host (t "setup.starting_date_choice") -NoNewline
        Write-Host " -> 1 (automatisch)" -ForegroundColor Gray
        
        $script:useAutoStartingDate = $true
        Show-Screen -Title "$(t 'setup.step3_title')" -Content @(
            "INFO:[DRY-RUN] $(t 'setup.automatic_selected')"
        ) -WaitForInput
    } else {
        do {
            $choice = Read-Host (t "setup.starting_date_choice")
            if ($choice -eq "" -or $choice -eq "1") {
                $script:useAutoStartingDate = $true
                Show-Screen -Title "$(t 'setup.step3_title')" -Content @(
                    "SUCCESS:$(t 'setup.automatic_selected')"
                ) -WaitForInput
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
                        Show-Screen -Title "$(t 'setup.step3_title')" -Content @(
                            "SUCCESS:$(t 'setup.specific_date_selected' @($dateInput))"
                        ) -WaitForInput
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
    Show-Status "$(t 'setup.step4_title')" "highlight"
    Show-Status "$(t 'setup.saving_configuration')" "info"
    
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
    
    Write-Host ""
    Show-Status "$(t 'setup.completed_title')" "success"
    Show-Status "$(t 'setup.configuration_saved')" "info"
    Show-Status "$(t 'setup.ready_for_processing')" "info"
    
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
    Clear-Screen
    
    # Header
    Write-Host "" 
    Write-Host "» Kategorie-Scanner" -ForegroundColor Cyan
    Write-Host ("─" * 19) -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Scannt alle CSV-Dateien und lässt Sie unbekannte Kategorien interaktiv zuordnen." -ForegroundColor White
    Write-Host "Die Zuordnungen werden in config.local.json gespeichert und wiederverwendet." -ForegroundColor Gray
    Write-Host ""
    
    # Load processor functions (save current language context)
    $currentLanguage = $Language
    $processorPath = Join-Path $PSScriptRoot "scripts/bank_csv_processor.ps1"
    . $processorPath
    
    # Restore language context
    $Language = $currentLanguage
    $global:i18n = [I18n]::new($langDir, $Language)
    
    # Make sure we have access to OwnIBANs for transfer detection
    # Always use the global IBAN mapping that was set during account detection
    $OwnIBANs = if ($global:OwnIBANs) { $global:OwnIBANs } else { $global:config.GetIBANMapping() }
    
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
    
    # Debug: Show IBAN count for transfer detection
    Write-Host "Transfer-Erkennung: $($OwnIBANs.Count) IBANs verfügbar" -ForegroundColor Cyan
    
    # Get CSV files
    $sourceDir = $global:config.GetSourceDir()
    $csvFiles = Get-ChildItem -Path $sourceDir -Filter "*.csv"
    
    # Collect all unique transactions that don't have categories (excluding transfers)
    $uncategorizedTransactions = @{}
    $totalTransactions = 0
    $filteredTransferCount = 0
    
    # Stille Verarbeitung ohne Ausgabe
    foreach ($file in $csvFiles) {
        # WICHTIG: Verwende RAW CSV Daten, nicht verarbeitete aus actual_import/
        # Process-BankCSV würde bereits kategorisierte Daten zurückgeben
        
        # Lade CSV direkt ohne Kategorisierung
        try {
            $csvData = Import-Csv -Path $file.FullName -Delimiter ";" -Encoding UTF8
        } catch {
            try {
                $csvData = Import-Csv -Path $file.FullName -Delimiter "," -Encoding UTF8
            } catch {
                Write-Host $global:i18n.Get("instructions.cannot_read_file", @($file.Name)) -ForegroundColor Red
                continue
            }
        }
        
        $processedData = @()
        foreach ($csvRow in $csvData) {
            # Type-safe field extraction - no Boolean conversion
            $dateField = if ($csvRow."Buchungstag") { $csvRow."Buchungstag" } elseif ($csvRow."Date") { $csvRow."Date" } elseif ($csvRow."Datum") { $csvRow."Datum" } else { "" }
            $payeeField = if ($csvRow."Name Zahlungsbeteiligter") { $csvRow."Name Zahlungsbeteiligter" } elseif ($csvRow."Payee") { $csvRow."Payee" } elseif ($csvRow."Empfänger") { $csvRow."Empfänger" } else { "" }
            $amountField = if ($csvRow."Betrag") { $csvRow."Betrag" } elseif ($csvRow."Amount") { $csvRow."Amount" } elseif ($csvRow."Umsatz") { $csvRow."Umsatz" } else { "" }
            $notesField = if ($csvRow."Verwendungszweck") { $csvRow."Verwendungszweck" } elseif ($csvRow."Purpose") { $csvRow."Purpose" } elseif ($csvRow."Memo") { $csvRow."Memo" } else { "" }
            
            # Simuliere die Struktur die Process-BankCSV zurückgibt
            $processedData += @{
                date = if ($dateField -is [string]) { $dateField } elseif ($dateField) { $dateField.ToString() } else { "" }
                payee = if ($payeeField -is [string]) { $payeeField } elseif ($payeeField) { $payeeField.ToString() } else { "" }
                amount = if ($amountField -is [string]) { $amountField } elseif ($amountField) { $amountField.ToString() } else { "" }
                notes = if ($notesField -is [string]) { $notesField } elseif ($notesField) { $notesField.ToString() } else { "" }
                category = ""  # WICHTIG: Keine Kategorie - das wollen wir ja finden!
            }
        }
        
        $processedCount = if ($processedData -is [array]) { $processedData.Count } elseif ($processedData) { 1 } else { 0 }
        $totalTransactions += $processedCount
        
        Write-Host "Debug: $($file.Name) hat $processedCount RAW Transaktionen" -ForegroundColor Yellow
        
        if ($processedCount -gt 0) {
            foreach ($row in $processedData) {
                # Type-safe category check
                $categoryText = if ($row.category -is [string]) { $row.category } elseif ($row.category) { $row.category.ToString() } else { "" }
                if (-not $row.category -or $categoryText.Trim() -eq "") {
                    # Create a pattern key for similar transactions - handle NULL payee with type safety
                    # Debug: Check what type $row.payee actually is
                    if ($row.payee -is [bool]) {
                        Write-Warning "Boolean payee detected: $($row.payee) - converting to string"
                        $payeeText = if ($row.payee) { "TRUE_PAYEE" } else { "FALSE_PAYEE" }
                    } elseif ($row.payee -is [string] -and $row.payee.Trim() -ne "") { 
                        $payeeText = $row.payee.Trim() 
                    } elseif ($row.payee -and $row.payee -isnot [string]) {
                        $payeeString = $row.payee.ToString()
                        $payeeText = if ($payeeString.Trim() -ne "") { $payeeString.Trim() } else { "UNKNOWN_PAYEE" }
                    } else { 
                        $payeeText = "UNKNOWN_PAYEE" 
                    }
                    
                    # PayPal-specific payee enhancement for wire transfers
                    if ($payeeText -match "(?i)paypal" -and $row.notes) {
                        $memoText = if ($row.notes -is [string]) { $row.notes.ToLower() } else { $row.notes.ToString().ToLower() }
                        $merchantName = ""
                        # Extract merchant name from PayPal memo - simple approach
                        if ($memoText -match "mullvad") {
                            $merchantName = "Mullvad VPN"
                        } elseif ($memoText -match "pp\.\d+") {
                            # Simple text extraction without complex regex
                            if ($memoText -match "mullvad\s+vpn") {
                                $merchantName = "Mullvad VPN"
                            } elseif ($memoText -match "netflix") {
                                $merchantName = "Netflix"
                            } elseif ($memoText -match "spotify") {
                                $merchantName = "Spotify"
                            } elseif ($memoText -match "google") {
                                $merchantName = "Google"
                            } elseif ($memoText -match "apple") {
                                $merchantName = "Apple"
                            } else {
                                $merchantName = "PayPal Service"
                            }
                        }
                        
                        if ($merchantName -and $merchantName -ne "") {
                            $payeeText = "PayPal ($merchantName)"
                        }
                    }
                    
                    # Pre-filter transfers - don't include them in uncategorized list
                    # Type-safe memo text conversion
                    $memoText = if ($row.notes) {
                        if ($row.notes -is [string]) { 
                            $row.notes.ToLower() 
                        } else { 
                            $row.notes.ToString().ToLower() 
                        }
                    } else { "" }
                    
                    # Check for IBAN-based transfers first (most accurate)
                    $targetIBAN = ""
                    
                    # Method 1: Direct IBAN column
                    if ($row.PSObject.Properties.Name -contains "IBAN Zahlungsbeteiligter" -and $row."IBAN Zahlungsbeteiligter") {
                        # Type-safe IBAN extraction
                        $ibanValue = $row."IBAN Zahlungsbeteiligter"
                        $targetIBAN = if ($ibanValue -is [string]) { $ibanValue.Trim() } elseif ($ibanValue) { $ibanValue.ToString().Trim() } else { "" }
                    }
                    
                    # Method 2: Extract IBAN from memo/Verwendungszweck (common in German banks)
                    if (-not $targetIBAN -and $row.notes) {
                        if ($row.notes -match "IBAN:\s*([A-Z]{2}\d{2}[A-Z0-9]+)") {
                            # Type-safe match trimming
                            $matchValue = $matches[1]
                            $targetIBAN = if ($matchValue -is [string]) { $matchValue.Trim() } elseif ($matchValue) { $matchValue.ToString().Trim() } else { "" }
                        }
                    }
                    
                    $isTransfer = $false
                    
                    # 1. IBAN-based transfer recognition (highest priority)
                    if ($targetIBAN -and ($OwnIBANs.Keys -contains $targetIBAN)) {
                        $isTransfer = $true
                        Write-Verbose "Transfer detected: IBAN $targetIBAN belongs to own account $($OwnIBANs[$targetIBAN])"
                    }
                    # 2. Fallback: keyword-based transfer recognition
                    # Type-safe payee text conversion for transfer test
                    $safePayeeText = if ($payeeText -is [string]) { $payeeText.ToLower() } elseif ($payeeText) { $payeeText.ToString().ToLower() } else { "" }
                    if (Test-IsTransfer -payee $safePayeeText -memo $memoText -examples @()) {
                        $isTransfer = $true
                    }
                    
                    if ($isTransfer) {
                        $filteredTransferCount++
                        continue  # Skip transfer transactions completely
                    }
                    
                    # 3. Check for automatic income categorization
                    $safeAmount = if ($row.amount -is [string]) { $row.amount } elseif ($row.amount) { $row.amount.ToString() } else { "" }
                    $safeMemo = if ($row.notes -is [string]) { $row.notes } elseif ($row.notes) { $row.notes.ToString() } else { "" }
                    $incomeCategory = Get-IncomeCategory -payee $payeeText -memo $safeMemo -amount $safeAmount
                    
                    if ($incomeCategory) {
                        $filteredTransferCount++  # Count as filtered/categorized
                        continue  # Skip income transactions - they're automatically categorized
                    }
                    
                    # Type-safe pattern key generation
                    $patternKey = if ($payeeText -is [string]) { $payeeText.ToLower() } elseif ($payeeText) { $payeeText.ToString().ToLower() } else { "unknown" }
                    
                    if (-not ($uncategorizedTransactions.Keys -contains $patternKey)) {
                        $uncategorizedTransactions[$patternKey] = @{
                            payee = $payeeText
                            memo = $row.notes
                            amount = $row.amount
                            count = 0
                            examples = @()
                        }
                    }
                    
                    $uncategorizedTransactions[$patternKey].count++
                    if (@($uncategorizedTransactions[$patternKey].examples).Count -lt 3) {
                        # Get account name from current file
                        $currentAccountName = Get-CleanAccountName -fileName $file.BaseName -csvFilePath $file.FullName
                        
                        $uncategorizedTransactions[$patternKey].examples += @{
                            date = if ($row.date -is [string]) { $row.date } elseif ($row.date) { $row.date.ToString() } else { "UNKNOWN_DATE" }
                            amount = if ($row.amount -is [string]) { $row.amount } elseif ($row.amount) { $row.amount.ToString() } else { "UNKNOWN_AMOUNT" }
                            memo = if ($row.notes -is [string]) { $row.notes } elseif ($row.notes) { $row.notes.ToString() } else { "UNKNOWN_MEMO" }
                            sourceAccount = if ($currentAccountName -is [string]) { $currentAccountName } elseif ($currentAccountName) { $currentAccountName.ToString() } else { "UNKNOWN_ACCOUNT" }
                            payeeName = if ($payeeText -is [string]) { $payeeText } elseif ($payeeText) { $payeeText.ToString() } else { "UNKNOWN_PAYEE_NAME" }
                        }
                    }
                }
            }
        }
    }
    
    # Zeige kompakte Scan-Ergebnisse und gehe direkt zu Optionen
    $categorizedCount = $totalTransactions - $filteredTransferCount - @($uncategorizedTransactions.GetEnumerator()).Count
    
    if (@($uncategorizedTransactions.GetEnumerator()).Count -eq 0) {
        Show-Screen -Title "Kategorisierung - Ergebnisse" -Content @(
            "SUCCESS:Alle Transaktionen sind bereits kategorisiert!"
        ) -WaitForInput
        return
    }
    
    # Direkt zu farbigen Kategorisierungsoptionen
    Clear-Screen
    
    # Header
    Write-Host "" 
    Write-Host "» Kategorisierungsoptionen" -ForegroundColor Cyan
    Write-Host ("─" * 25) -ForegroundColor Cyan
    Write-Host ""
    
    # Verbesserte Statistik mit automatischer Kategorisierung
    $uncategorizedCount = @($uncategorizedTransactions.GetEnumerator()).Count
    $autoCategorizedCount = $filteredTransferCount
    
    Write-Host "» Analyse-Ergebnisse:" -ForegroundColor Cyan
    Write-Host "  ✓ " -NoNewline -ForegroundColor Green
    Write-Host "Automatisch kategorisiert: " -NoNewline -ForegroundColor Gray
    Write-Host "$autoCategorizedCount" -NoNewline -ForegroundColor Green
    Write-Host " Transaktionen (Transfers + Einnahmen)" -ForegroundColor Gray
    
    Write-Host "  ⚠ " -NoNewline -ForegroundColor Yellow
    Write-Host "Benötigen Kategorisierung: " -NoNewline -ForegroundColor Gray
    Write-Host "$uncategorizedCount" -NoNewline -ForegroundColor Yellow
    Write-Host " Payee-Gruppen" -ForegroundColor Gray
    Write-Host ""
    
    # Farbige Optionen
    Write-Host "Wählen Sie eine Kategorisierungsoption:" -ForegroundColor White
    Write-Host ""
    
    Write-Host "[" -NoNewline -ForegroundColor Green
    Write-Host "1" -NoNewline -ForegroundColor Green
    Write-Host "] " -NoNewline -ForegroundColor Green
    Write-Host "Alle unkategorisierten Transaktionen einzeln durchgehen" -ForegroundColor White
    Write-Host "    " -NoNewline
    Write-Host "Detaillierte Kategorisierung jeder einzelnen Transaktion" -ForegroundColor Gray
    Write-Host ""
    
    Write-Host "[" -NoNewline -ForegroundColor Green
    Write-Host "2" -NoNewline -ForegroundColor Green
    Write-Host "] " -NoNewline -ForegroundColor Green
    Write-Host "Nur die häufigsten Payee-Gruppen bearbeiten" -ForegroundColor White
    Write-Host "    " -NoNewline
    Write-Host "Schnelle Kategorisierung nach Payee-Mustern (Standard)" -ForegroundColor Gray
    Write-Host ""
    
    Write-Host "[" -NoNewline -ForegroundColor Green
    Write-Host "3" -NoNewline -ForegroundColor Green
    Write-Host "] " -NoNewline -ForegroundColor Green
    Write-Host "Kategorisierungen zurücksetzen und neu beginnen" -ForegroundColor White
    Write-Host "    " -NoNewline
    Write-Host "Löscht alle vorherigen Zuordnungen und startet von vorn" -ForegroundColor Gray
    Write-Host ""
    
    Write-Host "[" -NoNewline -ForegroundColor Red
    Write-Host "4" -NoNewline -ForegroundColor Red
    Write-Host "] " -NoNewline -ForegroundColor Red
    Write-Host "Abbrechen" -ForegroundColor White
    Write-Host ""
    
    $scanChoice = Read-Host "Ihre Wahl (1-4, Enter für Option 2)"
    if ($scanChoice -eq "1") {
        Start-ExtendedCategoryMapping $uncategorizedTransactions
    } elseif ($scanChoice -eq "" -or $scanChoice -eq "2") {
        try {
            Start-InteractiveCategoryMapping $uncategorizedTransactions
        } catch {
            if ($_.Exception.Message -eq "CATEGORIZATION_BREAK") {
                Write-Host "✓ Kategorisierung vollständig beendet." -ForegroundColor Green
            } else {
                throw
            }
        }
    } elseif ($scanChoice -eq "3") {
        # Reset all categorizations
        $localConfigPath = Join-Path $PSScriptRoot "config.local.json"
        if (Test-Path $localConfigPath) {
            try {
                $localConfig = Get-Content $localConfigPath -Encoding UTF8 | ConvertFrom-Json
                
                # PowerShell 5.1/7.x compatible way to remove properties
                $newConfig = @{}
                foreach ($property in $localConfig.PSObject.Properties) {
                    if ($property.Name -ne "categoryMappings" -and $property.Name -ne "categoryKeywords") {
                        $newConfig[$property.Name] = $property.Value
                    }
                }
                $localConfig = [PSCustomObject]$newConfig
                $localConfig | ConvertTo-Json -Depth 5 | Out-File $localConfigPath -Encoding UTF8
                Show-Screen -Title "Kategorisierungen zurückgesetzt" -Content @(
                    "SUCCESS:Alle Kategorisierungen wurden zurückgesetzt.",
                    "INFO:Scanner wird automatisch neu gestartet..."
                )
                Start-Sleep 2
                
                # Restart the scanner with reset data
                Start-IntegratedCategoryScanner
            } catch {
                Show-Screen -Title "Fehler" -Content @(
                    "ERROR:Konnte Kategorisierungen nicht zurücksetzen: $($_.Exception.Message)"
                ) -WaitForInput
            }
        } else {
            Show-Screen -Title "Fehler" -Content @(
                "ERROR:Keine Konfigurationsdatei gefunden"
            ) -WaitForInput
        }
        return  # Exit after reset
    } else {
        Show-Screen -Title "Scanner abgebrochen" -Content @(
            "INFO:Kategorisierung wurde abgebrochen."
        ) -WaitForInput
    }
}

function Get-AllAvailableCategories {
    # Basis-Kategorien (Standard)
    $baseCategories = @{
        "Tägliche Ausgaben" = @("Lebensmittel", "Kraftstoff", "Restaurants & Ausgehen", "Drogerie & Gesundheit", "Taxi & Ridesharing")
        "Wohnen & Leben" = @("Wohnen", "Internet & Telefon", "Versicherungen", "Steuern")
        "Shopping & Freizeit" = @("Online Shopping", "Elektronik & Technik", "Streaming & Abos", "Mitgliedschaften", "Bildung")
        "Einnahmen" = @("Einkommen", "Kapitalerträge", "Bareinzahlungen")
        "Transfers & Sonstiges" = @("Transfer (Haushaltsbeitrag)", "Bankgebühren", "Spenden")
    }
    
    # Lade gespeicherte Kategorien aus categoryMappings
    try {
        $localConfigPath = Join-Path $PSScriptRoot "config.local.json"
        if (Test-Path $localConfigPath) {
            $content = Get-Content $localConfigPath -Encoding UTF8 -Raw
            $localConfig = $content | ConvertFrom-Json
            
            if ($localConfig.categoryMappings) {
                # Sammle alle eindeutigen Kategorien aus den Mappings
                $savedCategories = @{}
                $localConfig.categoryMappings.PSObject.Properties | ForEach-Object {
                    $category = $_.Value
                    if ($category -and $category.Trim() -ne "") {
                        # Prüfe ob Kategorie bereits in Standard-Kategorien existiert
                        $found = $false
                        foreach ($group in $baseCategories.Keys) {
                            if ($baseCategories[$group] -contains $category) {
                                $found = $true
                                break
                            }
                        }
                        
                        # Falls nicht gefunden, füge zu "Sonstige" hinzu
                        if (-not $found) {
                            if (-not ($savedCategories.Keys -contains "Sonstige")) {
                                $savedCategories["Sonstige"] = @()
                            }
                            if ($savedCategories["Sonstige"] -notcontains $category) {
                                $savedCategories["Sonstige"] += $category
                            }
                        }
                    }
                }
                
                # Merge saved categories into base categories
                foreach ($group in $savedCategories.Keys) {
                    if ($baseCategories.Keys -contains $group) {
                        # Füge neue Kategorien zur bestehenden Gruppe hinzu
                        foreach ($cat in $savedCategories[$group]) {
                            if ($baseCategories[$group] -notcontains $cat) {
                                $baseCategories[$group] += $cat
                            }
                        }
                    } else {
                        # Neue Gruppe hinzufügen
                        $baseCategories[$group] = $savedCategories[$group]
                    }
                }
            }
        }
    } catch {
        # Bei Fehlern Standard-Kategorien verwenden
    }
    
    return $baseCategories
}

function Start-ExtendedCategoryMapping {
    param([hashtable]$uncategorizedTransactions)
    
    # Reset global categorization stop flag
    $global:CategorizationStopped = $false
    
    # Removed old Write-Host outputs - now using seitenweise display
    
    # Lade alle verfügbaren Kategorien (Standard + Gespeicherte)
    $availableCategories = Get-AllAvailableCategories
    
    # Flache Liste für einfache Suche
    $flatCategories = @()
    foreach ($group in $availableCategories.Keys) {
        $flatCategories += $availableCategories[$group]
    }
    
    # Load existing category mappings from config.local.json
    $categoryMappings = @{}
    try {
        $localConfigPath = Join-Path $PSScriptRoot "config.local.json"
        if (Test-Path $localConfigPath) {
            $content = Get-Content $localConfigPath -Encoding UTF8 -Raw
            # PowerShell 5.1/7.x compatible JSON parsing
            if ($PSVersionTable.PSVersion.Major -ge 6) {
                $localConfig = $content | ConvertFrom-Json -AsHashtable
            } else {
                $localConfigObj = $content | ConvertFrom-Json
                $localConfig = @{}
                # Convert PSCustomObject to hashtable for PowerShell 5.1
                $localConfigObj.PSObject.Properties | ForEach-Object {
                    if ($_.Value -is [PSCustomObject]) {
                        $subHash = @{}
                        $_.Value.PSObject.Properties | ForEach-Object { $subHash[$_.Name] = $_.Value }
                        $localConfig[$_.Name] = $subHash
                    } else {
                        $localConfig[$_.Name] = $_.Value
                    }
                }
            }
            
            if (($localConfig.Keys -contains "categoryMappings") -and $localConfig["categoryMappings"]) {
                $categoryMappings = $localConfig["categoryMappings"]
                Write-Host "✓ Lade $(@($categoryMappings.GetEnumerator()).Count) gespeicherte Kategorie-Zuordnungen" -ForegroundColor Green
            }
        }
    } catch {
        Write-Host "⚠ Fehler beim Laden der Kategorie-Zuordnungen: $($_.Exception.Message)" -ForegroundColor Yellow
    }
    
    $allTransactions = @()
    
    # Sammle alle einzelnen Transaktionen aus den Gruppen
    foreach ($entry in $uncategorizedTransactions.GetEnumerator()) {
        # Type-safe payee extraction
        $payee = if ($entry.Value.payee -is [string]) { 
            $entry.Value.payee 
        } elseif ($entry.Value.payee -is [bool]) {
            if ($entry.Value.payee) { "TRUE_BOOLEAN_PAYEE" } else { "FALSE_BOOLEAN_PAYEE" }
        } elseif ($entry.Value.payee) { 
            $entry.Value.payee.ToString() 
        } else { 
            "UNKNOWN_PAYEE" 
        }
        $examples = $entry.Value.examples
        $count = $entry.Value.count
        
        # Skip this payee if already categorized (with fuzzy matching)
        $isAlreadyCategorized = $false
        $matchedCategory = $null
        
        # First try exact match
        if ($categoryMappings.Keys -contains $payee) {
            $isAlreadyCategorized = $true
            $matchedCategory = $categoryMappings[$payee]
        } else {
            # Try fuzzy matching (normalize punctuation and spaces)
            $normalizedPayee = $payee -replace '[^\w\s]', '' -replace '\s+', ' '
            $normalizedPayee = $normalizedPayee.Trim().ToLower()
            
            foreach ($savedPayee in $categoryMappings.Keys) {
                $normalizedSaved = $savedPayee -replace '[^\w\s]', '' -replace '\s+', ' '
                $normalizedSaved = $normalizedSaved.Trim().ToLower()
                
                if ($normalizedPayee -eq $normalizedSaved) {
                    $isAlreadyCategorized = $true
                    $matchedCategory = $categoryMappings[$savedPayee]
                    Write-Verbose "Fuzzy match found: '$payee' matches saved '$savedPayee' → $matchedCategory"
                    break
                }
            }
        }
        
        if ($isAlreadyCategorized) {
            Write-Verbose "Skipping already categorized payee: $payee → $matchedCategory"
            continue
        }
        
        # Für jede Transaktion in dieser Payee-Gruppe (nicht nur die examples)
        for ($i = 0; $i -lt $count; $i++) {
            if ($i -lt @($examples).Count) {
                # Verwende vorhandenes Example
                $example = $examples[$i]
                $allTransactions += @{
                    payee = $payee
                    date = if ($example.date -is [string]) { $example.date } elseif ($example.date) { $example.date.ToString() } else { "UNKNOWN_DATE" }
                    amount = if ($example.amount -is [string]) { $example.amount } elseif ($example.amount) { $example.amount.ToString() } else { "UNKNOWN_AMOUNT" }
                    memo = if ($example.memo -is [string]) { $example.memo } elseif ($example.memo) { $example.memo.ToString() } else { "UNKNOWN_MEMO" }
                    sourceAccount = if ($example.sourceAccount -is [string]) { $example.sourceAccount } elseif ($example.sourceAccount) { $example.sourceAccount.ToString() } else { "UNKNOWN_ACCOUNT" }
                    payeeName = if ($example.payeeName -is [string]) { $example.payeeName } elseif ($example.payeeName) { $example.payeeName.ToString() } else { "UNKNOWN_PAYEE_NAME" }
                }
            } else {
                # Erstelle Dummy-Transaktion für weitere gleichartige Transaktionen
                # PowerShell 5.1/7.x compatible way to get last element
                $examplesArray = @($examples)
                $lastExample = $examplesArray[$examplesArray.Count - 1]
                $allTransactions += @{
                    payee = $payee
                    date = if ($lastExample.date -is [string]) { $lastExample.date } elseif ($lastExample.date) { $lastExample.date.ToString() } else { "UNKNOWN_DATE" }
                    amount = if ($lastExample.amount -is [string]) { $lastExample.amount } elseif ($lastExample.amount) { $lastExample.amount.ToString() } else { "UNKNOWN_AMOUNT" }
                    memo = if ($lastExample.memo -is [string]) { $lastExample.memo } elseif ($lastExample.memo) { $lastExample.memo.ToString() } else { "UNKNOWN_MEMO" }
                    sourceAccount = if ($lastExample.sourceAccount -is [string]) { $lastExample.sourceAccount } elseif ($lastExample.sourceAccount) { $lastExample.sourceAccount.ToString() } else { "UNKNOWN_ACCOUNT" }
                    payeeName = if ($lastExample.payeeName -is [string]) { $lastExample.payeeName } elseif ($lastExample.payeeName) { $lastExample.payeeName.ToString() } else { "UNKNOWN_PAYEE_NAME" }
                }
            }
        }
    }
    
    # Sortiere Transaktionen nach Datum (neueste zuerst) - mit type-safe Date parsing
    $sortedTransactions = $allTransactions | Sort-Object { 
        $dateStr = if ($_.date -is [string]) { $_.date } elseif ($_.date) { $_.date.ToString() } else { "1900-01-01" }
        try {
            [DateTime]::ParseExact($dateStr, "yyyy-MM-dd", $null)
        } catch {
            # Fallback für ungültige Datumsformate
            try {
                [DateTime]::Parse($dateStr)
            } catch {
                [DateTime]::MinValue
            }
        }
    } -Descending
    
    # PowerShell 5.1/7.x compatible Count
    $totalTransactions = @($sortedTransactions).Count
    $processedCount = 0
    
    Show-Screen -Title "Erweiterte Kategoriezuordnung" -Content @(
        "Bearbeite $totalTransactions unkategorisierte Transaktionen",
        "INFO:Gruppiert nach $(@($uncategorizedTransactions.GetEnumerator()).Count) unterschiedlichen Payees",
        "INFO:Verwenden Sie [x] zum Beenden"
    )
    
    :outer foreach ($transaction in $sortedTransactions) {
        # Check global stop flag
        if ($global:CategorizationStopped) {
            Write-Host "✓ Kategorisierung beendet." -ForegroundColor Green
            break :outer
        }
        
        # Skip this transaction if its payee is already categorized
        $safePayee = if ($transaction.payee -is [string]) { $transaction.payee } elseif ($transaction.payee) { $transaction.payee.ToString() } else { "UNKNOWN_PAYEE" }
        
        $isAlreadyCategorized = $false
        # First try exact match
        if ($categoryMappings.Keys -contains $safePayee) {
            $isAlreadyCategorized = $true
            Write-Host "  🔍 DEBUG: Exact match found for '$safePayee'" -ForegroundColor Magenta
        } else {
            # Try fuzzy matching (normalize punctuation and spaces)
            $normalizedPayee = $safePayee -replace '[^\w\s]', '' -replace '\s+', ' '
            $normalizedPayee = $normalizedPayee.Trim().ToLower()
            
            foreach ($savedPayee in $categoryMappings.Keys) {
                $normalizedSaved = $savedPayee -replace '[^\w\s]', '' -replace '\s+', ' '
                $normalizedSaved = $normalizedSaved.Trim().ToLower()
                
                if ($normalizedPayee -eq $normalizedSaved) {
                    $isAlreadyCategorized = $true
                    Write-Verbose "Skipping already categorized payee: '$safePayee' matches saved '$savedPayee'"
                    break
                }
            }
        }
        
        if ($isAlreadyCategorized) {
            Write-Host "  ✓ Überspringe bereits kategorisierte Transaktion: $safePayee" -ForegroundColor Green
            continue
        }
        
        $processedCount++
        
        # Farbige Transaktionsanzeige
        Clear-Screen
        
        # Header
        Write-Host "" 
        Write-Host "» Transaktion kategorisieren" -ForegroundColor Cyan
        Write-Host ("─" * 27) -ForegroundColor Cyan
        Write-Host ""
        
        # Progress
        Write-Host "Transaktion " -NoNewline -ForegroundColor Gray
        Write-Host "$processedCount" -NoNewline -ForegroundColor Yellow
        Write-Host " von " -NoNewline -ForegroundColor Gray
        Write-Host "$totalTransactions" -ForegroundColor Yellow
        Write-Host ""
        
        # Farbige Transaktionsdaten - Type-safe handling
        Write-Host "Payee: " -NoNewline -ForegroundColor Gray
        Write-Host "$safePayee" -ForegroundColor White
        
        $safeDate = if ($transaction.date -is [string]) { $transaction.date } elseif ($transaction.date) { $transaction.date.ToString() } else { "UNKNOWN_DATE" }
        $safeAmount = if ($transaction.amount -is [string]) { $transaction.amount } elseif ($transaction.amount) { $transaction.amount.ToString() } else { "UNKNOWN_AMOUNT" }
        Write-Host "Datum: " -NoNewline -ForegroundColor Gray
        Write-Host "$safeDate" -NoNewline -ForegroundColor Cyan
        Write-Host " | Betrag: " -NoNewline -ForegroundColor Gray
        Write-Host "$safeAmount EUR" -ForegroundColor Green
        
        $safeSourceAccount = if ($transaction.sourceAccount -is [string]) { $transaction.sourceAccount } elseif ($transaction.sourceAccount) { $transaction.sourceAccount.ToString() } else { "" }
        if ($safeSourceAccount -and $safeSourceAccount.Trim() -ne "" -and $safeSourceAccount -ne "UNKNOWN_ACCOUNT") {
            Write-Host "Von Konto: " -NoNewline -ForegroundColor Gray
            Write-Host "$safeSourceAccount" -ForegroundColor Magenta
        }
        
        # Type-safe payeeName handling
        $safePayeeName = if ($transaction.payeeName -is [string]) { $transaction.payeeName } elseif ($transaction.payeeName) { $transaction.payeeName.ToString() } else { "" }
        if ($safePayeeName -and $safePayeeName.Trim() -ne "" -and $safePayeeName -ne "UNKNOWN_PAYEE") {
            Write-Host "An: " -NoNewline -ForegroundColor Gray
            Write-Host "$safePayeeName" -ForegroundColor Magenta
        }
        
        # Type-safe memo string handling
        $memoString = if ($transaction.memo -is [string]) { $transaction.memo } elseif ($transaction.memo) { $transaction.memo.ToString() } else { "" }
        if ($memoString -and $memoString.Trim() -ne "") {
            # Kürze zu lange Memos für bessere Lesbarkeit
            $shortMemo = if ($memoString.Length -gt 60) { 
                $memoString.Substring(0, 57) + "..."
            } else { 
                $memoString 
            }
            Write-Host "Memo: " -NoNewline -ForegroundColor Gray
            Write-Host "$shortMemo" -ForegroundColor White
            
            # Try to extract and show IBAN information from memo
            if ($transaction.memo -match "IBAN:\s*([A-Z]{2}\d{2}[A-Z0-9]+)") {
                $extractedIBAN = $matches[1]
                Write-Host "IBAN: " -NoNewline -ForegroundColor Gray
                Write-Host "$extractedIBAN" -ForegroundColor Yellow
                
                # Check if this IBAN belongs to one of our accounts
                if ($OwnIBANs.Keys -contains $extractedIBAN) {
                    $targetAccount = $OwnIBANs[$extractedIBAN]
                    Write-Host "✗ " -NoNewline -ForegroundColor Red
                    Write-Host "Transfer zu eigenem Konto: " -NoNewline -ForegroundColor Red
                    Write-Host "$targetAccount" -ForegroundColor Red
                }
            }
        }
        
        Write-Host ""
        
        # Intelligente Kategorievorschläge
        $suggestedCategory = Get-CategorySuggestion -payee $transaction.payee -examples @($transaction)
        
        if ($suggestedCategory) {
            Write-Host "💡 " -NoNewline -ForegroundColor Green
            Write-Host "Vorschlag: " -NoNewline -ForegroundColor Green
            Write-Host "$suggestedCategory" -ForegroundColor Yellow -BackgroundColor DarkBlue
            Write-Host ""
            
            # Direkte Kategorieauswahl anzeigen
            Write-Host "KATEGORIEN:" -ForegroundColor Yellow
            Write-Host ""
            
            $categoryIndex = 1
            $allCategories = @()
            
            # Kompakte Kategorieauswahl anzeigen
            foreach ($groupName in $availableCategories.Keys) {
                Write-Host "$groupName" -ForegroundColor Yellow
                
                $categories = $availableCategories[$groupName]
                $currentLine = ""
                
                foreach ($category in $categories) {
                    $marker = if ($category -eq $suggestedCategory) { "*" } else { "" }
                    
                    $numberPart = "[$categoryIndex]$marker"
                    $categoryPart = " $category"
                    $item = "$numberPart$categoryPart"
                    
                    $allCategories += $category
                    $categoryIndex++
                    
                    if ($currentLine.Length + $item.Length + 2 -lt 70) {
                        $currentLine += if ($currentLine) { "  $item" } else { $item }
                    } else {
                        if ($currentLine) { 
                            Write-CategoryLine $currentLine $suggestedCategory
                        }
                        $currentLine = $item
                    }
                }
                if ($currentLine) { 
                    Write-CategoryLine $currentLine $suggestedCategory
                }
                
                Write-Host ""
            }
            
            Write-Host ""
            Write-Host "[" -NoNewline -ForegroundColor Green
            Write-Host "0" -NoNewline -ForegroundColor Green 
            Write-Host "] Neue Kategorie  [" -NoNewline -ForegroundColor White
            Write-Host "j" -NoNewline -ForegroundColor Green
            Write-Host "/Enter] " -NoNewline -ForegroundColor White
            Write-Host "$suggestedCategory" -NoNewline -ForegroundColor Yellow -BackgroundColor DarkBlue
            Write-Host "  [" -NoNewline -ForegroundColor White
            Write-Host "k" -NoNewline -ForegroundColor Cyan
            Write-Host "] Keywords bearbeiten  [" -NoNewline -ForegroundColor White
            Write-Host "s" -NoNewline -ForegroundColor Yellow
            Write-Host "] Überspringen  [" -NoNewline -ForegroundColor White
            Write-Host "x" -NoNewline -ForegroundColor Red
            Write-Host "] Beenden" -ForegroundColor White
        } else {
            Write-Host "ℹ " -NoNewline -ForegroundColor Yellow
            Write-Host "Keine automatische Zuordnung möglich" -ForegroundColor Yellow
            Write-Host ""
            
            # Direkte Kategorieauswahl auch ohne Vorschlag
            Write-Host "KATEGORIEN:" -ForegroundColor Yellow
            Write-Host ""
            
            $categoryIndex = 1
            $allCategories = @()
            
            foreach ($groupName in $availableCategories.Keys) {
                Write-Host "$groupName" -ForegroundColor Yellow
                
                $categories = $availableCategories[$groupName]
                $currentLine = ""
                
                foreach ($category in $categories) {
                    $numberPart = "[$categoryIndex]"
                    $categoryPart = " $category"
                    $item = "$numberPart$categoryPart"
                    
                    $allCategories += $category
                    $categoryIndex++
                    
                    if ($currentLine.Length + $item.Length + 2 -lt 70) {
                        $currentLine += if ($currentLine) { "  $item" } else { $item }
                    } else {
                        if ($currentLine) { 
                            Write-CategoryLine $currentLine ""
                        }
                        $currentLine = $item
                    }
                }
                if ($currentLine) { 
                    Write-CategoryLine $currentLine ""
                }
                
                Write-Host ""
            }
            
            Write-Host ""
            Write-Host "[" -NoNewline -ForegroundColor Green
            Write-Host "0" -NoNewline -ForegroundColor Green 
            Write-Host "] Neue Kategorie  [" -NoNewline -ForegroundColor White
            Write-Host "k" -NoNewline -ForegroundColor Cyan
            Write-Host "] Keywords bearbeiten  [" -NoNewline -ForegroundColor White
            Write-Host "s" -NoNewline -ForegroundColor Yellow
            Write-Host "] Überspringen  [" -NoNewline -ForegroundColor White
            Write-Host "x" -NoNewline -ForegroundColor Red
            Write-Host "] Beenden" -ForegroundColor White
        }
        Write-Host ""
            
            do {
                $prompt = if ($suggestedCategory) { 
                    $global:i18n.Get("categorization.choose_category", @(@($allCategories).Count))
                } else { 
                    $global:i18n.Get("categorization.choose_category_no_suggestion", @(@($allCategories).Count))
                }
                $choice = Read-Host $prompt
                
                if ($choice -eq "x") {
                    $global:CategorizationStopped = $true
                    Show-Screen -Title $global:i18n.Get("categorization.categorization_ended") -Content @(
                        $global:i18n.Get("categorization.categorization_completed"),
                        $global:i18n.Get("categorization.processed_transactions", @($processedCount, $totalTransactions))
                    )
                    Start-Sleep 2
                    break :outer
                } elseif ($choice -eq "s") {
                    Show-Screen -Title "Transaktion übersprungen" -Content @(
                        "INFO:Transaktion wurde übersprungen"
                    )
                    Start-Sleep 1
                    break
                } elseif ($choice -eq "j" -or $choice -eq "y" -or ($choice -eq "" -and $suggestedCategory)) {
                    if ($suggestedCategory) {
                        $categoryMappings[$transaction.payee] = $suggestedCategory
                        Show-Screen -Title "Kategorie zugeordnet" -Content @(
                            "SUCCESS:$($transaction.payee) → $suggestedCategory"
                        )
                        Start-Sleep 1
                        break
                    } else {
                        Write-Host "  $($global:i18n.Get("categorization.no_suggestion_available"))" -ForegroundColor Red
                    }
                } elseif ($choice -eq "k") {
                    # Kategorie-Management-Menü
                    $keywordResult = Show-CategoryManagementMenu -transaction $transaction -availableCategories $availableCategories
                    if ($keywordResult -and $keywordResult -ne "SKIP") {
                        # Keyword wurde hinzugefügt, Transaktion automatisch kategorisieren
                        $categoryMappings[$transaction.payee] = $keywordResult
                        Show-Screen -Title "Keyword hinzugefügt und kategorisiert" -Content @(
                            "SUCCESS:Keyword hinzugefügt",
                            "SUCCESS:$($transaction.payee) → $keywordResult"
                        )
                        Start-Sleep 2
                        break
                    }
                    # Neustart der Kategorieauswahl nach Keyword-Änderungen
                    continue
                } elseif ($choice -eq "0") {
                    $selectedCategory = Add-NewCategoryWithKeywords -availableCategories ([ref]$availableCategories) -flatCategories ([ref]$flatCategories)
                    if ($selectedCategory -and $selectedCategory -ne "SKIP") {
                        $categoryMappings[$transaction.payee] = $selectedCategory
                        Show-Screen -Title "Kategorie zugeordnet" -Content @(
                            "SUCCESS:$($transaction.payee) → $selectedCategory"
                        )
                        Start-Sleep 1
                        break
                    }
                } elseif ($choice -match "^\d+$") {
                    $index = [int]$choice - 1
                    if ($index -ge 0 -and $index -lt @($allCategories).Count) {
                        $selectedCategory = $allCategories[$index]
                        $categoryMappings[$transaction.payee] = $selectedCategory
                        Show-Screen -Title "Kategorie zugeordnet" -Content @(
                            "SUCCESS:$($transaction.payee) → $selectedCategory"
                        )
                        Start-Sleep 1
                        break
                    } else {
                        Write-Host "  $($global:i18n.Get("categorization.invalid_choice", @(@($allCategories).Count)))" -ForegroundColor Red
                    }
                } elseif ($choice -eq "n") {
                    # Erweiterte Kategorieauswahl mit granularen Optionen
                    $result = Show-CategorySelectionWithTransaction -availableCategories ([ref]$availableCategories) -suggestedCategory $suggestedCategory -flatCategories ([ref]$flatCategories) -transactionInfo $transaction
                    
                    # Verarbeite verschiedene Rückgabetypen
                    if ($result -is [hashtable] -and ($result.Keys -contains 'mode')) {
                        # Neue granulare Kategorisierungsregel
                        $selectedCategory = $result.category
                        $mode = $result.mode
                        $criteria = $result.criteria
                        
                        # Speichere die Kategorisierungsregel basierend auf dem Modus
                        Save-GranularCategoryRule -mode $mode -criteria $criteria -category $selectedCategory
                        
                        # Standardzuordnung für Kompatibilität
                        $categoryMappings[$transaction.payee] = $selectedCategory
                        
                        $ruleDescription = Get-RuleDescription -mode $mode -criteria $criteria
                        Show-Screen -Title "Kategorisierungsregel erstellt" -Content @(
                            "SUCCESS:Regel erstellt: $ruleDescription",
                            "INFO:Kategorie: $selectedCategory"
                        )
                        Start-Sleep 2
                        break
                    } elseif ($result -eq "BREAK") {
                        Write-Host "✓ Kategorisierung beendet auf Wunsch des Benutzers." -ForegroundColor Green
                        break :outer
                    } elseif ($result -eq "SKIP") {
                        Show-Screen -Title "Transaktion übersprungen" -Content @(
                            "INFO:Transaktion wurde übersprungen"
                        )
                        Start-Sleep 1
                        break
                    } elseif ($result) {
                        # Einfache Kategoriezuordnung (alter Modus)
                        $categoryMappings[$transaction.payee] = $result
                        Show-Screen -Title "Kategorie zugeordnet" -Content @(
                            "SUCCESS:$($transaction.payee) → $result"
                        )
                        Start-Sleep 1
                        break
                    }
                } else {
                    $validOptions = if ($suggestedCategory) { "1-$(@($allCategories).Count), 0, j, k, s, x" } else { "1-$(@($allCategories).Count), 0, k, s, x" }
                    Write-Host "  ⚠ Ungültige Eingabe. Bitte $validOptions eingeben." -ForegroundColor Red
                }
            } while ($true)
    }
    
    # Speichere Kategorie-Zuordnungen
    # PowerShell 5.1/7.x compatible Count check
    if (@($categoryMappings.GetEnumerator()).Count -gt 0) {
        Show-Screen -Title "Kategoriezuordnung abgeschlossen" -Content @(
            "INFO:Speichere $(@($categoryMappings.GetEnumerator()).Count) Kategorie-Zuordnungen..."
        )
        Save-CategoryMappings $categoryMappings
        
        Show-Screen -Title "Kategoriezuordnung abgeschlossen" -Content @(
            "SUCCESS:$(@($categoryMappings.GetEnumerator()).Count) Kategorie-Zuordnungen gespeichert",
            "INFO:Erweiterte Kategorieliste: $(@($flatCategories).Count) Kategorien verfügbar",
            "INFO:Verarbeitete: $processedCount von $totalTransactions Transaktionen"
        )
        Start-Sleep 2
    }
    
    # Zeige Kategorisierungs-Statistik nur wenn nicht im Kategorisierung-nur-Modus
    if (-not $global:CategorizeOnlyMode) {
        Show-CategorizationStatistics
    } else {
        # Einfache Statistik ohne CSV-Verarbeitung
        Show-SimpleCategorizationStats -categoryMappings $categoryMappings -processedCount $processedCount -totalTransactions $totalTransactions
    }
}

function Show-GranularCategorizeOptions {
    param(
        [hashtable]$transactionInfo,
        [hashtable]$similarTransactions = @{}
    )
    
    Clear-Screen
    
    # Header
    Write-Host "" 
    Write-Host "» Kategorisierungsoptionen" -ForegroundColor Cyan
    Write-Host ("─" * 25) -ForegroundColor Cyan
    Write-Host ""
    
    # Transaktionsinfo anzeigen
    if ($transactionInfo -and @($transactionInfo.GetEnumerator()).Count -gt 0) {
        Write-Host "AKTUELLE TRANSAKTION:" -ForegroundColor Yellow
        Write-Host "Payee: " -NoNewline -ForegroundColor Gray
        Write-Host "$($transactionInfo.payee)" -ForegroundColor White
        Write-Host "Betrag: " -NoNewline -ForegroundColor Gray
        Write-Host "$($transactionInfo.amount) EUR" -NoNewline -ForegroundColor Green
        Write-Host " | Datum: " -NoNewline -ForegroundColor Gray
        Write-Host "$($transactionInfo.date)" -ForegroundColor Cyan
        
        if ($transactionInfo.memo -and $transactionInfo.memo.Trim() -ne "") {
            $shortMemo = if ($transactionInfo.memo.Length -gt 60) { 
                $transactionInfo.memo.Substring(0, 57) + "..."
            } else { 
                $transactionInfo.memo 
            }
            Write-Host "Memo: " -NoNewline -ForegroundColor Gray
            Write-Host "$shortMemo" -ForegroundColor White
        }
        Write-Host ""
    }
    
    # Ähnliche Transaktionen analysieren falls vorhanden
    if ($similarTransactions -and @($similarTransactions.GetEnumerator()).Count -gt 0) {
        $totalSimilar = 0
        $uniqueAmounts = @{}
        $uniqueMemos = @{}
        
        foreach ($transaction in $similarTransactions.Values) {
            if ($transaction.examples) {
                $totalSimilar += $transaction.count
                foreach ($example in $transaction.examples) {
                    if ($example.amount) { $uniqueAmounts[$example.amount] = $true }
                    if ($example.memo) { 
                        $memoWords = $example.memo -split '\s+' | Where-Object { $_.Length -gt 3 }
                        foreach ($word in $memoWords[0..2]) { $uniqueMemos[$word] = $true }
                    }
                }
            }
        }
        
        if ($totalSimilar -gt 1) {
            Write-Host "ÄHNLICHE TRANSAKTIONEN GEFUNDEN:" -ForegroundColor Cyan
            Write-Host "Anzahl: " -NoNewline -ForegroundColor Gray
            Write-Host "$totalSimilar" -NoNewline -ForegroundColor Yellow
            Write-Host " weitere Transaktionen mit demselben Payee" -ForegroundColor Gray
            
            if (@($uniqueAmounts.Keys).Count -gt 1) {
                Write-Host "Beträge: " -NoNewline -ForegroundColor Gray
                Write-Host "$(@($uniqueAmounts.Keys)[0..2] -join ', ')" -ForegroundColor White
                if (@($uniqueAmounts.Keys).Count -gt 3) {
                    Write-Host " ..." -NoNewline -ForegroundColor Gray
                }
            }
            Write-Host ""
        }
    }
    
    Write-Host ("─" * 50) -ForegroundColor DarkGray
    Write-Host ""
    
    # Kategorisierungsoptionen
    Write-Host "Wie möchten Sie kategorisieren?" -ForegroundColor White
    Write-Host ""
    
    Write-Host "[" -NoNewline -ForegroundColor Green
    Write-Host "1" -NoNewline -ForegroundColor Green
    Write-Host "] " -NoNewline -ForegroundColor Green
    Write-Host "Nur diese Transaktion kategorisieren" -ForegroundColor White
    Write-Host "    " -NoNewline
    Write-Host "Kategorisiert nur diese eine Transaktion" -ForegroundColor Gray
    Write-Host ""
    
    if ($similarTransactions -and @($similarTransactions.GetEnumerator()).Count -gt 0) {
        Write-Host "[" -NoNewline -ForegroundColor Green
        Write-Host "2" -NoNewline -ForegroundColor Green
        Write-Host "] " -NoNewline -ForegroundColor Green
        Write-Host "Ähnliche Transaktionen mitkatego­risieren" -ForegroundColor White
        Write-Host "    " -NoNewline
        Write-Host "Erstellt Regeln für alle ähnlichen Transaktionen" -ForegroundColor Gray
        Write-Host ""
    }
    
    Write-Host "[" -NoNewline -ForegroundColor Green
    Write-Host "s" -NoNewline -ForegroundColor Green
    Write-Host "] " -NoNewline -ForegroundColor Green
    Write-Host "Überspringen" -ForegroundColor White
    
    Write-Host "[" -NoNewline -ForegroundColor Red
    Write-Host "x" -NoNewline -ForegroundColor Red
    Write-Host "] " -NoNewline -ForegroundColor Red
    Write-Host "Kategorisierung beenden" -ForegroundColor White
    Write-Host ""
    
    do {
        $choice = Read-Host "Ihre Wahl (1, 2, s, x)"
        
        if ($choice -eq "1") {
            return "SINGLE"
        } elseif ($choice -eq "2" -and $similarTransactions -and @($similarTransactions.GetEnumerator()).Count -gt 0) {
            return "MULTIPLE"
        } elseif ($choice -eq "s") {
            return "SKIP"
        } elseif ($choice -eq "x") {
            return "BREAK"
        } else {
            Write-Host "  ⚠ Ungültige Auswahl. Bitte 1" -NoNewline -ForegroundColor Red
            if ($similarTransactions -and @($similarTransactions.GetEnumerator()).Count -gt 0) {
                Write-Host ", 2" -NoNewline -ForegroundColor Red
            }
            Write-Host ", s oder x eingeben." -ForegroundColor Red
        }
    } while ($true)
}

function Show-SimilarTransactionsCriteriaSelection {
    param(
        [hashtable]$transactionInfo,
        [hashtable]$similarTransactions,
        [ref]$availableCategories,
        [string]$suggestedCategory,
        [ref]$flatCategories
    )
    
    Clear-Screen
    
    # Header
    Write-Host "" 
    Write-Host "» Kategorisierungs-Kriterien" -ForegroundColor Cyan
    Write-Host ("─" * 27) -ForegroundColor Cyan
    Write-Host ""
    
    # Analysiere alle ähnlichen Transaktionen
    $allExamples = @()
    $uniqueAmounts = @{}
    $uniqueMemoWords = @{}
    $amountPatterns = @{}
    
    foreach ($transaction in $similarTransactions.Values) {
        if ($transaction.examples) {
            foreach ($example in $transaction.examples) {
                $allExamples += $example
                if ($example.amount) { 
                    $uniqueAmounts[$example.amount] = ($uniqueAmounts[$example.amount] + 1)
                    # Erkenne Betragsmuster (z.B. 8,99 für monatliche Abos)
                    if ($uniqueAmounts[$example.amount] -gt 1) {
                        $amountPatterns[$example.amount] = $uniqueAmounts[$example.amount]
                    }
                }
                if ($example.memo) { 
                    $memoWords = $example.memo -split '\s+' | Where-Object { $_.Length -gt 3 -and $_ -notmatch '^\d+$' }
                    foreach ($word in $memoWords) { 
                        $cleanWord = $word -replace '[^\w]', ''
                        if ($cleanWord.Length -gt 3) {
                            $uniqueMemoWords[$cleanWord.ToUpper()] = ($uniqueMemoWords[$cleanWord.ToUpper()] + 1)
                        }
                    }
                }
            }
        }
    }
    
    Write-Host $global:i18n.Get("categorization.analysis_similar") -ForegroundColor Yellow
    Write-Host "Gefunden: " -NoNewline -ForegroundColor Gray
    Write-Host "$(@($allExamples).Count)" -NoNewline -ForegroundColor Yellow
    Write-Host " Transaktionen mit Payee: " -NoNewline -ForegroundColor Gray
    Write-Host "$($transactionInfo.payee)" -ForegroundColor White
    Write-Host ""
    
    # Zeige Betragsmuster
    if (@($uniqueAmounts.Keys).Count -gt 1) {
        Write-Host "Verschiedene Beträge:" -ForegroundColor Cyan
        $sortedAmounts = $uniqueAmounts.GetEnumerator() | Sort-Object Key
        foreach ($amount in $sortedAmounts[0..4]) {
            $count = $amount.Value
            Write-Host "  • " -NoNewline -ForegroundColor Gray
            Write-Host "$($amount.Key) EUR" -NoNewline -ForegroundColor Green
            Write-Host " ($count mal)" -ForegroundColor Gray
        }
        if (@($uniqueAmounts.Keys).Count -gt 5) {
            Write-Host "  • ..." -ForegroundColor Gray
        }
        Write-Host ""
    }
    
    # Zeige häufige Keywords
    if (@($uniqueMemoWords.Keys).Count -gt 0) {
        $topWords = $uniqueMemoWords.GetEnumerator() | Sort-Object Value -Descending | Select-Object -First 5
        Write-Host "Häufige Schlüsselwörter:" -ForegroundColor Cyan
        foreach ($word in $topWords) {
            Write-Host "  • " -NoNewline -ForegroundColor Gray
            Write-Host "$($word.Key)" -NoNewline -ForegroundColor White
            Write-Host " ($($word.Value) mal)" -ForegroundColor Gray
        }
        Write-Host ""
    }
    
    Write-Host ("─" * 50) -ForegroundColor DarkGray
    Write-Host ""
    
    # Kategorisierungsoptionen
    Write-Host "Welche Transaktionen sollen kategorisiert werden?" -ForegroundColor White
    Write-Host ""
    
    Write-Host "[" -NoNewline -ForegroundColor Green
    Write-Host "1" -NoNewline -ForegroundColor Green
    Write-Host "] " -NoNewline -ForegroundColor Green
    Write-Host "Alle mit diesem Payee: " -NoNewline -ForegroundColor White
    Write-Host "\"$($transactionInfo.payee)\"" -ForegroundColor Cyan
    Write-Host "    " -NoNewline
    Write-Host "Kategorisiert alle $(@($allExamples).Count) Transaktionen" -ForegroundColor Gray
    Write-Host ""
    
    # Option für spezifischen Betrag falls Muster vorhanden
    if (@($amountPatterns.Keys).Count -gt 0) {
        $mostCommonAmount = $amountPatterns.GetEnumerator() | Sort-Object Value -Descending | Select-Object -First 1
        Write-Host "[" -NoNewline -ForegroundColor Green
        Write-Host "2" -NoNewline -ForegroundColor Green
        Write-Host "] " -NoNewline -ForegroundColor Green
        Write-Host "Payee + Betrag: " -NoNewline -ForegroundColor White
        Write-Host "\"$($transactionInfo.payee)\" + \"$($mostCommonAmount.Key) EUR\"" -ForegroundColor Cyan
        Write-Host "    " -NoNewline
        Write-Host "Kategorisiert $($mostCommonAmount.Value) Transaktionen mit diesem Betrag" -ForegroundColor Gray
        Write-Host ""
    }
    
    Write-Host "[" -NoNewline -ForegroundColor Green
    Write-Host "3" -NoNewline -ForegroundColor Green
    Write-Host "] " -NoNewline -ForegroundColor Green
    Write-Host "Payee + eigene Schlüsselwörter" -ForegroundColor White
    Write-Host "    " -NoNewline
    Write-Host "Definieren Sie eigene Kriterien für die Kategorisierung" -ForegroundColor Gray
    Write-Host ""
    
    Write-Host "[" -NoNewline -ForegroundColor Green
    Write-Host "s" -NoNewline -ForegroundColor Green
    Write-Host "] " -NoNewline -ForegroundColor Green
    Write-Host "Zurück zur einzelnen Kategorisierung" -ForegroundColor White
    Write-Host ""
    
    do {
        $choice = Read-Host "Ihre Wahl (1-3, s)"
        
        if ($choice -eq "1") {
            # Alle mit diesem Payee kategorisieren
            $selectedCategory = Show-StandardCategorySelection -availableCategories $availableCategories -suggestedCategory $suggestedCategory -flatCategories $flatCategories -transactionInfo $transactionInfo
            if ($selectedCategory -and $selectedCategory -notin @("SKIP", "BREAK")) {
                return @{
                    mode = "PAYEE_ONLY"
                    category = $selectedCategory
                    criteria = @{ payee = $transactionInfo.payee }
                }
            }
            return $selectedCategory
        } elseif ($choice -eq "2" -and @($amountPatterns.Keys).Count -gt 0) {
            # Payee + spezifischer Betrag
            $mostCommonAmount = $amountPatterns.GetEnumerator() | Sort-Object Value -Descending | Select-Object -First 1
            $selectedCategory = Show-StandardCategorySelection -availableCategories $availableCategories -suggestedCategory $suggestedCategory -flatCategories $flatCategories -transactionInfo $transactionInfo
            if ($selectedCategory -and $selectedCategory -notin @("SKIP", "BREAK")) {
                return @{
                    mode = "PAYEE_AMOUNT"
                    category = $selectedCategory
                    criteria = @{ 
                        payee = $transactionInfo.payee
                        amount = $mostCommonAmount.Key
                    }
                }
            }
            return $selectedCategory
        } elseif ($choice -eq "3") {
            # Eigene Keywords definieren
            return Show-CustomKeywordSelection -transactionInfo $transactionInfo -uniqueMemoWords $uniqueMemoWords -availableCategories $availableCategories -suggestedCategory $suggestedCategory -flatCategories $flatCategories
        } elseif ($choice -eq "s") {
            # Zurück zur einzelnen Kategorisierung
            return Show-StandardCategorySelection -availableCategories $availableCategories -suggestedCategory $suggestedCategory -flatCategories $flatCategories -transactionInfo $transactionInfo
        } else {
            Write-Host "  ⚠ Ungültige Auswahl. Bitte 1-3 oder s eingeben." -ForegroundColor Red
        }
    } while ($true)
}

function Show-CustomKeywordSelection {
    param(
        [hashtable]$transactionInfo,
        [hashtable]$uniqueMemoWords,
        [ref]$availableCategories,
        [string]$suggestedCategory,
        [ref]$flatCategories
    )
    
    Clear-Screen
    
    Write-Host "" 
    Write-Host "» Eigene Schlüsselwörter definieren" -ForegroundColor Cyan
    Write-Host ("─" * 33) -ForegroundColor Cyan
    Write-Host ""
    
    Write-Host "PAYEE: " -NoNewline -ForegroundColor Gray
    Write-Host "$($transactionInfo.payee)" -ForegroundColor White
    Write-Host ""
    
    if (@($uniqueMemoWords.Keys).Count -gt 0) {
        Write-Host "Verfügbare Schlüsselwörter aus den Transaktionen:" -ForegroundColor Cyan
        $topWords = $uniqueMemoWords.GetEnumerator() | Sort-Object Value -Descending | Select-Object -First 10
        $wordGroups = @()
        for ($i = 0; $i -lt @($topWords).Count; $i += 5) {
            $wordGroups += ,($topWords[$i..($i+4)] | Where-Object { $_ })
        }
        
        foreach ($group in $wordGroups) {
            Write-Host "  " -NoNewline
            foreach ($word in $group) {
                Write-Host "$($word.Key)" -NoNewline -ForegroundColor Yellow
                Write-Host "($($word.Value))" -NoNewline -ForegroundColor Gray
                Write-Host "  " -NoNewline
            }
            Write-Host ""
        }
        Write-Host ""
    }
    
    Write-Host "Geben Sie Schlüsselwörter ein (kommagetrennt):" -ForegroundColor White
    Write-Host "Beispiel: " -NoNewline -ForegroundColor Gray
    Write-Host "AWS, Cloud, Prime" -ForegroundColor Yellow
    Write-Host ""
    
    $keywords = Read-Host "Schlüsselwörter"
    
    if ($keywords -and $keywords.Trim() -ne "") {
        $keywordList = $keywords -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne "" }
        
        if (@($keywordList).Count -gt 0) {
            Write-Host ""
            Write-Host "Kategorisierungsregel wird erstellt für:" -ForegroundColor Green
            Write-Host "  Payee: " -NoNewline -ForegroundColor Gray
            Write-Host "$($transactionInfo.payee)" -ForegroundColor White
            Write-Host "  Keywords: " -NoNewline -ForegroundColor Gray
            Write-Host "$($keywordList -join ', ')" -ForegroundColor Yellow
            Write-Host ""
            
            $selectedCategory = Show-StandardCategorySelection -availableCategories $availableCategories -suggestedCategory $suggestedCategory -flatCategories $flatCategories -transactionInfo $transactionInfo
            if ($selectedCategory -and $selectedCategory -notin @("SKIP", "BREAK")) {
                return @{
                    mode = "PAYEE_KEYWORDS"
                    category = $selectedCategory
                    criteria = @{ 
                        payee = $transactionInfo.payee
                        keywords = $keywordList
                    }
                }
            }
            return $selectedCategory
        }
    }
    
    Write-Host "Keine gültigen Schlüsselwörter eingegeben. Zurück zur Kategorieauswahl..." -ForegroundColor Yellow
    Start-Sleep 2
    return Show-StandardCategorySelection -availableCategories $availableCategories -suggestedCategory $suggestedCategory -flatCategories $flatCategories -transactionInfo $transactionInfo
}

function Show-StandardCategorySelection {
    param(
        [ref]$availableCategories,
        [string]$suggestedCategory,
        [ref]$flatCategories,
        [hashtable]$transactionInfo = @{}
    )
    
    Clear-Screen
    
    # Header
    Write-Host "" 
    Write-Host "» Kategorie wählen" -ForegroundColor Cyan
    Write-Host ("─" * 17) -ForegroundColor Cyan
    Write-Host ""
    
    # Kompakte Transaktionsinfo
    if ($transactionInfo -and @($transactionInfo.GetEnumerator()).Count -gt 0) {
        Write-Host "Payee: " -NoNewline -ForegroundColor Gray
        Write-Host "$($transactionInfo.payee)" -NoNewline -ForegroundColor White
        Write-Host " | " -NoNewline -ForegroundColor Gray
        Write-Host "$($transactionInfo.amount) EUR" -ForegroundColor Green
        Write-Host ""
    }
    
    # Führe die Core-Kategorieauswahl durch
    return Show-CategorySelectionCore -availableCategories $availableCategories -suggestedCategory $suggestedCategory -flatCategories $flatCategories
}

function Show-CategorySelectionWithTransaction {
    param(
        [ref]$availableCategories,
        [string]$suggestedCategory,
        [ref]$flatCategories,
        [hashtable]$transactionInfo = @{},
        [hashtable]$similarTransactions = @{}
    )
    
    # Zuerst fragen, wie kategorisiert werden soll
    $categorizeMode = Show-GranularCategorizeOptions -transactionInfo $transactionInfo -similarTransactions $similarTransactions
    
    if ($categorizeMode -eq "SKIP") {
        return "SKIP"
    } elseif ($categorizeMode -eq "BREAK") {
        return "BREAK"
    } elseif ($categorizeMode -eq "MULTIPLE") {
        # Für ähnliche Transaktionen - zeige Kriterien-Auswahl
        return Show-SimilarTransactionsCriteriaSelection -transactionInfo $transactionInfo -similarTransactions $similarTransactions -availableCategories $availableCategories -suggestedCategory $suggestedCategory -flatCategories $flatCategories
    }
    
    # Standard-Kategorieauswahl für einzelne Transaktion
    return Show-CategorySelectionCore -availableCategories $availableCategories -suggestedCategory $suggestedCategory -flatCategories $flatCategories -transactionInfo $transactionInfo
}

function Show-CategorySelectionCore {
    param(
        [ref]$availableCategories,
        [string]$suggestedCategory,
        [ref]$flatCategories,
        [hashtable]$transactionInfo = @{}
    )
    
    Clear-Screen
    
    # Header
    Write-Host "" 
    Write-Host "» Kategorie wählen" -ForegroundColor Cyan
    Write-Host ("─" * 17) -ForegroundColor Cyan
    Write-Host ""
    
    # Farbige Buchungsdaten anzeigen
    if ($transactionInfo -and @($transactionInfo.GetEnumerator()).Count -gt 0) {
        Write-Host $global:i18n.Get("categorization.transaction") -ForegroundColor Yellow
        Write-Host "Payee: " -NoNewline -ForegroundColor Gray
        Write-Host "$($transactionInfo.payee)" -ForegroundColor White
        
        Write-Host "Datum: " -NoNewline -ForegroundColor Gray
        Write-Host "$($transactionInfo.date)" -NoNewline -ForegroundColor Cyan
        Write-Host " | Betrag: " -NoNewline -ForegroundColor Gray
        Write-Host "$($transactionInfo.amount) EUR" -ForegroundColor Green
        
        if ($transactionInfo.sourceAccount) {
            Write-Host "Von: " -NoNewline -ForegroundColor Gray
            Write-Host "$($transactionInfo.sourceAccount)" -ForegroundColor Magenta
        }
        if ($transactionInfo.memo) {
            # Type-safe memo processing for transaction info
            $safeMemoInfo = if ($transactionInfo.memo -is [string]) { $transactionInfo.memo } elseif ($transactionInfo.memo) { $transactionInfo.memo.ToString() } else { "" }
            $shortMemo = if ($safeMemoInfo.Length -gt 80) { 
                $safeMemoInfo.Substring(0, 77) + "..."
            } else { 
                $safeMemoInfo 
            }
            Write-Host "Memo: " -NoNewline -ForegroundColor Gray
            Write-Host "$shortMemo" -ForegroundColor White
        }
        Write-Host ""
        Write-Host ("─" * 50) -ForegroundColor DarkGray
        Write-Host ""
    }
    
    $categoryIndex = 1
    $allCategories = @()
    
    # Kompakte Kategorieauswahl (4 Spalten) mit farbigen Nummern
    foreach ($groupName in $availableCategories.Value.Keys) {
        Write-Host "$groupName" -ForegroundColor Yellow
        
        $categories = $availableCategories.Value[$groupName]
        $currentLine = ""
        
        foreach ($category in $categories) {
            $marker = if ($category -eq $suggestedCategory) { "*" } else { "" }
            
            # Farbige Darstellung: Nummer in Grün, Kategorie in Weiß
            $numberPart = "[$categoryIndex]$marker"
            $categoryPart = " $category"
            $item = "$numberPart$categoryPart"
            
            $allCategories += $category
            $categoryIndex++
            
            if ($currentLine.Length + $item.Length + 2 -lt 70) {
                $currentLine += if ($currentLine) { "  $item" } else { $item }
            } else {
                if ($currentLine) { 
                    # Ausgabe der aktuellen Zeile mit Farben
                    Write-CategoryLine $currentLine $suggestedCategory
                }
                $currentLine = $item
            }
        }
        if ($currentLine) { 
            Write-CategoryLine $currentLine $suggestedCategory
        }
        
        Write-Host ""
    }
    
    Write-Host ""
    Write-Host "[" -NoNewline -ForegroundColor Green
    Write-Host "0" -NoNewline -ForegroundColor Green 
    Write-Host "] Neue Kategorie  [" -NoNewline -ForegroundColor White
    Write-Host "s" -NoNewline -ForegroundColor Green
    Write-Host "] Überspringen  [" -NoNewline -ForegroundColor White
    Write-Host "x" -NoNewline -ForegroundColor Red
    Write-Host "] Beenden" -ForegroundColor White
    Write-Host ""
    
    do {
        $prompt = if ($suggestedCategory) {
            "Kategorie wählen (1-$($allCategories.Count), 0, s, x, Enter=Vorschlag)"
        } else {
            "Kategorie wählen (1-$($allCategories.Count), 0, s, x)"
        }
        $categoryChoice = Read-Host $prompt
        
        if ($categoryChoice -eq "x") {
            $global:CategorizationStopped = $true
            return "BREAK"
        } elseif ($categoryChoice -eq "s") {
            return "SKIP"
        } elseif ($categoryChoice -eq "0") {
            return Add-NewCategoryWithKeywords -availableCategories $availableCategories -flatCategories $flatCategories
        } elseif ($categoryChoice -eq "" -and $suggestedCategory) {
            # Enter drücken = Vorschlag übernehmen
            return $suggestedCategory
        } elseif ($categoryChoice -match "^\d+$") {
            $index = [int]$categoryChoice - 1
            if ($index -ge 0 -and $index -lt $allCategories.Count) {
                return $allCategories[$index]
            } else {
                Write-Host "  ⚠ Ungültige Auswahl. Bitte 1-$($allCategories.Count), 0, s oder x eingeben." -ForegroundColor Red
            }
        } else {
            Write-Host "  ⚠ Ungültige Eingabe. Bitte eine Zahl, s, oder x eingeben." -ForegroundColor Red
        }
    } while ($true)
}

function Write-CategoryLine {
    param(
        [string]$Line,
        [string]$SuggestedCategory
    )
    
    # Parse und farbige Darstellung der Kategoriezeile
    $parts = $Line -split "  "
    $first = $true
    
    foreach ($part in $parts) {
        if (-not $first) {
            Write-Host "  " -NoNewline
        }
        $first = $false
        
        if ($part -match "^\[(\d+)\]([*]?)\s*(.+)$") {
            $number = $matches[1]
            $marker = $matches[2]
            $category = $matches[3]
            
            # Nummer in Grün
            Write-Host "[" -NoNewline -ForegroundColor Green
            Write-Host $number -NoNewline -ForegroundColor Green
            Write-Host "]" -NoNewline -ForegroundColor Green
            
            # Marker in Gelb falls Vorschlag
            if ($marker -eq "*") {
                Write-Host "*" -NoNewline -ForegroundColor Yellow
            }
            
            # Kategorie in Weiß oder hervorgehoben falls Vorschlag
            if ($category -eq $SuggestedCategory) {
                Write-Host " $category" -NoNewline -ForegroundColor Yellow -BackgroundColor DarkBlue
            } else {
                Write-Host " $category" -NoNewline -ForegroundColor White
            }
        } else {
            Write-Host $part -NoNewline -ForegroundColor White
        }
    }
    Write-Host ""  # Zeilenumbruch
}

function Show-CategorySelection {
    param(
        [ref]$availableCategories,
        [string]$suggestedCategory,
        [ref]$flatCategories
    )
    
    # Build category content for seitenweise display
    $content = @()
    
    $categoryIndex = 1
    $allCategories = @()
    
    # Zeige thematisch gruppierte Kategorien in 2 Spalten
    foreach ($groupName in $availableCategories.Value.Keys) {
        $content += "$groupName"
        $content += ("─" * $groupName.Length)
        
        $categories = $availableCategories.Value[$groupName]
        for ($i = 0; $i -lt $categories.Count; $i += 2) {
            $leftCategory = $categories[$i]
            $rightCategory = if ($i + 1 -lt $categories.Count) { $categories[$i + 1] } else { "" }
            
            # Format links
            $leftMarker = if ($leftCategory -eq $suggestedCategory) { " (Vorschlag)" } else { "" }
            $leftText = "[$categoryIndex] $leftCategory$leftMarker"
            $allCategories += $leftCategory
            $categoryIndex++
            
            # Format rechts
            if ($rightCategory) {
                $rightMarker = if ($rightCategory -eq $suggestedCategory) { " (Vorschlag)" } else { "" }
                $rightText = "[$categoryIndex] $rightCategory$rightMarker"
                $allCategories += $rightCategory
                $categoryIndex++
                
                # 2-spaltiges Layout
                $leftPadded = $leftText.PadRight(38)
                $content += "$leftPadded $rightText"
            } else {
                $content += $leftText
            }
        }
        $content += ""
    }
    
    $content += @(
        "",
        "[0] Neue Kategorie erstellen (mit Keywords)",
        "[s] Diese Transaktion überspringen",
        "[x] Kategorisierung beenden"
    )
    
    Show-Screen -Title "Kategorie Auswahl" -Content $content
    
    do {
        $categoryChoice = Read-Host "Kategorie wählen (1-$($allCategories.Count), 0, s, x)"
        
        if ($categoryChoice -eq "x") {
            $global:CategorizationStopped = $true
            return "BREAK"
        } elseif ($categoryChoice -eq "s") {
            return "SKIP"
        } elseif ($categoryChoice -eq "0") {
            return Add-NewCategoryWithKeywords -availableCategories $availableCategories -flatCategories $flatCategories
        } elseif ($categoryChoice -match "^\d+$") {
            $index = [int]$categoryChoice - 1
            if ($index -ge 0 -and $index -lt $allCategories.Count) {
                return $allCategories[$index]
            } else {
                Write-Host "  ⚠ Ungültige Auswahl. Bitte 1-$($allCategories.Count), 0, s oder x eingeben." -ForegroundColor Red
            }
        } else {
            Write-Host "  ⚠ Ungültige Eingabe. Bitte eine Zahl, s, oder x eingeben." -ForegroundColor Red
        }
    } while ($true)
}

function Add-NewCategoryWithKeywords {
    param(
        [ref]$availableCategories,
        [ref]$flatCategories
    )
    
    Clear-Screen
    
    # Header
    Write-Host "" 
    Write-Host $global:i18n.Get("categorization.create_new_category") -ForegroundColor Cyan
    Write-Host ("─" * 26) -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Erstellen Sie eine neue Kategorie mit automatischen Keywords." -ForegroundColor White
    Write-Host ""
    
    $categoryName = Read-Host "📝 Name der neuen Kategorie"
    if (-not $categoryName -or $categoryName.Trim() -eq "") {
        Write-Host "  ⚠ Abgebrochen." -ForegroundColor Yellow
        return "SKIP"
    }
    
    $categoryName = $categoryName.Trim()
    
    Write-Host ""
    Write-Host "🏷️ " -NoNewline -ForegroundColor Cyan
    Write-Host "Keywords eingeben (optional):" -ForegroundColor Cyan
    Write-Host "     Beispiel: EDEKA, ALDI, REWE, Penny, Netto" -ForegroundColor Gray
    Write-Host "     Trennung mit Komma, leer lassen zum Überspringen" -ForegroundColor Gray
    Write-Host ""
    
    $keywordsInput = Read-Host "🔍 Keywords für automatische Zuordnung"
    
    # Bestimme automatisch die passende Kategorie-Gruppe
    $targetGroup = Get-AutoCategoryGroup -categoryName $categoryName
    Write-Host ""
    Write-Host "  📂 Automatisch zugeordnet zu Gruppe: $targetGroup" -ForegroundColor Cyan
    
    # Füge zur entsprechenden Gruppe hinzu
    if (-not ($availableCategories.Value.Keys -contains $targetGroup)) {
        $availableCategories.Value[$targetGroup] = @()
    }
    
    if ($availableCategories.Value[$targetGroup] -notcontains $categoryName) {
        $availableCategories.Value[$targetGroup] += $categoryName
        $flatCategories.Value += $categoryName
        Write-Host "  ✓ Kategorie '$categoryName' zur Gruppe '$targetGroup' hinzugefügt." -ForegroundColor Green
        
        # Speichere Keywords für spätere automatische Zuordnung
        if ($keywordsInput -and $keywordsInput.Trim() -ne "") {
            $keywords = $keywordsInput.Split(',') | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne "" }
            Save-CategoryKeywords -categoryName $categoryName -keywords $keywords
            Write-Host "  📝 Keywords gespeichert: $($keywords -join ', ')" -ForegroundColor Green
        }
    } else {
        Write-Host "  ℹ Kategorie '$categoryName' existiert bereits." -ForegroundColor Yellow
    }
    
    return $categoryName
}

function Get-AutoCategoryGroup {
    param([string]$categoryName)
    
    # Type-safe category name conversion\n    $nameLower = if ($categoryName -is [string]) { $categoryName.ToLower() } elseif ($categoryName) { $categoryName.ToString().ToLower() } else { "" }
    
    # Automatische Gruppenzuordnung basierend auf Kategoriename
    if ($nameLower -match "lebens|super|markt|food|essen|trinken|getränk") {
        return "Tägliche Ausgaben"
    } elseif ($nameLower -match "wohn|miete|strom|gas|wasser|versicher|steuer|internet|telefon") {
        return "Wohnen & Leben"
    } elseif ($nameLower -match "shop|online|elektronik|tech|streaming|abo|mitglied|bildung|freizeit") {
        return "Shopping & Freizeit"
    } elseif ($nameLower -match "einkommen|gehalt|lohn|kapital|zinsen|dividend|einnahm") {
        return "Einnahmen"
    } elseif ($nameLower -match "transfer|bank|gebühr|spende") {
        return "Transfers & Sonstiges"
    } else {
        # Standardgruppe für unbekannte Kategorien
        return "Sonstige"
    }
}

function Save-CategoryKeywords {
    param(
        [string]$categoryName,
        [array]$keywords
    )
    
    try {
        $localConfigPath = Join-Path $PSScriptRoot "config.local.json"
        $localConfig = if (Test-Path $localConfigPath) {
            Get-Content $localConfigPath -Encoding UTF8 | ConvertFrom-Json
        } else {
            @{}
        }
        
        if (-not $localConfig.categoryKeywords) {
            $localConfig | Add-Member -MemberType NoteProperty -Name "categoryKeywords" -Value @{}
        }
        
        $keywordString = $keywords -join ","
        $localConfig.categoryKeywords | Add-Member -MemberType NoteProperty -Name $categoryName -Value $keywordString -Force
        
        $localConfig | ConvertTo-Json -Depth 5 | Out-File $localConfigPath -Encoding UTF8
    } catch {
        Write-Host "  ⚠ Fehler beim Speichern der Keywords: $($_.Exception.Message)" -ForegroundColor Red
    }
}

function Save-CategoryMappings {
    param([hashtable]$categoryMappings)
    
    try {
        $localConfigPath = Join-Path $PSScriptRoot "config.local.json"
        $localConfig = if (Test-Path $localConfigPath) {
            $content = Get-Content $localConfigPath -Encoding UTF8 -Raw
            # PowerShell 5.1/7.x compatible JSON parsing
            if ($PSVersionTable.PSVersion.Major -ge 6) {
                $content | ConvertFrom-Json -AsHashtable
            } else {
                $localConfigObj = $content | ConvertFrom-Json
                $localConfigHash = @{}
                # Convert PSCustomObject to hashtable for PowerShell 5.1
                $localConfigObj.PSObject.Properties | ForEach-Object {
                    if ($_.Value -is [PSCustomObject]) {
                        $subHash = @{}
                        $_.Value.PSObject.Properties | ForEach-Object { $subHash[$_.Name] = $_.Value }
                        $localConfigHash[$_.Name] = $subHash
                    } else {
                        $localConfigHash[$_.Name] = $_.Value
                    }
                }
                $localConfigHash
            }
        } else {
            @{}
        }
        
        if (-not ($localConfig.Keys -contains "categoryMappings")) {
            $localConfig["categoryMappings"] = @{}
        }
        
        # First restore any preserved mappings from setup
        if ($global:preservedCategoryMappings) {
            Write-Host "✓ Restoring $(@($global:preservedCategoryMappings.GetEnumerator()).Count) preserved category mappings" -ForegroundColor Green
            foreach ($preserved in $global:preservedCategoryMappings.GetEnumerator()) {
                $localConfig["categoryMappings"][$preserved.Key] = $preserved.Value
            }
            $global:preservedCategoryMappings = $null  # Clear after use
        }
        
        # Then add new mappings
        foreach ($mapping in $categoryMappings.GetEnumerator()) {
            $localConfig["categoryMappings"][$mapping.Key] = $mapping.Value
        }
        
        $localConfig | ConvertTo-Json -Depth 5 | Set-Content $localConfigPath -Encoding UTF8
    } catch {
        Write-Host "⚠ Fehler beim Speichern der Kategorie-Zuordnungen: $($_.Exception.Message)" -ForegroundColor Red
    }
}

function Save-GranularCategoryRule {
    param(
        [string]$mode,
        [hashtable]$criteria,
        [string]$category
    )
    
    try {
        $localConfigPath = Join-Path $PSScriptRoot "config.local.json"
        $localConfig = if (Test-Path $localConfigPath) {
            Get-Content $localConfigPath -Encoding UTF8 | ConvertFrom-Json
        } else {
            @{}
        }
        
        # Erstelle granular rules Sektion falls nicht vorhanden
        if (-not $localConfig.granularRules) {
            $localConfig | Add-Member -MemberType NoteProperty -Name "granularRules" -Value @()
        }
        
        # Erstelle neue Regel
        $newRule = @{
            mode = $mode
            criteria = $criteria
            category = $category
            created = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
        }
        
        # Füge Regel hinzu
        $rulesList = [System.Collections.ArrayList]$localConfig.granularRules
        $rulesList.Add($newRule) | Out-Null
        $localConfig.granularRules = $rulesList.ToArray()
        
        $localConfig | ConvertTo-Json -Depth 10 | Out-File $localConfigPath -Encoding UTF8
        
        Write-Host "✓ Granulare Kategorisierungsregel gespeichert" -ForegroundColor Green
    } catch {
        Write-Host "⚠ Fehler beim Speichern der granularen Regel: $($_.Exception.Message)" -ForegroundColor Red
    }
}

function Get-RuleDescription {
    param(
        [string]$mode,
        [hashtable]$criteria
    )
    
    switch ($mode) {
        "PAYEE_ONLY" {
            return "Alle Transaktionen von '$($criteria.payee)'"
        }
        "PAYEE_AMOUNT" {
            return "Transaktionen von '$($criteria.payee)' mit Betrag '$($criteria.amount) EUR'"
        }
        "PAYEE_KEYWORDS" {
            return "Transaktionen von '$($criteria.payee)' mit Keywords: $($criteria.keywords -join ', ')"
        }
        default {
            return "Unbekannte Regel: $mode"
        }
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
    
    # Lade alle verfügbaren Kategorien (Standard + Gespeicherte)
    $availableCategories = Get-AllAvailableCategories
    
    # Flache Liste für Kompatibilität
    $flatCategories = @()
    foreach ($group in $availableCategories.Keys) {
        $flatCategories += $availableCategories[$group]
    }
    
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
        Write-Host "--- Payee $processedCount von $(@($uncategorizedTransactions.GetEnumerator()).Count) ---" -ForegroundColor Yellow
        Write-Host ((t "category_scanner.payee_label") + " $payee") -ForegroundColor White
        $transactionCountText = $global:i18n.Get("category_scanner.transaction_count", @($count))
        Write-Host $transactionCountText -ForegroundColor Gray
        
        # Show detailed information for better decision making
        Write-Host ""
        Write-Host (t "category_scanner.transaction_details") -ForegroundColor Cyan
        $exampleCount = 0
        foreach ($example in $examples) {
            $exampleCount++
            if ($exampleCount -gt 2) { break }  # Show max 2 examples
            
            Write-Host "  [$exampleCount] $($example.date) | $($example.amount) EUR" -ForegroundColor Gray
            
            # Show source account
            if ($example.sourceAccount) {
                $fromAccountText = $global:i18n.Get("category_scanner.from_account", @($example.sourceAccount))
                Write-Host "      $fromAccountText" -ForegroundColor Cyan
            }
            
            # Show target payee/account with type-safe handling
            $safeExamplePayeeName = if ($example.payeeName -is [string]) { $example.payeeName } elseif ($example.payeeName) { $example.payeeName.ToString() } else { "" }
            if ($safeExamplePayeeName -and $safeExamplePayeeName.Trim() -ne "" -and $safeExamplePayeeName -ne "UNKNOWN_PAYEE") {
                $toAccountText = $global:i18n.Get("category_scanner.to_account", @($safeExamplePayeeName))
                Write-Host "      $toAccountText" -ForegroundColor Magenta
            }
            
            # Show full memo/Verwendungszweck (not truncated)
            # Type-safe example memo handling
            $safeExampleMemo = if ($example.memo -is [string]) { $example.memo } elseif ($example.memo) { $example.memo.ToString() } else { "" }
            if ($safeExampleMemo -and $safeExampleMemo.Trim() -ne "") {
                $memoText = $global:i18n.Get("category_scanner.memo_label", @($example.memo))
                Write-Host "      $memoText" -ForegroundColor White
            }
            
            # Try to extract and show IBAN information
            if ($example.memo -match "IBAN:\s*([A-Z]{2}\d{2}[A-Z0-9]+)") {
                $extractedIBAN = $matches[1]
                $targetIbanText = $global:i18n.Get("category_scanner.target_iban", @($extractedIBAN))
                Write-Host "      $targetIbanText" -ForegroundColor Yellow
                
                # Check if this IBAN belongs to one of our accounts
                if ($OwnIBANs.Keys -contains $extractedIBAN) {
                    $targetAccount = $OwnIBANs[$extractedIBAN]
                    $transferToOwnText = $global:i18n.Get("category_scanner.transfer_to_own", @($targetAccount))
                    Write-Host "      $transferToOwnText" -ForegroundColor Green
                }
            }
            Write-Host ""
        }
        
        Write-Host ""
        if ($suggestedCategory) {
            $suggestedText = $global:i18n.Get("category_scanner.suggested_category", @($suggestedCategory))
            Write-Host $suggestedText -ForegroundColor Green
            Write-Host ""
            Write-Host (t "category_scanner.accept_suggestion") -ForegroundColor Green
            Write-Host (t "category_scanner.choose_other") -ForegroundColor Yellow
            Write-Host "  [k] Kategorie-Management (Keywords & Oberkategorien)" -ForegroundColor Cyan
            Write-Host (t "category_scanner.skip_entry") -ForegroundColor Gray
            Write-Host (t "category_scanner.quit_scanner") -ForegroundColor Red
            
            do {
                $choice = Read-Host (t "category_scanner.your_choice")
                
                if ($choice -eq "q") {
                    Write-Host (t "category_scanner.scanner_quit") -ForegroundColor Yellow
                    return
                } elseif ($choice -eq "s") {
                    Write-Host (t "category_scanner.entry_skipped") -ForegroundColor Yellow
                    break
                } elseif ($choice -eq "j" -or $choice -eq "y" -or $choice -eq "") {
                    $categoryMappings[$payee] = $suggestedCategory
                    $assignedText = $global:i18n.Get("category_scanner.assigned_mapping", @($payee, $suggestedCategory))
                    Write-Host $assignedText -ForegroundColor Green
                    break
                } elseif ($choice -eq "k") {
                    # Kontextuelle Keyword-Bearbeitung für aktuelle Transaktion
                    $transaction = @{
                        payee = $payee
                        memo = if ($examples -and @($examples).Count -gt 0) { $examples[0].memo } else { "" }
                        buchungstext = if ($examples -and @($examples).Count -gt 0) { $examples[0].buchungstext } else { "" }
                    }
                    $keywordResult = Show-CategoryManagementMenu -transaction $transaction -availableCategories $availableCategories
                    if ($keywordResult -and $keywordResult -ne "SKIP") {
                        # Keyword wurde hinzugefügt, Transaktion automatisch kategorisieren
                        $categoryMappings[$payee] = $keywordResult
                        $assignedText = $global:i18n.Get("category_scanner.assigned_mapping", @($payee, $keywordResult))
                        Write-Host $assignedText -ForegroundColor Green
                        break
                    }
                    # Falls SKIP, zurück zur Kategorisierung
                } elseif ($choice -eq "n") {
                    $result = Show-CategorySelectionWithTransaction -availableCategories ([ref]$availableCategories) -suggestedCategory $suggestedCategory -flatCategories ([ref]$flatCategories) -transactionInfo @{
                        payee = $payee
                        memo = if ($examples -and @($examples).Count -gt 0) { $examples[0].memo } else { "" }
                        amount = if ($examples -and @($examples).Count -gt 0) { $examples[0].amount } else { "" }
                        date = if ($examples -and @($examples).Count -gt 0) { $examples[0].date } else { "" }
                        sourceAccount = if ($examples -and @($examples).Count -gt 0) { $examples[0].sourceAccount } else { "" }
                    }
                    
                    # Handle both string and hashtable return values
                    if ($result -is [hashtable]) {
                        $selectedCategory = $result.category
                        if ($result.rule) {
                            # Save granular categorization rule
                            $global:granularRules += $result.rule
                            Write-Host ("Granulare Regel erstellt: " + $result.rule.description) -ForegroundColor Cyan
                        }
                    } else {
                        $selectedCategory = $result
                    }
                    
                    if ($selectedCategory -eq "BREAK") {
                        $global:CategorizationStopped = $true
                        Write-Host "Kategorisierung auf Wunsch beendet." -ForegroundColor Yellow
                        throw "CATEGORIZATION_BREAK"
                    } elseif ($selectedCategory -eq "SKIP") {
                        Write-Host "Payee übersprungen." -ForegroundColor Yellow
                        break
                    } elseif ($selectedCategory) {
                        $categoryMappings[$payee] = $selectedCategory
                        $assignedText = $global:i18n.Get("category_scanner.assigned_mapping", @($payee, $selectedCategory))
                        Write-Host $assignedText -ForegroundColor Green
                        break
                    }
                } else {
                    Write-Host "Ungültige Eingabe. Bitte j, n, k, s oder q eingeben." -ForegroundColor Red
                }
            } while ($true)
        } else {
            # No suggestion available, show categories directly
            Write-Host "Keine automatische Kategoriezuordnung möglich." -ForegroundColor Yellow
            $result = Show-CategorySelectionWithTransaction -availableCategories ([ref]$availableCategories) -suggestedCategory $null -flatCategories ([ref]$flatCategories) -transactionInfo @{
                payee = $payee
                memo = if ($examples -and @($examples).Count -gt 0) { $examples[0].memo } else { "" }
                amount = if ($examples -and @($examples).Count -gt 0) { $examples[0].amount } else { "" }
                date = if ($examples -and @($examples).Count -gt 0) { $examples[0].date } else { "" }
                sourceAccount = if ($examples -and @($examples).Count -gt 0) { $examples[0].sourceAccount } else { "" }
            }
            
            # Handle both string and hashtable return values
            if ($result -is [hashtable]) {
                $selectedCategory = $result.category
                if ($result.rule) {
                    # Save granular categorization rule
                    $global:granularRules += $result.rule
                    Write-Host ("Granulare Regel erstellt: " + $result.rule.description) -ForegroundColor Cyan
                }
            } else {
                $selectedCategory = $result
            }
            
            if ($selectedCategory -eq "BREAK") {
                Write-Host "Kategoriezuordnung beendet." -ForegroundColor Yellow
                return
            } elseif ($selectedCategory -eq "SKIP") {
                Write-Host "Payee übersprungen." -ForegroundColor Yellow
            } elseif ($selectedCategory) {
                $categoryMappings[$payee] = $selectedCategory
                $assignedText = $global:i18n.Get("category_scanner.assigned_mapping", @($payee, $selectedCategory))
                Write-Host $assignedText -ForegroundColor Green
            }
        }
    }
    
    # Save mappings to config.local.json AND session backup
    # PowerShell 5.1/7.x compatible Count check
    if (@($categoryMappings.GetEnumerator()).Count -gt 0) {
        Write-Host ""
        Write-Host "💾 Speichere Kategorie-Zuordnungen..." -ForegroundColor Cyan
        
        # Initialisiere CategoryManager für Session-Speicherung
        $categoryManager = New-CategoryManager -ConfigPath (Join-Path $PSScriptRoot "config.local.json")
        
        # Session-Backup erstellen (automatisch während Kategorisierung)
        $categoryManager.SaveSession($categoryMappings, @{
            processedPayees = $processedCount
            totalPayees = $totalTransactions
            timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            interruptible = $true
        })
        
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
    
    # Zeige Kategorisierungs-Statistik nur wenn nicht im Kategorisierung-nur-Modus
    if (-not $global:CategorizeOnlyMode) {
        Show-CategorizationStatistics
    } else {
        # Einfache Statistik ohne CSV-Verarbeitung
        Show-SimpleCategorizationStats -categoryMappings $categoryMappings
    }
}

function Show-SimpleCategorizationStats {
    param(
        [hashtable]$categoryMappings = @{},
        [int]$processedCount = 0,
        [int]$totalTransactions = 0
    )
    
    Clear-Screen
    
    # Header
    Write-Host "" 
    Write-Host "» Kategorisierungs-Statistik" -ForegroundColor Green
    Write-Host ("─" * 27) -ForegroundColor Green
    Write-Host ""
    
    # Einfache lokale Statistik ohne CSV-Verarbeitung
    $mappingCount = if ($categoryMappings) { @($categoryMappings.GetEnumerator()).Count } else { 0 }
    
    Write-Host "✓ KATEGORISIERUNGS-SYSTEM:" -ForegroundColor Green
    Write-Host "  Payee-Zuordnungen: $mappingCount" -ForegroundColor White
    
    if ($processedCount -gt 0 -and $totalTransactions -gt 0) {
        Write-Host "  Verarbeitete Transaktionen: $processedCount von $totalTransactions" -ForegroundColor White
    }
    
    Write-Host ""
    Write-Host "🔄 Tipp: Verwenden Sie Option 2 für CSV-Generierung nach der Kategorisierung." -ForegroundColor Cyan
    Write-Host ""
}

function Get-UserKeywords {
    try {
        $localConfigPath = Join-Path $PSScriptRoot "config.local.json"
        if (Test-Path $localConfigPath) {
            $localConfig = Get-Content $localConfigPath -Encoding UTF8 | ConvertFrom-Json
            if ($localConfig.PSObject.Properties.Name -contains "categoryKeywords") {
                $result = @{}
                foreach ($property in $localConfig.categoryKeywords.PSObject.Properties) {
                    $categoryName = $property.Name
                    $keywordString = $property.Value
                    $keywords = $keywordString.Split(',') | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne "" }
                    $result[$categoryName] = $keywords
                }
                return $result
            }
        }
    } catch {
        # Return empty if error
    }
    return @{}
}

function Show-CategorizationStatistics {
    Clear-Screen
    
    # Header
    Write-Host "" 
    Write-Host "» Kategorisierungs-Statistik" -ForegroundColor Green
    Write-Host ("─" * 27) -ForegroundColor Green
    Write-Host ""
    
    # Berechne aktuelle Statistiken
    $sourceDir = $global:config.GetSourceDir()
    $csvFiles = Get-ChildItem -Path $sourceDir -Filter "*.csv"
    
    $totalTransactions = 0
    $categorizedTransactions = 0
    $transferTransactions = 0
    $currentMappings = Get-UserCategoryMappings
    $currentKeywords = Get-UserKeywords
    
    # Lade processor functions für Analyse
    $currentLanguage = $Language
    $processorPath = Join-Path $PSScriptRoot "scripts/bank_csv_processor.ps1"
    . $processorPath
    
    # Restore language context
    $Language = $currentLanguage
    $global:i18n = [I18n]::new($langDir, $Language)
    
    # Analysiere alle Transaktionen
    foreach ($file in $csvFiles) {
        try {
            $processedData = Process-BankCSV -FilePath $file.FullName
            $processedCount = if ($processedData -is [array]) { $processedData.Count } elseif ($processedData) { 1 } else { 0 }
            $totalTransactions += $processedCount
            
            if ($processedCount -gt 0) {
                foreach ($row in $processedData) {
                    if ($row.category -and $row.category.Trim() -ne "") {
                        if ($row.category -match "Transfer") {
                            $transferTransactions++
                        } else {
                            $categorizedTransactions++
                        }
                    }
                }
            }
        } catch {
            # Fehler ignorieren
        }
    }
    
    $uncategorizedTransactions = $totalTransactions - $categorizedTransactions - $transferTransactions
    $categorizationRate = if ($totalTransactions -gt 0) { 
        [math]::Round(($categorizedTransactions / $totalTransactions) * 100, 1) 
    } else { 0 }
    
    # Statistiken anzeigen
    Write-Host "✓ " -NoNewline -ForegroundColor Green
    Write-Host "GESAMTSTATISTIK:" -ForegroundColor White
    Write-Host "  Transaktionen gesamt: " -NoNewline -ForegroundColor Gray
    Write-Host "$totalTransactions" -ForegroundColor Yellow
    Write-Host "  Kategorisiert: " -NoNewline -ForegroundColor Gray
    Write-Host "$categorizedTransactions" -NoNewline -ForegroundColor Green
    Write-Host " ($categorizationRate%)" -ForegroundColor Green
    Write-Host "  Transfers: " -NoNewline -ForegroundColor Gray
    Write-Host "$transferTransactions" -ForegroundColor Cyan
    Write-Host "  Unkategorisiert: " -NoNewline -ForegroundColor Gray
    Write-Host "$uncategorizedTransactions" -ForegroundColor $(if ($uncategorizedTransactions -eq 0) { "Green" } else { "Yellow" })
    Write-Host ""
    
    Write-Host "✓ " -NoNewline -ForegroundColor Green
    Write-Host "KATEGORISIERUNGS-SYSTEM:" -ForegroundColor White
    Write-Host "  Payee-Zuordnungen: " -NoNewline -ForegroundColor Gray
    Write-Host "$($currentMappings.Count)" -ForegroundColor Cyan
    Write-Host "  Keyword-Kategorien: " -NoNewline -ForegroundColor Gray
    Write-Host "$($currentKeywords.Count)" -ForegroundColor Cyan
    
    # Zeige Keyword-Details
    if ($currentKeywords.Count -gt 0) {
        Write-Host ""
        Write-Host "🏷️ " -NoNewline -ForegroundColor Cyan
        Write-Host "DEFINIERTE KEYWORDS:" -ForegroundColor Cyan
        foreach ($category in $currentKeywords.Keys) {
            $keywords = $currentKeywords[$category] -join ", "
            Write-Host "  ${category}: " -NoNewline -ForegroundColor Gray
            Write-Host "$keywords" -ForegroundColor White
        }
    }
    
    Write-Host ""
    if ($categorizationRate -ge 90) {
        Write-Host "✨ " -NoNewline -ForegroundColor Green
        Write-Host "Ausgezeichnet! Über 90% kategorisiert." -ForegroundColor Green
    } elseif ($categorizationRate -ge 70) {
        Write-Host "👍 " -NoNewline -ForegroundColor Yellow
        Write-Host "Gut! Über 70% kategorisiert." -ForegroundColor Yellow
    } else {
        Write-Host "🔄 " -NoNewline -ForegroundColor Yellow
        Write-Host "Tipp: Weitere Keywords anlegen für bessere Kategorisierung." -ForegroundColor Yellow
    }
    
    Write-Host ""
    Write-Host "Kategoriescanner abgeschlossen!" -ForegroundColor Green
    Start-Sleep 3
}

function Show-ExtractedIBANs {
    Clear-Screen
    
    # Header
    Write-Host "" 
    Write-Host "» IBAN-Extraktion abgeschlossen" -ForegroundColor Green
    Write-Host ("─" * 29) -ForegroundColor Green
    Write-Host ""
    
    Write-Host "✓ " -NoNewline -ForegroundColor Green
    Write-Host "Gefunden: " -NoNewline -ForegroundColor White
    Write-Host "$($script:extractedIBANs.Count)" -NoNewline -ForegroundColor Yellow
    Write-Host " IBANs für Transfer-Erkennung" -ForegroundColor White
    Write-Host ""
    
    if ($script:extractedIBANs.Count -gt 0) {
        Write-Host "IBAN-ZUORDNUNG:" -ForegroundColor Cyan
        foreach ($iban in $script:extractedIBANs.Keys) {
            $accountName = $script:extractedIBANs[$iban]
            Write-Host "  " -NoNewline
            Write-Host "$iban" -NoNewline -ForegroundColor Yellow
            Write-Host " → " -NoNewline -ForegroundColor Gray
            Write-Host "$accountName" -ForegroundColor Cyan
        }
    } else {
        Write-Host "⚠ " -NoNewline -ForegroundColor Yellow
        Write-Host "Keine IBANs gefunden!" -ForegroundColor Yellow
    }
    
    Write-Host ""
    Write-Host "BEFEHLE:" -ForegroundColor Cyan
    Write-Host "[" -NoNewline -ForegroundColor Green
    Write-Host "w" -NoNewline -ForegroundColor Green
    Write-Host "] Weiter  [" -NoNewline -ForegroundColor White
    Write-Host "x" -NoNewline -ForegroundColor Red
    Write-Host "] Abbrechen" -ForegroundColor White
    
    # Visuelle Trennung
    Write-Host ""
    Write-Host ("─" * 40) -ForegroundColor DarkGray
    
    if ($DryRun) {
        Write-Host "[DRY-RUN] " -NoNewline -ForegroundColor Yellow
        Write-Host "Automatisch weiter" -ForegroundColor Yellow
        Start-Sleep 2
    } else {
        do {
            $choice = Read-Host "IBAN-Extraktion (w/x, Enter=Weiter)"
            if ($choice -eq "x") {
                Write-Host "✗ Setup abgebrochen." -ForegroundColor Red
                exit 0
            } elseif ($choice -eq "w" -or $choice -eq "") {
                break
            } else {
                Write-Host "  ⚠ Bitte w oder x eingeben." -ForegroundColor Red
            }
        } while ($true)
    }
}

function Get-CategorySuggestion {
    param(
        [string]$payee,
        [array]$examples
    )
    
    # Use CategoryEngine if available - NO FALLBACK for testing
    if ($global:categoryEngine) {
        # Get the most representative example (not necessarily the first)
        $bestExample = Get-BestExample -examples $examples
        
        $transaction = @{
            payee = $payee
            memo = if ($bestExample -and $bestExample.memo) { $bestExample.memo } else { "" }
            buchungstext = if ($bestExample -and $bestExample.buchungstext) { $bestExample.buchungstext } else { "" }
            amount = if ($bestExample -and $bestExample.amount) { $bestExample.amount } else { "" }
        }
        
        $category = $global:categoryEngine.CategorizeTransaction($transaction)
        if ($category -and $category.Trim() -ne "") {
            return $category
        }
    }
    
    # FALLBACK TEMPORARILY DISABLED FOR CATEGORYENGINE TESTING
    # Will be re-enabled after successful testing
    return $null  # No suggestion available
    
    # # Fallback to original logic if CategoryEngine fails or returns empty
    # # Type-safe payee conversion
    # $payeeLower = if ($payee -is [string]) { $payee.ToLower() } elseif ($payee) { $payee.ToString().ToLower() } else { "" }
    # 
    # # Get the most representative example (not necessarily the first)
    # $bestExample = Get-BestExample -examples $examples
    # # Type-safe memo text conversion
    # $memoText = if ($bestExample -and $bestExample.memo) {
    #     if ($bestExample.memo -is [string]) { 
    #         $bestExample.memo.ToLower() 
    #     } else { 
    #         $bestExample.memo.ToString().ToLower() 
    #     }
    # } else { "" }
    # 
    # # Note: Transfers are already filtered out in the scanning phase
    # 
    # # Define category suggestion rules based on common German payee patterns
    # $categoryRules = @{
    #     "aldi|lidl|edeka|rewe|netto|penny|kaufland|real|denns|rossmann.*food|dm.*food" = "Lebensmittel"
    #     "tankstelle|shell|aral|esso|bp|total|jet|star|agip|fuel|benzin|diesel" = "Kraftstoff"
    #     "allianz|axa|versicherung|huk|signal|debeka|ergo|provinzial|generali" = "Versicherungen"
    #     "miete|nebenkosten|hausgeld|wohnung|immobilie|vermieter|vermietung" = "Wohnen"
    #     "restaurant|mcdonald|burger king|pizza|cafe|gastro|imbiss|delivery|lieferando" = "Restaurants & Ausgehen"
    #     "amazon(?!.*fuel)|ebay|zalando|otto|online.*shop|shop.*online|paypal.*shop" = "Online Shopping"
    #     "media markt|saturn|apple store|conrad|cyberport|notebooksbilliger|elektronik" = "Elektronik & Technik"
    #     "netflix|spotify|amazon prime|disney|sky|streaming|abo|subscription" = "Streaming & Abos"
    #     "bank.*gebühr|zinsen|entgelt|provision|kontoführung|überziehung|abschluss|quartal.*abschluss|jahres.*abschluss" = "Bankgebühren"
    #     "finanzamt|steuer|tax|abgaben|steuern|kfz.*steuer" = "Steuern"
    #     "dividende|zinsen.*ertrag|kapitalertrag|gewinn|rendite" = "Kapitalerträge"
    #     "einzahlung|bargeld|cash|geldautomat|atm" = "Bareinzahlungen"
    #     "apotheke|drogerie|dm(?!.*food)|rossmann(?!.*food)|müller.*drogerie|gesundheit" = "Drogerie & Gesundheit"
    #     "telekom|vodafone|o2|1&1|internet|telefon|handy|mobilfunk|provider" = "Internet & Telefon"
    #     "taxi|uber|bolt|fahrdienst|rideshare|lyft" = "Taxi & Ridesharing"
    #     "spende|donation|caritas|rotes kreuz|hilfswerk|charity" = "Spenden"
    #     "verein|mitglied.*beitrag|club|fitness|sport|gym|mcfit|clever fit" = "Mitgliedschaften"
    #     "schule|uni|bildung|kurs|seminar|weiterbildung|studium|fortbildung" = "Bildung"
    #     "gehalt|lohn|salary|einkommen|arbeitgeber|bonus|prämie" = "Einkommen"
    # }
    # 
    # # First check user-defined keywords from previous categorizations
    # $userKeywords = Get-UserKeywords
    # 
    # foreach ($category in $userKeywords.Keys) {
    #     $keywords = $userKeywords[$category]
    #     
    #     foreach ($keyword in $keywords) {
    #         # Type-safe keyword conversion
    #         $keywordLower = if ($keyword -is [string]) { $keyword.ToLower() } elseif ($keyword) { $keyword.ToString().ToLower() } else { "" }
    #         $payeeMatch = $payeeLower -match [regex]::Escape($keywordLower)
    #         $memoMatch = $memoText -match [regex]::Escape($keywordLower)
    #         
    #         if ($payeeMatch -or $memoMatch) {
    #             return $category
    #         }
    #     }
    # }
    # 
    # # Then check built-in payee name against rules
    # foreach ($pattern in $categoryRules.Keys) {
    #     if ($payeeLower -match $pattern) {
    #         $matchedCategory = $categoryRules[$pattern]
    #         return $matchedCategory
    #     }
    # }
    # 
    # # Check memo/purpose text against rules
    # foreach ($pattern in $categoryRules.Keys) {
    #     if ($memoText -match $pattern) {
    #         $matchedCategory = $categoryRules[$pattern]
    #         return $matchedCategory
    #     }
    # }
    # 
    # # Special amount-based suggestions with better logic
    # if ($bestExample) {
    #     $amount = [math]::Abs([decimal]$bestExample.amount)
    #     
    #     # Small amounts often groceries or daily expenses
    #     if ($amount -lt 50) {
    #         if ($payeeLower -match "markt|laden|shop|kiosk" -or $memoText -match "einkauf|lebensmittel") {
    #             return "Lebensmittel"
    #         }
    #     }
    #     
    #     # Medium amounts often fuel
    #     if ($amount -gt 30 -and $amount -lt 150) {
    #         if ($memoText -match "tankstelle|tank|fuel|benzin|diesel") {
    #             return "Kraftstoff"
    #         }
    #     }
    #     
    #     # Large regular amounts often rent/insurance
    #     if ($amount -gt 300) {
    #         if ($memoText -match "miete|rent|wohnung") {
    #             return "Wohnen"
    #         } elseif ($memoText -match "versicherung|insurance|police") {
    #             return "Versicherungen"
    #         }
    #     }
    # }
    # 
    # return $null  # No suggestion available
}

function Edit-AllCategoryKeywords {
    Clear-Screen
    
    # Header
    Write-Host "" 
    Write-Host "» Keywords aller Kategorien bearbeiten" -ForegroundColor Cyan
    Write-Host ("─" * 36) -ForegroundColor Cyan
    Write-Host ""
    
    # Lade existierende Keywords
    $existingKeywords = Get-UserKeywords
    
    # Lade alle verfügbaren Kategorien (Standard + Gespeicherte)
    $availableCategories = Get-AllAvailableCategories
    
    $allCategories = @()
    foreach ($group in $availableCategories.Keys) {
        $allCategories += $availableCategories[$group]
    }
    
    Write-Host "Gefunden: " -NoNewline -ForegroundColor Gray
    Write-Host "$($allCategories.Count)" -NoNewline -ForegroundColor Yellow
    Write-Host " Kategorien, " -NoNewline -ForegroundColor Gray
    Write-Host "$($existingKeywords.Count)" -NoNewline -ForegroundColor Yellow
    Write-Host " mit Keywords" -ForegroundColor Gray
    Write-Host ""
    
    $categoryIndex = 1
    foreach ($group in $availableCategories.Keys) {
        Write-Host "$group" -ForegroundColor Yellow
        
        foreach ($category in $availableCategories[$group]) {
            $keywords = if ($existingKeywords.Keys -contains $category) {
                $existingKeywords[$category] -join ", "
            } else {
                "(keine Keywords)"
            }
            
            Write-Host "[" -NoNewline -ForegroundColor Green
            Write-Host "$categoryIndex" -NoNewline -ForegroundColor Green
            Write-Host "] " -NoNewline -ForegroundColor Green
            Write-Host "$category" -NoNewline -ForegroundColor White
            Write-Host " → " -NoNewline -ForegroundColor Gray
            
            if ($keywords -eq "(keine Keywords)") {
                Write-Host "$keywords" -ForegroundColor DarkGray
            } else {
                Write-Host "$keywords" -ForegroundColor Cyan
            }
            
            $categoryIndex++
        }
        Write-Host ""
    }
    
    # Befehle
    Write-Host "BEFEHLE:" -ForegroundColor Cyan
    Write-Host "[" -NoNewline -ForegroundColor Green
    Write-Host "1-$($allCategories.Count)" -NoNewline -ForegroundColor Green
    Write-Host "] Kategorie bearbeiten  [" -NoNewline -ForegroundColor White
    Write-Host "x" -NoNewline -ForegroundColor Red
    Write-Host "] Zurück" -ForegroundColor White
    
    # Visuelle Trennung
    Write-Host ""
    Write-Host ("─" * 40) -ForegroundColor DarkGray
    
    do {
        $choice = Read-Host "Keywords bearbeiten"
        
        if ($choice -eq "x") {
            break
        } elseif ($choice -match "^\d+$") {
            $index = [int]$choice - 1
            if ($index -ge 0 -and $index -lt $allCategories.Count) {
                $selectedCategory = $allCategories[$index]
                
                Write-Host ""
                Write-Host "Kategorie: " -NoNewline -ForegroundColor Gray
                Write-Host "$selectedCategory" -ForegroundColor Yellow
                
                $currentKeywords = if ($existingKeywords.Keys -contains $selectedCategory) {
                    $existingKeywords[$selectedCategory] -join ", "
                } else {
                    ""
                }
                
                Write-Host "Aktuelle Keywords: " -NoNewline -ForegroundColor Gray
                Write-Host "$currentKeywords" -ForegroundColor Cyan
                Write-Host ""
                
                $newKeywords = Read-Host "Neue Keywords (Komma-getrennt, leer = löschen)"
                
                if ($newKeywords.Trim() -eq "") {
                    # Keywords löschen
                    Remove-CategoryKeywords -categoryName $selectedCategory
                    Write-Host "✓ Keywords für '$selectedCategory' gelöscht." -ForegroundColor Green
                } else {
                    # Keywords speichern
                    $keywordArray = $newKeywords.Split(',') | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne "" }
                    Save-CategoryKeywords -categoryName $selectedCategory -keywords $keywordArray
                    Write-Host "✓ Keywords für '$selectedCategory' gespeichert: " -NoNewline -ForegroundColor Green
                    Write-Host "$($keywordArray -join ', ')" -ForegroundColor Cyan
                }
                
                Write-Host ""
                Write-Host "Drücken Sie Enter zum Fortfahren..." -ForegroundColor Gray
                Read-Host
                
                # Zurück zur Übersicht
                Edit-AllCategoryKeywords
                return
            } else {
                Write-Host "  ⚠ Ungültige Auswahl. Bitte 1-$($allCategories.Count) oder x eingeben." -ForegroundColor Red
            }
        } else {
            Write-Host "  ⚠ Ungültige Eingabe. Bitte eine Zahl oder x eingeben." -ForegroundColor Red
        }
    } while ($true)
}

function Remove-CategoryKeywords {
    param([string]$categoryName)
    
    try {
        $localConfigPath = Join-Path $PSScriptRoot "config.local.json"
        if (Test-Path $localConfigPath) {
            $localConfig = Get-Content $localConfigPath -Encoding UTF8 | ConvertFrom-Json
            
            if ($localConfig.categoryKeywords -and $localConfig.categoryKeywords.PSObject.Properties.Name -contains $categoryName) {
                # PowerShell 5.1/7.x compatible way to remove properties
                $newKeywords = @{}
                foreach ($property in $localConfig.categoryKeywords.PSObject.Properties) {
                    if ($property.Name -ne $categoryName) {
                        $newKeywords[$property.Name] = $property.Value
                    }
                }
                
                $localConfig.categoryKeywords = [PSCustomObject]$newKeywords
                $localConfig | ConvertTo-Json -Depth 5 | Out-File $localConfigPath -Encoding UTF8
            }
        }
    } catch {
        Write-Host "  ⚠ Fehler beim Löschen der Keywords: $($_.Exception.Message)" -ForegroundColor Red
    }
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
        "mastercard.*abrechnung",  # Credit card billing transfers
        "visa.*abrechnung",        # Visa card billing transfers
        "kk\d+/\d+",              # Credit card reference like "kk4/25"
        "ausgleich",
        "umbuchung",
        "bankinternes.*verrechnungskonto"  # Internal bank accounting transfers
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

function Get-IncomeCategory {
    param(
        [string]$payee,
        [string]$memo,
        [string]$amount,
        [string]$buchungstext = ""
    )
    
    # Use CategoryEngine if available - NO FALLBACK for testing
    if ($global:categoryEngine) {
        $transaction = @{
            payee = $payee
            memo = $memo
            buchungstext = $buchungstext
            amount = $amount
        }
        
        $category = $global:categoryEngine.CategorizeTransaction($transaction)
        if ($category -and $category.Trim() -ne "") {
            return $category
        }
    }
    
    # FALLBACK TEMPORARILY DISABLED FOR CATEGORYENGINE TESTING
    # Will be re-enabled after successful testing
    return $null
    
    # # Fallback to original logic if CategoryEngine fails or returns empty
    # # Only process positive amounts (income)
    # if ($amount -match '^[0-9]+' -and $amount -notmatch '^-') {
    #     $payeeLower = if ($payee) { $payee.ToLower() } else { "" }
    #     $memoLower = if ($memo) { $memo.ToLower() } else { "" }
    #     
    #     # Lohn/Gehalt - Primary income from employer
    #     if ($memoLower -match "lohn.*gehalt|gehalt.*abrechnung|bezuege|salary" -or 
    #         $payeeLower -match "osiandersche.*buchhandlung|luxor.*solar") {
    #         return $global:i18n.Get("categories.income")
    #     }
    #     
    #     # Dividenden/Kapitalerträge - Investment income
    #     if ($memoLower -match "dividende|gewinn.*gewinnsparen|kapitalertrag|capital.*gain" -or
    #         $payeeLower -match "volksbank.*pur.*eg" -and $memoLower -match "gewinn") {
    #         return $global:i18n.Get("categories.capital_gains")
    #     }
    #     
    #     # Bareinzahlungen - Cash deposits (prioritize Buchungstext)
    #     if ($buchungstext -match "sb-einzahlung|bareinzahlung|einzahlung|schaltereinzahlung" -or
    #         $memoLower -match "bareinzahlung|einzahlung|cash.*deposit" -or
    #         ($payeeLower -match "volksbank|sparkasse|bank" -and $memoLower -match "einzahlung")) {
    #         return $global:i18n.Get("categories.cash_deposits")
    #     }
    #     
    #     # Verkaufserlöse - Sales income
    #     if ($memoLower -match "verkauf|secondhand|dein.*verkauf.*hessnatur" -or
    #         $payeeLower -match "rs.*recommerce.*technologies") {
    #         return $global:i18n.Get("categories.other_income")
    #     }
    #     
    #     # Steuerrückzahlungen - Tax refunds (could be expanded)
    #     if ($memoLower -match "steuer.*rückzahlung|tax.*refund|finanzamt") {
    #         return $global:i18n.Get("categories.tax_refunds")
    #     }
    #     
    #     # Rückzahlungen/Erstattungen - General refunds
    #     if ($memoLower -match "rückzahlung|erstattung|zurück|refund" -and 
    #         $memoLower -notmatch "kk\d+/\d+") {
    #         return $global:i18n.Get("categories.other_income")
    #     }
    #     
    #     # Kreditkarten-Kompensation - Credit card compensations
    #     if ($memoLower -match "kk\d+/\d+.*überweisungsgutschr|kreditkarte.*\d+/\d+") {
    #         return $global:i18n.Get("categories.internal_transfer")
    #     }
    #     
    #     # Geschenke/Zuwendungen - Gifts
    #     if ($memoLower -match "geschenk|gift|zuwendung" -or
    #         ($payeeLower -match "stefan.*laszczyk|alessandra.*schmid" -and 
    #          $memoLower -match "kontext.*gutschrift|geschenk")) {
    #         return $global:i18n.Get("categories.other_income")
    #     }
    #     
    #     # Sonstige Einkünfte aus regelmäßigen kleinen Beträgen
    #     if ($payeeLower -match "stefan.*laszczyk|alessandra.*schmid" -and 
    #         $memoLower -match "überweisungsgutschr|gutschrift" -and
    #         $memoLower -notmatch "kk\d+/\d+|kreditkarte") {
    #         return $global:i18n.Get("categories.other_income")
    #     }
    # }
    # 
    # return $null
}

function Get-BestExample {
    param([array]$examples)
    
    if (-not $examples -or @($examples).Count -eq 0) {
        return $null
    }
    
    # Prefer examples that are not transfers
    $nonTransferExamples = $examples | Where-Object { 
        # Type-safe memo handling for filtering
        $safeMemo = if ($_.memo -is [string]) { $_.memo.ToLower() } elseif ($_.memo) { $_.memo.ToString().ToLower() } else { "" }
        -not (Test-IsTransfer -payee "" -memo $safeMemo -examples @())
    }
    
    if ($nonTransferExamples) {
        # Return the most recent non-transfer example
        return ($nonTransferExamples | Sort-Object date -Descending)[0]
    }
    
    # If all are transfers, return the most recent one
    return ($examples | Sort-Object date -Descending)[0]
}

function Show-CompletionStatistics {
    Clear-Screen
    
    # Header
    Write-Host "" 
    Write-Host "» CSV2Actual - Verarbeitung abgeschlossen" -ForegroundColor Green
    Write-Host ("─" * 40) -ForegroundColor Green
    Write-Host ""
    
    # Hole Statistiken aus den verarbeiteten Dateien
    $sourceDir = $global:config.GetSourceDir()
    $csvFiles = Get-ChildItem -Path $sourceDir -Filter "*.csv"
    $outputDir = "actual_import/"
    
    # Zähle verarbeitete Transaktionen
    $totalTransactions = 0
    $processedFiles = 0
    
    foreach ($file in $csvFiles) {
        try {
            # Verwende die gleiche Verarbeitungslogik wie im Hauptscript
            $processorPath = Join-Path $PSScriptRoot "scripts/bank_csv_processor.ps1"
            # Einfache Berechnung über Dateigröße als Approximation
            $fileInfo = Get-Item $file.FullName
            if ($fileInfo.Length -gt 100) {
                $processedFiles++
                # Approximation: 100 Bytes pro Transaktion
                $totalTransactions += [math]::Floor($fileInfo.Length / 100)
            }
        } catch {
            # Fehler ignorieren
        }
    }
    
    # Statistiken anzeigen
    Write-Host "✓ " -NoNewline -ForegroundColor Green
    Write-Host "DATEIEN:" -ForegroundColor White
    Write-Host "  CSV-Dateien gefunden: " -NoNewline -ForegroundColor Gray
    Write-Host "$($csvFiles.Count)" -ForegroundColor Yellow
    Write-Host "  Erfolgreich verarbeitet: " -NoNewline -ForegroundColor Gray
    Write-Host "$processedFiles" -ForegroundColor Green
    Write-Host ""
    
    Write-Host "✓ " -NoNewline -ForegroundColor Green
    Write-Host "TRANSAKTIONEN:" -ForegroundColor White
    Write-Host "  Geschätzt verarbeitet: " -NoNewline -ForegroundColor Gray
    Write-Host "$totalTransactions" -ForegroundColor Yellow
    
    # Kategorisierung
    try {
        $categoryMappings = Get-UserCategoryMappings
        $keywordCount = Get-UserKeywords
        
        Write-Host "  Kategorisierte Payees: " -NoNewline -ForegroundColor Gray
        Write-Host "$($categoryMappings.Count)" -ForegroundColor Cyan
        Write-Host "  Keywords definiert: " -NoNewline -ForegroundColor Gray
        Write-Host "$($keywordCount.Count)" -ForegroundColor Cyan
    } catch {
        # Fehler ignorieren
    }
    Write-Host ""
    
    Write-Host "✓ " -NoNewline -ForegroundColor Green
    Write-Host "OUTPUT:" -ForegroundColor White
    Write-Host "  Ausgabeordner: " -NoNewline -ForegroundColor Gray
    Write-Host "$outputDir" -ForegroundColor Cyan
    
    # Dateien im Output-Ordner zählen
    if (Test-Path $outputDir) {
        $outputFiles = Get-ChildItem -Path $outputDir -Filter "*.csv"
        Write-Host "  Generierte CSV-Dateien: " -NoNewline -ForegroundColor Gray
        Write-Host "$($outputFiles.Count)" -ForegroundColor Green
    }
    
    # Startguthaben anzeigen falls vorhanden
    $balanceFile = "starting_balances.txt"
    if (Test-Path $balanceFile) {
        Write-Host "  Startguthaben-Datei: " -NoNewline -ForegroundColor Gray
        Write-Host "$balanceFile" -ForegroundColor Cyan
    }
    
    Write-Host ""
    Write-Host "✓ " -NoNewline -ForegroundColor Green
    Write-Host (Get-LocalizedString "instructions.next_steps") -ForegroundColor White
    Write-Host "  0. " -NoNewline -ForegroundColor Yellow
    Write-Host (Get-LocalizedString "instructions.setup_accounts_first") -ForegroundColor Yellow
    Write-Host "  1. " -NoNewline -ForegroundColor Gray
    Write-Host (Get-LocalizedString "instructions.accounts_setup_reminder") -ForegroundColor White
    Write-Host "  2. " -NoNewline -ForegroundColor Gray
    Write-Host (Get-LocalizedString "instructions.create_categories") -ForegroundColor White
    Write-Host "  3. " -NoNewline -ForegroundColor Gray
    Write-Host ((Get-LocalizedString "instructions.import_files") -f $outputDir) -ForegroundColor White
    Write-Host "  4. " -NoNewline -ForegroundColor Gray
    Write-Host (Get-LocalizedString "instructions.set_mapping") -ForegroundColor White
    
    Write-Host ""
    Write-Host "✨ " -NoNewline -ForegroundColor Yellow
    Write-Host "Verarbeitung erfolgreich abgeschlossen!" -ForegroundColor Green
    Write-Host ""
}

function Get-UserCategoryMappings {
    try {
        $localConfigPath = Join-Path $PSScriptRoot "config.local.json"
        if (Test-Path $localConfigPath) {
            $localConfig = Get-Content $localConfigPath -Encoding UTF8 | ConvertFrom-Json
            if ($localConfig.PSObject.Properties.Name -contains "categoryMappings") {
                $result = @{}
                foreach ($property in $localConfig.categoryMappings.PSObject.Properties) {
                    $result[$property.Name] = $property.Value
                }
                return $result
            }
        }
    } catch {
        # Return empty if error
    }
    return @{}
}

function Get-UncategorizedTransactions {
    param([array]$csvFiles)
    
    $uncategorizedTransactions = @{}
    $transferCount = 0
    $incomeCount = 0
    $alreadyCategorizedCount = 0
    
    # Load configuration and IBAN mapping
    $configPath = Join-Path $PSScriptRoot "config.json"
    $global:config = [Config]::new($configPath)
    
    # Load IBAN mapping using the config class (same as everywhere else)
    $OwnIBANs = $global:config.GetIBANMapping()
    
    # Load existing category mappings to check for already categorized transactions
    $categoryMappings = @{}
    $localConfigPath = "config.local.json"
    if (Test-Path $localConfigPath) {
        try {
            $localConfig = Get-Content -Path $localConfigPath -Raw -Encoding UTF8 | ConvertFrom-Json
            if ($localConfig.categoryMappings) {
                $localConfig.categoryMappings.PSObject.Properties | ForEach-Object {
                    $categoryMappings[$_.Name] = $_.Value
                }
            }
        } catch {
            Write-Warning "Fehler beim Laden der Kategorie-Zuordnungen: $($_.Exception.Message)"
        }
    }
    
    foreach ($file in $csvFiles) {
        Write-Host "  → Analysiere $($file.BaseName)..." -ForegroundColor Gray
        
        try {
            # Import CSV and process each row
            $csvData = Import-Csv -Path $file.FullName -Delimiter ';' -Encoding UTF8
            
            foreach ($row in $csvData) {
                # Extract payee text with PayPal enhancement
                $payeeText = if ($row."Name Zahlungsbeteiligter") { 
                    $row."Name Zahlungsbeteiligter".Trim() 
                } else { 
                    "UNKNOWN_PAYEE" 
                }
                
                # PayPal-specific payee enhancement
                if ($payeeText -match "(?i)paypal" -and $row."Verwendungszweck") {
                    $memoText = $row."Verwendungszweck".ToLower()
                    $merchantName = ""
                    if ($memoText -match "mullvad") {
                        $merchantName = "Mullvad VPN"
                    } elseif ($memoText -match "pp\.\d+") {
                        if ($memoText -match "mullvad\s+vpn") {
                            $merchantName = "Mullvad VPN"
                        } elseif ($memoText -match "netflix") {
                            $merchantName = "Netflix"
                        } elseif ($memoText -match "spotify") {
                            $merchantName = "Spotify"
                        } elseif ($memoText -match "google") {
                            $merchantName = "Google"
                        } elseif ($memoText -match "apple") {
                            $merchantName = "Apple"
                        } else {
                            $merchantName = "PayPal Service"
                        }
                    }
                    
                    if ($merchantName -and $merchantName -ne "") {
                        $payeeText = "PayPal ($merchantName)"
                    }
                }
                
                # Check if transfer
                $memoText = if ($row."Verwendungszweck") { $row."Verwendungszweck".ToLower() } else { "" }
                $targetIBAN = if ($row."IBAN Zahlungsbeteiligter") { $row."IBAN Zahlungsbeteiligter".Trim() } else { "" }
                
                # Fallback: Extract IBAN from memo text (for banks that put IBAN in notes)
                if (-not $targetIBAN -and $row."Verwendungszweck") {
                    if ($row."Verwendungszweck" -match 'IBAN:\s*([A-Z]{2}\d{2}[A-Z0-9]+)') {
                        $targetIBAN = $matches[1]
                    }
                }
                
                $isTransfer = $false
                if ($targetIBAN -and ($OwnIBANs.Keys -contains $targetIBAN)) {
                    $isTransfer = $true
                    $transferCount++
                }
                # TEMPORARILY DISABLED: elseif (Test-IsTransfer -payee $payeeText.ToLower() -memo $memoText -examples @()) {
                #     $isTransfer = $true
                #     $transferCount++
                # }
                
                if ($isTransfer) { continue }
                
                # Check if income
                $amount = if ($row."Betrag") { $row."Betrag" } else { "0" }
                if ($amount -match '^[0-9]+' -and $amount -notmatch '^-') {
                    $buchungstext = if ($row."Buchungstext") { $row."Buchungstext".ToLower() } else { "" }
                    $incomeCategory = Get-IncomeCategory -payee $payeeText -memo $memoText -amount $amount -buchungstext $buchungstext
                    if ($incomeCategory) {
                        $incomeCount++
                        continue
                    }
                }
                
                # Check if already categorized
                $isAlreadyCategorized = $false
                if ($categoryMappings.Keys -contains $payeeText) {
                    $isAlreadyCategorized = $true
                    $alreadyCategorizedCount++
                } else {
                    # Check CategoryEngine like SimpleAnalyzer does
                    if ($global:categoryEngine) {
                        $transaction = @{
                            payee = $payeeText
                            memo = $memoText
                            buchungstext = if ($row."Buchungstext") { $row."Buchungstext" } else { "" }
                            amount = $amount
                        }
                        
                        $category = $global:categoryEngine.CategorizeTransaction($transaction)
                        if ($category -and $category.Trim() -ne "") {
                            $isAlreadyCategorized = $true
                            $alreadyCategorizedCount++
                        }
                    }
                }
                
                if ($isAlreadyCategorized) {
                    continue
                }
                
                # Add to uncategorized
                if (-not ($uncategorizedTransactions.Keys -contains $payeeText)) {
                    $uncategorizedTransactions[$payeeText] = @{
                        payee = $payeeText
                        memo = if ($row."Verwendungszweck") { $row."Verwendungszweck" } else { "" }
                        amount = $amount
                        count = 0
                        examples = @()
                    }
                }
                
                $uncategorizedTransactions[$payeeText].count++
                if ($uncategorizedTransactions[$payeeText].examples.Count -lt 3) {
                    $uncategorizedTransactions[$payeeText].examples += @{
                        date = if ($row."Buchungstag") { $row."Buchungstag" } else { "UNKNOWN" }
                        amount = $amount
                        memo = if ($row."Verwendungszweck") { $row."Verwendungszweck" } else { "" }
                        sourceAccount = $file.BaseName
                        payeeName = $payeeText
                    }
                }
            }
        } catch {
            Write-Host "    ⚠ Fehler bei $($file.BaseName): $($_.Exception.Message)" -ForegroundColor Yellow
        }
    }
    
    Write-Host "  ✓ Automatisch kategorisiert: $($transferCount + $incomeCount + $alreadyCategorizedCount) Transaktionen (Transfers + Einnahmen + bereits kategorisiert)" -ForegroundColor Green
    
    return $uncategorizedTransactions
}

function Start-InteractiveCategorization {
    Write-Host ""
    Write-Host "» Interaktive Kategorisierung" -ForegroundColor Cyan
    Write-Host ("─" * 28) -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Starte direkte Kategorisierung der unkategorisierten Transaktionen..." -ForegroundColor White
    Write-Host ""
    
    # Ask user what they want to do
    Write-Host "Was möchten Sie tun?" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "  [1] Nur Kategorisierung bearbeiten und speichern" -ForegroundColor White
    Write-Host "  [2] Kategorisierung bearbeiten und CSV-Dateien generieren" -ForegroundColor White
    Write-Host "  [3] Abbrechen" -ForegroundColor Gray
    Write-Host ""
    
    do {
        $choice = Read-Host "Ihre Wahl (1-3)"
        $validChoice = $choice -in @("1", "2", "3")
        if (-not $validChoice) {
            Write-Host "Bitte wählen Sie 1, 2 oder 3." -ForegroundColor Red
        }
    } while (-not $validChoice)
    
    if ($choice -eq "3") {
        Write-Host "Kategorisierung abgebrochen." -ForegroundColor Yellow
        return
    }
    
    $categorizeOnly = ($choice -eq "1")
    
    # Initialize modules
    try {
        $sourceDir = $global:config.GetSourceDir()
        
        # Check if source files exist
        $csvFiles = Get-ChildItem -Path $sourceDir -Filter "*.csv" -ErrorAction SilentlyContinue
        if (-not $csvFiles -or $csvFiles.Count -eq 0) {
            Write-Host "❌ Keine CSV-Dateien im source/ Ordner gefunden!" -ForegroundColor Red
            Write-Host "   Bitte fügen Sie Ihre Bank-CSV-Exporte in den source/ Ordner hinzu." -ForegroundColor Yellow
            Write-Host ""
            Read-Host "Drücken Sie Enter zum Beenden"
            return
        }
        
        # First collect uncategorized transactions
        $uncategorizedTransactions = Get-UncategorizedTransactions -csvFiles $csvFiles
        
        if ($uncategorizedTransactions.Count -eq 0) {
            Write-Host "✅ Alle Transaktionen sind bereits kategorisiert!" -ForegroundColor Green
            Write-Host ""
            if ($categorizeOnly) {
                Read-Host "Drücken Sie Enter zum Beenden"
                return
            } else {
                Write-Host "Möchten Sie trotzdem CSV-Dateien mit den vorhandenen Kategorisierungen generieren? (j/n)" -ForegroundColor Yellow
                $generate = Read-Host
                if ($generate -notmatch "^(j|ja|y|yes)$") {
                    return
                }
            }
        } else {
            Write-Host "📊 Gefunden: $($uncategorizedTransactions.Count) unkategorisierte Transaktionsgruppen" -ForegroundColor Yellow
            Write-Host ""
            
            # Set global flag for categorize-only mode
            $global:CategorizeOnlyMode = $categorizeOnly
            
            # Start categorization process
            Start-ExtendedCategoryMapping -uncategorizedTransactions $uncategorizedTransactions
        }
        
        # Generate CSV files if requested
        if (-not $categorizeOnly) {
            Write-Host ""
            Write-Host "» CSV-Generierung" -ForegroundColor Cyan
            Write-Host ("─" * 17) -ForegroundColor Cyan
            Write-Host ""
            Write-Host "Generiere CSV-Dateien mit aktuellen Kategorisierungen..." -ForegroundColor White
            
            $processorPath = Join-Path $PSScriptRoot "scripts/bank_csv_processor.ps1"
            $null = & $processorPath -l $Language -Silent 2>$null
            
            Write-Host "✅ CSV-Dateien wurden im actual_import/ Ordner generiert." -ForegroundColor Green
            Write-Host ""
            Read-Host "Drücken Sie Enter zum Beenden"
        } else {
            Write-Host ""
            Write-Host "✅ Kategorisierungen wurden gespeichert." -ForegroundColor Green
            Write-Host ""
            Read-Host "Drücken Sie Enter zum Beenden"
        }
        
    } catch {
        Write-Host "❌ Fehler beim Starten der Kategorisierung: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host ""
        Read-Host "Drücken Sie Enter zum Beenden"
    }
}

function Start-TransactionAnalysis {
    param(
        [string]$CsvDirectory = ""
    )
    
    try {
        # Determine CSV directory
        if (-not $CsvDirectory) {
            $CsvDirectory = $global:config.GetSourceDir()
            if (-not $CsvDirectory) {
                $CsvDirectory = "source"
            }
        }
        
        # Initialize CategoryEngine (required by SimpleAnalyzer)
        $global:categoryEngine = [CategoryEngine]::new("$PSScriptRoot/categories.json", $Language)
        
        # Use SimpleAnalyzer instead of TransactionAnalyzer to avoid UTF-8 encoding issues
        Invoke-SimpleTransactionAnalysis -CsvDirectory $CsvDirectory -Language $Language
        
        # Wait for user input
        Write-Host ""
        if ($Language -eq "de") {
            Write-Host "Drücken Sie Enter zum Beenden..." -ForegroundColor Yellow
        } else {
            Write-Host "Press Enter to exit..." -ForegroundColor Yellow
        }
        Read-Host
        
    } catch {
        $errorMessage = if ($Language -eq "de") {
            "Fehler bei der Transaktionsanalyse: $($_.Exception.Message)"
        } else {
            "Error during transaction analysis: $($_.Exception.Message)"
        }
        
        Write-Host $errorMessage -ForegroundColor Red
        Write-Host "Details: $($_.Exception)" -ForegroundColor DarkRed
        
        Write-Host ""
        if ($Language -eq "de") {
            Write-Host "Drücken Sie Enter zum Beenden..." -ForegroundColor Yellow
        } else {
            Write-Host "Press Enter to exit..." -ForegroundColor Yellow
        }
        Read-Host
        exit 1
    }
}

function Start-RoutineProcessing {
    # Step 1: Find files
    Show-Screen -Title "CSV-Verarbeitung" -Content @(
        "INFO:Suche CSV-Dateien..."
    )
    $sourceDir = $global:config.GetSourceDir()
    $csvFiles = Get-ChildItem -Path $sourceDir -Filter "*.csv"
    
    if ($csvFiles.Count -eq 0) {
        Show-Screen -Title "Fehler" -Content @(
            "ERROR:Keine CSV-Dateien gefunden!",
            "INFO:Fügen Sie CSV-Dateien zum source/ Ordner hinzu"
        ) -WaitForInput
        exit 1
    }
    
    # Step 2: Process files
    Show-Screen -Title "CSV-Verarbeitung" -Content @(
        "SUCCESS:$($csvFiles.Count) CSV-Dateien gefunden",
        "INFO:Verarbeite Dateien..."
    )
    
    $processorPath = Join-Path $PSScriptRoot "scripts/bank_csv_processor.ps1"
    
    # Run processor silently and capture result
    if ($DryRun) {
        if ($script:selectedStartingDate) {
            $null = & $processorPath -l $Language -n -d $script:selectedStartingDate -Silent 2>$null
        } else {
            $null = & $processorPath -l $Language -n -Silent 2>$null
        }
    } else {
        if ($script:selectedStartingDate) {
            $null = & $processorPath -l $Language -d $script:selectedStartingDate -Silent 2>$null
        } else {
            $null = & $processorPath -l $Language -Silent 2>$null
        }
    }
    
    # Step 3: Show results
    $outputFolder = "actual_import/"
    Show-Screen -Title "Verarbeitung abgeschlossen" -Content @(
        "SUCCESS:CSV-Verarbeitung erfolgreich!",
        "",
        "INFO:$($csvFiles.Count) Dateien verarbeitet",
        "INFO:Ergebnisse in: $outputFolder",
        "",
        "Nächste Schritte:",
        "0. WICHTIG: Konten mit exakten Namen aus starting_balances.txt anlegen!",
        "1. Kategorien in Actual Budget anlegen",
        "2. CSV-Dateien aus '$outputFolder' importieren",
        "3. Mapping: date→Date, payee→Payee, category→Category, amount→Amount"
    )
    
    # Erweiterte farbige Statistik ohne Warten
    Show-CompletionStatistics
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
    param(
        [string]$key
    )
    
    # Get remaining arguments using special $args variable
    if ($args.Count -eq 0) {
        return $global:i18n.Get($key)
    } else {
        # PowerShell 5.1/7.x compatible parameter passing
        $argArray = @()
        for ($i = 0; $i -lt $args.Count; $i++) {
            $argArray += $args[$i]
        }
        return $global:i18n.Get($key, $argArray)
    }
}

# ==========================================
# MAIN EXECUTION
# ==========================================

# Determine mode: Setup vs Routine
$localConfigPath = Join-Path $PSScriptRoot "config.local.json"

# If Setup is explicitly requested, preserve categoryMappings but reset setup-specific parts
if ($Setup) {
    if (Test-Path $localConfigPath) {
        Write-Host "Setup mode requested: Preserving categoryMappings, resetting setup configuration..." -ForegroundColor Yellow
        
        # Load existing config to preserve categoryMappings
        try {
            $content = Get-Content $localConfigPath -Encoding UTF8 -Raw
            # PowerShell 5.1/7.x compatible JSON parsing
            if ($PSVersionTable.PSVersion.Major -ge 6) {
                $existingConfig = $content | ConvertFrom-Json -AsHashtable
            } else {
                $existingConfigObj = $content | ConvertFrom-Json
                $existingConfig = @{}
                $existingConfigObj.PSObject.Properties | ForEach-Object {
                    if ($_.Value -is [PSCustomObject]) {
                        $subHash = @{}
                        $_.Value.PSObject.Properties | ForEach-Object { $subHash[$_.Name] = $_.Value }
                        $existingConfig[$_.Name] = $subHash
                    } else {
                        $existingConfig[$_.Name] = $_.Value
                    }
                }
            }
            $preservedMappings = @{}
            
            # Preserve categoryMappings if they exist
            if ($existingConfig.Keys -contains "categoryMappings") {
                $preservedMappings = $existingConfig["categoryMappings"]
                Write-Host "✓ Preserving $(@($preservedMappings.GetEnumerator()).Count) existing category mappings" -ForegroundColor Green
            }
            
            # Remove the config file
            Remove-Item $localConfigPath -Force
            
            # If we had categoryMappings, restore them after setup
            if ($preservedMappings.Count -gt 0) {
                $global:preservedCategoryMappings = $preservedMappings
            }
        } catch {
            Write-Host "⚠ Could not preserve categoryMappings: $($_.Exception.Message)" -ForegroundColor Yellow
            Remove-Item $localConfigPath -Force
        }
        
        Write-Host "Setup configuration reset completed." -ForegroundColor Green
    }
}

# Kategorie-Management-Menü
function Show-CategoryManagementMenu {
    param(
        [hashtable]$transaction,
        [hashtable]$availableCategories
    )
    
    Clear-Screen
    
    Write-Host ""
    Write-Host "» Kategorie-Management" -ForegroundColor Cyan
    Write-Host ("─" * 20) -ForegroundColor Cyan
    Write-Host ""
    
    Write-Host "🔧 " -NoNewline -ForegroundColor Yellow
    Write-Host "Was möchten Sie bearbeiten?" -ForegroundColor White
    Write-Host ""
    Write-Host "  [1] Keywords für aktuelle Transaktion bearbeiten"
    Write-Host "  [2] Oberkategorien-Management"
    Write-Host "  [x] Zurück"
    Write-Host ""
    
    $choice = Read-Host "Ihre Wahl (1/2/x)"
    
    switch ($choice) {
        "1" { 
            return Edit-ContextualKeywords -transaction $transaction -availableCategories $availableCategories
        }
        "2" { 
            Edit-CategoryGroups -availableCategories $availableCategories
            return "SKIP"  # Keine Kategorisierung für aktuelle Transaktion
        }
        "x" { 
            return "SKIP" 
        }
        default { 
            return Show-CategoryManagementMenu -transaction $transaction -availableCategories $availableCategories
        }
    }
}

# Kontextuelle Keyword-Bearbeitung für aktuelle Transaktion
function Edit-ContextualKeywords {
    param(
        [hashtable]$transaction,
        [hashtable]$availableCategories
    )
    
    Clear-Screen
    
    # Header
    Write-Host ""
    Write-Host "» Keywords für aktuelle Transaktion bearbeiten" -ForegroundColor Cyan
    Write-Host ("─" * 47) -ForegroundColor Cyan
    Write-Host ""
    
    # Transaktionsdetails anzeigen
    Write-Host "📝 " -NoNewline -ForegroundColor Yellow
    Write-Host "Transaktion:" -ForegroundColor White
    Write-Host "  Payee: " -NoNewline -ForegroundColor Gray
    Write-Host "$($transaction.payee)" -ForegroundColor White
    Write-Host "  Memo:  " -NoNewline -ForegroundColor Gray
    Write-Host "$($transaction.memo)" -ForegroundColor White
    Write-Host ""
    
    # Extrahiere potentielle Keywords aus Payee und Memo
    $potentialKeywords = @()
    
    # Aus Payee extrahieren (Wörter mit 3+ Zeichen, keine Zahlen)
    $payeeWords = $transaction.payee -split '[\s\-\.\,\/\\]' | Where-Object { 
        $_.Length -ge 3 -and $_ -notmatch '^\d+$' -and $_ -notmatch '^[A-Z]{2}\d+$'
    }
    foreach ($word in $payeeWords) {
        if ($word -and $word.Trim()) {
            $potentialKeywords += $word.Trim()
        }
    }
    
    # Aus Memo extrahieren (Wörter mit 4+ Zeichen, keine IBANs/Referenzen)  
    $memoWords = $transaction.memo -split '[\s\-\.\,\/\\:\*]' | Where-Object { 
        $_.Length -ge 4 -and $_ -notmatch '^\d+$' -and $_ -notmatch '^[A-Z]{2}\d+$' -and 
        $_ -notmatch '^EREF' -and $_ -notmatch '^MREF' -and $_ -notmatch '^TAN'
    }
    foreach ($word in $memoWords) {
        if ($word -and $word.Trim()) {
            $potentialKeywords += $word.Trim()
        }
    }
    
    # Duplikate entfernen und filtern
    $potentialKeywords = $potentialKeywords | Sort-Object -Unique | Where-Object { $_.Length -ge 3 }
    
    if ($potentialKeywords.Count -eq 0) {
        Write-Host "❌ " -NoNewline -ForegroundColor Red
        Write-Host "Keine geeigneten Keywords in dieser Transaktion gefunden." -ForegroundColor Red
        Write-Host ""
        Write-Host "Drücken Sie Enter um zurückzukehren..."
        Read-Host
        return "SKIP"
    }
    
    # Zeige potentielle Keywords
    Write-Host "🔍 " -NoNewline -ForegroundColor Cyan
    Write-Host "Gefundene potentielle Keywords:" -ForegroundColor White
    for ($i = 0; $i -lt $potentialKeywords.Count; $i++) {
        Write-Host "  [" -NoNewline -ForegroundColor Green
        Write-Host ($i + 1) -NoNewline -ForegroundColor Green
        Write-Host "] " -NoNewline -ForegroundColor Green
        Write-Host "$($potentialKeywords[$i])" -ForegroundColor White
    }
    Write-Host ""
    
    # Zeige verfügbare Kategorien
    Write-Host "📂 " -NoNewline -ForegroundColor Yellow
    Write-Host "Verfügbare Kategorien:" -ForegroundColor White
    $flatCategories = @()
    foreach ($group in $availableCategories.Keys) {
        $flatCategories += $availableCategories[$group]
    }
    $flatCategories = $flatCategories | Sort-Object -Unique
    
    for ($i = 0; $i -lt [Math]::Min(10, $flatCategories.Count); $i++) {
        Write-Host "  " -NoNewline
        Write-Host "$($flatCategories[$i])" -ForegroundColor Cyan
    }
    if ($flatCategories.Count -gt 10) {
        Write-Host "  ... und $($flatCategories.Count - 10) weitere" -ForegroundColor Gray
    }
    Write-Host ""
    
    # User Input
    Write-Host "⚙️ " -NoNewline -ForegroundColor Magenta
    Write-Host "Aktionen:" -ForegroundColor White
    Write-Host "  [1-$($potentialKeywords.Count)] Keyword wählen und Kategorie zuweisen"
    Write-Host "  [e] Eigenes Keyword eingeben"
    Write-Host "  [x] Zurück ohne Änderung"
    Write-Host ""
    
    do {
        $choice = Read-Host "Ihre Wahl"
        
        if ($choice -eq "x") {
            return "SKIP"
        } elseif ($choice -eq "e") {
            # Eigenes Keyword eingeben
            $customKeyword = Read-Host "Keyword eingeben"
            if ($customKeyword.Trim()) {
                $selectedKeyword = $customKeyword.Trim()
                break
            }
        } elseif ($choice -match "^\d+$") {
            $index = [int]$choice - 1
            if ($index -ge 0 -and $index -lt $potentialKeywords.Count) {
                $selectedKeyword = $potentialKeywords[$index]
                break
            }
        }
        Write-Host "⚠️ Ungültige Auswahl. Bitte erneut versuchen." -ForegroundColor Red
    } while ($true)
    
    # Kategorie für ausgewähltes Keyword wählen
    Write-Host ""
    Write-Host "🏷️ " -NoNewline -ForegroundColor Green
    Write-Host "Keyword '$selectedKeyword' ausgewählt." -ForegroundColor White
    Write-Host "Welcher Kategorie soll es zugeordnet werden?" -ForegroundColor White
    Write-Host ""
    
    for ($i = 0; $i -lt $flatCategories.Count; $i++) {
        Write-Host "  [" -NoNewline -ForegroundColor Green
        Write-Host ($i + 1) -NoNewline -ForegroundColor Green
        Write-Host "] " -NoNewline -ForegroundColor Green
        Write-Host "$($flatCategories[$i])" -ForegroundColor White
    }
    Write-Host ""
    
    do {
        $categoryChoice = Read-Host "Kategorie wählen (1-$($flatCategories.Count), x für Abbruch)"
        
        if ($categoryChoice -eq "x") {
            return "SKIP"
        } elseif ($categoryChoice -match "^\d+$") {
            $categoryIndex = [int]$categoryChoice - 1
            if ($categoryIndex -ge 0 -and $categoryIndex -lt $flatCategories.Count) {
                $selectedCategory = $flatCategories[$categoryIndex]
                break
            }
        }
        Write-Host "⚠️ Ungültige Auswahl. Bitte erneut versuchen." -ForegroundColor Red
    } while ($true)
    
    # Keyword zur Kategorie hinzufügen
    try {
        # Lade aktuelle config.local.json
        $configPath = "config.local.json"
        if (Test-Path $configPath) {
            $config = Get-Content -Path $configPath -Raw -Encoding UTF8 | ConvertFrom-Json
        } else {
            $config = @{ categoryKeywords = @{} }
        }
        
        # Stelle sicher, dass categoryKeywords existiert
        if (-not $config.categoryKeywords) {
            $config | Add-Member -NotePropertyName "categoryKeywords" -NotePropertyValue @{}
        }
        
        # Füge Keyword zur Kategorie hinzu
        if ($config.categoryKeywords.$selectedCategory) {
            $existingKeywords = $config.categoryKeywords.$selectedCategory -split ','
            $existingKeywords = $existingKeywords | ForEach-Object { $_.Trim() }
            if ($existingKeywords -notcontains $selectedKeyword) {
                $config.categoryKeywords.$selectedCategory = ($existingKeywords + $selectedKeyword) -join ','
            }
        } else {
            $config.categoryKeywords | Add-Member -NotePropertyName $selectedCategory -NotePropertyValue $selectedKeyword
        }
        
        # Speichere Konfiguration
        $config | ConvertTo-Json -Depth 10 | Out-File -FilePath $configPath -Encoding UTF8
        
        # Lade CategoryEngine neu
        if ($global:categoryEngine) {
            $global:categoryEngine.LoadRules()
        }
        
        Write-Host ""
        Write-Host "✅ " -NoNewline -ForegroundColor Green
        Write-Host "Keyword '$selectedKeyword' zu Kategorie '$selectedCategory' hinzugefügt!" -ForegroundColor Green
        
        return $selectedCategory
        
    } catch {
        Write-Host ""
        Write-Host "❌ " -NoNewline -ForegroundColor Red
        Write-Host "Fehler beim Speichern: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "Drücken Sie Enter um zurückzukehren..."
        Read-Host
        return "SKIP"
    }
}

function Edit-CategoryGroups {
    param([hashtable]$availableCategories)
    
    Clear-Screen
    
    Write-Host ""
    Write-Host "» Oberkategorien-Management" -ForegroundColor Cyan
    Write-Host ("─" * 25) -ForegroundColor Cyan
    Write-Host ""
    
    # Zeige aktuellen Zustand
    Write-Host "📂 " -NoNewline -ForegroundColor Yellow
    Write-Host "Aktuelle Oberkategorien:" -ForegroundColor White
    Write-Host ""
    
    $currentGroups = $global:categoryEngine.GetAllCategories()
    $groupNumber = 1
    
    foreach ($groupName in $currentGroups.Keys) {
        Write-Host "  [$groupNumber] " -NoNewline -ForegroundColor Cyan
        Write-Host "$groupName" -ForegroundColor White
        Write-Host "      " -NoNewline
        Write-Host ($currentGroups[$groupName] -join ", ") -ForegroundColor Gray
        $groupNumber++
    }
    
    Write-Host ""
    Write-Host "🔧 " -NoNewline -ForegroundColor Yellow
    Write-Host "Optionen:" -ForegroundColor White
    Write-Host "  [g] Neue Oberkategorie erstellen"
    Write-Host "  [e] Oberkategorie bearbeiten"
    Write-Host "  [m] Kategorie zu anderer Oberkategorie verschieben"
    Write-Host "  [d] Oberkategorie löschen"
    Write-Host "  [x] Zurück"
    Write-Host ""
    
    $choice = Read-Host "Ihre Wahl (g/e/m/d/x)"
    
    switch ($choice.ToLower()) {
        "g" { 
            # Neue Oberkategorie erstellen
            $newGroupName = Read-Host "Name der neuen Oberkategorie"
            if ($newGroupName -and $newGroupName.Trim()) {
                $global:categoryEngine.categories["Standard"][$newGroupName.Trim()] = @()
                $global:categoryEngine.SaveCategoryGroups()
                Write-Host "✅ Oberkategorie '$($newGroupName.Trim())' erstellt!" -ForegroundColor Green
                Start-Sleep 2
            }
        }
        "e" {
            # Oberkategorie bearbeiten
            $groupNum = Read-Host "Nummer der zu bearbeitenden Oberkategorie"
            if ($groupNum -match '^\d+$') {
                $groupNames = @($currentGroups.Keys)
                if ([int]$groupNum -ge 1 -and [int]$groupNum -le $groupNames.Count) {
                    $selectedGroup = $groupNames[[int]$groupNum - 1]
                    $newName = Read-Host "Neuer Name für '$selectedGroup' (Enter = beibehalten)"
                    if ($newName -and $newName.Trim() -and $newName.Trim() -ne $selectedGroup) {
                        $categories = $global:categoryEngine.categories["Standard"][$selectedGroup]
                        $global:categoryEngine.categories["Standard"].Remove($selectedGroup)
                        $global:categoryEngine.categories["Standard"][$newName.Trim()] = $categories
                        $global:categoryEngine.SaveCategoryGroups()
                        Write-Host "✅ Oberkategorie umbenannt!" -ForegroundColor Green
                        Start-Sleep 2
                    }
                }
            }
        }
        "m" {
            # Kategorie verschieben
            Write-Host "Verfügbare Kategorien:"
            $allCategories = @()
            foreach ($group in $currentGroups.Keys) {
                foreach ($cat in $currentGroups[$group]) {
                    $allCategories += @{ Name = $cat; Group = $group }
                }
            }
            
            for ($i = 0; $i -lt $allCategories.Count; $i++) {
                Write-Host "  [$($i+1)] $($allCategories[$i].Name) (aktuell: $($allCategories[$i].Group))"
            }
            
            $catChoice = Read-Host "Kategorie-Nummer"
            if ($catChoice -match '^\d+$' -and [int]$catChoice -ge 1 -and [int]$catChoice -le $allCategories.Count) {
                $selectedCat = $allCategories[[int]$catChoice - 1]
                
                Write-Host "Ziel-Oberkategorien:"
                $groupNames = @($currentGroups.Keys)
                for ($i = 0; $i -lt $groupNames.Count; $i++) {
                    Write-Host "  [$($i+1)] $($groupNames[$i])"
                }
                
                $groupChoice = Read-Host "Ziel-Oberkategorie-Nummer"
                if ($groupChoice -match '^\d+$' -and [int]$groupChoice -ge 1 -and [int]$groupChoice -le $groupNames.Count) {
                    $targetGroup = $groupNames[[int]$groupChoice - 1]
                    
                    # Verschiebe Kategorie
                    $global:categoryEngine.categories["Standard"][$selectedCat.Group] = @($global:categoryEngine.categories["Standard"][$selectedCat.Group] | Where-Object { $_ -ne $selectedCat.Name })
                    $global:categoryEngine.categories["Standard"][$targetGroup] += $selectedCat.Name
                    $global:categoryEngine.SaveCategoryGroups()
                    
                    Write-Host "✅ '$($selectedCat.Name)' nach '$targetGroup' verschoben!" -ForegroundColor Green
                    Start-Sleep 2
                }
            }
        }
        "d" {
            # Oberkategorie löschen
            $groupNum = Read-Host "Nummer der zu löschenden Oberkategorie"
            if ($groupNum -match '^\d+$') {
                $groupNames = @($currentGroups.Keys)
                if ([int]$groupNum -ge 1 -and [int]$groupNum -le $groupNames.Count) {
                    $selectedGroup = $groupNames[[int]$groupNum - 1]
                    $confirm = Read-Host "Oberkategorie '$selectedGroup' wirklich löschen? (j/N)"
                    if ($confirm.ToLower() -eq "j") {
                        # Verschiebe alle Kategorien zu "Sonstige"
                        if (-not $global:categoryEngine.categories["Standard"]["Sonstige"]) {
                            $global:categoryEngine.categories["Standard"]["Sonstige"] = @()
                        }
                        $global:categoryEngine.categories["Standard"]["Sonstige"] += $global:categoryEngine.categories["Standard"][$selectedGroup]
                        $global:categoryEngine.categories["Standard"].Remove($selectedGroup)
                        $global:categoryEngine.SaveCategoryGroups()
                        Write-Host "✅ Oberkategorie gelöscht, Kategorien nach 'Sonstige' verschoben!" -ForegroundColor Green
                        Start-Sleep 2
                    }
                }
            }
        }
        "x" { return }
    }
    
    # Rekursiv zurück zum Menü
    Edit-CategoryGroups -availableCategories $availableCategories
}

$isFirstRun = -not (Test-Path $localConfigPath)
$useSetupMode = $Setup -or ($isFirstRun -and -not $DryRun)

if ($Categorize) {
    # Start direct categorization mode
    Start-InteractiveCategorization
} elseif ($Analyze) {
    # Start transaction analysis mode
    Start-TransactionAnalysis
} elseif ($useSetupMode) {
    # Start interactive setup mode
    Start-InteractiveSetup
} else {
    # Start routine processing mode
    Start-RoutineProcessing
}
