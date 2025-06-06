# CSV2Actual - Test Data Switcher
# Version: 1.0
# Author: sTLAs (https://github.com/sTLAs)
# Switches between different test data sets
param(
    [Parameter(Mandatory=$true)]
    [ValidateSet("demo", "real")]
    [string]$TestSet,
    
    [switch]$Help
)

if ($Help) {
    Write-Host "CSV2ACTUAL - TEST DATA SWITCHER" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "USAGE:"
    Write-Host "  powershell -ExecutionPolicy Bypass -File switch_test_data.ps1 -TestSet <demo|real>"
    Write-Host ""
    Write-Host "OPTIONS:"
    Write-Host "  -TestSet demo    Use demo/example CSV files"
    Write-Host "  -TestSet real    Use real bank CSV files from test_data/real_bank_csvs/"
    Write-Host "  -Help           Show this help"
    Write-Host ""
    Write-Host "EXAMPLES:"
    Write-Host "  # Switch to real bank data"
    Write-Host "  powershell -ExecutionPolicy Bypass -File switch_test_data.ps1 -TestSet real"
    Write-Host ""
    Write-Host "  # Switch back to demo data"
    Write-Host "  powershell -ExecutionPolicy Bypass -File switch_test_data.ps1 -TestSet demo"
    exit 0
}

$sourceDir = "source"
$backupDir = "source_backup"
$demoDir = "test_data/demo_csvs"
$realDir = "test_data/real_bank_csvs"

# Create backup of current source if it doesn't exist
if (-not (Test-Path $backupDir)) {
    Write-Host "Creating backup of current source directory..." -ForegroundColor Yellow
    Copy-Item $sourceDir $backupDir -Recurse
}

try {
    switch ($TestSet) {
        "demo" {
            Write-Host "Switching to DEMO test data..." -ForegroundColor Green
            
            if (-not (Test-Path $demoDir)) {
                throw "Demo directory not found: $demoDir"
            }
            
            # Clear source and copy demo files
            Remove-Item "$sourceDir/*" -Force
            Copy-Item "$demoDir/*" $sourceDir -Force
            
            $fileCount = (Get-ChildItem $sourceDir -Filter "*.csv").Count
            Write-Host "SUCCESS: Switched to demo data ($fileCount CSV files)" -ForegroundColor Green
        }
        
        "real" {
            Write-Host "Switching to REAL bank test data..." -ForegroundColor Yellow
            
            if (-not (Test-Path $realDir)) {
                throw "Real bank data directory not found: $realDir"
            }
            
            $realFiles = Get-ChildItem $realDir -Filter "*.csv"
            if ($realFiles.Count -eq 0) {
                throw "No CSV files found in $realDir. Please add your bank CSV exports first."
            }
            
            # Clear source and copy real files
            Remove-Item "$sourceDir/*" -Force
            Copy-Item "$realDir/*" $sourceDir -Force
            
            Write-Host "SUCCESS: Switched to real bank data ($($realFiles.Count) CSV files)" -ForegroundColor Green
            Write-Host "WARNING: Make sure your CSV files contain German bank columns!" -ForegroundColor Yellow
        }
    }
    
    Write-Host ""
    Write-Host "Current files in source/:" -ForegroundColor Cyan
    Get-ChildItem $sourceDir -Filter "*.csv" | ForEach-Object {
        Write-Host "  - $($_.Name)" -ForegroundColor White
    }
    
    Write-Host ""
    Write-Host "You can now run CSV2Actual with the selected test data:" -ForegroundColor Cyan
    Write-Host "  powershell -ExecutionPolicy Bypass -File CSV2Actual.ps1 -Language de -DryRun" -ForegroundColor White
}
catch {
    Write-Host "ERROR: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}