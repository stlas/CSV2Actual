# CSV2Actual - Community Loader Module
# Version: 1.0
# Author: sTLAs (https://github.com/sTLAs)
# Loads and manages community-contributed CSV formats and category sets

class CommunityLoader {
    [string]$communityPath
    [hashtable]$csvFormats
    [hashtable]$categorySets
    [object]$i18n
    
    CommunityLoader() {
        $this.communityPath = "$PSScriptRoot/../community"
        $this.csvFormats = @{}
        $this.categorySets = @{}
        
        # Use global i18n if available
        if ($global:i18n) {
            $this.i18n = $global:i18n
        }
        
        $this.LoadCommunityContent()
    }
    
    CommunityLoader([string]$communityPath) {
        $this.communityPath = $communityPath
        $this.csvFormats = @{}
        $this.categorySets = @{}
        
        # Use global i18n if available
        if ($global:i18n) {
            $this.i18n = $global:i18n
        }
        
        $this.LoadCommunityContent()
    }
    
    CommunityLoader([string]$communityPath, [object]$i18nInstance) {
        $this.communityPath = $communityPath
        $this.csvFormats = @{}
        $this.categorySets = @{}
        $this.i18n = $i18nInstance
        
        $this.LoadCommunityContent()
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
        # Fallback implementation
        $result = $key
        for ($i = 0; $i -lt $args.Length; $i++) {
            $result = $result -replace "\{$i\}", $args[$i].ToString()
        }
        return $result
    }
    
    [void] LoadCommunityContent() {
        $this.LoadCSVFormats()
        $this.LoadCategorySets()
    }
    
    [void] LoadCSVFormats() {
        $csvFormatsPath = Join-Path $this.communityPath "csv-formats"
        
        if (-not (Test-Path $csvFormatsPath)) {
            return
        }
        
        $jsonFiles = Get-ChildItem -Path $csvFormatsPath -Filter "*.json" -ErrorAction SilentlyContinue
        
        foreach ($file in $jsonFiles) {
            try {
                $content = Get-Content -Path $file.FullName -Encoding UTF8 -Raw
                $formatData = $content | ConvertFrom-Json
                
                # Validate required fields
                if ($this.ValidateCSVFormat($formatData)) {
                    $formatId = $file.BaseName
                    $this.csvFormats[$formatId] = $formatData
                }
            }
            catch {
                Write-Warning "Could not load CSV format from $($file.Name): $($_.Exception.Message)"
            }
        }
    }
    
    [void] LoadCategorySets() {
        $categoriesPath = Join-Path $this.communityPath "categories"
        
        if (-not (Test-Path $categoriesPath)) {
            return
        }
        
        $jsonFiles = Get-ChildItem -Path $categoriesPath -Filter "*.json" -ErrorAction SilentlyContinue
        
        foreach ($file in $jsonFiles) {
            try {
                $content = Get-Content -Path $file.FullName -Encoding UTF8 -Raw
                $categoryData = $content | ConvertFrom-Json
                
                # Validate required fields
                if ($this.ValidateCategorySet($categoryData)) {
                    $categoryId = $file.BaseName
                    $this.categorySets[$categoryId] = $categoryData
                }
            }
            catch {
                Write-Warning "Could not load category set from $($file.Name): $($_.Exception.Message)"
            }
        }
    }
    
    [bool] ValidateCSVFormat([object]$formatData) {
        $requiredFields = @("bankName", "country", "csvFormat", "columnMapping")
        
        foreach ($field in $requiredFields) {
            if (-not $formatData.PSObject.Properties.Name -contains $field) {
                return $false
            }
        }
        
        # Validate csvFormat structure
        if (-not $formatData.csvFormat.delimiter -or -not $formatData.csvFormat.encoding) {
            return $false
        }
        
        # Validate columnMapping structure
        if (-not $formatData.columnMapping.date -or -not $formatData.columnMapping.amount) {
            return $false
        }
        
        return $true
    }
    
    [bool] ValidateCategorySet([object]$categoryData) {
        $requiredFields = @("name", "language", "categories")
        
        foreach ($field in $requiredFields) {
            if (-not $categoryData.PSObject.Properties.Name -contains $field) {
                return $false
            }
        }
        
        # Validate categories structure
        if (-not $categoryData.categories.income -and -not $categoryData.categories.expenses) {
            return $false
        }
        
        return $true
    }
    
    [array] GetAvailableCSVFormats() {
        return $this.csvFormats.Keys | Sort-Object
    }
    
    [array] GetAvailableCSVFormats([string]$language) {
        $filtered = @()
        foreach ($formatId in $this.csvFormats.Keys) {
            $format = $this.csvFormats[$formatId]
            if (-not $language -or $format.language -eq $language) {
                $filtered += @{
                    id = $formatId
                    name = "$($format.bankName) ($($format.country))"
                    description = $format.description
                    language = $format.language
                }
            }
        }
        return $filtered | Sort-Object name
    }
    
    [array] GetAvailableCategorySets() {
        return $this.categorySets.Keys | Sort-Object
    }
    
    [array] GetAvailableCategorySets([string]$language) {
        $filtered = @()
        foreach ($categoryId in $this.categorySets.Keys) {
            $categorySet = $this.categorySets[$categoryId]
            if (-not $language -or $categorySet.language -eq $language) {
                $filtered += @{
                    id = $categoryId
                    name = $categorySet.name
                    description = $categorySet.description
                    language = $categorySet.language
                }
            }
        }
        return $filtered | Sort-Object name
    }
    
    [object] GetCSVFormat([string]$formatId) {
        if ($this.csvFormats.ContainsKey($formatId)) {
            return $this.csvFormats[$formatId]
        }
        return $null
    }
    
    [object] GetCategorySet([string]$categoryId) {
        if ($this.categorySets.ContainsKey($categoryId)) {
            return $this.categorySets[$categoryId]
        }
        return $null
    }
    
    [hashtable] GetCSVFormatMapping([string]$formatId) {
        $format = $this.GetCSVFormat($formatId)
        if (-not $format) {
            return @{}
        }
        
        return @{
            delimiter = $format.csvFormat.delimiter
            encoding = $format.csvFormat.encoding
            dateFormat = $format.csvFormat.dateFormat
            decimalSeparator = $format.csvFormat.decimalSeparator
            columnMapping = $format.columnMapping
        }
    }
    
    [hashtable] GetCategoryPatterns([string]$categoryId) {
        $categorySet = $this.GetCategorySet($categoryId)
        if (-not $categorySet) {
            return @{}
        }
        
        $patterns = @{
            income = @{}
            expenses = @{}
            transfers = @{}
        }
        
        # Process income categories
        if ($categorySet.categories.income.categories) {
            foreach ($category in $categorySet.categories.income.categories) {
                $patterns.income[$category.name] = $category.patterns
            }
        }
        
        # Process expense categories
        if ($categorySet.categories.expenses.categories) {
            foreach ($category in $categorySet.categories.expenses.categories) {
                $patterns.expenses[$category.name] = $category.patterns
            }
        }
        
        # Process transfer categories
        if ($categorySet.categories.transfers.categories) {
            foreach ($category in $categorySet.categories.transfers.categories) {
                $patterns.transfers[$category.name] = $category.patterns
            }
        }
        
        return $patterns
    }
    
    [int] GetCSVFormatCount() {
        return $this.csvFormats.Count
    }
    
    [int] GetCategorySetCount() {
        return $this.categorySets.Count
    }
    
    [hashtable] GetCommunityStats() {
        return @{
            csvFormats = $this.GetCSVFormatCount()
            categorySets = $this.GetCategorySetCount()
            totalContributions = $this.GetCSVFormatCount() + $this.GetCategorySetCount()
        }
    }
}