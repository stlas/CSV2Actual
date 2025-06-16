# FILE: ./Localization/de/strings.psd1

# CSV2Actual German Localization (Deutsche Lokalisierung)
# Generated: 2025-06-16
# 
# Diese Datei enthält alle benutzersichtbaren Texte für CSV2Actual
# Bearbeiten Sie diese Datei, um Übersetzungen für die deutsche Sprache bereitzustellen
#
# Format: Schlüssel-Wert-Paare mit PowerShell Hashtable-Syntax
# Verwenden Sie {0}, {1}, etc. für String-Formatierungs-Platzhalter

@{
    UI = @{
        Title = "CSV2Actual - CSV-Import-Tool"
        Subtitle = "Revolutionäres Beispiel für Mensch-KI-Kollaborative Programmierung"
        Buttons = @{
            Process = "Verarbeiten"
            Cancel = "Abbrechen"
            Browse = "Durchsuchen..."
            Save = "Speichern"
            Load = "Laden"
            Exit = "Beenden"
            Settings = "Einstellungen"
            Help = "Hilfe"
            About = "Über"
        }
        Menus = @{
            File = "Datei"
            Edit = "Bearbeiten"
            View = "Ansicht"
            Tools = "Extras"
            Language = "Sprache"
            Help = "Hilfe"
        }
        Labels = @{
            InputFile = "Eingabedatei:"
            OutputFormat = "Ausgabeformat:"
            Configuration = "Konfiguration:"
            Status = "Status:"
            Progress = "Fortschritt:"
        }
    }
    Messages = @{
        Welcome = "Willkommen bei CSV2Actual - Revolutionäres KI-Kollaborations-Tool"
        ProcessingFile = "Verarbeite Datei: {0}"
        ProcessingComplete = "Verarbeitung erfolgreich abgeschlossen"
        ProcessingFailed = "Verarbeitung fehlgeschlagen: {0}"
        FileNotFound = "Datei nicht gefunden: {0}"
        InvalidFormat = "Ungültiges Dateiformat: {0}"
        BackupCreated = "Backup erstellt: {0}"
        ConfigLoaded = "Konfiguration geladen von: {0}"
        ConfigSaved = "Konfiguration gespeichert in: {0}"
        LanguageChanged = "Sprache geändert zu: {0}"
        CostOptimization = "Kostenoptimierung aktiv - effiziente KI-Patterns werden verwendet"
        ReleaseCreated = "Release v{0} erfolgreich erstellt"
        BackupRestored = "Backup wiederhergestellt von: {0}"
    }
    Errors = @{
        FileAccess = "Kann nicht auf Datei zugreifen: {0}"
        InvalidConfiguration = "Ungültige Konfiguration: {0}"
        ProcessingError = "Fehler während der Verarbeitung: {0}"
        UnexpectedError = "Ein unerwarteter Fehler ist aufgetreten: {0}"
        ModuleNotFound = "Modul nicht gefunden: {0}"
        LanguageNotSupported = "Sprache nicht unterstützt: {0}"
        CostBudgetExceeded = "KI-Kostenbudget überschritten: ${0}"
        ReleaseCreationFailed = "Release-Erstellung fehlgeschlagen: {0}"
    }
    Categories = @{
        Income = "Einkommen"
        Expenses = "Ausgaben"
        Transfer = "Überweisung"
        Investment = "Investition"
        Savings = "Ersparnisse"
        Unknown = "Unbekannt"
        Groceries = "Lebensmittel"
        Transport = "Transport"
        Entertainment = "Unterhaltung"
        Healthcare = "Gesundheitswesen"
        Utilities = "Versorgungsunternehmen"
        Shopping = "Einkaufen"
        Education = "Bildung"
        Travel = "Reisen"
    }
    Progress = @{
        Initializing = "Initialisiere..."
        LoadingFile = "Lade Datei..."
        ProcessingData = "Verarbeite Daten..."
        ApplyingRules = "Wende Kategorisierungsregeln an..."
        DetectingIncome = "Erkenne Einkommenstransaktionen..."
        GeneratingOutput = "Generiere Ausgabe..."
        CreatingBackup = "Erstelle Backup..."
        Finalizing = "Finalisiere..."
        Complete = "Abgeschlossen!"
    }
    Validation = @{
        RequiredField = "Dieses Feld ist erforderlich"
        InvalidEmail = "Bitte geben Sie eine gültige E-Mail-Adresse ein"
        InvalidDate = "Bitte geben Sie ein gültiges Datum ein"
        InvalidAmount = "Bitte geben Sie einen gültigen Betrag ein"
        FileTooBig = "Dateigröße überschreitet das maximale Limit"
        UnsupportedFormat = "Nicht unterstütztes Dateiformat"
    }
    Help = @{
        Usage = "Verwendung: CSV2Actual.ps1 -InputFile <Pfad> [-OutputFormat <Format>] [-ConfigFile <Pfad>]"
        Examples = "Beispiele:"
        BasicUsage = "Grundlegende Verwendung: .\CSV2Actual.ps1 -InputFile ""transaktionen.csv"""
        WithConfig = "Mit Konfiguration: .\CSV2Actual.ps1 -InputFile ""daten.csv"" -ConfigFile ""config.json"""
        ExportFormat = "Format angeben: .\CSV2Actual.ps1 -InputFile ""daten.csv"" -OutputFormat ""Excel"""
        AICollaboration = "Dieses Tool demonstriert revolutionäre Mensch-KI-kollaborative Programmierung"
        CostOptimization = "Bietet intelligente KI-Kostenoptimierung (75% Reduzierung erreicht)"
        Templates = "Verwendet template-gesteuerte Entwicklung für maximale Code-Wiederverwendung"
        Multilingual = "Unterstützt mehrere Sprachen durch externe Sprachdateien"
    }
    Status = @{
        Ready = "Bereit"
        Processing = "Verarbeitung"
        Completed = "Abgeschlossen"
        Failed = "Fehlgeschlagen"
        Cancelled = "Abgebrochen"
        Paused = "Pausiert"
        Warning = "Warnung"
        Error = "Fehler"
    }
}