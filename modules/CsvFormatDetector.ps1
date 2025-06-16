# CSV2Actual - Dynamic CSV Format Detection Module
# Version: 1.2.2
# Author: sTLAs (https://github.com/sTLAs)
# Dynamically detects CSV formats and maps columns using community format definitions
# PowerShell 5.1 + 7.x Compatible

# Global variable to store community formats (PowerShell 5.1 compatible)
$global:CsvDetectorFormats = @{}
$global:CsvDetectorCommunityPath = ""

function Initialize-CsvFormatDetector {
    param(
        [string]$CommunityPath,
        [object]$I18n = $null
    )
    
    $global:CsvDetectorCommunityPath = $CommunityPath
    $global:CsvDetectorFormats = @{}
    
    Load-CommunityFormats
}

function Load-CommunityFormats {
    try {
        $formatPath = Join-Path $global:CsvDetectorCommunityPath "csv-formats"
        if (-not (Test-Path $formatPath)) { 
            Write-Warning "Community formats path not found: $formatPath"
            return 
        }
        
        $formatFiles = Get-ChildItem -Path $formatPath -Filter "*.json" -ErrorAction SilentlyContinue
        
        # PowerShell 5.1 compatible count check
        $fileCount = if ($formatFiles) { 
            if ($formatFiles.GetType().IsArray) { $formatFiles.Count } else { 1 } 
        } else { 0 }
        
        if ($fileCount -gt 0) {
            # Ensure we have an array even for single files (PowerShell 5.1 compat)
            $filesArray = @($formatFiles)
            
            foreach ($file in $filesArray) {
                try {
                    $content = Get-Content $file.FullName -Encoding UTF8 -Raw
                    $format = $content | ConvertFrom-Json
                    $global:CsvDetectorFormats[$file.BaseName] = $format
                } catch {
                    Write-Warning "Could not load format: $($file.Name) - $($_.Exception.Message)"
                }
            }
        }
    } catch {
        Write-Warning "Error loading community formats: $($_.Exception.Message)"
    }
}

function Get-SafeCount {
    param($Object)
    
    # PowerShell 5.1 safe count method
    if ($null -eq $Object) {
        return 0
    } elseif ($Object.GetType().IsArray) {
        return $Object.Count
    } elseif ($Object -is [System.Collections.ICollection]) {
        return $Object.Count
    } else {
        return 1
    }
}

function Get-SafeDivision {
    param(
        [int]$Numerator,
        [int]$Denominator
    )
    
    # PowerShell 5.1/7.x safe division
    if ($Denominator -eq 0) {
        return 0.0
    }
    
    # Force explicit numeric conversion to avoid array operation issues
    $num = [int]$Numerator
    $den = [int]$Denominator
    
    return [System.Math]::Round([double]$num / [double]$den, 2)
}

function Analyze-CSVStructure {
    param([string]$FilePath)
    
    $analysis = @{
        Headers = @()
        SampleData = $null
        Delimiter = ";"
        Encoding = "UTF8"
        DetectedFormat = $null
        ColumnMapping = @{}
    }
    
    try {
        if (-not (Test-Path $FilePath)) {
            Write-Warning "File not found: $FilePath"
            return $analysis
        }
        
        # Try different encodings
        $encodings = @("UTF8", "Default", "ASCII", "Unicode")
        $bestContent = $null
        
        foreach ($encoding in $encodings) {
            try {
                $content = Get-Content -Path $FilePath -Encoding $encoding -First 3 -ErrorAction SilentlyContinue
                $contentCount = Get-SafeCount $content
                
                if ($contentCount -gt 0 -and $content[0] -match "[;,]") {
                    $analysis.Encoding = $encoding
                    $bestContent = @($content)  # Ensure array for PowerShell 5.1
                    break
                }
            } catch { 
                continue 
            }
        }
        
        $bestContentCount = Get-SafeCount $bestContent
        if ($bestContentCount -eq 0) { 
            Write-Warning "Could not read CSV file or file is empty: $FilePath"
            return $analysis 
        }
        
        # Detect delimiter
        $headerLine = $bestContent[0]
        if ($headerLine -match ";") {
            $analysis.Delimiter = ";"
        } elseif ($headerLine -match ",") {
            $analysis.Delimiter = ","
        } elseif ($headerLine -match "`t") {
            $analysis.Delimiter = "`t"
        }
        
        # Extract headers safely
        try {
            $rawHeaders = $headerLine -split $analysis.Delimiter
            $headersList = @()
            
            foreach ($header in $rawHeaders) {
                $cleanHeader = ""
                if ($header -and $header.ToString().Trim()) {
                    $cleanHeader = $header.ToString().Trim('"').Trim()
                }
                if ($cleanHeader -ne "") {
                    $headersList += $cleanHeader
                }
            }
            
            $analysis.Headers = $headersList
        } catch {
            Write-Warning "Error parsing CSV headers: $($_.Exception.Message)"
            return $analysis
        }
        
        # Get sample data
        if ($bestContentCount -gt 1) {
            try {
                $rawSampleData = $bestContent[1] -split $analysis.Delimiter
                $sampleList = @()
                
                foreach ($sample in $rawSampleData) {
                    $cleanSample = ""
                    if ($sample -and $sample.ToString().Trim()) {
                        $cleanSample = $sample.ToString().Trim('"').Trim()
                    }
                    $sampleList += $cleanSample
                }
                
                $analysis.SampleData = $sampleList
            } catch {
                # Sample data is optional
            }
        }
        
        # Try to match against community formats
        $headersCount = Get-SafeCount $analysis.Headers
        if ($headersCount -gt 0) {
            $analysis.DetectedFormat = Find-MatchingCommunityFormat -Headers $analysis.Headers
            
            # Generate dynamic column mapping
            $analysis.ColumnMapping = Get-ColumnMapping -Headers $analysis.Headers -DetectedFormat $analysis.DetectedFormat
        }
        
    } catch {
        Write-Warning "Error analyzing CSV structure: $($_.Exception.Message)"
    }
    
    return $analysis
}

function Find-MatchingCommunityFormat {
    param([array]$Headers)
    
    $formatKeys = @($global:CsvDetectorFormats.Keys)
    $formatCount = Get-SafeCount $formatKeys
    
    if ($formatCount -eq 0) {
        return $null
    }
    
    foreach ($formatName in $formatKeys) {
        $format = $global:CsvDetectorFormats[$formatName]
        $matchScore = Get-FormatMatchScore -Headers $Headers -Format $format
        
        # If we match > 70% of expected columns, consider it a match
        if ($matchScore -gt 0.7) {
            return $formatName
        }
    }
    return $null
}

function Get-FormatMatchScore {
    param(
        [array]$Headers,
        [object]$Format
    )
    
    try {
        if (-not $Format -or -not $Format.columnMapping) {
            return 0.0
        }
        
        $properties = @($Format.columnMapping.PSObject.Properties)
        $totalColumns = Get-SafeCount $properties
        $matchedColumns = 0
        
        foreach ($columnProperty in $properties) {
            $expectedColumnName = $columnProperty.Value
            
            # Handle both single strings and arrays in columnMapping
            if ($expectedColumnName.GetType().IsArray) {
                $columnArray = @($expectedColumnName)
                foreach ($name in $columnArray) {
                    if ($Headers -contains $name) {
                        $matchedColumns++
                        break
                    }
                }
            } else {
                if ($Headers -contains $expectedColumnName) {
                    $matchedColumns++
                }
            }
        }
        
        return Get-SafeDivision -Numerator $matchedColumns -Denominator $totalColumns
        
    } catch {
        # Silently return 0.0 on calculation errors - the main functionality still works
        return 0.0
    }
}

function Get-ColumnMapping {
    param(
        [array]$Headers,
        [string]$DetectedFormat
    )
    
    $mapping = @{}
    
    # If we detected a community format, use its mapping
    if ($DetectedFormat -and $global:CsvDetectorFormats.ContainsKey($DetectedFormat)) {
        $format = $global:CsvDetectorFormats[$DetectedFormat]
        $properties = @($format.columnMapping.PSObject.Properties)
        
        foreach ($columnProperty in $properties) {
            $logicalName = $columnProperty.Name
            $physicalNames = $columnProperty.Value
            
            # Handle both single strings and arrays in columnMapping
            if ($physicalNames.GetType().IsArray) {
                $namesArray = @($physicalNames)
                foreach ($name in $namesArray) {
                    if ($Headers -contains $name) {
                        $mapping[$logicalName] = $name
                        break
                    }
                }
            } else {
                if ($Headers -contains $physicalNames) {
                    $mapping[$logicalName] = $physicalNames
                }
            }
        }
        return $mapping
    }
    
    # Fallback: Dynamic pattern-based detection
    return Get-DynamicMapping -Headers $Headers
}

function Get-DynamicMapping {
    param([array]$Headers)
    
    $mapping = @{}
    
    # Try to load patterns from community formats first
    $allPatterns = @{}
    $formatKeys = @($global:CsvDetectorFormats.Keys)
    
    foreach ($formatName in $formatKeys) {
        $format = $global:CsvDetectorFormats[$formatName]
        if ($format.PSObject.Properties.Name -contains "patterns") {
            $patternProperties = @($format.patterns.PSObject.Properties)
            
            foreach ($patternProperty in $patternProperties) {
                $fieldName = $patternProperty.Name
                $patterns = $patternProperty.Value
                
                if (-not $allPatterns.ContainsKey($fieldName)) {
                    $allPatterns[$fieldName] = @()
                }
                
                # PowerShell 5.1 compatible array handling
                if ($patterns.GetType().IsArray) {
                    $allPatterns[$fieldName] += @($patterns)
                } else {
                    $allPatterns[$fieldName] += $patterns
                }
            }
        }
    }
    
    # Fallback patterns if no community formats loaded
    if ((Get-SafeCount $allPatterns.Keys) -eq 0) {
        $allPatterns = @{
            'date' = @('buchungstag', 'date', 'datum', 'transaction.*date', 'booking.*date')
            'amount' = @('betrag', 'amount', 'umsatz', 'value', 'summe')
            'payee' = @('name.*zahlungsbeteiligter', 'payee', 'empfänger', 'recipient', 'name.*partner')
            'memo' = @('verwendungszweck', 'purpose', 'description', 'memo', 'reference', 'grund')
            'iban' = @('iban.*zahlungsbeteiligter', 'payee.*iban', 'partner.*iban', 'empfänger.*iban')
            'accountIban' = @('iban.*auftragskonto', 'account.*iban', 'own.*iban', 'konto.*iban', 'auftrag.*iban')
            'accountName' = @('bezeichnung.*auftragskonto', 'account.*name', 'account.*description', 'konto.*bezeichnung')
            'balance' = @('saldo.*nach.*buchung', 'balance.*after', 'running.*balance', 'kontostand')
        }
    }
    
    # Match headers against patterns
    $logicalFields = @($allPatterns.Keys)
    foreach ($logicalField in $logicalFields) {
        $fieldPatterns = @($allPatterns[$logicalField])
        
        foreach ($header in $Headers) {
            $headerLower = $header.ToLower()
            
            foreach ($pattern in $fieldPatterns) {
                if ($headerLower -match $pattern) {
                    $mapping[$logicalField] = $header
                    break
                }
            }
            
            if ($mapping.ContainsKey($logicalField)) {
                break
            }
        }
    }
    
    return $mapping
}

function Extract-AccountIBANFromCSV {
    param([string]$FilePath)
    
    $analysis = Analyze-CSVStructure -FilePath $FilePath
    $result = @{
        IBAN = $null
        AccountName = $null
        Success = $false
    }
    
    if (-not $analysis.ColumnMapping.ContainsKey('accountIban')) {
        return $result
    }
    
    try {
        $csvData = Import-Csv -Path $FilePath -Delimiter $analysis.Delimiter -Encoding $analysis.Encoding
        
        # PowerShell 5.1 compatible array handling
        $csvArray = @($csvData)
        $csvCount = Get-SafeCount $csvArray
        
        if ($csvCount -eq 0) {
            return $result
        }
        
        # Get first row to extract account IBAN
        $firstRow = $csvArray[0]
        $ibanColumnName = $analysis.ColumnMapping['accountIban']
        
        if ($firstRow -and $firstRow.PSObject.Properties.Name -contains $ibanColumnName) {
            $iban = $firstRow.$ibanColumnName
            if ($iban -and $iban -match "^[A-Z]{2}\d{2}[A-Z0-9]+$") {
                $result.IBAN = $iban
                $result.Success = $true
                
                # Try to get account name too
                if ($analysis.ColumnMapping.ContainsKey('accountName')) {
                    $accountNameColumn = $analysis.ColumnMapping['accountName']
                    if ($firstRow.PSObject.Properties.Name -contains $accountNameColumn) {
                        $result.AccountName = $firstRow.$accountNameColumn
                    }
                }
            }
        }
    } catch {
        Write-Warning "Error extracting IBAN from $FilePath`: $($_.Exception.Message)"
    }
    
    return $result
}

function Get-SupportedFormats {
    return @($global:CsvDetectorFormats.Keys)
}

function Get-FormatDetails {
    param([string]$FormatName)
    
    if ($global:CsvDetectorFormats.ContainsKey($FormatName)) {
        return $global:CsvDetectorFormats[$FormatName]
    }
    return $null
}