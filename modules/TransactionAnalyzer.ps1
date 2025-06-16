# CSV2Actual - Transaction Categorization Analyzer
# Version: 1.0.0
# Author: sTLAs (https://github.com/sTLAs)
# Analysiert alle Transaktionen und erstellt einen umfassenden Kategorisierungsbericht

class TransactionAnalyzer {
    [CategoryEngine]$categoryEngine
    [hashtable]$config
    [array]$ownIbans
    [hashtable]$stats
    [array]$uncategorizedTransactions
    [hashtable]$langStrings
    [string]$language
    
    TransactionAnalyzer([CategoryEngine]$categoryEngine, [hashtable]$config, [string]$language = "de") {
        $this.categoryEngine = $categoryEngine
        $this.config = $config
        $this.language = $language
        $this.LoadLanguageStrings()
        $this.LoadOwnIbans()
        $this.InitializeStats()
    }
    
    # Lädt Sprachstrings für die Ausgabe
    [void] LoadLanguageStrings() {
        $langFile = "lang/$($this.language).json"
        $this.langStrings = @{}
        
        if (Test-Path $langFile) {
            try {
                $langData = Get-Content -Path $langFile -Raw -Encoding UTF8 | ConvertFrom-Json
                if ($langData.analyzer) {
                    $this.langStrings = $this.ConvertToHashtable($langData.analyzer)
                }
            } catch {
                Write-Warning "Fehler beim Laden der Sprachdatei $langFile`: $($_.Exception.Message)"
            }
        }
        
        # Fallback-Strings falls Sprachdatei nicht verfügbar
        if ($this.langStrings.Count -eq 0) {
            $this.langStrings = @{
                "title" = "=== TRANSAKTIONS-KATEGORISIERUNGS-ANALYSE ==="
                "loading_csv" = "Lade CSV-Dateien aus Verzeichnis:"
                "found_files" = "Gefundene CSV-Dateien:"
                "processing_file" = "Verarbeite Datei:"
                "total_transactions" = "Gesamt-Transaktionen"
                "categorization_stats" = "=== KATEGORISIERUNGS-STATISTIKEN ==="
                "transfers" = "Transfers (eigene IBANs)"
                "income" = "Einnahmen (positive Beträge)"
                "exact_matches" = "Exakte Payee-Matches"
                "keyword_matches" = "Keyword-basierte Matches"
                "payee_keywords" = "Payee-Keywords"
                "memo_keywords" = "Memo-Keywords"
                "buchungstext_keywords" = "Buchungstext-Keywords"
                "amount_patterns" = "Betrags-Pattern"
                "uncategorized" = "Nicht kategorisiert"
                "category_distribution" = "=== KATEGORIE-VERTEILUNG ==="
                "uncategorized_payees" = "=== NICHT KATEGORISIERTE ZAHLUNGSEMPFAENGER ==="
                "sample_transactions" = "Beispiel-Transaktionen"
                "no_uncategorized" = "Alle Transaktionen sind kategorisiert!"
                "summary" = "=== ZUSAMMENFASSUNG ==="
                "categorization_rate" = "Kategorisierungsrate"
                "recommendations" = "=== EMPFEHLUNGEN ==="
                "add_mappings" = "Füge exakte Mappings hinzu für häufige Payees"
                "add_keywords" = "Füge Keywords hinzu für ähnliche Payees"
                "check_income" = "Prüfe Einkommens-Erkennungsregeln"
                "file_not_found" = "Datei nicht gefunden"
                "error_processing" = "Fehler beim Verarbeiten der Datei"
            }
        }
    }
    
    # Lädt eigene IBANs für Transfer-Erkennung
    [void] LoadOwnIbans() {
        $this.ownIbans = @()
        
        if ($this.config.accounts) {
            foreach ($account in $this.config.accounts) {
                if ($account.iban) {
                    $this.ownIbans += $account.iban
                }
            }
        }
        
        # Zusätzlich aus setup
        if ($this.config.setup -and $this.config.setup.accounts) {
            foreach ($account in $this.config.setup.accounts) {
                if ($account.iban -and $this.ownIbans -notcontains $account.iban) {
                    $this.ownIbans += $account.iban
                }
            }
        }
    }
    
    # Initialisiert Statistik-Struktur
    [void] InitializeStats() {
        $this.stats = @{
            "totalTransactions" = 0
            "transfers" = 0
            "income" = 0
            "exactMatches" = 0
            "keywordMatches" = @{
                "payee" = 0
                "memo" = 0
                "buchungstext" = 0
            }
            "amountPatterns" = 0
            "uncategorized" = 0
            "categoryDistribution" = @{}
        }
        $this.uncategorizedTransactions = @()
    }
    
    # Hauptfunktion: Analysiert alle CSV-Dateien
    [void] AnalyzeAllTransactions([string]$csvDirectory = "csv") {
        Write-Host ($this.GetString("title")) -ForegroundColor Cyan
        Write-Host ""
        
        # CSV-Dateien finden
        if (-not (Test-Path $csvDirectory)) {
            Write-Host "CSV-Verzeichnis nicht gefunden: $csvDirectory" -ForegroundColor Red
            return
        }
        
        Write-Host ($this.GetString("loading_csv")) -ForegroundColor Yellow
        Write-Host "  $csvDirectory" -ForegroundColor White
        
        $csvFiles = Get-ChildItem -Path $csvDirectory -Filter "*.csv" | Sort-Object Name
        
        if ($csvFiles.Count -eq 0) {
            Write-Host "Keine CSV-Dateien gefunden!" -ForegroundColor Red
            return
        }
        
        Write-Host ""
        Write-Host ($this.GetString("found_files")) -ForegroundColor Yellow
        foreach ($file in $csvFiles) {
            Write-Host "  $($file.Name)" -ForegroundColor White
        }
        Write-Host ""
        
        # Dateien verarbeiten
        foreach ($file in $csvFiles) {
            Write-Host ($this.GetString("processing_file")) -NoNewline -ForegroundColor Gray
            Write-Host " $($file.Name)" -ForegroundColor White
            
            try {
                $this.ProcessCsvFile($file.FullName)
            } catch {
                Write-Host "  " + ($this.GetString("error_processing")) + ": $($_.Exception.Message)" -ForegroundColor Red
            }
        }
        
        Write-Host ""
        $this.ShowResults()
    }
    
    # Verarbeitet eine einzelne CSV-Datei
    [void] ProcessCsvFile([string]$filePath) {
        if (-not (Test-Path $filePath)) {
            Write-Host "  " + ($this.GetString("file_not_found")) + ": $filePath" -ForegroundColor Red
            return
        }
        
        try {
            # CSV einlesen (verwende Import-Csv für automatische Header-Erkennung)
            $csvData = Import-Csv -Path $filePath -Delimiter ";" -Encoding UTF8
            
            foreach ($row in $csvData) {
                $transaction = $this.ConvertRowToTransaction($row)
                if ($transaction) {
                    $this.AnalyzeTransaction($transaction)
                }
            }
        } catch {
            throw ('Fehler beim Lesen der CSV-Datei: ' + $_.Exception.Message)
        }
    }
    
    # Konvertiert CSV-Zeile zu Transaktions-Hashtable
    [hashtable] ConvertRowToTransaction([object]$row) {
        # Verschiedene CSV-Formate unterstützen
        $transaction = @{
            payee = ""
            memo = ""
            buchungstext = ""
            amount = ""
            date = ""
            iban = ""
        }
        
        # Payee-Felder (verschiedene Namen möglich)
        $payeeFields = @("Empfänger/Zahlungspflichtige", "Payee", "Begünstigter", "Zahlungsempfänger", "Empfänger")
        foreach ($field in $payeeFields) {
            if ($row.$field) {
                $transaction.payee = $row.$field
                break
            }
        }
        
        # Memo-Felder
        $memoFields = @("Verwendungszweck", "Memo", "Beschreibung", "Description")
        foreach ($field in $memoFields) {
            if ($row.$field) {
                $transaction.memo = $row.$field
                break
            }
        }
        
        # Buchungstext-Felder
        $buchungsFields = @("Buchungstext", "Transaction Type", "Art der Transaktion")
        foreach ($field in $buchungsFields) {
            if ($row.$field) {
                $transaction.buchungstext = $row.$field
                break
            }
        }
        
        # Betrag-Felder
        $amountFields = @("Betrag", "Amount", "Umsatz")
        foreach ($field in $amountFields) {
            if ($row.$field) {
                $transaction.amount = $row.$field
                break
            }
        }
        
        # Datum-Felder
        $dateFields = @("Datum", "Date", "Buchungstag", "Wertstellung")
        foreach ($field in $dateFields) {
            if ($row.$field) {
                $transaction.date = $row.$field
                break
            }
        }
        
        # IBAN-Felder (für Transfer-Erkennung)
        $ibanFields = @("IBAN", "Kontonummer", "Account")
        foreach ($field in $ibanFields) {
            if ($row.$field) {
                $transaction.iban = $row.$field
                break
            }
        }
        
        return $transaction
    }
    
    # Analysiert eine einzelne Transaktion
    [void] AnalyzeTransaction([hashtable]$transaction) {
        $this.stats.totalTransactions++
        
        # Transfer-Erkennung (eigene IBANs)
        $isTransfer = $false
        if ($transaction.iban -and $this.ownIbans -contains $transaction.iban) {
            $isTransfer = $true
            $this.stats.transfers++
            $this.UpdateCategoryDistribution("Transfer (eigene IBAN)")
        }
        
        # Einkommens-Erkennung (positive Beträge)
        $isIncome = $false
        if (-not $isTransfer -and $transaction.amount) {
            $cleanAmount = $transaction.amount -replace '[^\d.,-]', ''
            $cleanAmount = $cleanAmount -replace ",", "."
            
            try {
                $numericAmount = [double]$cleanAmount
                if ($numericAmount -gt 0) {
                    $isIncome = $true
                    $this.stats.income++
                    $this.UpdateCategoryDistribution("Einkommen (positiver Betrag)")
                }
            } catch {
                # Betrag nicht parseable - ignorieren
            }
        }
        
        # Kategorisierung über CategoryEngine
        if (-not $isTransfer -and -not $isIncome) {
            $category = $this.categoryEngine.CategorizeTransaction($transaction)
            
            if ($category) {
                # Bestimme Art der Kategorisierung
                $this.DetermineCategorization($transaction, $category)
                $this.UpdateCategoryDistribution($category)
            } else {
                # Nicht kategorisiert
                $this.stats.uncategorized++
                $this.uncategorizedTransactions += $transaction
            }
        }
    }
    
    # Bestimmt wie die Transaktion kategorisiert wurde
    [void] DetermineCategorization([hashtable]$transaction, [string]$category) {
        $payee = $transaction.payee
        $memo = $transaction.memo
        $buchungstext = $transaction.buchungstext
        $amount = $transaction.amount
        
        # Prüfe exakte Payee-Matches
        if ($this.categoryEngine.rules["exactPayee"].Keys -contains $payee) {
            $this.stats.exactMatches++
            return
        }
        
        # Prüfe Payee-Keywords
        if ($this.CheckKeywordMatch($payee, $this.categoryEngine.rules["payeeKeywords"])) {
            $this.stats.keywordMatches.payee++
            return
        }
        
        # Prüfe Memo-Keywords
        if ($this.CheckKeywordMatch($memo, $this.categoryEngine.rules["memoKeywords"])) {
            $this.stats.keywordMatches.memo++
            return
        }
        
        # Prüfe Buchungstext-Keywords
        if ($this.CheckKeywordMatch($buchungstext, $this.categoryEngine.rules["buchungstextKeywords"])) {
            $this.stats.keywordMatches.buchungstext++
            return
        }
        
        # Prüfe Betrags-Pattern
        if ($this.categoryEngine.rules["amountPatterns"].Keys -contains $amount) {
            $this.stats.amountPatterns++
            return
        }
    }
    
    # Prüft ob Text gegen Keywords matched
    [bool] CheckKeywordMatch([string]$text, [hashtable]$keywordRules) {
        if (-not $text) { return $false }
        
        $textLower = $text.ToLower()
        foreach ($keyword in $keywordRules.Keys) {
            if ($textLower -match [regex]::Escape($keyword.ToLower())) {
                return $true
            }
        }
        
        return $false
    }
    
    # Aktualisiert Kategorie-Verteilung
    [void] UpdateCategoryDistribution([string]$category) {
        if ($this.stats.categoryDistribution.ContainsKey($category)) {
            $this.stats.categoryDistribution[$category]++
        } else {
            $this.stats.categoryDistribution[$category] = 1
        }
    }
    
    # Zeigt Ergebnisse an
    [void] ShowResults() {
        Write-Host ($this.GetString("categorization_stats")) -ForegroundColor Cyan
        Write-Host ""
        
        # Basis-Statistiken
        Write-Host ($this.GetString("total_transactions")) + ": " -NoNewline -ForegroundColor Yellow
        Write-Host $this.stats.totalTransactions -ForegroundColor White
        
        Write-Host ($this.GetString("transfers")) + ": " -NoNewline -ForegroundColor Yellow
        Write-Host $this.stats.transfers -ForegroundColor Green
        
        Write-Host ($this.GetString("income")) + ": " -NoNewline -ForegroundColor Yellow
        Write-Host $this.stats.income -ForegroundColor Green
        
        Write-Host ($this.GetString("exact_matches")) + ": " -NoNewline -ForegroundColor Yellow
        Write-Host $this.stats.exactMatches -ForegroundColor Green
        
        Write-Host ($this.GetString("keyword_matches")) + ":" -ForegroundColor Yellow
        Write-Host "  " + ($this.GetString("payee_keywords")) + ": " -NoNewline -ForegroundColor Gray
        Write-Host $this.stats.keywordMatches.payee -ForegroundColor Green
        Write-Host "  " + ($this.GetString("memo_keywords")) + ": " -NoNewline -ForegroundColor Gray
        Write-Host $this.stats.keywordMatches.memo -ForegroundColor Green
        Write-Host "  " + ($this.GetString("buchungstext_keywords")) + ": " -NoNewline -ForegroundColor Gray
        Write-Host $this.stats.keywordMatches.buchungstext -ForegroundColor Green
        
        Write-Host ($this.GetString("amount_patterns")) + ": " -NoNewline -ForegroundColor Yellow
        Write-Host $this.stats.amountPatterns -ForegroundColor Green
        
        Write-Host ($this.GetString("uncategorized")) + ": " -NoNewline -ForegroundColor Yellow
        if ($this.stats.uncategorized -gt 0) {
            Write-Host $this.stats.uncategorized -ForegroundColor Red
        } else {
            Write-Host "0" -ForegroundColor Green
        }
        
        Write-Host ""
        
        # Kategorie-Verteilung
        if ($this.stats.categoryDistribution.Count -gt 0) {
            Write-Host ($this.GetString("category_distribution")) -ForegroundColor Cyan
            Write-Host ""
            
            # Sortiere nach Häufigkeit (absteigend)
            $sortedCategories = $this.stats.categoryDistribution.GetEnumerator() | 
                Sort-Object Value -Descending
            
            foreach ($entry in $sortedCategories) {
                $percentage = [math]::Round(($entry.Value / $this.stats.totalTransactions) * 100, 1)
                Write-Host "  $($entry.Key): " -NoNewline -ForegroundColor White
                Write-Host ($entry.Value.ToString() + ' (' + $percentage.ToString() + '%)') -ForegroundColor Yellow
            }
            Write-Host ""
        }
        
        # Nicht kategorisierte Transaktionen
        $this.ShowUncategorizedTransactions()
        
        # Zusammenfassung
        $this.ShowSummary()
    }
    
    # Zeigt nicht kategorisierte Transaktionen
    [void] ShowUncategorizedTransactions() {
        Write-Host ($this.GetString("uncategorized_payees")) -ForegroundColor Cyan
        Write-Host ""
        
        if ($this.uncategorizedTransactions.Count -eq 0) {
            Write-Host ($this.GetString("no_uncategorized")) -ForegroundColor Green
            Write-Host ""
            return
        }
        
        # Gruppiere nach Payee
        $payeeGroups = @{}
        foreach ($transaction in $this.uncategorizedTransactions) {
            $payee = $transaction.payee
            if (-not $payee) { $payee = "Unbekannt" }
            
            if (-not $payeeGroups.ContainsKey($payee)) {
                $payeeGroups[$payee] = @()
            }
            $payeeGroups[$payee] += $transaction
        }
        
        # Sortiere nach Häufigkeit
        $sortedPayees = $payeeGroups.GetEnumerator() | 
            Sort-Object { $_.Value.Count } -Descending
        
        foreach ($payeeGroup in $sortedPayees) {
            $payee = $payeeGroup.Key
            $transactions = $payeeGroup.Value
            $count = $transactions.Count
            
            Write-Host ($payee + ' (' + $count + ' Transaktionen)') -ForegroundColor Yellow
            
            # Zeige ersten 3 Transaktionen als Beispiele
            $sampleCount = [Math]::Min(3, $count)
            for ($i = 0; $i -lt $sampleCount; $i++) {
                $tx = $transactions[$i]
                Write-Host "  - Memo: '$($tx.memo)' | Betrag: $($tx.amount)" -ForegroundColor Gray
            }
            
            if ($count -gt 3) {
                Write-Host "  ... und $($count - 3) weitere" -ForegroundColor DarkGray
            }
            Write-Host ""
        }
    }
    
    # Zeigt Zusammenfassung und Empfehlungen
    [void] ShowSummary() {
        Write-Host ($this.GetString("summary")) -ForegroundColor Cyan
        Write-Host ""
        
        # Kategorisierungsrate berechnen
        $categorized = $this.stats.totalTransactions - $this.stats.uncategorized
        $rate = if ($this.stats.totalTransactions -gt 0) {
            [math]::Round(($categorized / $this.stats.totalTransactions) * 100, 1)
        } else { 0 }
        
        Write-Host ($this.GetString("categorization_rate")) + ": " -NoNewline -ForegroundColor Yellow
        
        if ($rate -ge 95) {
            Write-Host "$rate% (Ausgezeichnet!)" -ForegroundColor Green
        } elseif ($rate -ge 85) {
            Write-Host "$rate% (Sehr gut)" -ForegroundColor Yellow
        } elseif ($rate -ge 70) {
            Write-Host "$rate% (Gut)" -ForegroundColor DarkYellow
        } else {
            Write-Host "$rate% (Verbesserungsbedarf)" -ForegroundColor Red
        }
        
        Write-Host ""
        
        # Empfehlungen basierend auf Ergebnissen
        if ($this.stats.uncategorized -gt 0) {
            Write-Host ($this.GetString("recommendations")) -ForegroundColor Cyan
            Write-Host ""
            
            # Häufige nicht kategorisierte Payees identifizieren
            $payeeGroups = @{}
            foreach ($transaction in $this.uncategorizedTransactions) {
                $payee = $transaction.payee
                if (-not $payee) { $payee = "Unbekannt" }
                
                if (-not $payeeGroups.ContainsKey($payee)) {
                    $payeeGroups[$payee] = 0
                }
                $payeeGroups[$payee]++
            }
            
            $topPayees = $payeeGroups.GetEnumerator() | 
                Sort-Object Value -Descending | 
                Select-Object -First 5
            
            if ($topPayees.Count -gt 0) {
                Write-Host "1. " + ($this.GetString("add_mappings")) + ":" -ForegroundColor Yellow
                foreach ($entry in $topPayees) {
                    Write-Host "   - '$($entry.Key)' ($($entry.Value) Transaktionen)" -ForegroundColor Gray
                }
                Write-Host ""
            }
            
            Write-Host "2. " + ($this.GetString("add_keywords")) -ForegroundColor Yellow
            Write-Host "3. " + ($this.GetString("check_income")) -ForegroundColor Yellow
        }
        
        Write-Host ""
    }
    
    # Hilfsfunktion für lokalisierte Strings
    [string] GetString([string]$key) {
        if ($this.langStrings.ContainsKey($key)) {
            return $this.langStrings[$key]
        }
        return $key
    }
    
    # Hilfsfunktion für PSCustomObject zu Hashtable (PowerShell 5.1 Kompatibilität)
    [hashtable] ConvertToHashtable([object]$obj) {
        $hashtable = @{}
        if ($obj -eq $null) { return $hashtable }
        
        foreach ($property in $obj.PSObject.Properties) {
            $value = $property.Value
            if ($value -ne $null -and $value.GetType().Name -eq "PSCustomObject") {
                $hashtable[$property.Name] = $this.ConvertToHashtable($value)
            } else {
                $hashtable[$property.Name] = $value
            }
        }
        
        return $hashtable
    }
}

# Standalone-Funktion für einfache Verwendung
function Invoke-TransactionAnalysis {
    param(
        [string]$CsvDirectory = "csv",
        [string]$Language = "de"
    )
    
    # Module laden falls nicht bereits geladen
    if (-not (Get-Command "CategoryEngine" -ErrorAction SilentlyContinue)) {
        . "$PSScriptRoot/CategoryEngine.ps1"
    }
    
    if (-not (Get-Command "Config" -ErrorAction SilentlyContinue)) {
        . "$PSScriptRoot/Config.ps1"
    }
    
    try {
        # Konfiguration laden
        $config = [Config]::new("$PSScriptRoot/../config.json")
        
        # CategoryEngine initialisieren
        $categoryEngine = [CategoryEngine]::new("$PSScriptRoot/../categories.json", $Language)
        
        # Analyzer erstellen und ausführen
        $analyzer = [TransactionAnalyzer]::new($categoryEngine, $config.data, $Language)
        $analyzer.AnalyzeAllTransactions($CsvDirectory)
        
    } catch {
        Write-Host "Fehler bei der Analyse: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "Details: $($_.Exception)" -ForegroundColor DarkRed
    }
}