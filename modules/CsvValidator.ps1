# CSV2Actual - CSV Validation Module
# Version: 1.2.2
# Author: sTLAs (https://github.com/sTLAs)
# Validates and fixes CSV file formats with internationalized error messages

class CsvValidator {
    [hashtable]$requiredColumns
    [hashtable]$alternativeColumns
    [object]$i18n
    
    CsvValidator() {
        $this.requiredColumns = @{
            "Date" = @("Buchungstag", "Valutadatum", "Date", "Datum")
            "Amount" = @("Betrag", "Amount", "Umsatz")
            "Payee" = @("Name Zahlungsbeteiligter", "Empfaenger", "Zahlungspflichtige", "Payee", "Beschreibung")
            "Purpose" = @("Verwendungszweck", "Buchungstext", "Purpose", "Description", "Memo")
            "Balance" = @("Saldo nach Buchung", "Saldo", "Balance")
            "IBAN" = @("IBAN Zahlungsbeteiligter", "IBAN", "Konto")
        }
        
        # Use global i18n if available
        if ($global:i18n) {
            $this.i18n = $global:i18n
        }
    }
    
    CsvValidator([object]$i18nInstance) {
        $this.requiredColumns = @{
            "Date" = @("Buchungstag", "Valutadatum", "Date", "Datum")
            "Amount" = @("Betrag", "Amount", "Umsatz")
            "Payee" = @("Name Zahlungsbeteiligter", "Empfaenger", "Zahlungspflichtige", "Payee", "Beschreibung")
            "Purpose" = @("Verwendungszweck", "Buchungstext", "Purpose", "Description", "Memo")
            "Balance" = @("Saldo nach Buchung", "Saldo", "Balance")
            "IBAN" = @("IBAN Zahlungsbeteiligter", "IBAN", "Konto")
        }
        $this.i18n = $i18nInstance
    }
    
    [string] t([string]$key) {
        if ($this.i18n) {
            return $this.i18n.Get($key)
        }
        return $key
    }
    
    [string] t([string]$key, [object[]]$args) {
        if ($this.i18n) {
            return $this.i18n.Get($key, $args)
        }
        # Fallback to English
        $fallbacks = @{
            "validation.file_not_found" = "File not found: {0}"
            "validation.could_not_read" = "Could not read CSV file with common encodings/delimiters"
            "validation.missing_columns" = "Missing required columns: {0}"
            "validation.error_reading_csv" = "Error reading CSV: {0}"
            "validation.suggest_column_fix" = "For '{0}', try renaming one of these columns:"
            "validation.available_columns" = "Available: {0}"
            "validation.expected_columns" = "Expected: {0}"
            "validation.date_format_warning" = "Date format may not be recognized. Expected: dd.MM.yyyy"
            "validation.amount_format_warning" = "Amount format may not be recognized. Expected: German format (1.234,56)"
            "validation.could_not_read_input" = "Could not read input file"
            "validation.csv_fixed_success" = "CSV file fixed and saved to: {0}"
            "validation.error_fixing_csv" = "Error fixing CSV: {0}"
        }
        
        $text = $fallbacks[$key]
        if (-not $text) { $text = $key }
        
        for ($i = 0; $i -lt $args.Length; $i++) {
            $text = $text -replace "\{$i\}", $args[$i]
        }
        
        return $text
    }
    
    [hashtable]ValidateFile([string]$filePath) {
        $result = @{
            isValid = $false
            errors = @()
            warnings = @()
            columnMapping = @{}
            suggestions = @()
        }
        
        if (-not (Test-Path $filePath)) {
            $result.errors += $this.t("validation.file_not_found", @($filePath))
            return $result
        }
        
        try {
            # Try different encodings and delimiters
            $csvData = $this.TryReadCsv($filePath)
            if (-not $csvData) {
                $result.errors += $this.t("validation.could_not_read")
                return $result
            }
            
            # Check column headers
            $headers = $csvData[0].PSObject.Properties.Name
            $mapping = $this.MapColumns($headers)
            
            $result.columnMapping = $mapping
            
            
            # Validate required columns
            $missingColumns = @()
            foreach ($required in @("Date", "Amount", "Payee")) {
                if (-not $mapping.ContainsKey($required) -or -not $mapping[$required]) {
                    $missingColumns += $required
                }
            }
            
            if ($missingColumns.Count -eq 0) {
                $result.isValid = $true
            }
            else {
                $result.errors += $this.t("validation.missing_columns", @(($missingColumns -join ', ')))
                $result.suggestions += $this.SuggestColumnFixes($headers, $missingColumns)
            }
            
            # Additional validations
            $this.ValidateDataTypes($csvData, $mapping, $result)
            
            # Validate balance consistency if both Amount and Balance columns are available
            if ($mapping.ContainsKey("Amount") -and $mapping.ContainsKey("Balance") -and $mapping["Amount"] -and $mapping["Balance"]) {
                $this.ValidateBalanceConsistency($csvData, $mapping, $result)
            }
            
        }
        catch {
            $errorMessage = if ($_.Exception.Message) { $_.Exception.Message } else { "Unknown error" }
            $result.errors += $this.t("validation.error_reading_csv", @($errorMessage))
        }
        
        return $result
    }
    
    [object]TryReadCsv([string]$filePath) {
        # Enhanced encoding detection with BOM handling
        $encodingResults = $this.DetectEncoding($filePath)
        
        $encodings = @("UTF8", "Default", "ASCII", "Unicode")
        if ($encodingResults.recommendedEncoding) {
            $encodings = @($encodingResults.recommendedEncoding) + $encodings
        }
        
        $delimiters = @(";", ",", "`t")
        if ($encodingResults.recommendedDelimiter) {
            $delimiters = @($encodingResults.recommendedDelimiter) + $delimiters
        }
        
        foreach ($encoding in $encodings) {
            foreach ($delimiter in $delimiters) {
                try {
                    # First try with normal Import-Csv
                    $data = Import-Csv -Path $filePath -Delimiter $delimiter -Encoding $encoding -ErrorAction Stop
                    if ($data -and $data[0] -and $data[0].PSObject.Properties.Count -gt 3) {
                        return $data
                    }
                }
                catch {
                    # Try with Get-Content and ConvertFrom-Csv for problematic files
                    try {
                        $content = Get-Content -Path $filePath -Encoding $encoding -ErrorAction Stop
                        if ($content -and $content.Count -gt 1) {
                            $data = $content | ConvertFrom-Csv -Delimiter $delimiter -ErrorAction Stop
                            if ($data -and $data[0] -and $data[0].PSObject.Properties.Count -gt 3) {
                                return $data
                            }
                        }
                    }
                    catch {
                        continue
                    }
                }
            }
        }
        
        # Try Windows-1252 encoding with Get-Content and manual parsing
        try {
            $content = Get-Content -Path $filePath -Encoding ([System.Text.Encoding]::GetEncoding(1252)) -ErrorAction Stop
            if ($content -and $content.Count -gt 1) {
                foreach ($delimiter in $delimiters) {
                    $tempFile = $null
                    try {
                        $tempFile = [System.IO.Path]::GetTempFileName()
                        $content | Out-File -FilePath $tempFile -Encoding UTF8
                        $data = Import-Csv -Path $tempFile -Delimiter $delimiter -ErrorAction Stop
                        Remove-Item -Path $tempFile -Force -ErrorAction SilentlyContinue
                        if ($data -and $data[0] -and $data[0].PSObject.Properties.Count -gt 3) {
                            return $data
                        }
                    }
                    catch {
                        if ($tempFile -and (Test-Path $tempFile)) {
                            Remove-Item -Path $tempFile -Force -ErrorAction SilentlyContinue
                        }
                        continue
                    }
                }
            }
        }
        catch {
            # Continue to next attempt
        }
        return $null
    }
    
    [hashtable] DetectEncoding([string]$filePath) {
        $result = @{
            hasBOM = $false
            bomType = "None"
            recommendedEncoding = $null
            recommendedDelimiter = $null
            fileSize = 0
        }
        
        try {
            $rawBytes = [System.IO.File]::ReadAllBytes($filePath)
            $result.fileSize = $rawBytes.Length
            
            # BOM Detection
            if ($rawBytes.Length -ge 3) {
                if ($rawBytes[0] -eq 0xEF -and $rawBytes[1] -eq 0xBB -and $rawBytes[2] -eq 0xBF) {
                    $result.hasBOM = $true
                    $result.bomType = "UTF-8"
                    $result.recommendedEncoding = "UTF8"
                }
            }
            
            # Try different encodings and score them
            $encodings = @(
                @{Name = "UTF8"; Encoding = [System.Text.Encoding]::UTF8},
                @{Name = "Default"; Encoding = [System.Text.Encoding]::Default},
                @{Name = "ASCII"; Encoding = [System.Text.Encoding]::ASCII}
            )
            
            $bestScore = -1
            foreach ($enc in $encodings) {
                try {
                    $content = $enc.Encoding.GetString($rawBytes)
                    $lines = $content -split "`n" | Select-Object -First 3
                    
                    if ($lines.Count -gt 0) {
                        $firstLine = $lines[0]
                        
                        # Score encoding quality
                        $score = 0
                        $hasValidCSV = $firstLine -match "[;,]"
                        $hasControlChars = $content -match "[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]"
                        $hasGermanChars = $content -match "[a-zA-Z]"
                        
                        if ($hasValidCSV) { $score += 3 }
                        if ($hasGermanChars -and $enc.Name -eq "UTF8") { $score += 2 }
                        if (-not $hasControlChars) { $score += 1 }
                        
                        if ($score -gt $bestScore) {
                            $bestScore = $score
                            $result.recommendedEncoding = $enc.Name
                            
                            # Detect delimiter - using safe approach
                            $tabChar = [char]9
                            $delimiters = @(";", ",", $tabChar, "|")
                            $delimiterCounts = @{}
                            foreach ($delim in $delimiters) {
                                $count = ($firstLine -split [regex]::Escape($delim)).Count - 1
                                $delimiterCounts[$delim] = $count
                            }
                            $bestDelimiter = ($delimiterCounts.GetEnumerator() | Sort-Object Value -Descending | Select-Object -First 1).Key
                            if ($delimiterCounts[$bestDelimiter] -gt 0) {
                                $result.recommendedDelimiter = $bestDelimiter
                            }
                        }
                    }
                } catch {
                    continue
                }
            }
        } catch {
            # File reading error - will be handled upstream
        }
        
        return $result
    }
    
    [hashtable]MapColumns([string[]]$headers) {
        $mapping = @{}
        
        foreach ($requiredCol in $this.requiredColumns.Keys) {
            $found = $false
            foreach ($header in $headers) {
                foreach ($pattern in $this.requiredColumns[$requiredCol]) {
                    if ($header -like "*$pattern*" -or $header -eq $pattern) {
                        $mapping[$requiredCol] = $header
                        $found = $true
                        break
                    }
                }
                if ($found) { break }
            }
        }
        
        return $mapping
    }
    
    [string[]]SuggestColumnFixes([string[]]$headers, [string[]]$missing) {
        $suggestions = @()
        
        foreach ($missingCol in $missing) {
            $suggestions += $this.t("validation.suggest_column_fix", @($missingCol))
            $suggestions += "  " + $this.t("validation.available_columns", @(($headers -join ', ')))
            $suggestions += "  " + $this.t("validation.expected_columns", @(($this.requiredColumns[$missingCol] -join ', ')))
            $suggestions += ""
        }
        
        return $suggestions
    }
    
    [void]ValidateDataTypes([object[]]$data, [hashtable]$mapping, [hashtable]$result) {
        if ($data.Count -eq 0) { return }
        
        $sample = $data | Select-Object -First 5
        
        # Check date format
        if ($mapping.ContainsKey("Date") -and $mapping["Date"]) {
            $dateCol = $mapping["Date"]
            $dateFormats = @("dd.MM.yyyy", "yyyy-MM-dd", "MM/dd/yyyy", "dd/MM/yyyy")
            $validDates = 0
            
            foreach ($row in $sample) {
                $dateValue = $row.$dateCol
                foreach ($format in $dateFormats) {
                    try {
                        $null = [DateTime]::ParseExact($dateValue, $format, $null)
                        $validDates++
                        break
                    }
                    catch { }
                }
            }
            
            if ($validDates -eq 0) {
                $result.warnings += $this.t("validation.date_format_warning")
            }
        }
        
        # Check amount format
        if ($mapping.ContainsKey("Amount") -and $mapping["Amount"]) {
            $amountCol = $mapping["Amount"]
            $validAmounts = 0
            
            foreach ($row in $sample) {
                $amountValue = $row.$amountCol
                # Try parsing with German format (comma as decimal separator)
                $cleanAmount = $amountValue -replace '\.', '' -replace ',', '.'
                try {
                    $null = [decimal]$cleanAmount
                    $validAmounts++
                }
                catch { }
            }
            
            if ($validAmounts -eq 0) {
                $result.warnings += $this.t("validation.amount_format_warning")
            }
        }
    }
    
    [hashtable]FixCsvFile([string]$inputPath, [string]$outputPath, [hashtable]$columnMapping) {
        $result = @{
            success = $false
            message = ""
        }
        
        try {
            $data = $this.TryReadCsv($inputPath)
            if (-not $data) {
                $result.message = $this.t("validation.could_not_read_input")
                return $result
            }
            
            # Rename columns according to mapping
            $fixedData = @()
            foreach ($row in $data) {
                $newRow = [PSCustomObject]@{}
                
                foreach ($standardCol in $columnMapping.Keys) {
                    $originalCol = $columnMapping[$standardCol]
                    if ($originalCol -and $row.PSObject.Properties.Name -contains $originalCol) {
                        $newRow | Add-Member -NotePropertyName $standardCol -NotePropertyValue $row.$originalCol
                    }
                }
                
                $fixedData += $newRow
            }
            
            # Export with standard format
            $fixedData | Export-Csv -Path $outputPath -NoTypeInformation -Delimiter ";" -Encoding UTF8
            
            $result.success = $true
            $result.message = $this.t("validation.csv_fixed_success", @($outputPath))
            
        }
        catch {
            $errorMessage = if ($_.Exception.Message) { $_.Exception.Message } else { "Unknown error" }
            $result.message = $this.t("validation.error_fixing_csv", @($errorMessage))
        }
        
        return $result
    }
    
    [void]ValidateBalanceConsistency([object]$csvData, [hashtable]$columnMapping, [hashtable]$result) {
        $amountCol = $columnMapping["Amount"]
        $balanceCol = $columnMapping["Balance"]
        
        if (-not $amountCol -or -not $balanceCol) { 
            return 
        }
        
        $balanceErrors = @()
        $calculatedBalance = $null
        $isFirstRow = $true
        $rowNumber = 1
        
        foreach ($row in $csvData) {
            $rowNumber++
            
            # Parse amount (German format: 1.234,56 -> 1234.56)
            $amountText = $row.$amountCol
            if (-not $amountText) { continue }
            
            $cleanAmount = $amountText -replace '\.', '' -replace ',', '.'
            try {
                $amount = [decimal]$cleanAmount
            }
            catch {
                continue  # Skip rows with invalid amounts
            }
            
            # Parse balance (German format: 1.234,56 -> 1234.56)
            $balanceText = $row.$balanceCol
            if (-not $balanceText) { continue }
            
            $cleanBalance = $balanceText -replace '\.', '' -replace ',', '.'
            try {
                $reportedBalance = [decimal]$cleanBalance
            }
            catch {
                continue  # Skip rows with invalid balances
            }
            
            # For the first row, establish the starting balance
            if ($isFirstRow) {
                # Calculate what the previous balance must have been
                $calculatedBalance = $reportedBalance - $amount
                $isFirstRow = $false
            } else {
                # Calculate expected balance: previous balance + current amount
                $expectedBalance = $calculatedBalance + $amount
                
                # Check if calculated balance matches reported balance (with small tolerance for rounding)
                $difference = [Math]::Abs($expectedBalance - $reportedBalance)
                if ($difference -gt 0.01) {  # Allow 1 cent tolerance
                    $balanceErrors += "Zeile $rowNumber`: Saldo-Inkonsistenz. Erwartet: $($expectedBalance.ToString('N2')) EUR, Gemeldet: $($reportedBalance.ToString('N2')) EUR, Differenz: $($difference.ToString('N2')) EUR"
                }
            }
            
            # Update calculated balance for next iteration
            $calculatedBalance = $reportedBalance
        }
        
        # Add balance validation results
        if ($balanceErrors.Count -gt 0) {
            $result.warnings += "Saldo-KonsistenzprÃ¼fung ergab $($balanceErrors.Count) Inkonsistenz(en):"
            foreach ($error in $balanceErrors) {
                $result.warnings += "  $error"
            }
        } else {
            # Only log successful validation to avoid cluttering console
            if ($rowNumber -gt 2) {  # Only if we actually validated something
                $result.warnings += "OK Saldo-Konsistenz: Alle $($rowNumber - 1) Transaktionen sind mathematisch korrekt"
            }
        }
    }
}
