# CategoryManager.ps1 - Modulares Kategorien-Management System
# Ermöglicht Import/Export von Kategorien-Sets und Community-Sharing

# Icon-Set für PowerShell 5.1/7.x Kompatibilität
# Temporär nur ASCII-Zeichen für maximale Kompatibilität
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
        
        # Erstelle Categories-Ordner falls nicht vorhanden
        if (-not (Test-Path $this.CategoriesPath)) {
            New-Item -ItemType Directory -Path $this.CategoriesPath -Force | Out-Null
        }
    }
    
    # Lade Kategorien aus verschiedenen Quellen
    [hashtable] LoadCategories([string]$source = "auto") {
        try {
            switch ($source) {
                "config" {
                    return $this.LoadFromConfig()
                }
                "session" {
                    return $this.LoadFromSession()
                }
                "file" {
                    return $this.LoadFromFile()
                }
                "community" {
                    return $this.LoadFromCommunity()
                }
                default {
                    return $this.LoadWithPriority()
                }
            }
            return @{} # Fallback für PowerShell Klassen-Syntax
        } catch {
            Write-Warning "Fehler beim Laden der Kategorien: $($_.Exception.Message)"
            return @{}
        }
    }
    
    # Automatische Prioritäts-basierte Ladung
    [hashtable] LoadWithPriority() {
        # 1. Session-Kategorien (höchste Priorität)
        $sessionFile = Join-Path $this.CategoriesPath "session_categories.json"
        if (Test-Path $sessionFile) {
            $this.SessionCategories = $this.LoadFromSession()
            if ($this.SessionCategories.Count -gt 0) {
                Write-Host "$($script:Icons.Folder) Session-Kategorien geladen: $($this.SessionCategories.Count) Mappings" -ForegroundColor Green
                return $this.SessionCategories
            }
        }
        
        # 2. Gespeicherte Kategorien-Datei
        $savedFile = Join-Path $this.CategoriesPath "saved_categories.json"
        if (Test-Path $savedFile) {
            $savedCategories = $this.LoadFromFile($savedFile)
            if ($savedCategories.Count -gt 0) {
                Write-Host "$($script:Icons.Save) Gespeicherte Kategorien geladen: $($savedCategories.Count) Mappings" -ForegroundColor Cyan
                return $savedCategories
            }
        }
        
        # 3. Fallback zu config.local.json
        return $this.LoadFromConfig()
    }
    
    # Lade aus config.local.json
    [hashtable] LoadFromConfig() {
        if (Test-Path $this.ConfigPath) {
            $config = Get-Content $this.ConfigPath -Encoding UTF8 | ConvertFrom-Json
            if ($config.PSObject.Properties.Name -contains "categoryMappings") {
                $mappings = @{}
                foreach ($prop in $config.categoryMappings.PSObject.Properties) {
                    $mappings[$prop.Name] = $prop.Value
                }
                $this.ActiveCategories = $mappings
                return $mappings
            }
        }
        return @{}
    }
    
    # Lade aus Session-Datei
    [hashtable] LoadFromSession() {
        $sessionFile = Join-Path $this.CategoriesPath "session_categories.json"
        if (Test-Path $sessionFile) {
            $sessionData = Get-Content $sessionFile -Encoding UTF8 | ConvertFrom-Json
            
            $mappings = @{}
            if ($sessionData.PSObject.Properties.Name -contains "categoryMappings") {
                foreach ($prop in $sessionData.categoryMappings.PSObject.Properties) {
                    $mappings[$prop.Name] = $prop.Value
                }
            }
            
            # Metadata laden
            $this.HasUnsavedChanges = if ($sessionData.PSObject.Properties.Name -contains "hasUnsavedChanges") { 
                $sessionData.hasUnsavedChanges 
            } else { 
                $false 
            }
            
            $this.SessionCategories = $mappings
            return $mappings
        }
        return @{}
    }
    
    # Lade aus spezifischer Datei
    [hashtable] LoadFromFile([string]$filePath = "") {
        if (-not $filePath) {
            $filePath = Join-Path $this.CategoriesPath "saved_categories.json"
        }
        
        if (Test-Path $filePath) {
            $data = Get-Content $filePath -Encoding UTF8 | ConvertFrom-Json
            
            $mappings = @{}
            if ($data.PSObject.Properties.Name -contains "categoryMappings") {
                foreach ($prop in $data.categoryMappings.PSObject.Properties) {
                    $mappings[$prop.Name] = $prop.Value
                }
            }
            
            return $mappings
        }
        return @{}
    }
    
    # Community-Kategorien laden
    [hashtable] LoadFromCommunity() {
        $communityPath = Join-Path $this.CategoriesPath "community"
        if (-not (Test-Path $communityPath)) {
            New-Item -ItemType Directory -Path $communityPath -Force | Out-Null
        }
        
        # Zeige verfügbare Community-Sets
        $communityFiles = Get-ChildItem -Path $communityPath -Filter "*.json"
        if ($communityFiles.Count -eq 0) {
            Write-Host "$($script:Icons.Mailbox) Keine Community-Kategorien gefunden in: $communityPath" -ForegroundColor Yellow
            return @{}
        }
        
        Write-Host "$($script:Icons.World) Verfügbare Community-Kategorien:" -ForegroundColor Cyan
        for ($i = 0; $i -lt $communityFiles.Count; $i++) {
            $file = $communityFiles[$i]
            $metadata = $this.GetCategorySetMetadata($file.FullName)
            Write-Host "  [$($i+1)] $($file.BaseName) - $($metadata.description)" -ForegroundColor White
        }
        
        $choice = Read-Host "Welches Set laden? (1-$($communityFiles.Count), Enter=Abbrechen)"
        if ($choice -match '^\d+$' -and [int]$choice -ge 1 -and [int]$choice -le $communityFiles.Count) {
            $selectedFile = $communityFiles[[int]$choice - 1]
            return $this.LoadFromFile($selectedFile.FullName)
        }
        
        return @{}
    }
    
    # Speichere Session-Stand
    [void] SaveSession([hashtable]$categories, [hashtable]$metadata = @{}) {
        $sessionFile = Join-Path $this.CategoriesPath "session_categories.json"
        
        $sessionData = @{
            metadata = @{
                created = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
                lastModified = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
                totalMappings = $categories.Count
                source = "interactive_session"
                hasUnsavedChanges = $true
            }
            categoryMappings = $categories
        }
        
        # Zusätzliche Metadata hinzufügen
        foreach ($key in $metadata.Keys) {
            $sessionData.metadata[$key] = $metadata[$key]
        }
        
        $sessionData | ConvertTo-Json -Depth 5 | Out-File $sessionFile -Encoding UTF8
        $this.SessionCategories = $categories
        $this.HasUnsavedChanges = $true
        
        Write-Host "$($script:Icons.Save) Session zwischengespeichert: $($categories.Count) Kategorien" -ForegroundColor Green
    }
    
    # Finale Speicherung
    [void] SaveCategories([hashtable]$categories, [string]$name = "", [string]$description = "") {
        if (-not $name) {
            $name = "saved_categories_$(Get-Date -Format 'yyyy-MM-dd_HHmmss')"
        }
        
        $fileName = "$name.json"
        $filePath = Join-Path $this.CategoriesPath $fileName
        
        $categoryData = @{
            metadata = @{
                name = $name
                description = if ($description) { $description } else { "Kategorien-Set erstellt am $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" }
                created = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
                version = "1.0"
                totalMappings = $categories.Count
                source = "csv2actual_interactive"
                compatible = @("PowerShell_5.1", "PowerShell_7.x")
            }
            categoryMappings = $categories
            granularRules = $this.LoadGranularRules()
        }
        
        $categoryData | ConvertTo-Json -Depth 5 | Out-File $filePath -Encoding UTF8
        
        # Session-Datei löschen da finale Speicherung erfolgt
        $sessionFile = Join-Path $this.CategoriesPath "session_categories.json"
        if (Test-Path $sessionFile) {
            Remove-Item $sessionFile -Force
        }
        
        $this.HasUnsavedChanges = $false
        Write-Host "$($script:Icons.Check) Kategorien gespeichert: $filePath" -ForegroundColor Green
        Write-Host "$($script:Icons.Info) $($categories.Count) Kategorien-Mappings archiviert" -ForegroundColor Cyan
    }
    
    # Community-Export
    [void] ExportForCommunity([hashtable]$categories, [string]$name, [string]$description, [string]$author = "Anonymous") {
        $communityPath = Join-Path $this.CategoriesPath "community"
        if (-not (Test-Path $communityPath)) {
            New-Item -ItemType Directory -Path $communityPath -Force | Out-Null
        }
        
        $fileName = "$($name -replace '[^\w\-_]', '_').json"
        $filePath = Join-Path $communityPath $fileName
        
        $communityData = @{
            metadata = @{
                name = $name
                description = $description
                author = $author
                created = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
                version = "1.0"
                language = "de"
                totalMappings = $categories.Count
                tags = @("german_banks", "csv2actual", "community")
                license = "CC0-1.0"
            }
            categoryMappings = $categories
            granularRules = $this.LoadGranularRules()
        }
        
        $communityData | ConvertTo-Json -Depth 5 | Out-File $filePath -Encoding UTF8
        Write-Host "$($script:Icons.World) Community-Export erstellt: $filePath" -ForegroundColor Green
        Write-Host "$($script:Icons.Export) Bereit zum Teilen mit anderen Nutzern!" -ForegroundColor Cyan
    }
    
    # Multi-Set-Loading für Bibliotheken
    [hashtable] LoadMultipleSets() {
        Write-Host "$($script:Icons.Library) $($global:i18n.Get('categorymanager.library_title'))" -ForegroundColor Cyan
        Write-Host "" -ForegroundColor Cyan
        Write-Host ""
        Write-Host $global:i18n.Get('categorymanager.library_description') -ForegroundColor White
        Write-Host ""
        
        $mergedCategories = @{}
        $loadedSets = @()
        $conflictLog = @()
        
        do {
            # Verfügbare Sets anzeigen
            $this.ShowAvailableSets()
            Write-Host ""
            Write-Host $global:i18n.Get('categorymanager.current_loaded', $mergedCategories.Count, $loadedSets.Count) -ForegroundColor Cyan
            if ($loadedSets.Count -gt 0) {
                Write-Host $global:i18n.Get('categorymanager.loaded_sets', ($loadedSets -join ', ')) -ForegroundColor Gray
            }
            Write-Host ""
            
            Write-Host "[1] Community-Set laden" -ForegroundColor Green
            Write-Host "[2] Gespeichertes Set laden" -ForegroundColor Cyan  
            Write-Host "[3] Session laden" -ForegroundColor Yellow
            Write-Host "[4] Konflikte anzeigen" -ForegroundColor Magenta
            Write-Host "[5] Bibliothek speichern" -ForegroundColor Blue
            Write-Host "[f] Fertig - Bibliothek verwenden" -ForegroundColor Green
            Write-Host "[x] Abbrechen" -ForegroundColor Red
            Write-Host ""
            
            $choice = Read-Host "Aktion wählen"
            
            switch ($choice) {
                "1" {
                    $newCategories = $this.LoadFromCommunity()
                    if ($newCategories.Count -gt 0) {
                        $conflicts = $this.MergeCategoriesWithConflictDetection([ref]$mergedCategories, $newCategories, "Community-Set")
                        $conflictLog += $conflicts
                        $loadedSets += "Community-Set"
                    }
                }
                "2" {
                    $fileName = $this.SelectSavedCategoryFile()
                    if ($fileName) {
                        $newCategories = $this.LoadFromFile($fileName)
                        if ($newCategories.Count -gt 0) {
                            $setName = (Split-Path $fileName -LeafBase)
                            $conflicts = $this.MergeCategoriesWithConflictDetection([ref]$mergedCategories, $newCategories, $setName)
                            $conflictLog += $conflicts
                            $loadedSets += $setName
                        }
                    }
                }
                "3" {
                    $sessionCategoriesLocal = $this.LoadFromSession()
                    if ($sessionCategoriesLocal.Count -gt 0) {
                        $conflicts = $this.MergeCategoriesWithConflictDetection([ref]$mergedCategories, $sessionCategoriesLocal, "Session")
                        $conflictLog += $conflicts
                        $loadedSets += "Session"
                    }
                }
                "4" {
                    $this.ShowConflictReport($conflictLog)
                }
                "5" {
                    if ($mergedCategories.Count -gt 0) {
                        $libraryName = Read-Host "Name für die Bibliothek"
                        $description = "Bibliothek aus $($loadedSets.Count) Sets: $($loadedSets -join ', ')"
                        $this.SaveCategories($mergedCategories, "Library_$libraryName", $description)
                    } else {
                        Write-Host "$($script:Icons.Error) Keine Kategorien zum Speichern vorhanden" -ForegroundColor Red
                        Read-Host "Enter zum Fortfahren"
                    }
                }
                "f" {
                    if ($mergedCategories.Count -gt 0) {
                        Write-Host ""
                        Write-Host "$($script:Icons.Check) Bibliothek erstellt: $($mergedCategories.Count) Kategorien" -ForegroundColor Green
                        Write-Host "$($script:Icons.Info) Zusammengesetzt aus: $($loadedSets -join ', ')" -ForegroundColor Cyan
                        if ($conflictLog.Count -gt 0) {
                            Write-Host "$($script:Icons.Warning) $($conflictLog.Count) Konflikte aufgelöst" -ForegroundColor Yellow
                        }
                        Write-Host ""
                        return $mergedCategories
                    } else {
                        Write-Host "$($script:Icons.Error) Keine Kategorien geladen" -ForegroundColor Red
                        Read-Host "Enter zum Fortfahren"
                    }
                }
                "x" {
                    return @{}
                }
                default {
                    Write-Host "$($script:Icons.Error) Ungültige Auswahl" -ForegroundColor Red
                }
            }
        } while ($true)
        
        # Fallback return (wird nie erreicht, aber PowerShell benötigt es)
        return @{}
    }
    
    # Zeige verfügbare Sets
    [void] ShowAvailableSets() {
        Write-Host "$($script:Icons.Package) VERFÜGBARE SETS:" -ForegroundColor Yellow
        
        # Community-Sets
        $communityPath = Join-Path $this.CategoriesPath "community"
        if (Test-Path $communityPath) {
            $communityFiles = Get-ChildItem -Path $communityPath -Filter "*.json"
            if ($communityFiles.Count -gt 0) {
                Write-Host ""
                Write-Host "$($script:Icons.World) Community-Sets ($($communityFiles.Count)):" -ForegroundColor Magenta
                foreach ($file in $communityFiles) {
                    $metadata = $this.GetCategorySetMetadata($file.FullName)
                    Write-Host "   $($file.BaseName) ($($metadata.totalMappings) Kategorien)" -ForegroundColor White
                }
            }
        }
        
        # Gespeicherte Sets
        $savedFiles = Get-ChildItem -Path $this.CategoriesPath -Filter "*.json" | Where-Object { $_.Name -ne "session_categories.json" }
        if ($savedFiles.Count -gt 0) {
            Write-Host ""
            Write-Host "$($script:Icons.Save) Gespeicherte Sets ($($savedFiles.Count)):" -ForegroundColor Cyan
            foreach ($file in $savedFiles) {
                $metadata = $this.GetCategorySetMetadata($file.FullName)
                Write-Host "   $($file.BaseName) ($($metadata.totalMappings) Kategorien)" -ForegroundColor White
            }
        }
        
        # Session
        $sessionFile = Join-Path $this.CategoriesPath "session_categories.json"
        if (Test-Path $sessionFile) {
            $sessionData = Get-Content $sessionFile -Encoding UTF8 | ConvertFrom-Json
            $sessionCount = if ($sessionData.PSObject.Properties.Name -contains "categoryMappings") { 
                @($sessionData.categoryMappings.PSObject.Properties).Count 
            } else { 0 }
            Write-Host ""
            Write-Host "$($script:Icons.Session) Session ($sessionCount Kategorien)" -ForegroundColor Yellow
        }
    }
    
    # Datei-Auswahl für gespeicherte Sets
    [string] SelectSavedCategoryFile() {
        $savedFiles = Get-ChildItem -Path $this.CategoriesPath -Filter "*.json" | Where-Object { $_.Name -ne "session_categories.json" }
        
        if ($savedFiles.Count -eq 0) {
            Write-Host "$($script:Icons.Error) Keine gespeicherten Kategorien-Sets gefunden" -ForegroundColor Red
            Read-Host "Enter zum Fortfahren"
            return ""
        }
        
        Write-Host ""
        Write-Host "$($script:Icons.Save) GESPEICHERTE SETS:" -ForegroundColor Cyan
        for ($i = 0; $i -lt $savedFiles.Count; $i++) {
            $file = $savedFiles[$i]
            $metadata = $this.GetCategorySetMetadata($file.FullName)
            Write-Host "  [$($i+1)] $($file.BaseName) - $($metadata.totalMappings) Kategorien" -ForegroundColor White
            Write-Host "      $($metadata.description)" -ForegroundColor Gray
        }
        Write-Host ""
        
        $choice = Read-Host "Set auswählen (1-$($savedFiles.Count), Enter=Abbrechen)"
        if ($choice -match '^\d+$' -and [int]$choice -ge 1 -and [int]$choice -le $savedFiles.Count) {
            return $savedFiles[[int]$choice - 1].FullName
        }
        
        return ""
    }
    
    # Merge mit Konflikt-Erkennung
    [array] MergeCategoriesWithConflictDetection([ref]$targetCategories, [hashtable]$sourceCategories, [string]$sourceName) {
        $conflicts = @()
        $newCount = 0
        $overwriteCount = 0
        
        foreach ($payee in $sourceCategories.Keys) {
            if ($targetCategories.Value.ContainsKey($payee)) {
                $existingCategory = $targetCategories.Value[$payee]
                $newCategory = $sourceCategories[$payee]
                
                if ($existingCategory -ne $newCategory) {
                    # Konflikt erkannt
                    $conflict = @{
                        payee = $payee
                        existing = $existingCategory
                        new = $newCategory
                        source = $sourceName
                        timestamp = Get-Date -Format "HH:mm:ss"
                    }
                    $conflicts += $conflict
                    
                    # Nutzer-Entscheidung bei Konflikt
                    Write-Host ""
                    Write-Host "$($script:Icons.Warning) $($global:i18n.Get('categorymanager.conflict_detected'))" -ForegroundColor Yellow
                    Write-Host $global:i18n.Get('categorymanager.payee_label', $payee) -ForegroundColor White
                    Write-Host $global:i18n.Get('categorymanager.existing_category', $existingCategory) -ForegroundColor Green
                    Write-Host $global:i18n.Get('categorymanager.new_category', $sourceName, $newCategory) -ForegroundColor Cyan
                    Write-Host ""
                    Write-Host $global:i18n.Get('categorymanager.conflict_choices') -ForegroundColor Yellow
                    
                    $conflictChoice = Read-Host "Entscheidung"
                    switch ($conflictChoice) {
                        "2" {
                            $targetCategories.Value[$payee] = $newCategory
                            $overwriteCount++
                            Write-Host "$($script:Icons.Check) $($global:i18n.Get('categorymanager.overwritten_with', $newCategory))" -ForegroundColor Cyan
                        }
                        "3" {
                            Write-Host "$($script:Icons.Skip) $($global:i18n.Get('categorymanager.skipped'))" -ForegroundColor Gray
                        }
                        default {
                            Write-Host "$($script:Icons.Check) $($global:i18n.Get('categorymanager.kept_existing', $existingCategory))" -ForegroundColor Green
                        }
                    }
                }
            } else {
                # Neue Kategorie hinzufügen
                $targetCategories.Value[$payee] = $sourceCategories[$payee]
                $newCount++
            }
        }
        
        Write-Host ""
        Write-Host "$($script:Icons.Info) $($global:i18n.Get('categorymanager.merge_completed'))" -ForegroundColor Green
        Write-Host "  $($script:Icons.Check) $($global:i18n.Get('categorymanager.new_categories', $newCount))" -ForegroundColor Green
        Write-Host "  $($script:Icons.Info) $($global:i18n.Get('categorymanager.overwritten_count', $overwriteCount))" -ForegroundColor Cyan
        Write-Host "  $($script:Icons.Warning) $($global:i18n.Get('categorymanager.conflicts_count', $conflicts.Count))" -ForegroundColor Yellow
        Write-Host "  $($global:i18n.Get('categorymanager.total_categories', $targetCategories.Value.Count))" -ForegroundColor White
        Write-Host ""
        
        return $conflicts
    }
    
    # Konflikt-Report anzeigen
    [void] ShowConflictReport([array]$conflicts) {
        if ($conflicts.Count -eq 0) {
            Write-Host "$($script:Icons.Check) Keine Konflikte aufgetreten" -ForegroundColor Green
            Read-Host "Enter zum Fortfahren"
            return
        }
        
        # Clear-Host disabled until all errors resolved
        Write-Host "$($script:Icons.Warning) KONFLIKT-REPORT" -ForegroundColor Yellow
        Write-Host "" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "Insgesamt $($conflicts.Count) Konflikte aufgetreten:" -ForegroundColor White
        Write-Host ""
        
        foreach ($conflict in $conflicts) {
            Write-Host "[$($conflict.timestamp)] " -NoNewline -ForegroundColor Gray
            Write-Host "$($conflict.payee)" -ForegroundColor White
            Write-Host "  Bestehend: " -NoNewline -ForegroundColor Gray
            Write-Host "$($conflict.existing)" -ForegroundColor Green
            Write-Host "  Quelle: " -NoNewline -ForegroundColor Gray
            Write-Host "$($conflict.new) " -NoNewline -ForegroundColor Cyan
            Write-Host "($($conflict.source))" -ForegroundColor Gray
            Write-Host ""
        }
        
        Read-Host "Enter zum Fortfahren"
    }
    
    # Kategorien-Review & Korrektur
    [hashtable] ReviewAndCorrectCategories([hashtable]$existingCategories) {
        Write-Host "$($script:Icons.Search) KATEGORIEN-REVIEW MODUS" -ForegroundColor Yellow
        Write-Host "" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "Vorhandene Kategorien: $($existingCategories.Count)" -ForegroundColor Cyan
        Write-Host ""
        
        $correctedCategories = $existingCategories.Clone()
        $changesMade = $false
        
        foreach ($payee in $existingCategories.Keys | Sort-Object) {
            $currentCategory = $existingCategories[$payee]
            
            Write-Host "Payee: " -NoNewline -ForegroundColor Gray
            Write-Host "$payee" -ForegroundColor White
            Write-Host "Aktuelle Kategorie: " -NoNewline -ForegroundColor Gray
            Write-Host "$currentCategory" -ForegroundColor Green
            Write-Host ""
            
            Write-Host "[Enter] Beibehalten  [n] Neue Kategorie  [d] Löschen  [s] Überspringen alle" -ForegroundColor Yellow
            $choice = Read-Host "Aktion"
            
            switch ($choice) {
                "n" {
                    $newCategory = Read-Host "Neue Kategorie eingeben"
                    if ($newCategory) {
                        $correctedCategories[$payee] = $newCategory
                        $changesMade = $true
                        Write-Host "$($script:Icons.Check) Geändert zu: $newCategory" -ForegroundColor Green
                    }
                }
                "d" {
                    $correctedCategories.Remove($payee)
                    $changesMade = $true
                    Write-Host "$($script:Icons.Error) Entfernt" -ForegroundColor Red
                }
                "s" {
                    Write-Host "$($script:Icons.Skip) Alle weiteren beibehalten" -ForegroundColor Cyan
                    break
                }
                default {
                    Write-Host "$($script:Icons.Check) Beibehalten" -ForegroundColor Gray
                }
            }
            Write-Host ""
        }
        
        if ($changesMade) {
            Write-Host "$($script:Icons.Edit) Änderungen vorgenommen: " -NoNewline -ForegroundColor Yellow
            Write-Host "$($correctedCategories.Count) finale Kategorien" -ForegroundColor Green
            $this.SaveSession($correctedCategories, @{ reviewCompleted = $true })
        }
        
        return $correctedCategories
    }
    
    # Hilfsfunktionen
    [hashtable] LoadGranularRules() {
        if (Test-Path $this.ConfigPath) {
            $config = Get-Content $this.ConfigPath -Encoding UTF8 | ConvertFrom-Json
            if ($config.PSObject.Properties.Name -contains "granularRules") {
                return $config.granularRules
            }
        }
        return @{}
    }
    
    [hashtable] GetCategorySetMetadata([string]$filePath) {
        if (Test-Path $filePath) {
            $data = Get-Content $filePath -Encoding UTF8 | ConvertFrom-Json
            if ($data.PSObject.Properties.Name -contains "metadata") {
                return @{
                    name = $data.metadata.name
                    description = $data.metadata.description
                    author = if ($data.metadata.PSObject.Properties.Name -contains "author") { $data.metadata.author } else { "Unknown" }
                    created = $data.metadata.created
                    totalMappings = $data.metadata.totalMappings
                }
            }
        }
        return @{
            name = (Split-Path $filePath -LeafBase)
            description = "Kategorien-Set"
            author = "Unknown"
            created = "Unknown"
            totalMappings = 0
        }
    }
    
    # Session-Status prüfen
    [bool] HasActiveSession() {
        $sessionFile = Join-Path $this.CategoriesPath "session_categories.json"
        return (Test-Path $sessionFile)
    }
    
    # Session löschen
    [void] ClearSession() {
        $sessionFile = Join-Path $this.CategoriesPath "session_categories.json"
        if (Test-Path $sessionFile) {
            Remove-Item $sessionFile -Force
            Write-Host "$($script:Icons.Delete) Session-Daten gelöscht" -ForegroundColor Yellow
        }
        $this.SessionCategories = @{}
        $this.HasUnsavedChanges = $false
    }
}  # Ende der CategoryManager Klasse

# Standalone-Funktionen für einfache Nutzung
function New-CategoryManager {
    param([string]$ConfigPath = "config.local.json")
    
    $fullPath = if ([System.IO.Path]::IsPathRooted($ConfigPath)) { 
        $ConfigPath 
    } else { 
        Join-Path $PSScriptRoot "../$ConfigPath" 
    }
    
    return [CategoryManager]::new($fullPath)
}

function Show-CategoryManagerMenu {
    param([CategoryManager]$Manager)
    
    do {
        # Clear-Host disabled until all errors resolved
        Write-Host "$($script:Icons.Library) KATEGORIEN-MANAGER" -ForegroundColor Cyan
        Write-Host "" -ForegroundColor Cyan
        Write-Host ""
        
        if ($Manager.HasActiveSession()) {
            Write-Host "$($script:Icons.Session) Aktive Session erkannt!" -ForegroundColor Yellow
            Write-Host ""
        }
        
        Write-Host "[1] Session-Kategorien laden" -ForegroundColor Green
        Write-Host "[2] Gespeicherte Kategorien laden" -ForegroundColor Cyan
        Write-Host "[3] Community-Kategorien laden" -ForegroundColor Magenta
        Write-Host "[4] $($script:Icons.Library) Bibliothek erstellen (Multi-Set)" -ForegroundColor Blue
        Write-Host "[5] Kategorien überprüfen `& korrigieren" -ForegroundColor Yellow
        Write-Host "[6] Kategorien exportieren" -ForegroundColor Blue
        Write-Host "[7] Community-Export erstellen" -ForegroundColor Magenta
        Write-Host "[8] Session löschen" -ForegroundColor Red
        Write-Host "[x] Zurück zum Hauptmenü" -ForegroundColor Gray
        Write-Host ""
        
        $choice = Read-Host "Option wählen"
        
        switch ($choice) {
            "1" {
                $categories = $Manager.LoadFromSession()
                if ($categories.Count -gt 0) {
                    Write-Host "$($script:Icons.Check) $($categories.Count) Session-Kategorien geladen" -ForegroundColor Green
                    return $categories
                } else {
                    Write-Host "$($script:Icons.Error) Keine Session-Kategorien gefunden" -ForegroundColor Red
                }
                Read-Host "Enter zum Fortfahren"
            }
            "2" {
                $categories = $Manager.LoadFromFile()
                if ($categories.Count -gt 0) {
                    Write-Host "$($script:Icons.Check) $($categories.Count) gespeicherte Kategorien geladen" -ForegroundColor Green
                    return $categories
                } else {
                    Write-Host "$($script:Icons.Error) Keine gespeicherten Kategorien gefunden" -ForegroundColor Red
                }
                Read-Host "Enter zum Fortfahren"
            }
            "3" {
                $categories = $Manager.LoadFromCommunity()
                if ($categories.Count -gt 0) {
                    Write-Host "$($script:Icons.Check) $($categories.Count) Community-Kategorien geladen" -ForegroundColor Green
                    return $categories
                }
                Read-Host "Enter zum Fortfahren"
            }
            "4" {
                $library = $Manager.LoadMultipleSets()
                if ($library.Count -gt 0) {
                    Write-Host "$($script:Icons.Check) Bibliothek mit $($library.Count) Kategorien erstellt" -ForegroundColor Green
                    return $library
                }
                Read-Host "Enter zum Fortfahren"
            }
            "5" {
                $existingCategories = $Manager.LoadWithPriority()
                if ($existingCategories.Count -gt 0) {
                    $corrected = $Manager.ReviewAndCorrectCategories($existingCategories)
                    return $corrected
                } else {
                    Write-Host "$($script:Icons.Error) Keine Kategorien zum Überprüfen gefunden" -ForegroundColor Red
                    Read-Host "Enter zum Fortfahren"
                }
            }
            "6" {
                $categories = $Manager.LoadWithPriority()
                if ($categories.Count -gt 0) {
                    $name = Read-Host "Name für das Kategorien-Set"
                    $description = Read-Host "Beschreibung (optional)"
                    $Manager.SaveCategories($categories, $name, $description)
                } else {
                    Write-Host "$($script:Icons.Error) Keine Kategorien zum Exportieren gefunden" -ForegroundColor Red
                }
                Read-Host "Enter zum Fortfahren"
            }
            "7" {
                $categories = $Manager.LoadWithPriority()
                if ($categories.Count -gt 0) {
                    $name = Read-Host "Community-Set Name"
                    $description = Read-Host "Beschreibung für die Community"
                    $author = Read-Host "Ihr Name/Handle (optional)"
                    $Manager.ExportForCommunity($categories, $name, $description, $author)
                } else {
                    Write-Host "$($script:Icons.Error) Keine Kategorien zum Community-Export gefunden" -ForegroundColor Red
                }
                Read-Host "Enter zum Fortfahren"
            }
            "8" {
                $confirm = Read-Host "Session wirklich löschen? (j/n)"
                if ($confirm -eq "j" -or $confirm -eq "y") {
                    $Manager.ClearSession()
                }
            }
            "x" {
                return @{}
            }
        }
    } while ($true)
}

Write-Host "$($script:Icons.Check) CategoryManager-Modul geladen" -ForegroundColor Green
