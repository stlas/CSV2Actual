# CSV2Actual - Internationalization Module
# Version: 1.2.2
# Author: sTLAs (https://github.com/sTLAs)
# Handles language files and localized strings (EN/DE support)

class I18n {
    [hashtable]$strings
    [string]$currentLanguage
    [string]$defaultLanguage = "en"
    [string]$languageDir = "lang"
    
    I18n() {
        $this.currentLanguage = $this.defaultLanguage
        $this.LoadLanguage($this.currentLanguage)
    }
    
    I18n([string]$language) {
        $this.currentLanguage = $language
        $this.defaultLanguage = "en"
        $this.LoadLanguage($language)
    }
    
    I18n([string]$languageDir, [string]$language) {
        $this.currentLanguage = $language
        $this.defaultLanguage = "en"
        $this.languageDir = $languageDir
        $this.LoadLanguage($language)
    }
    
    [void]LoadLanguage([string]$language) {
        $langFile = Join-Path $this.languageDir "$language.json"
        
        if (Test-Path $langFile) {
            try {
                $jsonObject = Get-Content $langFile -Encoding UTF8 | ConvertFrom-Json
                $this.strings = $this.ConvertToHashtable($jsonObject)
                $this.currentLanguage = $language
            }
            catch {
                Write-Warning "Failed to load language file '$langFile'. Error: $($_.Exception.Message). Falling back to English."
                $this.LoadLanguage($this.defaultLanguage)
            }
        }
        else {
            if ($language -ne $this.defaultLanguage) {
                Write-Warning "Language file '$langFile' not found. Falling back to English."
                $this.LoadLanguage($this.defaultLanguage)
            }
            else {
                throw "Default language file not found: $($this.languageDir)/$($this.defaultLanguage).json"
            }
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
    
    [string]Get([string]$key) {
        return $this.Get($key, @())
    }
    
    [string]Get([string]$key, [object[]]$arguments) {
        $keys = $key.Split('.')
        $current = $this.strings
        
        foreach ($k in $keys) {
            if ($current.ContainsKey($k)) {
                $current = $current[$k]
            }
            else {
                return "[$key]"  # Return key in brackets if not found
            }
        }
        
        $text = $current.ToString()
        
        # Replace placeholders {0}, {1}, etc. with arguments
        if ($arguments -and $arguments.Length -gt 0) {
            for ($i = 0; $i -lt $arguments.Length; $i++) {
                $argValue = if ($arguments[$i] -ne $null) { $arguments[$i].ToString() } else { "null" }
                $placeholder = "{$i}"
                $text = $text -replace [regex]::Escape($placeholder), $argValue
            }
        }
        
        return $text
    }
    
    # Simplified method for single parameter
    [string]Format([string]$key, [string]$arg0) {
        $text = $this.Get($key, @())
        if ($text.Contains("{0}")) {
            $text = $text -replace [regex]::Escape("{0}"), $arg0
        }
        return $text
    }
    
    [string[]]GetAvailableLanguages() {
        $langFiles = Get-ChildItem "$($this.languageDir)/*.json" | ForEach-Object { $_.BaseName }
        return $langFiles
    }
    
    [void]SwitchLanguage([string]$language) {
        $this.LoadLanguage($language)
    }
}

# Helper function for easy access
function Get-LocalizedString {
    param(
        [string]$key,
        [array]$args = @()
    )
    return $global:i18n.Get($key, $args)
}

# Alias for shorter usage
Set-Alias -Name "t" -Value "Get-LocalizedString"
