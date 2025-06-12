# CSV2Actual - IBAN Auto-Discovery Script
# Version: 1.2.0
# Author: sTLAs (https://github.com/sTLAs)
# Automatically discovers IBANs from CSV files and creates IBAN mapping for transfer detection

param(
    [Parameter(Mandatory=$true)]
    [string]$SourceDir,
    
    [Parameter(Mandatory=$true)]
    [string]$OutputConfig,
    
    [switch]$Silent
)

function Write-Status {
    param([string]$Message, [string]$Color = "White")
    if (-not $Silent) {
        Write-Host $Message -ForegroundColor $Color
    }
}

function Extract-IBANs-From-CSV {
    param([string]$FilePath)
    
    $result = @{
        ownIBAN = ""
        targetIBANs = @()
        accountName = ""
    }
    
    try {
        # Try different encodings to read the file
        $encodings = @("UTF8", "Default", "ASCII")
        $csvData = $null
        
        foreach ($encoding in $encodings) {
            try {
                $csvData = Import-Csv -Path $FilePath -Delimiter ";" -Encoding $encoding -ErrorAction Stop
                if ($csvData -and $csvData.Count -gt 0) {
                    break
                }
            } catch {
                continue
            }
        }
        
        if (-not $csvData) {
            Write-Status "Warning: Could not read $FilePath" "Yellow"
            return $result
        }
        
        # Extract own account IBAN from first row
        $firstRow = $csvData[0]
        if ($firstRow.PSObject.Properties.Name -contains "IBAN Auftragskonto") {
            $result.ownIBAN = $firstRow."IBAN Auftragskonto".Trim()
        }
        
        # Extract account name from first row
        if ($firstRow.PSObject.Properties.Name -contains "Bezeichnung Auftragskonto") {
            $result.accountName = $firstRow."Bezeichnung Auftragskonto".Trim()
        }
        
        # Extract all target IBANs from transactions
        foreach ($row in $csvData) {
            if ($row.PSObject.Properties.Name -contains "IBAN Zahlungsbeteiligter") {
                $targetIBAN = $row."IBAN Zahlungsbeteiligter".Trim()
                if ($targetIBAN -and $targetIBAN -ne "" -and $targetIBAN -match "^[A-Z]{2}[0-9]{2}[A-Z0-9]+$") {
                    if ($result.targetIBANs -notcontains $targetIBAN) {
                        $result.targetIBANs += $targetIBAN
                    }
                }
            }
        }
        
        Write-Status "  Found own IBAN: $($result.ownIBAN)" "Green"
        Write-Status "  Found $($result.targetIBANs.Count) unique target IBANs" "Green"
        Write-Status "  Account name: $($result.accountName)" "Green"
        
    } catch {
        Write-Status "Error processing $FilePath`: $($_.Exception.Message)" "Red"
    }
    
    return $result
}

function Create-IBAN-Mapping {
    param([hashtable]$DiscoveredData)
    
    $ibanMapping = @{}
    $accountNames = @{}
    
    # Create mapping from discovered data
    foreach ($fileName in $DiscoveredData.Keys) {
        $data = $DiscoveredData[$fileName]
        
        if ($data.ownIBAN) {
            # Create account key from filename
            $cleanFileName = $fileName -replace "\.csv$", "" -replace "\s+", "-"
            $accountKey = $cleanFileName.ToLower()
            
            # Map own IBAN to account
            $ibanMapping[$data.ownIBAN] = $accountKey
            
            # Use discovered account name or fallback to filename
            $displayName = if ($data.accountName) { $data.accountName } else { $cleanFileName }
            $accountNames[$accountKey] = $displayName
        }
    }
    
    # Cross-reference: if IBAN A appears as target in IBAN B's transactions, 
    # and IBAN B is our own account, then transfers between them should be detected
    foreach ($fileName in $DiscoveredData.Keys) {
        $data = $DiscoveredData[$fileName]
        
        foreach ($targetIBAN in $data.targetIBANs) {
            # Check if this target IBAN is one of our own accounts
            if ($ibanMapping.ContainsKey($targetIBAN)) {
                Write-Status "  Transfer relationship detected: $($data.ownIBAN) <-> $targetIBAN" "Cyan"
            }
        }
    }
    
    return @{
        ibanMapping = $ibanMapping
        accountNames = $accountNames
    }
}

# Main execution
Write-Status "CSV2Actual - IBAN Auto-Discovery" "Cyan"
Write-Status "Analyzing CSV files in: $SourceDir" "White"

if (-not (Test-Path $SourceDir)) {
    Write-Status "ERROR: Source directory not found: $SourceDir" "Red"
    exit 1
}

$csvFiles = Get-ChildItem -Path $SourceDir -Filter "*.csv"
if ($csvFiles.Count -eq 0) {
    Write-Status "ERROR: No CSV files found in $SourceDir" "Red"
    exit 1
}

Write-Status "Found $($csvFiles.Count) CSV files to analyze" "Yellow"

# Discover IBANs from each file
$discoveredData = @{}
foreach ($file in $csvFiles) {
    Write-Status "Analyzing: $($file.Name)" "White"
    $discoveredData[$file.Name] = Extract-IBANs-From-CSV -FilePath $file.FullName
}

# Create IBAN mapping
$mapping = Create-IBAN-Mapping -DiscoveredData $discoveredData

if ($mapping.ibanMapping.Count -eq 0) {
    Write-Status "WARNING: No IBANs discovered. Using fallback configuration." "Yellow"
    
    # Create minimal local config without IBAN mapping
    $localConfig = @{
        meta = @{
            autoGenerated = $true
            created = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            description = "CSV2Actual lokale Konfiguration (ohne IBAN-Discovery)"
            version = "1.2.0"
        }
        defaults = @{
            currency = "EUR"
            language = "de"
            dateFormat = "dd.MM.yyyy"
            decimalSeparator = ","
            thousandsSeparator = "."
        }
        files = @{
            analyzed = $csvFiles.Name
            encodings = @{}
        }
        csvFormat = @{
            delimiter = @()
            encoding = @()
            fieldMapping = @{}
        }
    }
    
    # Add encoding info for each file
    foreach ($file in $csvFiles) {
        $localConfig.files.encodings[$file.Name] = "UTF8"
        $localConfig.csvFormat.delimiter += ";"
        $localConfig.csvFormat.encoding += "UTF8"
    }
    
} else {
    Write-Status "Creating IBAN mapping with $($mapping.ibanMapping.Count) accounts" "Green"
    
    # Create comprehensive local config with IBAN mapping
    $localConfig = @{
        meta = @{
            autoGenerated = $true
            created = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            description = "CSV2Actual lokale Konfiguration mit IBAN-Discovery"
            version = "1.2.0"
        }
        defaults = @{
            currency = "EUR"
            language = "de"
            dateFormat = "dd.MM.yyyy"
            decimalSeparator = ","
            thousandsSeparator = "."
        }
        accounts = @{
            ibanMapping = $mapping.ibanMapping
            accountNames = $mapping.accountNames
        }
        files = @{
            analyzed = $csvFiles.Name
            encodings = @{}
        }
        csvFormat = @{
            delimiter = @()
            encoding = @()
            fieldMapping = @{}
        }
    }
    
    # Add encoding info for each file
    foreach ($file in $csvFiles) {
        $localConfig.files.encodings[$file.Name] = "UTF8"
        $localConfig.csvFormat.delimiter += ";"
        $localConfig.csvFormat.encoding += "UTF8"
    }
    
    # Show discovered accounts
    Write-Status "" "White"
    Write-Status "Discovered Accounts:" "Yellow"
    foreach ($iban in $mapping.ibanMapping.Keys) {
        $accountKey = $mapping.ibanMapping[$iban]
        $accountName = $mapping.accountNames[$accountKey]
        Write-Status "  $iban -> $accountName" "Green"
    }
}

# Save configuration
try {
    $localConfig | ConvertTo-Json -Depth 10 | Set-Content -Path $OutputConfig -Encoding UTF8
    Write-Status "" "White"
    Write-Status "Configuration saved to: $OutputConfig" "Green"
    Write-Status "IBAN discovery completed successfully!" "Green"
} catch {
    Write-Status "ERROR: Could not save configuration: $($_.Exception.Message)" "Red"
    exit 1
}

exit 0