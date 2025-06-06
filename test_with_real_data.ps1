# CSV2Actual - Real Data Tester
# Version: 1.0
# Author: sTLAs (https://github.com/sTLAs)
# Quick script to test with real bank CSV data
param(
    [string]$Language = "de",
    [switch]$DryRun,
    [switch]$Silent,
    [switch]$Help
)

if ($Help) {
    Write-Host "CSV2ACTUAL - REAL DATA TESTER" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Quick testing with real bank CSV files from test_data/real_bank_csvs/"
    Write-Host ""
    Write-Host "USAGE:"
    Write-Host "  powershell -ExecutionPolicy Bypass -File test_with_real_data.ps1 [OPTIONS]"
    Write-Host ""
    Write-Host "OPTIONS:"
    Write-Host "  -Language de|en  Language for output (default: de)"
    Write-Host "  -DryRun         Preview only, don't write files"
    Write-Host "  -Silent         Minimal output"
    Write-Host "  -Help           Show this help"
    Write-Host ""
    Write-Host "EXAMPLES:"
    Write-Host "  # Test with real data (dry run)"
    Write-Host "  powershell -ExecutionPolicy Bypass -File test_with_real_data.ps1 -DryRun"
    Write-Host ""
    Write-Host "  # Process real data"
    Write-Host "  powershell -ExecutionPolicy Bypass -File test_with_real_data.ps1"
    exit 0
}

$realDataDir = "test_data/real_bank_csvs"
$sourceDir = "source"
$backupDir = "source_backup_for_real_test"

Write-Host "CSV2ACTUAL - REAL DATA TESTER" -ForegroundColor Cyan
Write-Host ""

# Check if real data exists
if (-not (Test-Path $realDataDir)) {
    Write-Host "ERROR: Real data directory not found: $realDataDir" -ForegroundColor Red
    Write-Host "Please create the directory and add your bank CSV files." -ForegroundColor Yellow
    exit 1
}

$realFiles = Get-ChildItem $realDataDir -Filter "*.csv"
if ($realFiles.Count -eq 0) {
    Write-Host "ERROR: No CSV files found in $realDataDir" -ForegroundColor Red
    Write-Host "Please add your German bank CSV exports to test with real data." -ForegroundColor Yellow
    exit 1
}

try {
    # Backup current source
    Write-Host "Backing up current source directory..." -ForegroundColor Yellow
    if (Test-Path $backupDir) {
        Remove-Item $backupDir -Recurse -Force
    }
    Copy-Item $sourceDir $backupDir -Recurse
    
    # Switch to real data
    Write-Host "Switching to real bank data ($($realFiles.Count) files)..." -ForegroundColor Green
    Remove-Item "$sourceDir/*" -Force
    Copy-Item "$realDataDir/*" $sourceDir -Force
    
    Write-Host "Files loaded:" -ForegroundColor Cyan
    $realFiles | ForEach-Object {
        Write-Host "  - $($_.Name)" -ForegroundColor White
    }
    Write-Host ""
    
    # Build arguments
    $args = @()
    if ($DryRun) { $args += "-DryRun" }
    if ($Silent) { $args += "-Silent" }
    $args += "-Language"
    $args += $Language
    
    # Run the main processor
    Write-Host "Running CSV2Actual with real data..." -ForegroundColor Green
    Write-Host ""
    
    & "$PSScriptRoot/bank_csv_processor.ps1" @args
    
    Write-Host ""
    Write-Host "Real data test completed!" -ForegroundColor Green
}
catch {
    Write-Host "ERROR during real data test: $($_.Exception.Message)" -ForegroundColor Red
}
finally {
    # Restore original source
    Write-Host ""
    Write-Host "Restoring original test data..." -ForegroundColor Yellow
    Remove-Item "$sourceDir/*" -Force
    Copy-Item "$backupDir/*" $sourceDir -Force
    Remove-Item $backupDir -Recurse -Force
    Write-Host "Original test data restored." -ForegroundColor Green
}