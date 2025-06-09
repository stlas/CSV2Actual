# CSV2Actual - Interactive Wizard
# Version: 1.0
# Author: sTLAs (https://github.com/sTLAs)
# Interactive guided conversion from German bank CSV to Actual Budget
# Features: Internationalization (EN/DE), JSON Configuration, Step-by-step guidance

param(
    [Alias("l")][string]$Language = "en",
    [Alias("s")][switch]$Silent,
    [Alias("n")][switch]$DryRun,
    [Alias("h")][switch]$Help,
    [Alias("w")][switch]$Wizard = $true
)

# Set UTF-8 encoding for console
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

# Load modules
. "$PSScriptRoot/modules/Config.ps1"
. "$PSScriptRoot/modules/I18n.ps1"
. "$PSScriptRoot/modules/CsvValidator.ps1"
. "$PSScriptRoot/modules/CommunityLoader.ps1"

# Initialize configuration and internationalization
try {
    $global:config = [Config]::new("$PSScriptRoot/config.json")
    $langDir = $global:config.Get("paths.languageDir")
    $global:i18n = [I18n]::new($langDir, $Language)
    $global:communityLoader = [CommunityLoader]::new("$PSScriptRoot/community", $global:i18n)
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

function Show-Help {
    Write-Host (t "cli.help_title") -ForegroundColor Cyan
    Write-Host ""
    Write-Host (t "cli.usage") -ForegroundColor Yellow
    Write-Host "  powershell -File CSV2Actual.ps1 [OPTIONS]"
    Write-Host ""
    Write-Host (t "cli.options") -ForegroundColor Yellow
    Write-Host "  -Language, -l    Language (en/de) - default: en"
    Write-Host "  -DryRun, -n      $(t 'cli.dry_run_desc')"
    Write-Host "  -Silent, -s      $(t 'cli.silent_desc')"
    Write-Host "  -Wizard, -w      Interactive wizard mode (default)"
    Write-Host "  -Help, -h        $(t 'cli.help_desc')"
    Write-Host ""
    Write-Host (t "cli.examples") -ForegroundColor Yellow
    Write-Host "  # English wizard:"
    Write-Host "  powershell -File CSV2Actual.ps1"
    Write-Host ""
    Write-Host "  # German wizard:"
    Write-Host "  powershell -File CSV2Actual.ps1 -Language de"
    Write-Host ""
    Write-Host "  # Direct dry run:"
    Write-Host "  powershell -File CSV2Actual.ps1 -DryRun -Silent"
}

# Show help if requested
if ($Help) {
    Show-Help
    exit 0
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
    
    if ($messageKey) {
        Write-Host (t $messageKey) -ForegroundColor Yellow
    }
    Write-Host "Press Enter to continue..." -ForegroundColor Gray
    Read-Host | Out-Null
}

function Step1-Preparation {
    Write-StepHeader "wizard.step1_title" 1 5
    
    Write-Host (t "instructions.place_csv") -ForegroundColor White
    Write-Host (t "instructions.expected_format") -ForegroundColor Gray
    Write-Host ""
    
    # Check if source folder exists
    if (-not (Test-Path "source")) {
        Write-Host "Creating source/ folder..." -ForegroundColor Yellow
        New-Item -ItemType Directory -Path "source" -Force | Out-Null
    }
    
    # List available CSV files
    $csvFiles = Get-ChildItem -Path "source" -Filter "*.csv" -ErrorAction SilentlyContinue
    
    if ($csvFiles.Count -eq 0) {
        Write-Host ""
        Write-Host "WARNING: No CSV files found in source/ folder" -ForegroundColor Red
        Write-Host "Please add your bank CSV exports and run the script again." -ForegroundColor Yellow
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
        Write-Host "0. $(t 'community.use_default')" -ForegroundColor White
        
        for ($i = 0; $i -lt $csvFormats.Count; $i++) {
            $format = $csvFormats[$i]
            Write-Host "$($i + 1). $($format.name)" -ForegroundColor White
            if ($format.description) {
                Write-Host "   $($format.description)" -ForegroundColor Gray
            }
        }
        Write-Host ""
        
        do {
            $choice = Read-Host (t "community.enter_choice_range" @($availableBankFormats.Count)) 
            try {
                $choiceNum = [int]$choice
                if ($choiceNum -eq 0) {
                    $selectedBankFormat = $null
                    break
                } elseif ($choiceNum -ge 1 -and $choiceNum -le $csvFormats.Count) {
                    $selectedBankFormat = $csvFormats[$choiceNum - 1].id
                    Write-Host "$(t 'community.selected'): $($csvFormats[$choiceNum - 1].name)" -ForegroundColor Green
                    break
                } else {
                    Write-Host (t "community.invalid_choice") -ForegroundColor Red
                }
            } catch {
                Write-Host (t "community.invalid_choice") -ForegroundColor Red
            }
        } while ($true)
    }
    
    Write-Host ""
    
    # Category set selection
    $selectedCategorySet = $null
    $categorySets = $global:communityLoader.GetAvailableCategorySets($Language)
    
    if ($categorySets.Count -gt 0) {
        Write-Host (t "community.select_category_set") -ForegroundColor Yellow
        Write-Host "0. $(t 'community.use_default')" -ForegroundColor White
        
        for ($i = 0; $i -lt $categorySets.Count; $i++) {
            $categorySet = $categorySets[$i]
            Write-Host "$($i + 1). $($categorySet.name)" -ForegroundColor White
            if ($categorySet.description) {
                Write-Host "   $($categorySet.description)" -ForegroundColor Gray
            }
        }
        Write-Host ""
        
        do {
            $choice = Read-Host (t "community.enter_choice_range" @($availableCategorySets.Count))
            try {
                $choiceNum = [int]$choice
                if ($choiceNum -eq 0) {
                    $selectedCategorySet = $null
                    break
                } elseif ($choiceNum -ge 1 -and $choiceNum -le $categorySets.Count) {
                    $selectedCategorySet = $categorySets[$choiceNum - 1].id
                    Write-Host "$(t 'community.selected'): $($categorySets[$choiceNum - 1].name)" -ForegroundColor Green
                    break
                } else {
                    Write-Host (t "community.invalid_choice") -ForegroundColor Red
                }
            } catch {
                Write-Host (t "community.invalid_choice") -ForegroundColor Red
            }
        } while ($true)
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
    
    foreach ($file in $csvFiles) {
        Write-Host "VALIDATING: $($file.Name)..." -ForegroundColor Yellow
        
        $validation = $validator.ValidateFile($file.FullName)
        $validationResults[$file.Name] = $validation
        
        if ($validation.isValid) {
            Write-Host "   OK: Valid format" -ForegroundColor Green
        }
        else {
            Write-Host "   ERROR: Issues found:" -ForegroundColor Red
            foreach ($error in $validation.errors) {
                Write-Host "      - $error" -ForegroundColor Red
            }
            
            if ($validation.suggestions.Count -gt 0) {
                Write-Host "   SUGGESTIONS:" -ForegroundColor Yellow
                foreach ($suggestion in $validation.suggestions) {
                    Write-Host "      $suggestion" -ForegroundColor Yellow
                }
            }
            $allValid = $false
        }
        Write-Host ""
    }
    
    if (-not $allValid) {
        Write-Host (t 'messages.format_issues_warning') -ForegroundColor Yellow
        Write-Host (t 'messages.do_you_want') -ForegroundColor White
        Write-Host "1) $(t 'messages.continue_anyway')" -ForegroundColor Gray
        Write-Host "2) $(t 'messages.fix_automatically')" -ForegroundColor Gray
        Write-Host "3) $(t 'messages.exit_fix_manually')" -ForegroundColor Gray
        
        $choice = Read-Host (t 'messages.enter_choice')
        
        switch ($choice) {
            "2" {
                Write-Host (t 'messages.processor_can_handle') -ForegroundColor Green
                Write-Host (t 'messages.continuing_with_files') -ForegroundColor Yellow
            }
            "3" {
                Write-Host (t 'messages.fix_files_manually') -ForegroundColor Yellow
                exit 1
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
    
    $msg = (t 'messages.processing') -replace '\{0\}', 'CSV files'
    Write-Host "PROCESSING: $msg" -ForegroundColor Yellow
    Write-Host ""
    
    # Run the main processor
    $processorArgs = $params -join " "
    $languageArg = "-Language $Language"
    
    # Detect PowerShell executable
    $psCommand = if ($PSVersionTable.PSEdition -eq "Core") { "pwsh" } else { "powershell" }
    $command = "$psCommand -ExecutionPolicy Bypass -File bank_csv_processor.ps1 $processorArgs $languageArg"
    
    Write-Host "Executing: $command" -ForegroundColor Gray
    Write-Host ""
    
    Invoke-Expression $command
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host ""
        Write-Host "SUCCESS: $(t 'messages.success')" -ForegroundColor Green
    }
    else {
        Write-Host ""
        Write-Host "ERROR: Processing failed. Check the output above for details." -ForegroundColor Red
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
    $importMsg = (t 'instructions.import_files') -replace '\{0\}', 'actual_import'
    Write-Host "2. $importMsg" -ForegroundColor Yellow
    $mappingMsg = t 'instructions.set_mapping'
    Write-Host "3. $mappingMsg" -ForegroundColor Yellow
    $startMsg = t 'instructions.start_import'
    Write-Host "4. $startMsg" -ForegroundColor Yellow
    
    Write-Host ""
    Write-Host (t 'instructions.documentation_note') -ForegroundColor Cyan
    Write-Host "   - categories_ascii_safe.md (category list)" -ForegroundColor White
    Write-Host "   - actual_import/ACTUAL_IMPORT_GUIDE.txt (step-by-step)" -ForegroundColor White
    Write-Host "   - CATEGORIZATION_EXPLAINED.md (how categorization works)" -ForegroundColor White
    
    Write-Host ""
    Write-Host "SUCCESS: Setup complete! Your files are ready for Actual Budget." -ForegroundColor Green
    Write-Host ""
}

# MAIN EXECUTION
try {
    if ($Wizard -and -not $Silent) {
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
        # Direct execution without wizard
        $params = @()
        if ($DryRun) { $params += "-DryRun" }
        if ($Silent) { $params += "-Silent" }
        
        $processorArgs = $params -join " "
        Invoke-Expression "powershell -ExecutionPolicy Bypass -File bank_csv_processor.ps1 $processorArgs"
    }
}
catch {
    Write-Host ""
    Write-Host "ERROR: An error occurred during processing" -ForegroundColor Red
    $errorDetails = $_.Exception.Message
    Write-Host "Details: $errorDetails" -ForegroundColor Yellow
    exit 1
}