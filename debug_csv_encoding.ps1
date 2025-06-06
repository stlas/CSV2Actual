# CSV2Actual - CSV Encoding Debugger
# Version: 1.0
# Author: sTLAs (https://github.com/sTLAs)
# Advanced CSV encoding and format analysis tool

param(
    [string]$FilePath = "",
    [Alias("l")][string]$Language = "en",
    [switch]$Verbose
)

# Load modules
. "$PSScriptRoot/modules/I18n.ps1"

# Initialize i18n
try {
    $global:i18n = [I18n]::new("$PSScriptRoot/lang", $Language)
} catch {
    Write-Host "WARNING: Could not load language files, using English fallback" -ForegroundColor Yellow
    $global:i18n = $null
}

function t {
    param([string]$key, [array]$args = @())
    if ($global:i18n) {
        if ($args.Length -gt 0) {
            return $global:i18n.Get($key, $args)
        }
        return $global:i18n.Get($key)
    }
    return $key
}

Write-Host "CSV2ACTUAL - ENCODING DEBUGGER" -ForegroundColor Cyan
Write-Host ""

# Find CSV file if not specified
if (-not $FilePath) {
    $csvFiles = Get-ChildItem -Path "source" -Filter "*.csv" -ErrorAction SilentlyContinue
    if ($csvFiles.Count -eq 0) {
        $csvFiles = Get-ChildItem -Path "." -Filter "*.csv" -ErrorAction SilentlyContinue
    }
    
    if ($csvFiles.Count -eq 0) {
        Write-Host "ERROR: No CSV files found in source/ or current directory!" -ForegroundColor Red
        Read-Host "Press Enter to exit"
        exit 1
    }
    
    if ($csvFiles.Count -eq 1) {
        $FilePath = $csvFiles[0].FullName
    } else {
        Write-Host "Multiple CSV files found. Please choose:" -ForegroundColor Yellow
        for ($i = 0; $i -lt $csvFiles.Count; $i++) {
            Write-Host "  $($i + 1). $($csvFiles[$i].Name)" -ForegroundColor White
        }
        $choice = Read-Host "Enter number (1-$($csvFiles.Count))"
        try {
            $index = [int]$choice - 1
            if ($index -ge 0 -and $index -lt $csvFiles.Count) {
                $FilePath = $csvFiles[$index].FullName
            } else {
                throw "Invalid selection"
            }
        } catch {
            Write-Host "ERROR: Invalid selection!" -ForegroundColor Red
            exit 1
        }
    }
}

if (-not (Test-Path $FilePath)) {
    Write-Host "ERROR: File not found: $FilePath" -ForegroundColor Red
    exit 1
}

$fileName = (Get-Item $FilePath).Name
Write-Host "ANALYZING: $fileName" -ForegroundColor Yellow
Write-Host ""

# STEP 1: Raw data analysis
Write-Host "STEP 1: Raw Data Analysis" -ForegroundColor Cyan
Write-Host "========================" -ForegroundColor Cyan

$rawBytes = [System.IO.File]::ReadAllBytes($FilePath)
Write-Host "File size: $($rawBytes.Length) bytes" -ForegroundColor White

# BOM Detection
$hasBOM = $false
$bomType = "None"
if ($rawBytes.Length -ge 3) {
    if ($rawBytes[0] -eq 0xEF -and $rawBytes[1] -eq 0xBB -and $rawBytes[2] -eq 0xBF) {
        $hasBOM = $true
        $bomType = "UTF-8"
    }
}

Write-Host "BOM detected: $bomType" -ForegroundColor $(if ($hasBOM) { "Yellow" } else { "Green" })

# Sample raw bytes
Write-Host "First 20 bytes (hex): " -NoNewline -ForegroundColor Gray
$sampleBytes = $rawBytes[0..([Math]::Min(19, $rawBytes.Length - 1))]
$hexString = ($sampleBytes | ForEach-Object { $_.ToString("X2") }) -join " "
Write-Host $hexString -ForegroundColor White

Write-Host ""

# STEP 2: Encoding detection
Write-Host "STEP 2: Encoding Detection" -ForegroundColor Cyan
Write-Host "==========================" -ForegroundColor Cyan

$encodings = @(
    @{Name = "UTF-8"; Encoding = [System.Text.Encoding]::UTF8},
    @{Name = "UTF-8 (no BOM)"; Encoding = [System.Text.UTF8Encoding]::new($false)},
    @{Name = "Windows-1252"; Encoding = [System.Text.Encoding]::GetEncoding(1252)},
    @{Name = "ISO-8859-1"; Encoding = [System.Text.Encoding]::GetEncoding("ISO-8859-1")},
    @{Name = "ASCII"; Encoding = [System.Text.Encoding]::ASCII}
)

$bestEncoding = $null
$bestScore = -1

foreach ($enc in $encodings) {
    try {
        $content = $enc.Encoding.GetString($rawBytes)
        $lines = $content -split "`n" | Select-Object -First 5
        
        # Score encoding quality
        $score = 0
        $hasGermanChars = $content -match "[äöüßÄÖÜ]"
        $hasControlChars = $content -match "[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]"
        $hasValidCSV = $lines[0] -match "[;,\t]"
        
        if ($hasValidCSV) { $score += 3 }
        if ($hasGermanChars -and $enc.Name -match "UTF-8|1252") { $score += 2 }
        if (-not $hasControlChars) { $score += 1 }
        
        $status = "OK"
        if ($hasControlChars) { $status = "Contains control characters" }
        if (-not $hasValidCSV) { $status = "No CSV delimiters found" }
        
        Write-Host "  $($enc.Name): $status (Score: $score)" -ForegroundColor $(if ($score -ge 3) { "Green" } elseif ($score -ge 1) { "Yellow" } else { "Red" })
        
        if ($Verbose -and $lines.Count -gt 0) {
            Write-Host "    Sample: $($lines[0].Substring(0, [Math]::Min(50, $lines[0].Length)))..." -ForegroundColor Gray
        }
        
        if ($score -gt $bestScore) {
            $bestScore = $score
            $bestEncoding = $enc
        }
    } catch {
        Write-Host "  $($enc.Name): ERROR - $($_.Exception.Message)" -ForegroundColor Red
    }
}

Write-Host ""
Write-Host "RECOMMENDED ENCODING: $($bestEncoding.Name)" -ForegroundColor Green
Write-Host ""

# STEP 3: CSV Structure Analysis
Write-Host "STEP 3: CSV Structure Analysis" -ForegroundColor Cyan
Write-Host "==============================" -ForegroundColor Cyan

try {
    $content = $bestEncoding.Encoding.GetString($rawBytes)
    if ($hasBOM -and $bestEncoding.Name -match "UTF-8") {
        $content = $content.TrimStart([char]0xFEFF)
    }
    
    $lines = $content -split "`r?`n" | Where-Object { $_.Trim() -ne "" }
    Write-Host "Total lines: $($lines.Count)" -ForegroundColor White
    
    if ($lines.Count -gt 0) {
        $firstLine = $lines[0]
        
        # Delimiter detection
        $delimiters = @(";", ",", "`t", "|")
        $delimiterCounts = @{}
        
        foreach ($delim in $delimiters) {
            $count = ($firstLine -split [regex]::Escape($delim)).Count - 1
            $delimiterCounts[$delim] = $count
        }
        
        $bestDelimiter = ($delimiterCounts.GetEnumerator() | Sort-Object Value -Descending | Select-Object -First 1).Key
        $columnCount = $delimiterCounts[$bestDelimiter] + 1
        
        Write-Host "Detected delimiter: '$bestDelimiter' ($columnCount columns)" -ForegroundColor Green
        
        # Show column headers
        $headers = $firstLine -split [regex]::Escape($bestDelimiter)
        Write-Host "Column headers:" -ForegroundColor White
        for ($i = 0; $i -lt $headers.Count; $i++) {
            Write-Host "  $($i + 1). '$($headers[$i].Trim())'" -ForegroundColor Gray
        }
        
        # Sample data analysis
        if ($lines.Count -gt 1) {
            Write-Host ""
            Write-Host "Sample data (first 3 rows):" -ForegroundColor White
            for ($i = 1; $i -le [Math]::Min(3, $lines.Count - 1); $i++) {
                $row = $lines[$i] -split [regex]::Escape($bestDelimiter)
                Write-Host "  Row $i: $($row.Count) columns" -ForegroundColor Gray
                if ($Verbose) {
                    for ($j = 0; $j -lt [Math]::Min($row.Count, $headers.Count); $j++) {
                        Write-Host "    $($headers[$j]): '$($row[$j].Trim())'" -ForegroundColor DarkGray
                    }
                }
            }
        }
    }
} catch {
    Write-Host "ERROR analyzing CSV structure: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host ""

# STEP 4: Recommendations
Write-Host "STEP 4: Recommendations" -ForegroundColor Cyan
Write-Host "======================" -ForegroundColor Cyan

Write-Host "For CSV2Actual processing:" -ForegroundColor Yellow
Write-Host "  1. Use encoding: $($bestEncoding.Name)" -ForegroundColor White
Write-Host "  2. Use delimiter: '$bestDelimiter'" -ForegroundColor White

if ($hasBOM) {
    Write-Host "  3. BOM will be automatically handled" -ForegroundColor White
} else {
    Write-Host "  3. No BOM detected - good for compatibility" -ForegroundColor White
}

Write-Host ""

# Optional: Create cleaned version
$createCleaned = Read-Host "Create cleaned version for testing? (y/n)"
if ($createCleaned -eq "y" -or $createCleaned -eq "Y") {
    try {
        $cleanedContent = $bestEncoding.Encoding.GetString($rawBytes)
        if ($hasBOM) {
            $cleanedContent = $cleanedContent.TrimStart([char]0xFEFF)
        }
        
        $outputPath = $FilePath -replace "\.csv$", "_CLEANED.csv"
        [System.IO.File]::WriteAllText($outputPath, $cleanedContent, [System.Text.Encoding]::UTF8)
        Write-Host "Cleaned version saved: $(Split-Path $outputPath -Leaf)" -ForegroundColor Green
    } catch {
        Write-Host "ERROR creating cleaned version: $($_.Exception.Message)" -ForegroundColor Red
    }
}

Write-Host ""
Write-Host "Analysis complete!" -ForegroundColor Green
Read-Host "Press Enter to exit"