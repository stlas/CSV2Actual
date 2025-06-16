# CSV2Actual - Einheitliches Kategorisierungs-Modul
# Version: 2.0.0
# Author: sTLAs (https://github.com/sTLAs)
# Vereinheitlichtes System für alle Kategorisierungs-Logik

class CategoryEngine {
    [hashtable]$categories
    [hashtable]$rules
    [hashtable]$langStrings
    [string]$configPath
    [string]$language
    
    CategoryEngine([string]$configPath = "categories.json", [string]$language = "de") {
        $this.configPath = $configPath
        $this.language = $language
        $this.LoadLanguageStrings()
        $this.LoadCategories()
        $this.LoadRules()
    }
    
    # Lädt Sprachstrings aus lang/*.json
    [void] LoadLanguageStrings() {
        $langFile = "lang/$($this.language).json"
        $this.langStrings = @{}
        
        if (Test-Path $langFile) {
            try {
                $langData = Get-Content -Path $langFile -Raw -Encoding UTF8 | ConvertFrom-Json
                if ($langData.categories) {
                    $this.langStrings = $this.ConvertToHashtable($langData.categories)
                }
            } catch {
                Write-Warning "Fehler beim Laden der Sprachdatei $langFile`: $($_.Exception.Message)"
            }
        }
        
        # Fallback-Kategorien falls Sprachdatei nicht gefunden
        if ($this.langStrings.Count -eq 0) {
            $this.langStrings = @{
                "groceries" = "Lebensmittel"
                "fuel" = "Kraftstoff" 
                "restaurants" = "Restaurants & Ausgehen"
                "pharmacy_health" = "Drogerie & Gesundheit"
                "taxi_ridesharing" = "Taxi & Ridesharing"
                "housing" = "Wohnen"
                "internet_phone" = "Internet & Telefon"
                "insurance" = "Versicherungen"
                "taxes" = "Steuern"
                "online_shopping" = "Online Shopping"
                "electronics" = "Elektronik & Technik"
                "streaming" = "Streaming & Abos"
                "memberships" = "Mitgliedschaften"
                "education" = "Bildung"
                "income" = "Einkommen"
                "capital_gains" = "Kapitalerträge"
                "cash_deposits" = "Bareinzahlungen"
                "transfer_household" = "Transfer (Haushaltsbeitrag)"
                "bank_fees" = "Bankgebühren"
                "donations" = "Spenden"
            }
        }
    }
    
    # Lädt Kategorien-Definition aus Sprachstrings
    [void] LoadCategories() {
        $this.categories = @{
            "Standard" = @{
                "Tägliche Ausgaben" = @(
                    $this.GetLocalizedString("groceries"),
                    $this.GetLocalizedString("fuel"),
                    $this.GetLocalizedString("restaurants"),
                    $this.GetLocalizedString("pharmacy_health"),
                    $this.GetLocalizedString("taxi_ridesharing")
                )
                "Wohnen & Leben" = @(
                    $this.GetLocalizedString("housing"),
                    $this.GetLocalizedString("internet_phone"),
                    $this.GetLocalizedString("insurance"),
                    $this.GetLocalizedString("taxes")
                )
                "Shopping & Freizeit" = @(
                    $this.GetLocalizedString("online_shopping"),
                    $this.GetLocalizedString("electronics"),
                    $this.GetLocalizedString("streaming"),
                    $this.GetLocalizedString("memberships"),
                    $this.GetLocalizedString("education")
                )
                "Einnahmen" = @(
                    $this.GetLocalizedString("income"),
                    $this.GetLocalizedString("capital_gains"),
                    $this.GetLocalizedString("cash_deposits"),
                    $this.GetLocalizedString("winnings")
                )
                "Transfers & Sonstiges" = @(
                    $this.GetLocalizedString("transfer"),
                    $this.GetLocalizedString("transfer_household"),
                    $this.GetLocalizedString("bank_fees"),
                    $this.GetLocalizedString("donations"),
                    $this.GetLocalizedString("savings")
                )
            }
            "Benutzerdefiniert" = @{}
        }
        
        # Lade Konfigurationsdatei falls vorhanden
        $localConfigPath = $this.configPath -replace "categories\.json", "config.local.json"
        if (Test-Path $localConfigPath) {
            try {
                $content = Get-Content -Path $localConfigPath -Raw -Encoding UTF8 | ConvertFrom-Json
                if ($content.categories) {
                    $this.categories["Benutzerdefiniert"] = $this.ConvertToHashtable($content.categories)
                }
                # Lade benutzerdefinierte Oberkategorien-Zuordnungen
                if ($content.categoryGroups) {
                    $this.categories["Standard"] = $this.ConvertToHashtable($content.categoryGroups)
                }
            } catch {
                Write-Warning "Fehler beim Laden der Kategorien-Konfiguration: $($_.Exception.Message)"
            }
        }
    }
    
    # Hilfsfunktion für lokalisierte Strings
    [string] GetLocalizedString([string]$key) {
        if ($this.langStrings.ContainsKey($key)) {
            return $this.langStrings[$key]
        }
        # Fallback: Gib den Schlüssel zurück wenn nicht gefunden
        return $key
    }
    
    # Lädt Kategorisierungs-Regeln
    [void] LoadRules() {
        $this.rules = @{
            "exactPayee" = @{}      # Exakte Payee-Matches
            "payeeKeywords" = @{}   # Payee-Schlüsselwörter
            "memoKeywords" = @{}    # Memo-Schlüsselwörter
            "buchungstextKeywords" = @{} # Buchungstext-Schlüsselwörter
            "amountPatterns" = @{}  # Betragsmuster
            "combined" = @{}        # Kombinierte Regeln
        }
        
        # Standard-Memo-Keywords für häufige Begriffe
        $incomeCategory = $this.GetLocalizedString("income")
        $fuelCategory = $this.GetLocalizedString("fuel")
        $transferCategory = $this.GetLocalizedString("transfer")
        
        $this.rules["memoKeywords"]["LOHN"] = $incomeCategory
        $this.rules["memoKeywords"]["GEHALT"] = $incomeCategory
        $this.rules["memoKeywords"]["SALARY"] = $incomeCategory
        $this.rules["memoKeywords"]["VERDIENST"] = $incomeCategory
        $this.rules["memoKeywords"]["EINKOMMEN"] = $incomeCategory
        $this.rules["memoKeywords"]["INCOME"] = $incomeCategory
        $this.rules["memoKeywords"]["PAYROLL"] = $incomeCategory
        $this.rules["memoKeywords"]["AUSZAHLUNG"] = $incomeCategory
        
        # Weitere Standard-Keywords
        $this.rules["memoKeywords"]["TANKSTELLE"] = $fuelCategory
        $this.rules["memoKeywords"]["TANKEN"] = $fuelCategory
        $this.rules["memoKeywords"]["GAS STATION"] = $fuelCategory
        $this.rules["memoKeywords"]["FUEL"] = $fuelCategory
        
        # Universelle Kreditkarten-Transfer-Erkennung
        # Diese Transaktionen sind interne Bankverrechnungen für Kreditkarten-Abrechnungen
        $this.rules["memoKeywords"]["MASTERCARD ABRECHNUNG"] = $transferCategory
        $this.rules["memoKeywords"]["VISA ABRECHNUNG"] = $transferCategory
        $this.rules["memoKeywords"]["KREDITKARTEN ABRECHNUNG"] = $transferCategory
        $this.rules["memoKeywords"]["KREDITKARTE ABRECHNUNG"] = $transferCategory
        $this.rules["memoKeywords"]["CREDIT CARD BILLING"] = $transferCategory
        $this.rules["memoKeywords"]["CARD PAYMENT"] = $transferCategory
        
        # Betrags-sensitive Keywords (werden in CategorizeTransaction geprüft)
        # Diese werden NICHT direkt zu rules hinzugefügt, sondern in der Logik verwendet
        
        # Lade bestehende Konfiguration
        $localConfigPath = $this.configPath -replace "categories\.json", "config.local.json"
        if (Test-Path $localConfigPath) {
            try {
                $content = Get-Content -Path $localConfigPath -Raw -Encoding UTF8 | ConvertFrom-Json
                
                # Konvertiere bestehende categoryMappings
                if ($content.categoryMappings) {
                    $content.categoryMappings.PSObject.Properties | ForEach-Object {
                        $this.rules["exactPayee"][$_.Name] = $_.Value
                    }
                }
                
                # Konvertiere bestehende categoryKeywords (für Payee UND Memo)
                if ($content.categoryKeywords) {
                    $content.categoryKeywords.PSObject.Properties | ForEach-Object {
                        $keywords = $_.Value.Split(',') | ForEach-Object { $_.Trim() }
                        foreach ($keyword in $keywords) {
                            if ($keyword) {
                                # Keywords sowohl für Payee als auch für Memo verfügbar machen
                                $this.rules["payeeKeywords"][$keyword] = $_.Name
                                $this.rules["memoKeywords"][$keyword] = $_.Name
                            }
                        }
                    }
                }
                
                # Konvertiere Memo-Keywords
                if ($content.memoKeywords) {
                    $content.memoKeywords.PSObject.Properties | ForEach-Object {
                        $keywords = $_.Value.Split(',') | ForEach-Object { $_.Trim() }
                        foreach ($keyword in $keywords) {
                            if ($keyword) {
                                $this.rules["memoKeywords"][$keyword] = $_.Name
                            }
                        }
                    }
                }
                
                # Konvertiere Buchungstext-Keywords  
                if ($content.buchungstextKeywords) {
                    $content.buchungstextKeywords.PSObject.Properties | ForEach-Object {
                        $keywords = $_.Value.Split(',') | ForEach-Object { $_.Trim() }
                        foreach ($keyword in $keywords) {
                            if ($keyword) {
                                $this.rules["buchungstextKeywords"][$keyword] = $_.Name
                            }
                        }
                    }
                }
            } catch {
                Write-Warning "Fehler beim Laden der Regel-Konfiguration: $($_.Exception.Message)"
            }
        }
    }
    
    # Hauptfunktion: Kategorisiert eine Transaktion
    [string] CategorizeTransaction([hashtable]$transaction) {
        $payee = $transaction.payee
        $memo = $transaction.memo
        $buchungstext = $transaction.buchungstext
        $amount = $transaction.amount
        
        # 0. Spezielle Bankgebühren-Erkennung (höchste Priorität vor allem anderen)
        if ($payee -match "Barauszahlungsgebuehr|Kontoführungsgebühr|Gebühr" -or $memo -match "Barauszahlungsgebuehr|Kontoführungsgebühr|Gebühr") {
            return $this.GetLocalizedString("bank_fees")
        }
        
        # 0.5. Betrags-sensitive Keywords VOR exactPayee (Gewinnsparen etc.)
        $category = $this.CheckAmountSensitiveKeywords($memo, $payee, $amount)
        if ($category) { return $category }
        
        # 1. Exakte Payee-Matches (höchste Priorität)
        if ($this.rules["exactPayee"].Keys -contains $payee) {
            return $this.rules["exactPayee"][$payee]
        }
        
        # 2. IBAN-basierte Transfer-Erkennung (vor Keywords)
        $category = $this.CheckInternalTransfer($memo)
        if ($category) { return $category }
        
        # 2.5. PayPal-spezifische Kategorisierung
        $category = $this.CheckPayPalTransaction($payee, $memo)
        if ($category) { return $category }
        
        # 3. Payee-Keywords
        $category = $this.CheckKeywords($payee, $this.rules["payeeKeywords"])
        if ($category) { return $category }
        
        # 4. Memo-Keywords
        $category = $this.CheckKeywords($memo, $this.rules["memoKeywords"])
        if ($category) { return $category }
        
        # 5. Buchungstext-Keywords
        $category = $this.CheckKeywords($buchungstext, $this.rules["buchungstextKeywords"])
        if ($category) { return $category }
        
        # 6. Betragsmuster
        if ($this.rules["amountPatterns"].Keys -contains $amount) {
            return $this.rules["amountPatterns"][$amount]
        }
        
        # Nicht kategorisiert
        return ""
    }
    
    # Prüft Text gegen Keywords
    [string] CheckKeywords([string]$text, [hashtable]$keywordRules) {
        if (-not $text) { return "" }
        
        $textLower = $text.ToLower()
        foreach ($keyword in $keywordRules.Keys) {
            if ($textLower -match [regex]::Escape($keyword.ToLower())) {
                return $keywordRules[$keyword]
            }
        }
        
        return ""
    }
    
    # Prüft betrags-sensitive Keywords (z.B. Gewinnsparen)
    [string] CheckAmountSensitiveKeywords([string]$memo, [string]$payee, [string]$amount) {
        if (-not $memo -and -not $payee) { return "" }
        
        $memoLower = if ($memo) { $memo.ToLower() } else { "" }
        $payeeLower = if ($payee) { $payee.ToLower() } else { "" }
        
        # Parse amount to determine if positive or negative
        $numericAmount = 0
        if ($amount) {
            $cleanAmount = $amount -replace '[^\d.,-]', ''
            $cleanAmount = $cleanAmount -replace ',', '.'
            try {
                $numericAmount = [double]$cleanAmount
                if ($amount -match '^-') {
                    $numericAmount = -[Math]::Abs($numericAmount)
                }
            } catch {
                # Kann Betrag nicht parsen, ignoriere betrags-sensitive Regeln
                return ""
            }
        }
        
        # Gewinnsparen-Logik
        if ($memoLower -match "gewinnsparen|gewinn.*sparen" -or $payeeLower -match "gewinnsparen") {
            if ($numericAmount -lt 0) {
                # Negative Beträge = Spareinlagen
                return $this.GetLocalizedString("savings") # Fällt auf "Sparen" zurück wenn nicht definiert
            } elseif ($numericAmount -gt 0) {
                # Positive Beträge = Gewinne
                return $this.GetLocalizedString("winnings") # Fällt auf "Gewinn" zurück wenn nicht definiert
            }
        }
        
        # Gewinn-Keywords (positive Beträge)
        if ($numericAmount -gt 0 -and ($memoLower -match "herzlichen.*glückwunsch|gewinn|jackpot|preis|glückwunsch.*gewinn" -or $payeeLower -match "lotto|gewinn")) {
            return $this.GetLocalizedString("winnings")
        }
        
        # Intelligente Kartenzahlungs-Kategorisierung
        if ($payeeLower -match "lastschrift.*kartenzahlung|kartenzahlung|card payment") {
            # Analysiere Memo für Geschäftstyp - Reihenfolge ist wichtig!
            # Parkhaus hat Priorität vor Supermarkt (z.B. "PARKHAUS KAUFLAND")
            if ($memoLower -match "parkhaus|parken|parking") {
                return "Parken"
            } elseif ($memoLower -match "friseur|haare|hair|salon|artista|beauty") {
                return $this.GetLocalizedString("pharmacy_health")
            } elseif ($memoLower -match "rewe") {
                return "REWE"
            } elseif ($memoLower -match "edeka") {
                return "EDEKA"
            } elseif ($memoLower -match "aldi") {
                return "ALDI"
            } elseif ($memoLower -match "lidl") {
                return "LIDL"
            } elseif ($memoLower -match "kaufland") {
                return "KAUFLAND"
            } elseif ($memoLower -match "netto") {
                return "Netto"
            } elseif ($memoLower -match "penny") {
                return "Penny"
            } elseif ($memoLower -match "supermarkt|grocery|schaeferei|baeckerei|metzgerei|fleischerei|golderer") {
                return $this.GetLocalizedString("groceries")
            } elseif ($memoLower -match "tankstelle|shell|aral|esso|jet|fuel|gas.*station") {
                return $this.GetLocalizedString("fuel")
            } elseif ($memoLower -match "apotheke|pharmacy|dm.*drogerie|rossmann") {
                return $this.GetLocalizedString("pharmacy_health")
            } elseif ($memoLower -match "restaurant|mcdonald|burger|pizza|cafe|bistro") {
                return $this.GetLocalizedString("restaurants")
            } elseif ($memoLower -match "media.*markt|saturn|elektronik|electronics") {
                return $this.GetLocalizedString("electronics")
            } elseif ($memoLower -match "baumarkt|obi|hornbach|bauhaus") {
                return $this.GetLocalizedString("housing")
            } elseif ($memoLower -match "c&a|h&m|zara|primark|mode|fashion|kleidung") {
                return $this.GetLocalizedString("clothing")
            }
            # Falls kein spezifisches Muster gefunden, verwende Fallback
            # return "" bedeutet: verwende die bestehende exactPayee-Zuordnung
        }
        
        return ""
    }
    
    # Fügt neue Kategorisierungs-Regel hinzu
    [void] AddRule([string]$type, [string]$pattern, [string]$category) {
        switch ($type) {
            "exactPayee" { $this.rules["exactPayee"][$pattern] = $category }
            "payeeKeyword" { $this.rules["payeeKeywords"][$pattern] = $category }
            "memoKeyword" { $this.rules["memoKeywords"][$pattern] = $category }
            "buchungstextKeyword" { $this.rules["buchungstextKeywords"][$pattern] = $category }
            "amount" { $this.rules["amountPatterns"][$pattern] = $category }
        }
    }
    
    # Speichert alle Regeln
    [void] SaveRules() {
        $localConfigPath = $this.configPath -replace "categories\.json", "config.local.json"
        
        # Konvertiere zurück zu altem Format für Kompatibilität
        $config = @{
            categoryMappings = $this.rules["exactPayee"]
            categoryKeywords = @{}
        }
        
        # Gruppiere Keywords nach Kategorie
        foreach ($keyword in $this.rules["payeeKeywords"].Keys) {
            $category = $this.rules["payeeKeywords"][$keyword]
            if (-not $config.categoryKeywords[$category]) {
                $config.categoryKeywords[$category] = @()
            }
            $config.categoryKeywords[$category] += $keyword
        }
        
        # Konvertiere Arrays zu Comma-separated Strings
        foreach ($category in $config.categoryKeywords.Keys) {
            $config.categoryKeywords[$category] = $config.categoryKeywords[$category] -join ','
        }
        
        # Lade bestehende Konfiguration und merge
        if (Test-Path $localConfigPath) {
            try {
                $existing = Get-Content -Path $localConfigPath -Raw -Encoding UTF8 | ConvertFrom-Json
                
                # Behalte andere Einstellungen
                if ($existing.setup) { $config.setup = $existing.setup }
                if ($existing.accounts) { $config.accounts = $existing.accounts }
            } catch {
                Write-Warning "Fehler beim Laden der bestehenden Konfiguration"
            }
        }
        
        # Speichere
        $config | ConvertTo-Json -Depth 5 | Out-File -FilePath $localConfigPath -Encoding UTF8
    }
    
    # Speichert Oberkategorien-Zuordnungen
    [void] SaveCategoryGroups() {
        $localConfigPath = $this.configPath -replace "categories\.json", "config.local.json"
        
        $config = @{}
        
        # Lade bestehende Konfiguration
        if (Test-Path $localConfigPath) {
            try {
                $config = $this.ConvertToHashtable((Get-Content -Path $localConfigPath -Raw -Encoding UTF8 | ConvertFrom-Json))
            } catch {
                Write-Warning "Fehler beim Laden der bestehenden Konfiguration"
            }
        }
        
        # Aktualisiere categoryGroups
        $config["categoryGroups"] = $this.categories["Standard"]
        
        # Speichere
        $config | ConvertTo-Json -Depth 5 | Out-File -FilePath $localConfigPath -Encoding UTF8
    }
    
    # Hilfsfunktion für PSCustomObject zu Hashtable
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
    
    # Gibt alle verfügbaren Kategorien zurück
    [hashtable] GetAllCategories() {
        $result = @{}
        
        # Standard-Kategorien hinzufügen
        foreach ($group in $this.categories["Standard"].Keys) {
            $result[$group] = $this.categories["Standard"][$group]
        }
        
        # Benutzerdefinierte Kategorien aus categories hinzufügen
        foreach ($group in $this.categories["Benutzerdefiniert"].Keys) {
            if ($result.Keys -contains $group) {
                # Merge mit bestehender Gruppe
                $result[$group] += $this.categories["Benutzerdefiniert"][$group]
            } else {
                $result[$group] = $this.categories["Benutzerdefiniert"][$group]
            }
        }
        
        # Dynamisch erstellte Kategorien aus Rules hinzufügen
        $usedCategories = @{}
        
        # Sammle alle verwendeten Kategorien aus allen Regel-Typen
        foreach ($ruleType in $this.rules.Keys) {
            foreach ($pattern in $this.rules[$ruleType].Keys) {
                $category = $this.rules[$ruleType][$pattern]
                if ($category -and $category.Trim() -ne "") {
                    $usedCategories[$category] = $true
                }
            }
        }
        
        # Prüfe welche Kategorien nicht in Standard-Kategorien enthalten sind
        foreach ($category in $usedCategories.Keys) {
            $found = $false
            foreach ($group in $result.Keys) {
                if ($result[$group] -contains $category) {
                    $found = $true
                    break
                }
            }
            
            # Falls nicht gefunden, zu "Sonstige" hinzufügen
            if (-not $found) {
                if (-not ($result.Keys -contains "Sonstige")) {
                    $result["Sonstige"] = @()
                }
                if ($result["Sonstige"] -notcontains $category) {
                    $result["Sonstige"] += $category
                }
            }
        }
        
        return $result
    }
    
    # Debug-Funktionen
    [void] ShowRuleStats() {
        Write-Host "=== KATEGORISIERUNGS-REGELN ===" -ForegroundColor Cyan
        Write-Host "Exakte Payee-Matches: $($this.rules['exactPayee'].Count)" -ForegroundColor Yellow
        Write-Host "Payee-Keywords: $($this.rules['payeeKeywords'].Count)" -ForegroundColor Yellow
        Write-Host "Memo-Keywords: $($this.rules['memoKeywords'].Count)" -ForegroundColor Yellow
        Write-Host "Buchungstext-Keywords: $($this.rules['buchungstextKeywords'].Count)" -ForegroundColor Yellow
        Write-Host "Betrags-Patterns: $($this.rules['amountPatterns'].Count)" -ForegroundColor Yellow
        Write-Host "Sprache: $($this.language)" -ForegroundColor Yellow
        Write-Host "Geladene Sprachstrings: $($this.langStrings.Count)" -ForegroundColor Yellow
    }
    
    # Prüft auf interne Transfers anhand von IBANs im Memo
    [string] CheckInternalTransfer([string]$memo) {
        if (-not $memo) { return "" }
        
        # Lade lokale Konfiguration für IBAN-Mapping
        $localConfigPath = $this.configPath -replace "categories\.json", "config.local.json"
        if (-not (Test-Path $localConfigPath)) { return "" }
        
        try {
            $content = Get-Content -Path $localConfigPath -Raw -Encoding UTF8 | ConvertFrom-Json
            if (-not $content.accounts -or -not $content.accounts.ibanMapping) { return "" }
            
            # Suche nach IBAN-Pattern im Memo (DE + 20 Ziffern)
            $ibanPattern = "DE\d{20}"
            $matches = [regex]::Matches($memo, $ibanPattern)
            
            foreach ($match in $matches) {
                $foundIban = $match.Value
                # Prüfe ob diese IBAN zu unseren eigenen Konten gehört
                if ($content.accounts.ibanMapping.PSObject.Properties.Name -contains $foundIban) {
                    $targetAccount = $content.accounts.ibanMapping.$foundIban
                    # Rückgabe einer lokalisierten Transfer-Kategorie
                    return $this.GetLocalizedString("transfer")
                }
            }
        } catch {
            # Falls Fehler beim Laden der Konfiguration, ignoriere Transfer-Erkennung
            return ""
        }
        
        return ""
    }
    
    # Einheitliche PayPal-Kategorisierung für alle Formate
    [string] CheckPayPalTransaction([string]$payee, [string]$memo) {
        if (-not $payee) { return "" }
        
        # Prüfe ob es eine PayPal-Transaktion ist (alle Varianten)
        $isPayPal = $payee -match "paypal" -or $payee -match "PAYPAL"
        if (-not $isPayPal) { return "" }
        
        $merchant = $this.ExtractPayPalMerchant($payee, $memo)
        if (-not $merchant) { return "" }
        
        return $this.CategorizePayPalMerchant($merchant)
    }
    
    # Extrahiert Merchant-Namen aus verschiedenen PayPal-Formaten
    [string] ExtractPayPalMerchant([string]$payee, [string]$memo) {
        $merchant = ""
        
        # Format 1: PAYPAL *MERCHANT (Kreditkarte)
        if ($payee -match "PAYPAL \*(.+?)(?:\s|$)") {
            $merchant = $matches[1].Trim()
        }
        # Format 4: PayPal Service - Merchant aus Memo (VOR Format 2!)
        elseif ($payee -match "PayPal \(PayPal Service\)" -and $memo) {
            # Direkte Merchant-Namen im Memo suchen
            if ($memo -match "Google") {
                $merchant = "Google"
            }
            elseif ($memo -match "Apple") {
                $merchant = "Apple"
            }
            elseif ($memo -match "bei (.+?)(?:/|,|\s|$)") {
                $merchant = $matches[1].Trim()
            }
        }
        # Format 2: PayPal (MERCHANT) (Service/Specific)
        elseif ($payee -match "PayPal \((.+?)\)") {
            $merchant = $matches[1].Trim()
        }
        # Format 3: PayPal Europe - Merchant aus Memo extrahieren
        elseif ($payee -match "PayPal.*Europe" -and $memo) {
            # Verschiedene Memo-Patterns für Merchant-Extraktion
            if ($memo -match "Ihr Einkauf bei (.+?)(?:\s+EREF:|/ABBUCHUNG|$)") {
                $merchant = $matches[1].Trim()
            }
            elseif ($memo -match "bei (.+?)(?:/|,|\s+EREF:|\s*$)") {
                $merchant = $matches[1].Trim()
            }
            elseif ($memo -match "(\w+\.\w+\.\w+)/") {
                # Pattern für URLs wie "handyhuellen.de"
                $merchant = $matches[1].Trim()
            }
        }
        
        # Bereinige Merchant-Namen
        if ($merchant) {
            $merchant = $merchant -replace "^\.|^/|/$", ""  # Entferne führende/trailing Punkte/Slashes
            $merchant = $merchant.Trim()
        }
        
        return $merchant
    }
    
    # Kategorisiert basierend auf Merchant-Namen
    [string] CategorizePayPalMerchant([string]$merchant) {
        if (-not $merchant) { return "" }
        
        $merchantLower = $merchant.ToLower()
        
        # Spezielle Services
        if ($merchantLower -match "^google|google payment|youtube|gmail|google cloud|google store|google play") {
            return "Google"
        }
        if ($merchantLower -match "^apple|apple services|app store|itunes|icloud|apple music|apple tv") {
            return "Apple"
        }
        if ($merchantLower -match "^mullvad|vpn") {
            return "Internet & Telefon"
        }
        
        # Fallback: Verwende Merchant-Name als Kategorie (erste Buchstabe groß)
        if ($merchant.Length -gt 0) {
            return $merchant.Substring(0,1).ToUpper() + $merchant.Substring(1).ToLower()
        }
        
        return ""
    }
    
    
    # PowerShell 5.1 kompatible Version ohne optionale Parameter
    [void] TestTransaction([string]$payee) {
        $this.TestTransactionFull($payee, "", "", "")
    }
    
    [void] TestTransaction([string]$payee, [string]$memo) {
        $this.TestTransactionFull($payee, $memo, "", "")
    }
    
    [void] TestTransactionFull([string]$payee, [string]$memo, [string]$buchungstext, [string]$amount) {
        $transaction = @{
            payee = $payee
            memo = $memo
            buchungstext = $buchungstext
            amount = $amount
        }
        
        $result = $this.CategorizeTransaction($transaction)
        
        Write-Host "Test-Transaktion:" -ForegroundColor Cyan
        Write-Host "  Payee: $payee" -ForegroundColor White
        if ($memo) { Write-Host "  Memo: $memo" -ForegroundColor White }
        if ($buchungstext) { Write-Host "  Buchungstext: $buchungstext" -ForegroundColor White }
        if ($amount) { Write-Host "  Betrag: $amount" -ForegroundColor White }
        Write-Host "  → Kategorie: " -NoNewline -ForegroundColor Gray
        if ($result) {
            Write-Host "$result" -ForegroundColor Green
        } else {
            Write-Host "Nicht kategorisiert" -ForegroundColor Red
        }
    }
}