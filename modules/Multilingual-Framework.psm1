# FILE: ./modules/Multilingual-Framework.psm1

# Multilingual-Framework.psm1 - Centralized Localization System for CSV2Actual
# Version 1.0 - External language files for easy localization

<#
.SYNOPSIS
    Provides centralized multilingual support for CSV2Actual with external language files.

.DESCRIPTION
    This module handles all localization aspects of CSV2Actual, supporting multiple languages
    through external JSON/PSD1 files. Designed for easy translation and maintenance.

.NOTES
    Author: Human-AI Collaborative Development
    Project: CSV2Actual - Exemplary Human-AI Programming Cooperation
    Documentation: English (in-code), German+English (GitHub)
#>

# Default language configuration
$script:DefaultLanguage = "en"
$script:CurrentLanguage = $script:DefaultLanguage
$script:LanguageCache = @{}
$script:LocalizationPath = ".\Localization"

#region Core Localization Functions

<#
.SYNOPSIS
    Initializes the localization system with specified language.

.PARAMETER Language
    Two-letter ISO language code (e.g., "de", "en", "fr")

.PARAMETER FallbackLanguage
    Fallback language if requested language is not available

.EXAMPLE
    Initialize-Localization -Language "de" -FallbackLanguage "en"
#>
function Initialize-Localization {
    [CmdletBinding()]
    param(
        [Parameter(Position = 0)]
        [ValidatePattern('^[a-z]{2}$')]
        [string]$Language = (Get-SystemLanguage),
        
        [Parameter()]
        [ValidatePattern('^[a-z]{2}$')]
        [string]$FallbackLanguage = "en"
    )
    
    Write-Verbose "Initializing localization system with language: $Language"
    
    # Verify localization directory exists
    if (-not (Test-Path $script:LocalizationPath)) {
        Write-Warning "Localization directory not found: $script:LocalizationPath"
        New-Item -Path $script:LocalizationPath -ItemType Directory -Force | Out-Null
        Write-Information "Created localization directory"
    }
    
    # Set current language
    $script:CurrentLanguage = $Language
    
    # Load language files
    $loadResult = Import-LanguageFile -Language $Language
    if (-not $loadResult) {
        Write-Warning "Failed to load language '$Language', falling back to '$FallbackLanguage'"
        $script:CurrentLanguage = $FallbackLanguage
        Import-LanguageFile -Language $FallbackLanguage | Out-Null
    }
    
    Write-Information "Localization initialized: $($script:CurrentLanguage)"
}

<#
.SYNOPSIS
    Imports language file for specified language.

.PARAMETER Language
    Two-letter ISO language code

.RETURNS
    Boolean indicating success
#>
function Import-LanguageFile {
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory)]
        [ValidatePattern('^[a-z]{2}$')]
        [string]$Language
    )
    
    $languageFile = Join-Path $script:LocalizationPath "$Language\strings.psd1"
    
    if (-not (Test-Path $languageFile)) {
        Write-Verbose "Language file not found: $languageFile"
        return $false
    }
    
    try {
        $languageData = Import-PowerShellDataFile -Path $languageFile
        $script:LanguageCache[$Language] = $languageData
        Write-Verbose "Successfully loaded language file: $languageFile"
        return $true
    }
    catch {
        Write-Error "Failed to load language file '$languageFile': $($_.Exception.Message)"
        return $false
    }
}

<#
.SYNOPSIS
    Gets localized string for specified key.

.PARAMETER Key
    Localization key in dot notation (e.g., "UI.Buttons.Save")

.PARAMETER Arguments
    Arguments for string formatting

.PARAMETER Language
    Override current language for this specific request

.EXAMPLE
    Get-LocalizedString -Key "Messages.ProcessingFile" -Arguments @("data.csv")
#>
function Get-LocalizedString {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory, Position = 0)]
        [string]$Key,
        
        [Parameter()]
        [object[]]$Arguments = @(),
        
        [Parameter()]
        [ValidatePattern('^[a-z]{2}$')]
        [string]$Language = $script:CurrentLanguage
    )
    
    # Ensure language is loaded
    if (-not $script:LanguageCache.ContainsKey($Language)) {
        if (-not (Import-LanguageFile -Language $Language)) {
            # Fall back to default language
            $Language = $script:DefaultLanguage
            if (-not $script:LanguageCache.ContainsKey($Language)) {
                Import-LanguageFile -Language $Language | Out-Null
            }
        }
    }
    
    # Navigate through nested keys
    $current = $script:LanguageCache[$Language]
    $keyParts = $Key -split '\.'
    
    foreach ($part in $keyParts) {
        if ($current -is [hashtable] -and $current.ContainsKey($part)) {
            $current = $current[$part]
        }
        else {
            Write-Warning "Localization key not found: $Key (Language: $Language)"
            return "[$Key]" # Return key in brackets to indicate missing translation
        }
    }
    
    # Apply string formatting if arguments provided
    if ($Arguments.Count -gt 0 -and $current -is [string]) {
        try {
            return ($current -f $Arguments)
        }
        catch {
            Write-Warning "String formatting failed for key '$Key': $($_.Exception.Message)"
            return $current
        }
    }
    
    return $current
}

<#
.SYNOPSIS
    Sets the current language for the session.

.PARAMETER Language
    Two-letter ISO language code
#>
function Set-CurrentLanguage {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidatePattern('^[a-z]{2}$')]
        [string]$Language
    )
    
    if (Import-LanguageFile -Language $Language) {
        $script:CurrentLanguage = $Language
        Write-Information "Language changed to: $Language"
    }
    else {
        Write-Error "Failed to set language to '$Language'"
    }
}

<#
.SYNOPSIS
    Gets the current system language.

.RETURNS
    Two-letter ISO language code
#>
function Get-SystemLanguage {
    [CmdletBinding()]
    [OutputType([string])]
    param()
    
    try {
        $culture = Get-Culture
        return $culture.TwoLetterISOLanguageName.ToLower()
    }
    catch {
        Write-Verbose "Failed to get system language, defaulting to 'en'"
        return "en"
    }
}

<#
.SYNOPSIS
    Gets list of available languages.

.RETURNS
    Array of available language codes
#>
function Get-AvailableLanguages {
    [CmdletBinding()]
    [OutputType([string[]])]
    param()
    
    if (-not (Test-Path $script:LocalizationPath)) {
        return @()
    }
    
    $languages = Get-ChildItem -Path $script:LocalizationPath -Directory | 
                 Where-Object { $_.Name -match '^[a-z]{2}$' } |
                 ForEach-Object { $_.Name }
    
    return $languages
}

#endregion

#region Language File Management

<#
.SYNOPSIS
    Creates a new language file template.

.PARAMETER Language
    Two-letter ISO language code

.PARAMETER BaseLanguage
    Base language to copy structure from (default: "en")
#>
function New-LanguageFile {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidatePattern('^[a-z]{2}$')]
        [string]$Language,
        
        [Parameter()]
        [ValidatePattern('^[a-z]{2}$')]
        [string]$BaseLanguage = "en"
    )
    
    $languageDir = Join-Path $script:LocalizationPath $Language
    $languageFile = Join-Path $languageDir "strings.psd1"
    
    # Create directory if it doesn't exist
    if (-not (Test-Path $languageDir)) {
        New-Item -Path $languageDir -ItemType Directory -Force | Out-Null
    }
    
    # Check if file already exists
    if (Test-Path $languageFile) {
        Write-Warning "Language file already exists: $languageFile"
        return
    }
    
    # Get base language structure or create default
    $baseStructure = $null
    if ($script:LanguageCache.ContainsKey($BaseLanguage)) {
        $baseStructure = $script:LanguageCache[$BaseLanguage]
    }
    elseif (Import-LanguageFile -Language $BaseLanguage) {
        $baseStructure = $script:LanguageCache[$BaseLanguage]
    }
    
    if ($null -eq $baseStructure) {
        # Create default structure
        $baseStructure = Get-DefaultLanguageStructure
    }
    
    # Create new language file with structure from base language
    $content = ConvertTo-LanguageFileContent -Data $baseStructure -Language $Language
    
    Set-Content -Path $languageFile -Value $content -Encoding UTF8
    Write-Information "Created new language file: $languageFile"
}

<#
.SYNOPSIS
    Converts hashtable to PowerShell data file content.

.PARAMETER Data
    Hashtable with language strings

.PARAMETER Language
    Target language code
#>
function ConvertTo-LanguageFileContent {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable]$Data,
        
        [Parameter(Mandatory)]
        [string]$Language
    )
    
    $header = @"
# CSV2Actual Localization File - $Language
# Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
# 
# This file contains all user-facing strings for CSV2Actual
# Edit this file to provide translations for the $Language language
#
# Format: Key-Value pairs using PowerShell hashtable syntax
# Use {0}, {1}, etc. for string formatting placeholders

"@
    
    $content = $header + "`n`n@{`n"
    $content += ConvertTo-HashtableString -Hashtable $Data -IndentLevel 1
    $content += "}`n"
    
    return $content
}

<#
.SYNOPSIS
    Converts hashtable to formatted string representation.
#>
function ConvertTo-HashtableString {
    param(
        [hashtable]$Hashtable,
        [int]$IndentLevel = 0
    )
    
    $indent = "    " * $IndentLevel
    $result = ""
    
    foreach ($key in ($Hashtable.Keys | Sort-Object)) {
        $value = $Hashtable[$key]
        
        if ($value -is [hashtable]) {
            $result += "$indent$key = @{`n"
            $result += ConvertTo-HashtableString -Hashtable $value -IndentLevel ($IndentLevel + 1)
            $result += "$indent}`n"
        }
        else {
            $escapedValue = $value -replace '"', '""'
            $result += "$indent$key = `"$escapedValue`"`n"
        }
    }
    
    return $result
}

<#
.SYNOPSIS
    Gets the default language structure for CSV2Actual.
#>
function Get-DefaultLanguageStructure {
    return @{
        UI = @{
            Title = "CSV2Actual - CSV Import Tool"
            Buttons = @{
                Process = "Process"
                Cancel = "Cancel"
                Browse = "Browse..."
                Save = "Save"
                Load = "Load"
                Exit = "Exit"
            }
            Menus = @{
                File = "File"
                Edit = "Edit"
                View = "View"
                Tools = "Tools"
                Help = "Help"
            }
        }
        Messages = @{
            ProcessingFile = "Processing file: {0}"
            ProcessingComplete = "Processing completed successfully"
            ProcessingFailed = "Processing failed: {0}"
            FileNotFound = "File not found: {0}"
            InvalidFormat = "Invalid file format: {0}"
            BackupCreated = "Backup created: {0}"
            ConfigLoaded = "Configuration loaded from: {0}"
            ConfigSaved = "Configuration saved to: {0}"
        }
        Errors = @{
            FileAccess = "Cannot access file: {0}"
            InvalidConfiguration = "Invalid configuration: {0}"
            ProcessingError = "Error during processing: {0}"
            UnexpectedError = "An unexpected error occurred: {0}"
        }
        Categories = @{
            Income = "Income"
            Expenses = "Expenses"
            Transfer = "Transfer"
            Investment = "Investment"
            Unknown = "Unknown"
        }
        Progress = @{
            Initializing = "Initializing..."
            LoadingFile = "Loading file..."
            ProcessingData = "Processing data..."
            ApplyingRules = "Applying categorization rules..."
            GeneratingOutput = "Generating output..."
            Finalizing = "Finalizing..."
        }
    }
}

#endregion

#region Convenience Aliases and Shortcuts

# Create convenient aliases for commonly used functions
Set-Alias -Name "T" -Value "Get-LocalizedString" -Scope Global
Set-Alias -Name "Translate" -Value "Get-LocalizedString" -Scope Global
Set-Alias -Name "SetLang" -Value "Set-CurrentLanguage" -Scope Global

#endregion

# Export public functions
Export-ModuleMember -Function @(
    'Initialize-Localization',
    'Get-LocalizedString', 
    'Set-CurrentLanguage',
    'Get-SystemLanguage',
    'Get-AvailableLanguages',
    'New-LanguageFile'
) -Alias @('T', 'Translate', 'SetLang')