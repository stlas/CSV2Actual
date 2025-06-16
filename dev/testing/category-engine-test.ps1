# Test-Script für das neue CategoryEngine-Modul mit I18n-Support
# Kann separat ausgeführt werden für schnelle Entwicklung und Tests

. "$PSScriptRoot/modules/CategoryEngine.ps1"

Write-Host "=== CATEGORY ENGINE I18N TEST ===" -ForegroundColor Cyan
Write-Host ""

# Test 1: Deutsche Engine
Write-Host "=== TEST 1: DEUTSCHE SPRACHE ===" -ForegroundColor Green
$engine_de = [CategoryEngine]::new("$PSScriptRoot/categories.json", "de")
$engine_de.ShowRuleStats()
Write-Host ""

# Test 2: Englische Engine
Write-Host "=== TEST 2: ENGLISCHE SPRACHE ===" -ForegroundColor Green
$engine_en = [CategoryEngine]::new("$PSScriptRoot/categories.json", "en")
$engine_en.ShowRuleStats()
Write-Host ""

# Test 3: ALDI Test mit deutscher Engine
Write-Host "=== TEST 3: ALDI Keyword-Matching (DE) ===" -ForegroundColor Yellow
$engine_de.TestTransaction("ALDI SUED SAGT DANKE 023022", "ALDI SE U. CO. KG/BAUSCHLOTTER STR. 37/PFORZHEIM/DE")
Write-Host ""

# Test 4: Kategorien-Vergleich
Write-Host "=== TEST 4: KATEGORIEN-VERGLEICH ===" -ForegroundColor Yellow

Write-Host "`nDEUTSCHE KATEGORIEN:" -ForegroundColor Cyan
$categories_de = $engine_de.GetAllCategories()
foreach ($group in $categories_de.Keys) {
    Write-Host "  $group`:" -ForegroundColor Magenta
    foreach ($category in $categories_de[$group]) {
        Write-Host "    - $category" -ForegroundColor White
    }
}

Write-Host "`nENGLISCHE KATEGORIEN:" -ForegroundColor Cyan
$categories_en = $engine_en.GetAllCategories()
foreach ($group in $categories_en.Keys) {
    Write-Host "  $group`:" -ForegroundColor Magenta
    foreach ($category in $categories_en[$group]) {
        Write-Host "    - $category" -ForegroundColor White
    }
}

Write-Host ""

# Test 5: Sprachstring-Vergleich
Write-Host "=== TEST 5: SPRACHSTRING-VERGLEICH ===" -ForegroundColor Yellow
Write-Host "Deutsch: $($engine_de.langStrings.Count) Sprachstrings geladen" -ForegroundColor White
Write-Host "English: $($engine_en.langStrings.Count) Sprachstrings geladen" -ForegroundColor White

Write-Host ""
Write-Host "=== I18N TEST ABGESCHLOSSEN ===" -ForegroundColor Green
Write-Host ""
Write-Host "Verwendung im Hauptskript:"
Write-Host '  $engine = [CategoryEngine]::new("categories.json", "de")'
Write-Host '  $category = $engine.CategorizeTransaction(@{payee="ALDI"; memo="..."})'
Write-Host ""