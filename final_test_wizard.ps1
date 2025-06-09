# Final test of wizard t function from current CSV2Actual.ps1
param([string]$Language = "de")

# Load all modules exactly as CSV2Actual.ps1 does
. "$PSScriptRoot/modules/Config.ps1"
. "$PSScriptRoot/modules/I18n.ps1"
. "$PSScriptRoot/modules/CsvValidator.ps1"
. "$PSScriptRoot/modules/CommunityLoader.ps1"

# Initialize exactly like CSV2Actual.ps1
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

# EXACT Helper function from current CSV2Actual.ps1 line 39-46
function t {
    param([string]$key)
    if ($args.Count -eq 0) {
        return $global:i18n.Get($key)
    } else {
        return $global:i18n.Get($key, $args)
    }
}

Write-Host "=== FINAL TEST OF WIZARD T FUNCTION ===" -ForegroundColor Cyan

# Load community content exactly like wizard
$global:communityLoader.LoadCommunityContent()

# Get CSV formats exactly like Step2-CommunitySettings
$csvFormats = $global:communityLoader.GetAvailableCSVFormats($Language)
Write-Host "CSV Formats loaded: $($csvFormats.Count)" -ForegroundColor Green

if ($csvFormats.Count -gt 0) {
    Write-Host "`n--- Testing the EXACT wizard scenario ---" -ForegroundColor Yellow
    
    # Exact code from lines 172-183 in CSV2Actual.ps1
    for ($i = 0; $i -lt $csvFormats.Count; $i++) {
        $format = $csvFormats[$i]
        Write-Host "$($i + 1). $($format.name)" -ForegroundColor White
        if ($format.description) {
            Write-Host "   $($format.description)" -ForegroundColor Gray
        }
    }
    
    $maxChoice = $csvFormats.Count
    Write-Host "`nmaxChoice variable: $maxChoice" -ForegroundColor Cyan
    
    # EXACT line that was failing (line 183)
    $promptResult = t "community.enter_choice_range" $maxChoice
    Write-Host "Prompt result: '$promptResult'" -ForegroundColor White
    
    # Test if it contains {0} placeholder
    if ($promptResult -match '\{0\}') {
        Write-Host "ERROR: Still contains {0} placeholder!" -ForegroundColor Red
    } else {
        Write-Host "SUCCESS: No {0} placeholder found!" -ForegroundColor Green
    }
}

Write-Host "`n--- Additional tests ---" -ForegroundColor Yellow
$test1 = t "community.enter_choice_range" 5
$test2 = t "community.enter_choice_range" 10
Write-Host "Test with 5: '$test1'" -ForegroundColor White
Write-Host "Test with 10: '$test2'" -ForegroundColor White