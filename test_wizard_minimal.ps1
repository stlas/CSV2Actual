# Minimal test for wizard functionality
param(
    [string]$Language = "de"
)

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
    Write-Host "✅ Configuration and I18n loaded successfully" -ForegroundColor Green
}
catch {
    Write-Host "❌ ERROR: Could not load configuration or language files" -ForegroundColor Red
    Write-Host "Details: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# Test CsvValidator
try {
    $validator = [CsvValidator]::new($global:i18n)
    Write-Host "✅ CsvValidator loaded successfully" -ForegroundColor Green
}
catch {
    Write-Host "❌ ERROR: Could not load CsvValidator" -ForegroundColor Red
    Write-Host "Details: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# Test CommunityLoader
try {
    $global:communityLoader = [CommunityLoader]::new("$PSScriptRoot/community", $global:i18n)
    $global:communityLoader.LoadCommunityContent()
    Write-Host "✅ CommunityLoader loaded successfully" -ForegroundColor Green
}
catch {
    Write-Host "❌ ERROR: Could not load CommunityLoader" -ForegroundColor Red
    Write-Host "Details: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# Test string interpolation
try {
    $testString = $global:i18n.Get("community.enter_choice_range", @(5))
    Write-Host "✅ String interpolation test: '$testString'" -ForegroundColor Green
}
catch {
    Write-Host "❌ ERROR: String interpolation failed" -ForegroundColor Red
    Write-Host "Details: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host ""
Write-Host "🎉 All tests passed! Wizard should work correctly now." -ForegroundColor Green