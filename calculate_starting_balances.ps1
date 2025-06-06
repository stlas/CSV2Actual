# CSV2Actual - Starting Balance Calculator
# Version: 1.0
# Author: sTLAs (https://github.com/sTLAs)
# Calculates starting balances for all accounts based on CSV data
# Features: Internationalization (EN/DE), JSON Configuration

param(
    [Alias("l")][string]$Language = "en"
)

# Load modules
. "$PSScriptRoot/modules/Config.ps1"
. "$PSScriptRoot/modules/I18n.ps1"

# Initialize configuration and internationalization
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

Write-Host (t "balance.calculator_title") -ForegroundColor Cyan
Write-Host (t "balance.calculator_desc") -ForegroundColor Green
Write-Host ""

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
        # Load CSV with configured settings
        $delimiter = $csvSettings.delimiter
        $encoding = $csvSettings.encoding
        $csvData = Import-Csv -Path $file.FullName -Delimiter $delimiter -Encoding $encoding
        
        if ($csvData.Count -eq 0) {
            Write-Host "  " + (t "balance.file_empty_warning") -ForegroundColor Yellow
            continue
        }
        
        # Ersten Eintrag finden (ältester Saldo = Startsaldo)
        $firstEntry = $csvData | Sort-Object {
            try {
                [DateTime]::ParseExact($_.Buchungstag, "dd.MM.yyyy", $null)
            } catch {
                [DateTime]::MaxValue
            }
        } | Select-Object -First 1
        
        if ($firstEntry -and $firstEntry.'Saldo nach Buchung') {
            # Saldo nach Buchung konvertieren (Deutsch zu Englisch)
            $balanceAfterText = $firstEntry.'Saldo nach Buchung' -replace '\.', '' -replace ',', '.'
            $amountText = $firstEntry.'Betrag' -replace '\.', '' -replace ',', '.'
            try {
                $balanceAfter = [decimal]$balanceAfterText
                $amount = [decimal]$amountText
                # Startsaldo = Saldo nach Buchung - Buchungsbetrag
                $balance = $balanceAfter - $amount
                
                # Derive account name from filename using config
                $accountName = $fileName -replace " seit.*", ""
                
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
                    date = $firstEntry.Buchungstag
                    file = $fileName
                }
                
                Write-Host "  Starting Balance: $balance EUR (Date: $($firstEntry.Buchungstag))" -ForegroundColor Green
                
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
    
    Write-Host "  $($name.PadRight(30)) $($balanceFormatted.PadLeft(12)) EUR (Date: $date)" -ForegroundColor $color
}

Write-Host "  $("-" * 55)" -ForegroundColor Gray
Write-Host "  $("TOTAL BALANCE".PadRight(30)) $(("{0:N2}" -f $totalBalance).PadLeft(12)) EUR" -ForegroundColor White

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
$balanceOutput += "Account Name                   | Starting Balance EUR | Date"
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