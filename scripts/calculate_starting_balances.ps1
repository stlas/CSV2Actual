# CSV2Actual - Starting Balance Calculator
# Version: 1.2.1
# Author: sTLAs (https://github.com/sTLAs)
# Calculates starting balances for all accounts based on CSV data
# Features: Internationalization (EN/DE), JSON Configuration

param(
    [Alias("l")][string]$Language = "en"
)

# Load modules
. "$PSScriptRoot/../modules/Config.ps1"
. "$PSScriptRoot/../modules/I18n.ps1"
. "$PSScriptRoot/../modules/CsvValidator.ps1"

# Initialize configuration and internationalization
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
    param([string]$key, [array]$args = @())
    if ($args.Length -eq 1) {
        return $global:i18n.Format($key, $args[0].ToString())
    } elseif ($args.Length -eq 0) {
        return $global:i18n.Get($key)
    } else {
        return $global:i18n.Get($key, $args)
    }
}

Write-Host (t "balance.calculator_title") -ForegroundColor Cyan
Write-Host (t "balance.calculator_desc") -ForegroundColor Green
Write-Host ""

# Load currency from configuration
$currency = $global:config.Get("defaults.currency")
if (-not $currency) { $currency = "EUR" }  # Fallback

# Check source directory
$sourceDir = $global:config.GetSourceDir()
if (-not (Test-Path $sourceDir)) {
    Write-Host (t "balance.source_dir_not_found" @($sourceDir)) -ForegroundColor Red
    exit 1
}

# Find all CSV files
$csvSettings = $global:config.GetCSVSettings()
$excludePatterns = $csvSettings.excludePatterns
$csvFiles = Get-ChildItem -Path $sourceDir -Filter "*.csv" | Where-Object {
    $fileName = $_.BaseName
    $exclude = $false
    foreach ($pattern in $excludePatterns) {
        if ($fileName -match $pattern) {
            $exclude = $true
            break
        }
    }
    -not $exclude
}

if ($csvFiles.Count -eq 0) {
    Write-Host (t "balance.no_csv_files") -ForegroundColor Red
    exit 1
}

$msg = (t "balance.analyzing_files") -replace '\{0\}', $csvFiles.Count
Write-Host $msg -ForegroundColor Yellow
Write-Host ""

$accountBalances = @{}

foreach ($file in $csvFiles) {
    $fileName = $file.BaseName
    $msg = (t "balance.processing_file") -replace '\{0\}', $fileName
    Write-Host $msg -ForegroundColor White
    
    try {
        # Validate CSV and get column mapping
        $validator = [CsvValidator]::new($global:i18n)
        $validationResult = $validator.ValidateFile($file.FullName)
        
        # Load CSV with configured settings or validator fallback
        $delimiter = $csvSettings.delimiter
        $encoding = $csvSettings.encoding
        $csvData = Import-Csv -Path $file.FullName -Delimiter $delimiter -Encoding $encoding
        
        if (-not $csvData) {
            # Use validator's TryReadCsv as fallback
            $csvData = $validator.TryReadCsv($file.FullName)
        }
        
        if ($csvData.Count -eq 0) {
            Write-Host "  " + (t "balance.file_empty_warning") -ForegroundColor Yellow
            continue
        }
        
        # Get column mapping
        $columnMapping = $validationResult.columnMapping
        
        # Get dynamic column names
        $dateColumn = $columnMapping["Date"]
        $amountColumn = $columnMapping["Amount"]
        $balanceColumn = $columnMapping["Balance"]
        
        # Fallback to hardcoded names if mapping unavailable
        if (-not $dateColumn) { $dateColumn = "Buchungstag" }
        if (-not $amountColumn) { $amountColumn = "Betrag" }
        if (-not $balanceColumn) { $balanceColumn = "Saldo nach Buchung" }
        
        # Ersten Eintrag finden (ältester Saldo = Startsaldo)
        $firstEntry = $csvData | Sort-Object {
            try {
                if ($_.PSObject.Properties.Name -contains $dateColumn) {
                    [DateTime]::ParseExact($_.$dateColumn, "dd.MM.yyyy", $null)
                } else {
                    [DateTime]::MaxValue
                }
            } catch {
                [DateTime]::MaxValue
            }
        } | Select-Object -First 1
        
        if ($firstEntry -and $firstEntry.PSObject.Properties.Name -contains $balanceColumn -and $firstEntry.$balanceColumn) {
            # Saldo nach Buchung konvertieren (Deutsch zu Englisch)
            $balanceAfterText = $firstEntry.$balanceColumn -replace '\.', '' -replace ',', '.'
            $amountText = if ($firstEntry.PSObject.Properties.Name -contains $amountColumn) { $firstEntry.$amountColumn -replace '\.', '' -replace ',', '.' } else { '0' }
            try {
                $balanceAfter = [decimal]$balanceAfterText
                $amount = [decimal]$amountText
                # Startsaldo = Saldo nach Buchung - Buchungsbetrag
                $balance = $balanceAfter - $amount
                
                # Derive account name from filename using config
                $accountName = $fileName -replace " seit.*", ""
                
                # Handle Geschäftsanteil files specially (same as bank_csv_processor.ps1)
                if ($fileName -match "(.+?)\s+Geschäftsanteil(?:\s+Genossenschaft)?") {
                    $accountName = $matches[1] + " Geschäftsanteile"
                }
                
                # Try to map to configured account names
                $accountNames = $global:config.Get("accounts.accountNames")
                if ($accountNames) {
                    foreach ($accountKey in $accountNames.Keys) {
                        $configuredName = $global:config.GetAccountName($accountKey)
                        if ($fileName -match ($configuredName -replace "-", ".*")) {
                            $accountName = $configuredName
                            break
                        }
                    }
                }
                
                $accountBalances[$accountName] = @{
                    balance = $balance
                    date = if ($firstEntry.PSObject.Properties.Name -contains $dateColumn) { $firstEntry.$dateColumn } else { 'Unknown' }
                    file = $fileName
                }
                
                $displayDate = if ($firstEntry.PSObject.Properties.Name -contains $dateColumn) { $firstEntry.$dateColumn } else { 'Unknown' }
                Write-Host "  Starting Balance: $balance $currency (Date: $displayDate)" -ForegroundColor Green
                
            } catch {
                Write-Host "  " + (t "balance.balance_convert_error" @($balanceAfterText)) -ForegroundColor Red
            }
        } else {
            Write-Host "  " + (t "balance.no_balance_warning") -ForegroundColor Yellow
        }
        
    } catch {
        Write-Host (t "balance.error_reading_file" @($fileName, $_.Exception.Message)) -ForegroundColor Red
    }
}

Write-Host ""
Write-Host "STARTING BALANCES OVERVIEW FOR ACTUAL BUDGET:" -ForegroundColor Cyan
Write-Host ("=" * 50) -ForegroundColor Cyan

$sortedAccounts = $accountBalances.GetEnumerator() | Sort-Object Name
$totalBalance = 0

foreach ($account in $sortedAccounts) {
    $name = $account.Key
    $data = $account.Value
    $balance = $data.balance
    $date = $data.date
    $totalBalance += $balance
    
    $balanceFormatted = "{0:N2}" -f $balance
    $color = if ($balance -ge 0) { "Green" } else { "Red" }
    
    Write-Host "  $($name.PadRight(30)) $($balanceFormatted.PadLeft(12)) $currency (Date: $date)" -ForegroundColor $color
}

Write-Host "  $("-" * 55)" -ForegroundColor Gray
Write-Host "  $("TOTAL BALANCE".PadRight(30)) $(("{0:N2}" -f $totalBalance).PadLeft(12)) $currency" -ForegroundColor White

Write-Host ""
Write-Host "INSTRUCTIONS FOR ACTUAL BUDGET:" -ForegroundColor Yellow
Write-Host "1. Create the accounts in Actual Budget" -ForegroundColor White
Write-Host "2. Enter the starting balances shown above" -ForegroundColor White
Write-Host "3. Then import the CSV files from the 'actual_import' folder" -ForegroundColor White
Write-Host ""

# Startsalden in Datei speichern
$balanceOutput = @()
$balanceOutput += "# STARTING BALANCES FOR ACTUAL BUDGET"
$balanceOutput += "# Generated on: $(Get-Date -Format 'MM/dd/yyyy HH:mm')"
$balanceOutput += ""
$balanceOutput += "Account Name                   | Starting Balance $currency | Date"
$balanceOutput += ("-" * 65)

foreach ($account in $sortedAccounts) {
    $name = $account.Key
    $data = $account.Value
    $balance = "{0:N2}" -f $data.balance
    $date = $data.date
    $balanceOutput += "$($name.PadRight(30)) | $($balance.PadLeft(12)) | $date"
}

$balanceOutput += ("-" * 65)
$balanceOutput += "$("TOTAL BALANCE".PadRight(30)) | $(("{0:N2}" -f $totalBalance).PadLeft(12)) |"

$outputFile = "starting_balances.txt"
$balanceOutput | Out-File -FilePath $outputFile -Encoding UTF8
$msg = (t "balance.results_saved") -replace '\{0\}', $outputFile
Write-Host $msg -ForegroundColor Green

Write-Host ""
Write-Host (t "balance.calculation_complete") -ForegroundColor Green