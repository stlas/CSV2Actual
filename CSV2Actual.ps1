# CSV2Actual - Interactive Wizard
# Version: 1.1.0
# Author: sTLAs (https://github.com/sTLAs)
# Interactive guided conversion from German bank CSV to Actual Budget
# Features: Internationalization (EN/DE), JSON Configuration, Step-by-step guidance

param(
    [Alias("l")][string]$Language = "en",
    [Alias("s")][switch]$Silent,
    [Alias("n")][switch]$DryRun,
    [Alias("h")][switch]$Help,
    [Alias("w")][switch]$Wizard,
    [Alias("i")][switch]$Interview
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

# Early help check before any heavy processing
if ($Help) {
    Write-Host "CSV2Actual - Interactive Wizard Help" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "USAGE:" -ForegroundColor Yellow
    Write-Host "  powershell -File CSV2Actual.ps1 [OPTIONS]"
    Write-Host ""
    Write-Host "OPTIONS:" -ForegroundColor Yellow
    Write-Host "  -Language, -l    Language (en/de) - default: en"
    Write-Host "  -DryRun, -n      Preview mode - no files written"
    Write-Host "  -Silent, -s      Minimal output mode"
    Write-Host "  -Wizard, -w      Interactive wizard mode (default)"
    Write-Host "  -Interview, -i   Force setup interview (re-configure)"
    Write-Host "  -Help, -h        Show this help"
    Write-Host ""
    Write-Host "EXAMPLES:" -ForegroundColor Yellow
    Write-Host "  # English wizard:"
    Write-Host "  powershell -File CSV2Actual.ps1"
    Write-Host ""
    Write-Host "  # German wizard:"
    Write-Host "  powershell -File CSV2Actual.ps1 -Language de"
    Write-Host ""
    Write-Host "  # Re-run setup interview:"
    Write-Host "  powershell -File CSV2Actual.ps1 -Interview"
    Write-Host ""
    Write-Host "  # Silent processing:"
    Write-Host "  powershell -File CSV2Actual.ps1 -Silent"
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

# Check if local configuration exists, if not run setup interview
$localConfigPath = Join-Path $PSScriptRoot "config.local.json"
if ((-not (Test-Path $localConfigPath) -and -not $DryRun) -or $Interview) {
    Write-Host ""
    if ($Interview) {
        Write-Host (t "wizard_help.interview_rerun") -ForegroundColor Cyan
        Write-Host (t "wizard_help.config_overwrite") -ForegroundColor White
    } else {
        Write-Host (t "wizard_help.first_use_detected") -ForegroundColor Cyan
        Write-Host (t "wizard_help.starting_interview") -ForegroundColor White
    }
    Write-Host ""
    
    # Run setup interview
    $setupArgs = @()
    if ($Language -ne "en") { $setupArgs += "-Language $Language" }
    
    $pwshCommand = if (Get-Command "pwsh" -ErrorAction SilentlyContinue) { "pwsh" } else { "powershell" }
    $setupCommand = "$pwshCommand -ExecutionPolicy Bypass -File scripts/setup_interview.ps1 $($setupArgs -join ' ')"
    Invoke-Expression $setupCommand
    
    if ($LASTEXITCODE -ne 0) {
        Write-Host (t "wizard_help.interview_failed") -ForegroundColor Yellow
    } else {
        Write-Host (t "wizard_help.interview_complete") -ForegroundColor Green
        # Reload configuration with local settings (suppress duplicate loading message)
        $global:config.Reload()
    }
}

# Load currency from configuration
$currency = $global:config.Get("defaults.currency")
if (-not $currency) { $currency = "EUR" }  # Fallback

# Helper function for localization  
function t {
    [CmdletBinding()]
    param(
        [string]$key,
        [Parameter(Mandatory=$false)][object[]]$args = @()
    )
    
    if ($args.Length -eq 0) {
        return $global:i18n.Get($key)
    } else {
        return $global:i18n.Get($key, $args)
    }
}


function Write-Header {
    Clear-Host
    Write-Host ("=" * 60) -ForegroundColor Cyan
    Write-Host (t "main.title") -ForegroundColor Cyan
    Write-Host (t "main.subtitle") -ForegroundColor Gray
    Write-Host ("=" * 60) -ForegroundColor Cyan
    Write-Host ""
}

function Write-StepHeader {
    param([string]$stepKey, [int]$current, [int]$total)
    
    Write-Host ""
    Write-Host "[$current/$total] $(t $stepKey)" -ForegroundColor Yellow
    $descKey = $stepKey -replace "_title", "_desc"
    Write-Host (t $descKey) -ForegroundColor Gray
    Write-Host ("-" * 50) -ForegroundColor Gray
}

function Wait-UserInput {
    param([string]$messageKey = "")
    
    # Skip waiting for user input in DryRun or Silent mode
    if ($DryRun -or $Silent) {
        if ($messageKey) {
            Write-Host (t $messageKey) -ForegroundColor Yellow
        }
        Write-Host (t "wizard_help.skipping_input") -ForegroundColor Cyan
        return
    }
    
    if ($messageKey) {
        Write-Host (t $messageKey) -ForegroundColor Yellow
    }
    Write-Host (t "wizard_help.press_enter") -ForegroundColor Gray
    Read-Host | Out-Null
}

function Step1-Preparation {
    Write-StepHeader "wizard.step1_title" 1 5
    
    Write-Host (t "instructions.place_csv") -ForegroundColor White
    Write-Host (t "instructions.expected_format") -ForegroundColor Gray
    Write-Host ""
    
    # Check if source folder exists
    if (-not (Test-Path "source")) {
        Write-Host (t "wizard_help.creating_folder") -ForegroundColor Yellow
        New-Item -ItemType Directory -Path "source" -Force | Out-Null
    }
    
    # List available CSV files
    $csvFiles = Get-ChildItem -Path "source" -Filter "*.csv" -ErrorAction SilentlyContinue
    
    if ($csvFiles.Count -eq 0) {
        Write-Host ""
        Write-Host (t "wizard_help.no_csv_warning") -ForegroundColor Red
        Write-Host (t "wizard_help.add_files_restart") -ForegroundColor Yellow
        Write-Host ""
        exit 1
    }
    else {
        $msg = (t 'messages.files_found') -replace '\{0\}', $csvFiles.Count
        Write-Host "OK: $msg" -ForegroundColor Green
        Write-Host ""
        foreach ($file in $csvFiles) {
            Write-Host "   FILE: $($file.Name)" -ForegroundColor White
        }
        
        # Auto-discover IBANs and generate local configuration
        Write-Host ""
        $localConfigPath = "$PSScriptRoot/config.local.json"
        if (-not (Test-Path $localConfigPath) -or 
            (Get-Item $localConfigPath).LastWriteTime -lt (Get-ChildItem -Path "source" -Filter "*.csv" | Sort-Object LastWriteTime -Descending | Select-Object -First 1).LastWriteTime) {
            
            Write-Host "Auto-discovering account relationships..." -ForegroundColor Cyan
            
            # Run auto-discovery script
            try {
                if ($Silent) {
                    $discoveryResult = & "$PSScriptRoot/auto_discover_ibans_simple.ps1" -SourceDir "source" -OutputConfig $localConfigPath -Silent
                } else {
                    $discoveryResult = & "$PSScriptRoot/auto_discover_ibans_simple.ps1" -SourceDir "source" -OutputConfig $localConfigPath
                }
                
                if (Test-Path $localConfigPath) {
                    Write-Host "Created local configuration with discovered accounts" -ForegroundColor Green
                    
                    # Reload global config to include discovered data
                    $global:config.Reload()
                } else {
                    Write-Host "No IBANs discovered - using default configuration" -ForegroundColor Yellow
                }
            } catch {
                Write-Host "Auto-discovery failed: $($_.Exception.Message)" -ForegroundColor Yellow
                Write-Host "Using default configuration" -ForegroundColor Gray
            }
        } else {
            Write-Host "Using existing local configuration" -ForegroundColor Green
        }
    }
    
    Wait-UserInput
    return $csvFiles
}

function Step2-CommunitySettings {
    Write-StepHeader "wizard.step2_title" 2 5
    
    $communityStats = $global:communityLoader.GetCommunityStats()
    
    if ($communityStats.totalContributions -eq 0) {
        Write-Host (t "community.no_contributions") -ForegroundColor Gray
        Write-Host (t "community.using_defaults") -ForegroundColor White
        Write-Host ""
        Wait-UserInput
        return @{
            selectedBankFormat = $null
            selectedCategorySet = $null
        }
    }
    
    Write-Host (t "community.available_content") -ForegroundColor White
    Write-Host "  $(t 'community.csv_formats'): $($communityStats.csvFormats)" -ForegroundColor Gray
    Write-Host "  $(t 'community.category_sets'): $($communityStats.categorySets)" -ForegroundColor Gray
    Write-Host ""
    
    # Bank format selection
    $selectedBankFormat = $null
    $csvFormats = $global:communityLoader.GetAvailableCSVFormats($Language)
    
    if ($csvFormats.Count -gt 0) {
        Write-Host (t "community.select_bank_format") -ForegroundColor Yellow
        $defaultText = t 'community.use_default'
        Write-Host "1. $defaultText" -ForegroundColor White
        
        for ($i = 0; $i -lt $csvFormats.Count; $i++) {
            $format = $csvFormats[$i]
            $itemNumber = $i + 2
            Write-Host "$itemNumber. $($format.name)" -ForegroundColor White
            if ($format.description) {
                Write-Host "   $($format.description)" -ForegroundColor Gray
            }
        }
        Write-Host ""
        
        $maxChoice = $csvFormats.Count + 1
        
        # Auto-select default for DryRun or Silent mode
        if ($DryRun -or $Silent) {
            $choice = '1'
            Write-Host "Auto-selecting: 1 (Default)" -ForegroundColor Cyan
        } else {
            do {
                $promptText = $global:i18n.Get("community.enter_choice_range", @($maxChoice))
                $choice = Read-Host $promptText 
                if ([string]::IsNullOrWhiteSpace($choice)) {
                    $choice = '1'  # Default selection
                    Write-Host "Using default: 1" -ForegroundColor Cyan
                    break
                }
                try {
                    $choiceNum = [int]$choice
                    if ($choiceNum -ge 1 -and $choiceNum -le $csvFormats.Count + 1) {
                        break
                    } else {
                        Write-Host (t "community.invalid_choice") -ForegroundColor Red
                    }
                } catch {
                    Write-Host (t "community.invalid_choice") -ForegroundColor Red
                }
            } while ($true)
        }
        
        $choiceNum = [int]$choice
        if ($choiceNum -eq 1) {
            $selectedBankFormat = $null
        } else {
            $index = $choiceNum - 2
            $selectedFormat = $csvFormats[$index]
            $selectedBankFormat = $selectedFormat.id
            $selectedText = t 'community.selected'
            $formatName = $selectedFormat.name
            Write-Host "$selectedText`: $formatName" -ForegroundColor Green
        }
    }
    
    Write-Host ""
    
    # Category set selection
    $selectedCategorySet = $null
    $categorySets = $global:communityLoader.GetAvailableCategorySets($Language)
    
    if ($categorySets.Count -gt 0) {
        Write-Host (t "community.select_category_set") -ForegroundColor Yellow
        $defaultText = t 'community.use_default'
        Write-Host "1. $defaultText" -ForegroundColor White
        
        for ($i = 0; $i -lt $categorySets.Count; $i++) {
            $categorySet = $categorySets[$i]
            $itemNumber = $i + 2
            Write-Host "$itemNumber. $($categorySet.name)" -ForegroundColor White
            if ($categorySet.description) {
                Write-Host "   $($categorySet.description)" -ForegroundColor Gray
            }
        }
        Write-Host ""
        
        $maxCategoryChoice = $categorySets.Count + 1
        
        # Auto-select default for DryRun or Silent mode
        if ($DryRun -or $Silent) {
            $choice = '1'
            Write-Host "Auto-selecting: 1 (Default)" -ForegroundColor Cyan
        } else {
            do {
                $promptText = $global:i18n.Get("community.enter_choice_range", @($maxCategoryChoice))
                $choice = Read-Host $promptText
                if ([string]::IsNullOrWhiteSpace($choice)) {
                    $choice = '1'  # Default selection
                    Write-Host "Using default: 1" -ForegroundColor Cyan
                    break
                }
                try {
                    $choiceNum = [int]$choice
                    if ($choiceNum -ge 1 -and $choiceNum -le $categorySets.Count + 1) {
                        break
                    } else {
                        Write-Host (t "community.invalid_choice") -ForegroundColor Red
                    }
                } catch {
                    Write-Host (t "community.invalid_choice") -ForegroundColor Red
                }
            } while ($true)
        }
        
        $choiceNum = [int]$choice
        if ($choiceNum -eq 1) {
            $selectedCategorySet = $null
        } else {
            $index = $choiceNum - 2
            $selectedCategory = $categorySets[$index]
            $selectedCategorySet = $selectedCategory.id
            $selectedText = t 'community.selected'
            $categoryName = $selectedCategory.name
            Write-Host "$selectedText`: $categoryName" -ForegroundColor Green
        }
    }
    
    Wait-UserInput
    return @{
        selectedBankFormat = $selectedBankFormat
        selectedCategorySet = $selectedCategorySet
    }
}

function Step3-Validation {
    param([array]$csvFiles)
    
    Write-StepHeader "wizard.step3_title" 3 5
    
    # Ensure CsvValidator is available
    try {
        $validator = [CsvValidator]::new($global:i18n)
    } catch {
        Write-Host "ERROR: Could not initialize CSV validator: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "Retrying with fallback..." -ForegroundColor Yellow
        
        # Try to reload the module
        try {
            . "$PSScriptRoot/modules/CsvValidator.ps1"
            $validator = [CsvValidator]::new($global:i18n)
            Write-Host "CSV validator loaded successfully on retry." -ForegroundColor Green
        } catch {
            Write-Host "CRITICAL ERROR: Cannot load CSV validator. Skipping validation step." -ForegroundColor Red
            Write-Host "Details: $($_.Exception.Message)" -ForegroundColor Red
            Wait-UserInput
            return $null
        }
    }
    $allValid = $true
    $validationResults = @{}
    
    # Progress bar for validation
    Write-Host (t "processor.checking_files" @($csvFiles.Count)) -ForegroundColor Cyan
    $progressWidth = 40
    $validCount = 0
    $invalidCount = 0
    
    for ($i = 0; $i -lt $csvFiles.Count; $i++) {
        $file = $csvFiles[$i]
        $percent = [math]::Round(($i / $csvFiles.Count) * 100)
        $completed = [math]::Round(($i / $csvFiles.Count) * $progressWidth)
        $remaining = $progressWidth - $completed
        
        # Create progress bar
        $filledBar = '█' * $completed
        $emptyBar = ' ' * $remaining
        $progressBar = "[$filledBar$emptyBar] $percent%"
        Write-Host "`r$progressBar" -NoNewline -ForegroundColor Green
        
        $validation = $validator.ValidateFile($file.FullName)
        $validationResults[$file.Name] = $validation
        
        if ($validation.isValid) {
            $validCount++
        } else {
            $invalidCount++
            $allValid = $false
        }
        
        Start-Sleep -Milliseconds 100
    }
    
    # Final progress bar
    $finalBar = '█' * $progressWidth
    $progressBar = "[$finalBar] 100%"
    Write-Host "`r$progressBar" -ForegroundColor Green
    Write-Host ""
    
    # Summary
    if ($validCount -gt 0) {
        Write-Host (t "processor.valid_files" @($validCount)) -ForegroundColor Green
    }
    if ($invalidCount -gt 0) {
        Write-Host (t "processor.files_need_adjustment" @($invalidCount)) -ForegroundColor Yellow
    }
    
    if (-not $allValid) {
        Write-Host (t 'messages.format_issues_warning') -ForegroundColor Yellow
        Write-Host (t 'messages.do_you_want') -ForegroundColor White
        $msg1 = t 'messages.continue_anyway'
        $msg2 = t 'messages.fix_automatically'
        $msg3 = t 'messages.exit_fix_manually'
        Write-Host "Option 1: " -NoNewline -ForegroundColor Gray
        Write-Host $msg1 -ForegroundColor Gray
        Write-Host "Option 2: " -NoNewline -ForegroundColor Gray
        Write-Host $msg2 -ForegroundColor Gray
        Write-Host "Option 3: " -NoNewline -ForegroundColor Gray
        Write-Host $msg3 -ForegroundColor Gray
        
        # Auto-select option 2 for DryRun or Silent mode
        if ($DryRun -or $Silent) {
            $choice = 'option2'
            Write-Host "Auto-selecting: Option 2 (Automatic fix)" -ForegroundColor Cyan
        } else {
            $choice = Read-Host (t 'messages.enter_choice')
            if ([string]::IsNullOrWhiteSpace($choice)) {
                $choice = 'option2'  # Default to automatic fix
                Write-Host "Using default: Option 2" -ForegroundColor Cyan
            } elseif ($choice -eq '1') {
                $choice = 'option1'
            } elseif ($choice -eq '2') {
                $choice = 'option2'
            } elseif ($choice -eq '3') {
                $choice = 'option3'
            }
        }
        
        switch ($choice) {
            'option2' {
                Write-Host (t 'messages.processor_can_handle') -ForegroundColor Green
                Write-Host (t 'messages.continuing_with_files') -ForegroundColor Yellow
            }
            'option3' {
                Write-Host (t 'messages.fix_files_manually') -ForegroundColor Yellow
                if (-not ($DryRun -or $Silent)) {
                    exit 1
                }
            }
            default {
                Write-Host (t 'messages.continuing_with_files') -ForegroundColor Yellow
            }
        }
    }
    
    Wait-UserInput
    return $validationResults
}

function Step4-Processing {
    Write-StepHeader "wizard.step4_title" 4 5
    
    $params = @()
    if ($DryRun) { $params += "-DryRun" }
    if ($Silent) { $params += "-Silent" }
    
    # Get CSV file count for progress bar
    $csvFiles = Get-ChildItem -Path "source" -Filter "*.csv" -ErrorAction SilentlyContinue
    
    Write-Host (t "processor.converting_files" @($csvFiles.Count)) -ForegroundColor Cyan
    
    # Run the main processor silently and capture output
    $params += "-Silent"  # Force silent mode to reduce noise
    $processorArgs = $params -join " "
    $languageArg = "-Language $Language"
    
    # Detect PowerShell executable
    $psCommand = if ($PSVersionTable.PSEdition -eq "Core") { "pwsh" } else { "powershell" }
    $command = "$psCommand -ExecutionPolicy Bypass -File scripts/bank_csv_processor.ps1 $processorArgs $languageArg"
    
    # Progress simulation while processing
    $progressWidth = 40
    for ($i = 0; $i -le 100; $i += 5) {
        $completed = [math]::Round(($i / 100) * $progressWidth)
        $remaining = $progressWidth - $completed
        $filledBar = '█' * $completed
        $emptyBar = ' ' * $remaining
        $progressBar = "[$filledBar$emptyBar] $i%"
        Write-Host "`r$progressBar" -NoNewline -ForegroundColor Green
        
        if ($i -eq 50) {
            # Execute at halfway point
            $output = Invoke-Expression $command 2>&1
        }
        Start-Sleep -Milliseconds 100
    }
    
    # Final progress bar
    $finalBar = '█' * $progressWidth
    $progressBar = "[$finalBar] 100%"
    Write-Host "`r$progressBar" -ForegroundColor Green
    Write-Host ""
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host ""
        $successMsg = t 'messages.success'
        Write-Host $successMsg -ForegroundColor Green
    }
    else {
        Write-Host ""
        Write-Host (t "processor.processing_failed") -ForegroundColor Red
        exit 1
    }
    
    Wait-UserInput
}

function Step5-ImportGuide {
    Write-StepHeader "wizard.step5_title" 5 5
    
    $nextSteps = t 'instructions.next_steps'
    Write-Host (t 'messages.guide_next_steps') -ForegroundColor Cyan
    Write-Host ""
    
    # Show categories that need to be created
    Write-Host (t 'instructions.create_categories_desc') -ForegroundColor Yellow
    Write-Host ""
    
    $categories = @(
        (t 'instructions.transfer_categories'),
        (t 'instructions.salary_categories'), 
        (t 'instructions.expense_categories')
    )
    
    foreach ($category in $categories) {
        Write-Host "   - $category" -ForegroundColor White
    }
    
    Write-Host ""
    $importMsg = $global:i18n.Get('instructions.import_files', @('actual_import'))
    Write-Host "$importMsg" -ForegroundColor Yellow
    $mappingMsg = t 'instructions.set_mapping'
    Write-Host "$mappingMsg" -ForegroundColor Yellow
    $startMsg = t 'instructions.start_import'
    Write-Host "$startMsg" -ForegroundColor Yellow
    
    Write-Host ""
    
    # Show detailed account and category information
    Write-Host (t 'instructions.account_setup_title') -ForegroundColor Yellow
    
    # Display accounts that need to be created
    $latestBalanceFile = Get-ChildItem -Path "logs" -Filter "starting_balances_*.txt" -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 1
    if ($latestBalanceFile) {
        $balanceContent = Get-Content $latestBalanceFile.FullName -ErrorAction SilentlyContinue
        $inAccountSection = $false
        foreach ($line in $balanceContent) {
            if ($line -match "^Account: (.+)") {
                $accountName = $matches[1]
                Write-Host "   📊 $accountName" -ForegroundColor White
                $inAccountSection = $true
            } elseif ($inAccountSection -and $line -match "^  Starting Balance: (.+)") {
                Write-Host "      💰 Startsaldo: $($matches[1])" -ForegroundColor Cyan
            } elseif ($inAccountSection -and $line -match "^  Date: (.+)") {
                Write-Host "      📅 Startdatum: $($matches[1])" -ForegroundColor Gray
                $inAccountSection = $false
            }
        }
    } else {
        # Fallback: Show CSV files as account names
        $csvFiles = Get-ChildItem -Path "source" -Filter "*.csv" -ErrorAction SilentlyContinue
        foreach ($file in $csvFiles) {
            $accountName = $file.BaseName
            Write-Host "   📊 $accountName" -ForegroundColor White
        }
    }
    
    Write-Host ""
    Write-Host (t 'instructions.categories_to_create') -ForegroundColor Yellow
    
    # Get used categories from processed files
    $usedCategories = @()
    $outputFiles = Get-ChildItem -Path "actual_import" -Filter "*.csv" -ErrorAction SilentlyContinue
    foreach ($outputFile in $outputFiles) {
        try {
            $csvData = Import-Csv -Path $outputFile.FullName -Delimiter "," -Encoding UTF8
            $categories = $csvData | Where-Object { $_.category -and $_.category.Trim() -ne "" } | Select-Object -ExpandProperty category | Sort-Object -Unique
            $usedCategories += $categories
        } catch {
            # Ignore errors when reading output files
        }
    }
    
    $usedCategories = $usedCategories | Sort-Object -Unique
    if ($usedCategories.Count -gt 0) {
        $transferCategories = $usedCategories | Where-Object { $_ -match "Transfer" }
        $salaryCategories = $usedCategories | Where-Object { $_ -match "Gehalt|Salary" }
        $otherCategories = $usedCategories | Where-Object { $_ -notmatch "Transfer" -and $_ -notmatch "Gehalt|Salary" }
        
        if ($transferCategories.Count -gt 0) {
            Write-Host "   🔄 " + (t 'instructions.transfer_categories') + ":" -ForegroundColor Green
            foreach ($cat in $transferCategories) {
                Write-Host "      - $cat" -ForegroundColor White
            }
        }
        
        if ($salaryCategories.Count -gt 0) {
            Write-Host "   💼 " + (t 'instructions.salary_categories') + ":" -ForegroundColor Green
            foreach ($cat in $salaryCategories) {
                Write-Host "      - $cat" -ForegroundColor White
            }
        }
        
        if ($otherCategories.Count -gt 0) {
            Write-Host "   🏷️ " + (t 'instructions.expense_categories') + ":" -ForegroundColor Green
            foreach ($cat in $otherCategories) {
                Write-Host "      - $cat" -ForegroundColor White
            }
        }
        
        Write-Host ""
        Write-Host "   ✅ Gesamt: $($usedCategories.Count) Kategorien" -ForegroundColor Cyan
    } else {
        Write-Host "   ⚠️ Keine Kategorien in den Ausgabedateien gefunden" -ForegroundColor Yellow
    }
    
    Write-Host ""
    Write-Host (t 'instructions.documentation_note') -ForegroundColor Cyan
    Write-Host "   - actual_import/ACTUAL_IMPORT_GUIDE.txt (step-by-step)" -ForegroundColor White
    Write-Host "   - logs/starting_balances_*.txt (account setup)" -ForegroundColor White
    
    Write-Host ""
    $setupCompleteMsg = t 'messages.setup_complete'
    Write-Host $setupCompleteMsg -ForegroundColor Green
    
    # Add statistics
    Write-Host ""
    Write-Host (t 'messages.statistics_title') -ForegroundColor Cyan
    
    # Try to get statistics from processor log (check logs directory first)
    $logFiles = @()
    $logsDir = Join-Path $PSScriptRoot "logs"
    if (Test-Path $logsDir) {
        $logFiles += Get-ChildItem -Path $logsDir -Filter "csv_processor_*.log" -ErrorAction SilentlyContinue
    }
    $logFiles += Get-ChildItem -Path . -Filter "csv_processor_*.log" -ErrorAction SilentlyContinue
    $logFiles = $logFiles | Sort-Object LastWriteTime -Descending
    
    if ($logFiles.Count -gt 0) {
        $latestLog = $logFiles[0]
        $logContent = Get-Content $latestLog.FullName -ErrorAction SilentlyContinue
        
        # Extract statistics from log
        $fileCount = 0
        $transactionCount = 0
        $categorizedPercent = 0
        $transferCount = 0
        $accountCount = 0
        $totalStartingBalance = 0
        
        foreach ($line in $logContent) {
            if ($line -match "Verarbeitete Dateien: (\d+)") {
                $fileCount = $matches[1]
            }
            if ($line -match "Total Transaktionen: (\d+)") {
                $transactionCount = $matches[1]
            }
            if ($line -match "Kategorisierung: ([\d.]+)%") {
                $categorizedPercent = $matches[1]
            }
            if ($line -match "Transfer-Kategorien: (\d+)") {
                $transferCount = $matches[1]
            }
            if ($line -match "Total accounts: (\d+), Total balance: ([\d.,]+) $currency") {
                $accountCount = $matches[1]
                $totalStartingBalance = $matches[2] -replace '\.', '' -replace ',', '.'
            }
        }
        
        # Display statistics
        if ($fileCount -gt 0) {
            $statsFiles = $global:i18n.Get('messages.stats_files', @($fileCount))
            Write-Host "  $statsFiles" -ForegroundColor White
        }
        if ($transactionCount -gt 0) {
            $statsTransactions = $global:i18n.Get('messages.stats_transactions', @($transactionCount))
            Write-Host "  $statsTransactions" -ForegroundColor White
            
            $categorizedCount = [math]::Round([double]$transactionCount * [double]$categorizedPercent / 100.0)
            $statsCategorized = $global:i18n.Get('messages.stats_categorized', @($categorizedCount, $categorizedPercent))
            Write-Host "  $statsCategorized" -ForegroundColor Yellow
        }
        if ($transferCount -gt 0) {
            $statsTransfers = $global:i18n.Get('messages.stats_transfers', @($transferCount))
            Write-Host "  $statsTransfers" -ForegroundColor Green
        }
        if ($accountCount -gt 0) {
            Write-Host "  💰 Accounts: $accountCount, Starting Balance Total: $('{0:N2}' -f [decimal]$totalStartingBalance) $currency" -ForegroundColor Cyan
        }
    } else {
        # Fallback when no log file available
        $csvFiles = Get-ChildItem -Path "source" -Filter "*.csv" -ErrorAction SilentlyContinue
        if ($csvFiles.Count -gt 0) {
            $statsFiles = $global:i18n.Get('messages.stats_files', @($csvFiles.Count))
            Write-Host "  $statsFiles" -ForegroundColor White
        }
    }
    Write-Host ""
}

# MAIN EXECUTION
try {
    if ($Wizard) {
        Write-Header
        Write-Host (t "main.welcome") -ForegroundColor Green
        Write-Host ""
        
        $csvFiles = Step1-Preparation
        $communitySettings = Step2-CommunitySettings
        $validationResults = Step3-Validation $csvFiles
        Step4-Processing
        Step5-ImportGuide
    }
    else {
        # Direct execution - Auto-discover IBANs first, then process
        $localConfigPath = "$PSScriptRoot/config.local.json"
        $csvFiles = Get-ChildItem -Path "source" -Filter "*.csv" -ErrorAction SilentlyContinue
        
        if ($csvFiles.Count -gt 0 -and (-not (Test-Path $localConfigPath) -or 
            (Get-Item $localConfigPath).LastWriteTime -lt (Get-ChildItem -Path "source" -Filter "*.csv" | Sort-Object LastWriteTime -Descending | Select-Object -First 1).LastWriteTime)) {
            
            if (-not $Silent) {
                Write-Host "Auto-discovering account relationships..." -ForegroundColor Cyan
            }
            
            try {
                $discoveryArgs = @("-SourceDir", "source", "-OutputConfig", $localConfigPath)
                if ($Silent) { $discoveryArgs += "-Silent" }
                $discoveryResult = & "$PSScriptRoot/auto_discover_ibans_simple.ps1" @discoveryArgs
                
                if (Test-Path $localConfigPath) {
                    if (-not $Silent) {
                        Write-Host "Created local configuration with discovered accounts" -ForegroundColor Green
                    }
                    # Reload global config to include discovered data
                    $global:config = [Config]::new("$PSScriptRoot/config.json")
                }
            } catch {
                if (-not $Silent) {
                    Write-Host "Auto-discovery failed: $($_.Exception.Message)" -ForegroundColor Yellow
                }
            }
        }
        
        # Process CSV files
        $params = @()
        if ($DryRun) { $params += "-DryRun" }
        if ($Silent) { $params += "-Silent" }
        $params += "-Language $Language"
        
        $processorArgs = $params -join " "
        $pwshCommand = if (Get-Command "pwsh" -ErrorAction SilentlyContinue) { "pwsh" } else { "powershell" }
        Invoke-Expression "$pwshCommand -ExecutionPolicy Bypass -File scripts/bank_csv_processor.ps1 $processorArgs"
    }
}
catch {
    Write-Host ""
    Write-Host (t "wizard_help.processing_error") -ForegroundColor Red
    $errorDetails = $_.Exception.Message
    Write-Host "Details: $errorDetails" -ForegroundColor Yellow
    exit 1
}