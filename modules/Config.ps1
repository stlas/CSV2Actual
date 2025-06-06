# CSV2Actual - Configuration Management Module
# Version: 0.1 Alpha
# Loads and manages configuration from config.json

class Config {
    [hashtable]$data
    [string]$configPath
    
    Config([string]$path = "config.json") {
        $this.configPath = $path
        $this.LoadConfig()
    }
    
    [void] LoadConfig() {
        if (-not (Test-Path $this.configPath)) {
            throw "Configuration file not found: $($this.configPath)"
        }
        
        try {
            $jsonContent = Get-Content -Path $this.configPath -Raw -Encoding UTF8
            # Convert to hashtable for older PowerShell versions
            $jsonObject = $jsonContent | ConvertFrom-Json
            $this.data = $this.ConvertToHashtable($jsonObject)
        }
        catch {
            throw "Failed to load configuration: $($_.Exception.Message)"
        }
    }
    
    # Convert PSCustomObject to Hashtable for PowerShell 5.1 compatibility
    [hashtable] ConvertToHashtable([object]$obj) {
        $hashtable = @{}
        
        if ($obj -eq $null) {
            return $hashtable
        }
        
        foreach ($property in $obj.PSObject.Properties) {
            $value = $property.Value
            
            if ($value -ne $null -and $value.GetType().Name -eq "PSCustomObject") {
                $hashtable[$property.Name] = $this.ConvertToHashtable($value)
            }
            elseif ($value -is [System.Object[]] -and $value.Count -gt 0 -and $value[0].GetType().Name -eq "PSCustomObject") {
                $hashtable[$property.Name] = @($value | ForEach-Object { $this.ConvertToHashtable($_) })
            }
            else {
                $hashtable[$property.Name] = $value
            }
        }
        
        return $hashtable
    }
    
    # Get configuration value by dot notation path
    [object] Get([string]$path) {
        $parts = $path.Split('.')
        $current = $this.data
        
        foreach ($part in $parts) {
            if ($current.ContainsKey($part)) {
                $current = $current[$part]
            }
            else {
                return $null
            }
        }
        
        return $current
    }
    
    # Get user configuration
    [hashtable] GetUser([string]$userKey) {
        $users = $this.Get("users")
        if ($users -and $users.ContainsKey($userKey)) {
            return $users[$userKey]
        }
        return @{}
    }
    
    # Get account name with user substitution
    [string] GetAccountName([string]$accountKey) {
        $accountNames = $this.Get("accounts.accountNames")
        if (-not $accountNames -or -not $accountNames.ContainsKey($accountKey)) {
            return $accountKey
        }
        
        $template = $accountNames[$accountKey]
        
        # Replace user placeholders
        $user1 = $this.GetUser("user1")
        $user2 = $this.GetUser("user2")
        
        $template = $template -replace '\{\{user1\.displayName\}\}', $user1.displayName
        $template = $template -replace '\{\{user2\.displayName\}\}', $user2.displayName
        
        return $template
    }
    
    # Get IBAN mapping
    [hashtable] GetIBANMapping() {
        $mapping = $this.Get("accounts.ibanMapping")
        if (-not $mapping) {
            return @{}
        }
        
        # Create result with resolved account names
        $result = @{}
        foreach ($iban in $mapping.Keys) {
            $accountKey = $mapping[$iban]
            $result[$iban] = $this.GetAccountName($accountKey)
        }
        
        return $result
    }
    
    # Get categorization patterns
    [hashtable] GetCategorizationPatterns() {
        return $this.Get("categorization")
    }
    
    # Get salary category for user
    [string] GetSalaryCategory([string]$userKey, [string]$language = "en") {
        $user = $this.GetUser($userKey)
        if (-not $user) {
            return ""
        }
        
        # Load language strings
        $langPath = "$($this.Get('paths.languageDir'))/$language.json"
        if (Test-Path $langPath) {
            $langContent = Get-Content -Path $langPath -Raw -Encoding UTF8 | ConvertFrom-Json -AsHashtable
            $template = $langContent.categories.salary_user
            if ($template) {
                return $template -replace '\{0\}', $user.displayName
            }
        }
        
        # Fallback
        return "Salary $($user.displayName)"
    }
    
    # Get transfer category
    [string] GetTransferCategory([string]$direction, [string]$accountKey, [string]$language = "en") {
        $accountName = $this.GetAccountName($accountKey)
        
        # Load language strings
        $langPath = "$($this.Get('paths.languageDir'))/$language.json"
        if (Test-Path $langPath) {
            $langContent = Get-Content -Path $langPath -Raw -Encoding UTF8 | ConvertFrom-Json -AsHashtable
            $template = $langContent.categories."transfer_$direction"
            if ($template) {
                return $template -replace '\{0\}', $accountName
            }
        }
        
        # Fallback
        if ($direction -eq "from") {
            return "Transfer from $accountName"
        }
        else {
            return "Transfer to $accountName"
        }
    }
    
    # Get paths
    [string] GetSourceDir() {
        return $this.Get("paths.sourceDir")
    }
    
    [string] GetOutputDir() {
        return $this.Get("paths.outputDir")
    }
    
    [string] GetLanguageDir() {
        return $this.Get("paths.languageDir")
    }
    
    # Get CSV settings
    [hashtable] GetCSVSettings() {
        return $this.Get("csv")
    }
    
    # Check if text matches user salary patterns
    [string] CheckSalaryPattern([string]$text, [string]$language = "en") {
        $text = $text.ToLower()
        
        $user1 = $this.GetUser("user1")
        if ($user1 -and $user1.salaryPatterns) {
            foreach ($pattern in $user1.salaryPatterns) {
                if ($text -match $pattern) {
                    return $this.GetSalaryCategory("user1", $language)
                }
            }
        }
        
        $user2 = $this.GetUser("user2")
        if ($user2 -and $user2.salaryPatterns) {
            foreach ($pattern in $user2.salaryPatterns) {
                if ($text -match $pattern) {
                    return $this.GetSalaryCategory("user2", $language)
                }
            }
        }
        
        return ""
    }
    
    # Reload configuration
    [void] Reload() {
        $this.LoadConfig()
    }
}