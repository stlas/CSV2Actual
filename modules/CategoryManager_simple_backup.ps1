# Vereinfachte CategoryManager Version für Debugging
class CategoryManager {
    [string]$ConfigPath
    [hashtable]$ActiveCategories
    
    CategoryManager([string]$configPath) {
        $this.ConfigPath = $configPath
        $this.ActiveCategories = @{}
    }
    
    [hashtable] LoadCategories() {
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

Write-Host "CategoryManager-Modul (vereinfacht) geladen" -ForegroundColor Green