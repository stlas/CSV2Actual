# Debug script for IBAN mapping

# Load modules
. "$PSScriptRoot/modules/Config.ps1"

# Initialize configuration
$global:config = [Config]::new("$PSScriptRoot/config.json")
$OwnIBANs = $global:config.GetIBANMapping()

Write-Host "=== DEBUG: IBAN Mapping ===" -ForegroundColor Cyan
Write-Host ""

Write-Host "Configured IBANs in config.json:" -ForegroundColor Yellow
foreach ($iban in $OwnIBANs.Keys) {
    Write-Host "  $iban -> $($OwnIBANs[$iban])" -ForegroundColor Green
}
Write-Host ""

# Check Genossenschaftsanteil files
$sourceDir = $global:config.GetSourceDir()
$genossenschaftFiles = Get-ChildItem -Path $sourceDir -Filter "*Geschäftsanteil*"

foreach ($file in $genossenschaftFiles) {
    Write-Host "File: $($file.Name)" -ForegroundColor Cyan
    
    try {
        $csvData = Import-Csv -Path $file.FullName -Delimiter ";" -Encoding UTF8
        
        foreach ($row in $csvData) {
            $targetIBAN = if ($row.'IBAN Zahlungsbeteiligter') { $row.'IBAN Zahlungsbeteiligter'.Trim() } else { '' }
            $accountIBAN = if ($row.'IBAN Auftragskonto') { $row.'IBAN Auftragskonto'.Trim() } else { '' }
            
            Write-Host "  Target IBAN (Zahlungsbeteiligter): '$targetIBAN'" -ForegroundColor White
            Write-Host "  Account IBAN (Auftragskonto): '$accountIBAN'" -ForegroundColor White
            
            if ($targetIBAN -and $OwnIBANs.ContainsKey($targetIBAN)) {
                Write-Host "    ✓ Target IBAN found in mapping -> $($OwnIBANs[$targetIBAN])" -ForegroundColor Green
            } else {
                Write-Host "    ✗ Target IBAN NOT found in mapping" -ForegroundColor Red
            }
            
            if ($accountIBAN -and $OwnIBANs.ContainsKey($accountIBAN)) {
                Write-Host "    ✓ Account IBAN found in mapping -> $($OwnIBANs[$accountIBAN])" -ForegroundColor Green
            } else {
                Write-Host "    ✗ Account IBAN NOT found in mapping" -ForegroundColor Red
            }
            
            # Check amount
            $amount = 0
            if ($row.Betrag) {
                $cleanAmount = $row.Betrag -replace '\.', '' -replace ',', '.'
                try {
                    $amount = [decimal]$cleanAmount
                } catch { }
            }
            
            Write-Host "  Amount: $amount" -ForegroundColor White
            Write-Host "  Payee: '$($row.'Name Zahlungsbeteiligter')'" -ForegroundColor White
            Write-Host "  Notes: '$($row.Verwendungszweck)'" -ForegroundColor White
            Write-Host ""
        }
        
    } catch {
        Write-Host "  Error reading file: $($_.Exception.Message)" -ForegroundColor Red
    }
    Write-Host ""
}

Write-Host "=== END DEBUG ===" -ForegroundColor Cyan