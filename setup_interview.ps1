# CSV2Actual - Setup Interview System
# Version: 1.1.0
# Author: sTLAs (https://github.com/sTLAs)
# Interactive setup for first-time users

param(
    [switch]$SkipIntroduction,
    [string]$Language = ""
)

$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

# Load modules
. "$PSScriptRoot/modules/Config.ps1"
. "$PSScriptRoot/modules/I18n.ps1"

# Helper function for localization  
function t {
    [CmdletBinding()]
    param(
        [string]$key,
        [Parameter(Mandatory=$false)][object[]]$args = @()
    )
    
    if ($global:i18n) {
        if ($args.Length -eq 0) {
            return $global:i18n.Get($key)
        } else {
            return $global:i18n.Get($key, $args)
        }
    } else {
        # Fallback if i18n not loaded
        return $key
    }
}

function Get-AccountNameFromCSV {
    param(
        [string]$FilePath,
        [hashtable]$FieldMappings,
        [hashtable]$Headers
    )
    
    try {
        $accountNameColumn = $FieldMappings["AccountName"]
        if (-not $accountNameColumn) { return "" }
        
        $delimiter = $Headers.Delimiter
        $encoding = [System.Text.Encoding]::UTF8
        
        # Read first few lines to find account name
        $lines = Get-Content -Path $FilePath -Encoding UTF8 -TotalCount 3
        if ($lines.Count -lt 2) { return "" }
        
        $headerLine = $lines[0] -split $delimiter
        $dataLine = $lines[1] -split $delimiter
        
        # Find the column index for account name
        for ($i = 0; $i -lt $headerLine.Count; $i++) {
            if ($headerLine[$i].Trim() -eq $accountNameColumn) {
                if ($i -lt $dataLine.Count) {
                    $accountName = $dataLine[$i].Trim()
                    # Clean up the account name
                    $accountName = $accountName -replace '^"', '' -replace '"$', ''
                    if ($accountName -and $accountName -ne "" -and $accountName.Length -le 50) {
                        return $accountName
                    }
                }
                break
            }
        }
    } catch {
        # Silently fail and return empty string
    }
    
    return ""
}

function Write-Banner {
    param([string]$Title, [string]$Color = "Cyan")
    
    $bannerTitle = t "setup.banner_title"
    $bannerSubtitle = t "setup.banner_subtitle"
    
    $banner = @"
=================================================================
                     $bannerTitle                        
                 $bannerSubtitle                    
=================================================================
"@
    Write-Host $banner -ForegroundColor $Color
    Write-Host ""
    Write-Host $Title -ForegroundColor Yellow
    Write-Host ""
}

function Write-StepBanner {
    param([string]$StepNumber, [string]$Title)
    
    Write-Host ""
    $stepFormat = t "setup.step_format"
    $stepText = $stepFormat -f $StepNumber, $Title
    Write-Host $stepText -ForegroundColor Green
    Write-Host ""
}

function Wait-UserConfirmation {
    param([string]$Message = "")
    
    Write-Host ""
    if ([string]::IsNullOrWhiteSpace($Message)) {
        $Message = t "setup.press_enter_continue"
    }
    Write-Host $Message -ForegroundColor Yellow
    Read-Host | Out-Null
}

function Get-UserChoice {
    param(
        [string]$Question,
        [array]$Options,
        [string]$Default = "",
        [switch]$AllowCustom
    )
    
    Write-Host $Question -ForegroundColor White
    Write-Host ""
    
    for ($i = 0; $i -lt $Options.Count; $i++) {
        $marker = if ($Options[$i] -eq $Default) { (t "setup.default_marker") } else { "" }
        Write-Host "  $($i + 1). $($Options[$i])$marker" -ForegroundColor Gray
    }
    
    if ($AllowCustom) {
        Write-Host "  $($Options.Count + 1). $(t 'setup.custom_input')" -ForegroundColor Gray
    }
    
    Write-Host ""
    
    do {
        $maxChoice = if ($AllowCustom) { $Options.Count + 1 } else { $Options.Count }
        $choice = Read-Host (t "setup.your_choice" @($maxChoice))
        
        if ([string]::IsNullOrWhiteSpace($choice) -and $Default) {
            return $Default
        }
        
        try {
            $choiceNum = [int]$choice
            if ($choiceNum -ge 1 -and $choiceNum -le $Options.Count) {
                return $Options[$choiceNum - 1]
            } elseif ($AllowCustom -and $choiceNum -eq ($Options.Count + 1)) {
                $custom = Read-Host (t "setup.custom_input")
                return $custom
            } else {
                Write-Host (t "setup.invalid_selection" @($maxChoice)) -ForegroundColor Red
            }
        } catch {
            Write-Host (t "setup.invalid_input") -ForegroundColor Red
        }
    } while ($true)
}

function Analyze-CSVFiles {
    param([string]$SourceDir)
    
    $csvFiles = Get-ChildItem -Path $SourceDir -Filter "*.csv" -ErrorAction SilentlyContinue
    if ($csvFiles.Count -eq 0) {
        return $null
    }
    
    $analysis = @{
        Files = $csvFiles
        Encodings = @{}
        Headers = @{}
        DateFormats = @()
        Currencies = @()
        DecimalFormats = @{}
        FieldMappings = @{}
        StartingBalances = @{}
    }
    
    Write-Host (t "setup.analyzing_files" @($csvFiles.Count)) -ForegroundColor Cyan
    
    foreach ($file in $csvFiles) {
        Write-Host "  • $($file.Name)" -ForegroundColor Gray
        
        try {
            # Try different encodings
            $encodings = @("UTF8", "Default", "ASCII", "Unicode")
            $bestEncoding = "UTF8"
            $bestContent = $null
            
            foreach ($encoding in $encodings) {
                try {
                    $content = Get-Content -Path $file.FullName -Encoding $encoding -First 10
                    if ($content -and $content[0] -match "[;,]") {
                        $bestEncoding = $encoding
                        $bestContent = $content
                        break
                    }
                } catch {}
            }
            
            if ($bestContent) {
                $analysis.Encodings[$file.Name] = $bestEncoding
                
                # Analyze header
                $delimiter = if ($bestContent[0] -match ";") { ";" } else { "," }
                $headers = $bestContent[0] -split $delimiter
                $analysis.Headers[$file.Name] = @{
                    Delimiter = $delimiter
                    Columns = $headers
                }
                
                # Analyze sample data
                if ($bestContent.Count -gt 1) {
                    $sampleRow = $bestContent[1] -split $delimiter
                    
                    # Look for date patterns
                    foreach ($cell in $sampleRow) {
                        if ($cell -match "\d{2}\.\d{2}\.\d{4}") {
                            if ($analysis.DateFormats -notcontains "dd.MM.yyyy") {
                                $analysis.DateFormats += "dd.MM.yyyy"
                            }
                        } elseif ($cell -match "\d{4}-\d{2}-\d{2}") {
                            if ($analysis.DateFormats -notcontains "yyyy-MM-dd") {
                                $analysis.DateFormats += "yyyy-MM-dd"
                            }
                        }
                    }
                    
                    # Look for currency patterns
                    foreach ($cell in $sampleRow) {
                        if ($cell -match "EUR|€") {
                            if ($analysis.Currencies -notcontains "EUR") {
                                $analysis.Currencies += "EUR"
                            }
                        } elseif ($cell -match "USD|\$") {
                            if ($analysis.Currencies -notcontains "USD") {
                                $analysis.Currencies += "USD"
                            }
                        }
                    }
                    
                    # Look for decimal formats
                    foreach ($cell in $sampleRow) {
                        if ($cell -match "\d+,\d{2}") {
                            $analysis.DecimalFormats["comma"] = $true
                        } elseif ($cell -match "\d+\.\d{2}") {
                            $analysis.DecimalFormats["dot"] = $true
                        }
                    }
                }
                
                # Field mapping suggestions
                $fieldMapping = @{}
                for ($i = 0; $i -lt $headers.Count; $i++) {
                    $header = $headers[$i].Trim()
                    
                    if ($header -match "Buchungstag|Date|Datum") {
                        $fieldMapping["Date"] = $header
                    } elseif ($header -match "Betrag|Amount|Umsatz") {
                        $fieldMapping["Amount"] = $header
                    } elseif ($header -match "Name.*Zahlungsbeteiligter|Payee|Empfänger") {
                        $fieldMapping["Payee"] = $header
                    } elseif ($header -match "IBAN.*Zahlungsbeteiligter|Payee.*IBAN") {
                        $fieldMapping["PayeeIBAN"] = $header
                    } elseif ($header -match "Verwendungszweck|Purpose|Description|Memo") {
                        $fieldMapping["Purpose"] = $header
                    } elseif ($header -match "Saldo.*nach.*Buchung|Balance.*After|Running.*Balance") {
                        $fieldMapping["Balance"] = $header
                    } elseif ($header -match "IBAN.*Auftrag|Account.*IBAN") {
                        $fieldMapping["AccountIBAN"] = $header
                    } elseif ($header -match "Bezeichnung.*Auftrag|Account.*Name|Account.*Description|Kontobezeichnung") {
                        $fieldMapping["AccountName"] = $header
                    }
                }
                $analysis.FieldMappings[$file.Name] = $fieldMapping
            }
        } catch {
            Write-Host (t "setup.analysis_warning" @($file.Name)) -ForegroundColor Yellow
        }
    }
    
    return $analysis
}

function Get-FieldMapping {
    param([hashtable]$Analysis)
    
    Write-StepBanner "4" (t "setup.field_mapping_title")
    
    Write-Host (t "setup.field_mapping_desc") -ForegroundColor White
    Write-Host (t "setup.field_mapping_confirm") -ForegroundColor White
    Write-Host ""
    
    # Get all unique columns from all files
    $allColumns = @()
    foreach ($fileHeaders in $Analysis.Headers.Values) {
        $allColumns += $fileHeaders.Columns
    }
    $allColumns = $allColumns | Sort-Object -Unique
    
    # Required field mappings
    $requiredFields = @{
        "Date" = (t "setup.field_date")
        "Amount" = (t "setup.field_amount")
        "Payee" = (t "setup.field_payee")
        "Purpose" = (t "setup.field_purpose")
        "Balance" = (t "setup.field_balance")
        "AccountIBAN" = (t "setup.field_account_iban")
    }
    
    $fieldMapping = @{}
    
    foreach ($field in $requiredFields.Keys) {
        $description = $requiredFields[$field]
        
        # Find best suggestion from analysis
        $suggestion = ""
        foreach ($fileMapping in $Analysis.FieldMappings.Values) {
            if ($fileMapping.ContainsKey($field)) {
                $suggestion = $fileMapping[$field]
                break
            }
        }
        
        Write-Host "=== $description ===" -ForegroundColor Yellow
        
        if ($suggestion) {
            Write-Host (t "setup.automatic_suggestion" @($suggestion)) -ForegroundColor Green
            $confirm = Read-Host (t "setup.accept_suggestion")
            
            if ($confirm -eq "j" -or $confirm -eq "J") {
                $fieldMapping[$field] = $suggestion
                Write-Host (t "setup.field_assigned" @($field, $suggestion)) -ForegroundColor Green
                continue
            }
        }
        
        Write-Host (t "setup.available_columns") -ForegroundColor Gray
        for ($i = 0; $i -lt $allColumns.Count; $i++) {
            Write-Host "  $($i + 1). $($allColumns[$i])" -ForegroundColor Gray
        }
        Write-Host ""
        
        $choice = Read-Host (t "setup.column_choice" @($description))
        
        try {
            $choiceNum = [int]$choice
            if ($choiceNum -ge 1 -and $choiceNum -le $allColumns.Count) {
                $fieldMapping[$field] = $allColumns[$choiceNum - 1]
            }
        } catch {
            $fieldMapping[$field] = $choice
        }
        
        Write-Host (t "setup.field_assigned" @($field, $fieldMapping[$field])) -ForegroundColor Green
        Write-Host ""
    }
    
    return $fieldMapping
}

# Main Interview Process
try {
    if (-not $SkipIntroduction) {
        Write-Banner (t "setup.welcome_title")
        
        Write-Host (t "setup.welcome_desc") -ForegroundColor White
        Write-Host (t "setup.welcome_desc2") -ForegroundColor White
        Write-Host (t "setup.welcome_desc3") -ForegroundColor White
        
        Wait-UserConfirmation
    }
    
    # Check if config.local.json already exists
    $localConfigPath = Join-Path $PSScriptRoot "config.local.json"
    if (Test-Path $localConfigPath) {
        Write-Host (t "setup.config_exists_warning") -ForegroundColor Yellow
        $overwrite = Read-Host (t "setup.run_setup_again")
        if ($overwrite -ne "j" -and $overwrite -ne "J") {
            Write-Host (t "setup.setup_cancelled") -ForegroundColor Yellow
            exit 0
        }
    }
    
    # Load initial configuration and language system
    try {
        $global:config = [Config]::new("$PSScriptRoot/config.json")
        $langDir = $global:config.Get("paths.languageDir")
        
        # Set default language if not provided
        if (-not $Language) {
            $Language = "de"  # Default to German for setup
        }
        
        $global:i18n = [I18n]::new($langDir, $Language)
    } catch {
        Write-Host "Warning: Could not load language files. Using fallback." -ForegroundColor Yellow
        $Language = "de"
        # Initialize fallback i18n to prevent null reference
        $global:i18n = $null
    }

    # Step 1: Language Selection
    Write-StepBanner "1" (t "setup.step1_title")
    
    if (-not $Language -or $Language -eq "de") {
        $languages = @("Deutsch (DE)", "English (EN)")
        $selectedLang = Get-UserChoice (t "setup.language_question" -ErrorAction SilentlyContinue) $languages "Deutsch (DE)"
        $Language = if ($selectedLang -eq "Deutsch (DE)") { "de" } else { "en" }
        
        # Reload with selected language
        try {
            $global:i18n = [I18n]::new($langDir, $Language)
        } catch {
            Write-Host (t "setup.language_load_warning") -ForegroundColor Yellow
        }
    }
    
    Write-Host (t "setup.language_selected" @($Language)) -ForegroundColor Green
    
    # Step 2: CSV File Instructions
    Write-StepBanner "2" (t "setup.step2_title")
    
    $sourceDir = Join-Path $PSScriptRoot "source"
    if (-not (Test-Path $sourceDir)) {
        New-Item -ItemType Directory -Path $sourceDir -Force | Out-Null
        Write-Host (t "setup.source_folder_created") -ForegroundColor Green
    }
    
    Write-Host (t "setup.csv_instructions") -ForegroundColor White
    Write-Host ""
    Write-Host "    $sourceDir" -ForegroundColor Yellow
    Write-Host ""
    Write-Host (t "setup.supported_formats") -ForegroundColor White
    Write-Host (t "setup.format_volksbank") -ForegroundColor Gray
    Write-Host (t "setup.format_sparkasse") -ForegroundColor Gray
    Write-Host (t "setup.format_standard") -ForegroundColor Gray
    Write-Host ""
    Write-Host (t "setup.multi_account_tip") -ForegroundColor Cyan
    Write-Host ""
    
    # Wait for user to copy files
    do {
        $confirmation = Read-Host (t "setup.confirm_files_copied")
        if ($confirmation.ToLower() -eq "weiter" -or $confirmation.ToLower() -eq "continue") {
            break
        } else {
            Write-Host (t "setup.copy_files_first") -ForegroundColor Yellow
        }
    } while ($true)
    
    # Step 3: Analyze CSV Files
    Write-StepBanner "3" (t "setup.step3_title")
    
    $analysis = Analyze-CSVFiles $sourceDir
    if (-not $analysis -or $analysis.Files.Count -eq 0) {
        Write-Host (t "setup.no_csv_found") -ForegroundColor Red
        Write-Host (t "setup.copy_files_restart") -ForegroundColor Yellow
        exit 1
    }
    
    Write-Host (t "setup.files_analyzed" @($analysis.Files.Count)) -ForegroundColor Green
    Write-Host ""
    
    # Step 4: Configuration Questions
    Write-StepBanner "4" (t "setup.step4_title")
    
    # Currency Detection
    $detectedCurrency = if ($analysis.Currencies.Count -gt 0) { $analysis.Currencies[0] } else { "EUR" }
    $currencies = @("EUR", "USD", "CHF", "GBP")
    if ($currencies -notcontains $detectedCurrency) {
        $currencies = @($detectedCurrency) + $currencies
    }
    $currency = Get-UserChoice (t "setup.currency_question") $currencies $detectedCurrency -AllowCustom
    
    # Date Format
    $detectedDateFormat = if ($analysis.DateFormats.Count -gt 0) { $analysis.DateFormats[0] } else { "dd.MM.yyyy" }
    $dateFormats = @("dd.MM.yyyy", "yyyy-MM-dd", "MM/dd/yyyy")
    $dateFormat = Get-UserChoice (t "setup.date_format_question") $dateFormats $detectedDateFormat
    
    # Decimal Format
    $hasComma = $analysis.DecimalFormats.ContainsKey("comma")
    $hasDot = $analysis.DecimalFormats.ContainsKey("dot")
    
    if ($hasComma -and -not $hasDot) {
        $decimalSeparator = ","
        $thousandsSeparator = "."
    } elseif ($hasDot -and -not $hasComma) {
        $decimalSeparator = "."
        $thousandsSeparator = ","
    } else {
        # Ask user
        $decimalFormats = @((t "setup.number_format_german"), (t "setup.number_format_international"))
        $selectedFormat = Get-UserChoice (t "setup.number_format_question") $decimalFormats (t "setup.number_format_german")
        
        if ($selectedFormat -eq (t "setup.number_format_german")) {
            $decimalSeparator = ","
            $thousandsSeparator = "."
        } else {
            $decimalSeparator = "."
            $thousandsSeparator = ","
        }
    }
    
    Write-Host (t "setup.number_format_selected" @($decimalSeparator, $thousandsSeparator)) -ForegroundColor Green
    
    # Field Mapping
    $fieldMapping = Get-FieldMapping $analysis
    
    # Step 4.5: Account Name Mapping
    Write-StepBanner "4.5" (t "setup.account_mapping_title")
    
    Write-Host (t "setup.account_mapping_desc") -ForegroundColor White
    Write-Host (t "setup.account_mapping_reason") -ForegroundColor Gray
    Write-Host ""
    
    $accountMapping = @{}
    foreach ($file in $analysis.Files) {
        $originalName = $file.BaseName
        
        # Try to get account name from CSV data if available
        $csvSuggestion = ""
        if ($analysis.FieldMappings[$file.Name] -and $analysis.FieldMappings[$file.Name]["AccountName"]) {
            $csvSuggestion = Get-AccountNameFromCSV -FilePath $file.FullName -FieldMappings $analysis.FieldMappings[$file.Name] -Headers $analysis.Headers[$file.Name]
        }
        
        # Fallback to cleaned filename
        $filenameSuggestion = $originalName -replace " seit \d+\.\d+\.\d+", "" -replace " Kontoauszug.*", "" -replace " Export.*", ""
        
        # Use CSV suggestion if available, otherwise use filename suggestion
        $suggestion = if ($csvSuggestion) { $csvSuggestion } else { $filenameSuggestion }
        
        Write-Host (t "setup.account_file" @($originalName)) -ForegroundColor Yellow
        Write-Host (t "setup.account_suggestion" @($suggestion)) -ForegroundColor Cyan
        
        do {
            $accountName = Read-Host (t "setup.account_name_prompt")
            if ([string]::IsNullOrWhiteSpace($accountName)) {
                $accountName = $suggestion
                Write-Host (t "setup.account_using_suggestion" @($suggestion)) -ForegroundColor Green
            }
            
            # Validate account name (no special characters that could cause issues)
            if ($accountName -match '[<>:"/\\|?*]') {
                Write-Host (t "setup.account_invalid_chars") -ForegroundColor Red
                continue
            }
            
            break
        } while ($true)
        
        $accountMapping[$originalName] = $accountName
        Write-Host (t "setup.account_mapped" @($originalName, $accountName)) -ForegroundColor Green
        Write-Host ""
    }
    
    # Step 5: Generate Configuration
    Write-StepBanner "5" (t "setup.step5_title")
    
    $localConfig = @{
        meta = @{
            version = "1.1.0"
            description = "CSV2Actual lokale Konfiguration (Setup Interview)"
            created = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
            autoGenerated = $true
        }
        defaults = @{
            language = $Language
            currency = $currency
            dateFormat = $dateFormat
            decimalSeparator = $decimalSeparator
            thousandsSeparator = $thousandsSeparator
        }
        csvFormat = @{
            delimiter = if ($analysis.Headers.Values[0].Delimiter) { $analysis.Headers.Values[0].Delimiter } else { ";" }
            encoding = if ($analysis.Encodings.Values[0]) { $analysis.Encodings.Values[0] } else { "UTF8" }
            fieldMapping = $fieldMapping
        }
        files = @{
            analyzed = $analysis.Files.Name
            encodings = $analysis.Encodings
        }
        accounts = @{
            nameMapping = $accountMapping
        }
    }
    
    # Save local configuration
    $json = $localConfig | ConvertTo-Json -Depth 10
    $json | Out-File -FilePath $localConfigPath -Encoding UTF8
    
    Write-Host (t "setup.config_saved") -ForegroundColor Green
    Write-Host ""
    
    # Summary
    Write-StepBanner "FERTIG" (t "setup.final_title")
    
    Write-Host (t "setup.setup_complete") -ForegroundColor Green
    Write-Host ""
    Write-Host (t "setup.your_configuration") -ForegroundColor White
    Write-Host (t "setup.config_language" @($Language)) -ForegroundColor Gray
    Write-Host (t "setup.config_currency" @($currency)) -ForegroundColor Gray
    Write-Host (t "setup.config_date_format" @($dateFormat)) -ForegroundColor Gray
    Write-Host (t "setup.config_decimal_format" @($decimalSeparator, $thousandsSeparator)) -ForegroundColor Gray
    Write-Host (t "setup.config_csv_files" @($analysis.Files.Count)) -ForegroundColor Gray
    Write-Host ""
    Write-Host (t "setup.next_steps") -ForegroundColor Cyan
    Write-Host (t "setup.next_step1") -ForegroundColor White
    Write-Host "     powershell -ExecutionPolicy Bypass -File CSV2Actual.ps1 -Language $Language" -ForegroundColor Yellow
    Write-Host (t "setup.next_step2") -ForegroundColor White
    Write-Host ""
    
} catch {
    Write-Host ""
    Write-Host (t "setup.setup_error" @($_.Exception.Message)) -ForegroundColor Red
    Write-Host (t "setup.setup_error_retry") -ForegroundColor Yellow
    exit 1
}