# CategoryManager.ps1 - Minimale Version für Tests

# Icon-Set für PowerShell 5.1/7.x Kompatibilität
$script:Icons = @{
    Folder = "[DIR]"
    Save = "[SAVE]"
    World = "[COMM]"
    Library = "[LIB]"
    Package = "[PKG]"
    Check = "[OK]"
    Warning = "[WARN]"
    Error = "[ERR]"
    Info = "[INFO]"
    Export = "[EXPORT]"
    Mailbox = "[EMPTY]"
    Session = "[SESS]"
    Search = "[FIND]"
    Edit = "[EDIT]"
    Delete = "[DEL]"
    Skip = "[SKIP]"
}

class CategoryManager {
    [string]$ConfigPath
    [string]$CategoriesPath
    [hashtable]$ActiveCategories
    [hashtable]$SessionCategories
    [bool]$HasUnsavedChanges
    
    CategoryManager([string]$configPath) {
        $this.ConfigPath = $configPath
        $this.CategoriesPath = Join-Path (Split-Path $configPath) "categories"
        $this.ActiveCategories = @{}
        $this.SessionCategories = @{}
        $this.HasUnsavedChanges = $false
        
        if (-not (Test-Path $this.CategoriesPath)) {
            New-Item -ItemType Directory -Path $this.CategoriesPath -Force | Out-Null
        }
    }
    
    [hashtable] LoadCategories([string]$source = "auto") {
        return @{}
    }
    
    [hashtable] LoadFromConfig() {
        if (Test-Path $this.ConfigPath) {
            $config = Get-Content $this.ConfigPath -Encoding UTF8 | ConvertFrom-Json
            if ($config.PSObject.Properties.Name -contains "categoryMappings") {
                $mappings = @{}
                foreach ($prop in $config.categoryMappings.PSObject.Properties) {
                    $mappings[$prop.Name] = $prop.Value
                }
                return $mappings
            }
        }
        return @{}
    }
}

function New-CategoryManager {
    param([string]$ConfigPath = "config.local.json")
    
    $fullPath = if ([System.IO.Path]::IsPathRooted($ConfigPath)) { 
        $ConfigPath 
    } else { 
        Join-Path $PSScriptRoot "../$ConfigPath" 
    }
    
    return [CategoryManager]::new($fullPath)
}

Write-Host "$($script:Icons.Check) CategoryManager-Modul geladen" -ForegroundColor Green