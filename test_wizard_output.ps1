# CSV2Actual - Wizard Output Logger
# Version: 1.0
# Author: sTLAs (https://github.com/sTLAs)
# Runs the wizard and captures all output to a file for debugging
param(
    [string]$Language = "de",
    [switch]$DryRun,
    [switch]$Help
)

if ($Help) {
    Write-Host "CSV2ACTUAL - WIZARD OUTPUT LOGGER" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Runs the wizard and logs all output to a file for debugging"
    Write-Host ""
    Write-Host "USAGE:"
    Write-Host "  powershell -ExecutionPolicy Bypass -File test_wizard_output.ps1 [OPTIONS]"
    Write-Host ""
    Write-Host "OPTIONS:"
    Write-Host "  -Language de|en  Language for output (default: de)"
    Write-Host "  -DryRun         Enable dry run mode"
    Write-Host "  -Help           Show this help"
    Write-Host ""
    Write-Host "OUTPUT:"
    Write-Host "  - Console output as normal"
    Write-Host "  - Full output logged to: wizard_output_YYYYMMDD_HHMMSS.log"
    Write-Host ""
    Write-Host "EXAMPLE:"
    Write-Host "  powershell -ExecutionPolicy Bypass -File test_wizard_output.ps1 -DryRun"
    exit 0
}

$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$logFile = "wizard_output_$timestamp.log"

Write-Host "CSV2ACTUAL - WIZARD OUTPUT LOGGER" -ForegroundColor Cyan
Write-Host "Logging all output to: $logFile" -ForegroundColor Yellow
Write-Host "Running wizard with Language=$Language, DryRun=$DryRun" -ForegroundColor Gray
Write-Host ""

# Build arguments
$args = @("-Language", $Language)
if ($DryRun) { $args += "-DryRun" }

# Create input for wizard (simulate user choosing option 2, then continuing)
$input = @("", "2", "", "")

try {
    # Run wizard with input simulation and capture all output
    $input | & powershell -ExecutionPolicy Bypass -File CSV2Actual.ps1 @args *>&1 | 
        ForEach-Object {
            # Write to console
            Write-Host $_
            # Write to log file with proper encoding
            Add-Content -Path $logFile -Value $_ -Encoding UTF8
        }
    
    Write-Host ""
    Write-Host "LOGGING COMPLETE!" -ForegroundColor Green
    Write-Host "Output saved to: $logFile" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "You can now analyze the output or share it for debugging." -ForegroundColor Yellow
}
catch {
    Write-Host "ERROR during logging: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Partial output may be in: $logFile" -ForegroundColor Yellow
}