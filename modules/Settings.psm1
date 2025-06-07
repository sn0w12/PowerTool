# PowerTool Settings Module
# Provides centralized settings management for core and extension settings

$script:settingsPath = Join-Path $env:APPDATA "PowerTool\settings.json"
$script:settingsDir = Split-Path $script:settingsPath -Parent

# Default core settings
$script:defaultCoreSettings = @{
    "core.theme" = "default"
    "core.auto-update" = $true
    "core.verbose" = $false
    "core.confirm-destructive" = $true
    "core.max-history" = 100
}

# Registry for extension settings schemas
$script:extensionSettingsSchemas = @{}

function Initialize-SettingsDirectory {
    if (-not (Test-Path $script:settingsDir)) {
        New-Item -Path $script:settingsDir -ItemType Directory -Force | Out-Null
    }
}

function Get-SettingsData {
    Initialize-SettingsDirectory

    if (Test-Path $script:settingsPath) {
        try {
            $content = Get-Content $script:settingsPath -Raw -ErrorAction Stop
            $jsonObject = $content | ConvertFrom-Json -ErrorAction Stop

            # Convert PSCustomObject to hashtable for compatibility
            $hashtable = @{}
            $jsonObject.PSObject.Properties | ForEach-Object {
                $hashtable[$_.Name] = $_.Value
            }

            return $hashtable
        } catch {
            Write-Warning "Failed to read settings file: $($_.Exception.Message). Using defaults."
        }
    }

    return @{}
}

function Save-SettingsData {
    param([hashtable]$Settings)

    Initialize-SettingsDirectory

    try {
        $Settings | ConvertTo-Json -Depth 10 | Set-Content $script:settingsPath -ErrorAction Stop
        return $true
    } catch {
        Write-Error "Failed to save settings: $($_.Exception.Message)"
        return $false
    }
}

function Register-ExtensionSettings {
    param(
        [string]$ExtensionName,
        [hashtable]$SettingsSchema
    )

    $script:extensionSettingsSchemas[$ExtensionName] = $SettingsSchema
}

function Get-AllSettings {
    $settings = Get-SettingsData
    $allSettings = @{}

    # Add core settings with defaults
    foreach ($key in $script:defaultCoreSettings.Keys) {
        $allSettings[$key] = if ($settings.ContainsKey($key)) { $settings[$key] } else { $script:defaultCoreSettings[$key] }
    }

    # Add extension settings
    foreach ($extensionName in $script:extensionSettingsSchemas.Keys) {
        $schema = $script:extensionSettingsSchemas[$extensionName]
        foreach ($settingKey in $schema.Keys) {
            $fullKey = "$extensionName.$settingKey"
            $allSettings[$fullKey] = if ($settings.ContainsKey($fullKey)) { $settings[$fullKey] } else { $schema[$settingKey].Default }
        }
    }

    return $allSettings
}

function Get-Setting {
    param([string]$Key)

    if (-not $Key) {
        Write-Host "Setting key is required." -ForegroundColor Red
        return $null
    }

    $allSettings = Get-AllSettings

    if ($allSettings.ContainsKey($Key)) {
        return $allSettings[$Key]
    } else {
        Write-Host "Setting '$Key' not found." -ForegroundColor Red
        return $null
    }
}

function Set-Setting {
    param(
        [string]$Key,
        [object]$Value
    )

    if (-not $Key) {
        Write-Host "Setting key is required." -ForegroundColor Red
        return
    }

    # Validate setting exists
    $allSettings = Get-AllSettings
    if (-not $allSettings.ContainsKey($Key)) {
        Write-Host "Setting '$Key' not found. Use 'powertool settings' to see available settings." -ForegroundColor Red
        return
    }

    # Load current settings
    $settings = Get-SettingsData

    # Type validation and conversion
    if ($Key.StartsWith("core.")) {
        # Core settings validation
        $expectedType = $script:defaultCoreSettings[$Key].GetType()
        if ($Value.GetType() -ne $expectedType) {
            # Try to convert common types
            try {
                switch ($expectedType.Name) {
                    "Boolean" {
                        $valueStr = $Value.ToString().ToLower()
                        if ($valueStr -in @("true", "1", "yes", "on", "enabled")) {
                            $Value = $true
                        } elseif ($valueStr -in @("false", "0", "no", "off", "disabled")) {
                            $Value = $false
                        } else {
                            throw "Invalid boolean value. Use: true/false, 1/0, yes/no, on/off, enabled/disabled"
                        }
                    }
                    "Int32" {
                        $Value = [int]::Parse($Value.ToString())
                    }
                    "String" {
                        $Value = $Value.ToString()
                    }
                }
            } catch {
                Write-Host "Invalid value for '$Key'. $($_.Exception.Message)" -ForegroundColor Red
                return
            }
        }
    } else {
        # Extension settings validation
        $extensionName = $Key.Split('.')[0]
        $settingKey = $Key.Split('.', 2)[1]

        if ($script:extensionSettingsSchemas.ContainsKey($extensionName)) {
            $schema = $script:extensionSettingsSchemas[$extensionName]
            if ($schema.ContainsKey($settingKey)) {
                $settingSchema = $schema[$settingKey]

                # Type conversion for extension settings
                if ($settingSchema.ContainsKey('Type')) {
                    $expectedType = $settingSchema.Type
                    try {
                        switch ($expectedType) {
                            "Boolean" {
                                $valueStr = $Value.ToString().ToLower()
                                if ($valueStr -in @("true", "1", "yes", "on", "enabled")) {
                                    $Value = $true
                                } elseif ($valueStr -in @("false", "0", "no", "off", "disabled")) {
                                    $Value = $false
                                } else {
                                    throw "Invalid boolean value. Use: true/false, 1/0, yes/no, on/off, enabled/disabled"
                                }
                            }
                            "Int32" {
                                $Value = [int]::Parse($Value.ToString())
                            }
                            "String" {
                                $Value = $Value.ToString()
                            }
                        }
                    } catch {
                        Write-Host "Invalid value for '$Key'. $($_.Exception.Message)" -ForegroundColor Red
                        return
                    }
                }

                # Validate against ValidValues if specified
                if ($settingSchema.ContainsKey('ValidValues') -and $settingSchema.ValidValues) {
                    $validValues = $settingSchema.ValidValues
                    if ($Value -notin $validValues) {
                        Write-Host "Invalid value '$Value' for setting '$Key'. Valid values are: $($validValues -join ', ')" -ForegroundColor Red
                        return
                    }
                }
            }
        }
    }

    # Set the value
    $settings[$Key] = $Value

    if (Save-SettingsData -Settings $settings) {
        Write-Host "Setting '$Key' updated to: " -NoNewline -ForegroundColor Green
        Write-Host $Value -ForegroundColor Cyan
    } else {
        Write-Host "Failed to save setting '$Key'." -ForegroundColor Red
    }
}

function Show-Settings {
    param([string]$Filter)

    $allSettings = Get-AllSettings
    $filteredSettings = if ($Filter) {
        $allSettings.GetEnumerator() | Where-Object { $_.Key -like "*$Filter*" }
    } else {
        $allSettings.GetEnumerator()
    }

    if ($filteredSettings.Count -eq 0) {
        if ($Filter) {
            Write-Host "No settings found matching filter: '$Filter'" -ForegroundColor Yellow
        } else {
            Write-Host "No settings available." -ForegroundColor Yellow
        }
        return
    }

    Write-Host "PowerTool Settings:" -ForegroundColor Blue
    Write-Host ""

    # Group by prefix (core, extension names)
    $groups = @{}
    foreach ($setting in $filteredSettings) {
        $prefix = if ($setting.Key.Contains('.')) {
            $setting.Key.Split('.')[0]
        } else {
            "other"
        }

        if (-not $groups.ContainsKey($prefix)) {
            $groups[$prefix] = @()
        }
        $groups[$prefix] += $setting
    }

    # Display core settings first
    $sortedGroups = @("core") + ($groups.Keys | Where-Object { $_ -ne "core" } | Sort-Object)

    foreach ($groupName in $sortedGroups) {
        if (-not $groups.ContainsKey($groupName)) { continue }

        $displayName = if ($groupName -eq "core") { "Core Settings" } else { "$groupName Extension" }
        Write-Host "  ${displayName}:" -ForegroundColor Magenta

        $sortedSettings = $groups[$groupName] | Sort-Object { $_.Key }
        foreach ($setting in $sortedSettings) {
            $fullKey = $setting.Key

            Write-Host "    " -NoNewline
            Write-Host $fullKey -NoNewline -ForegroundColor Cyan

            $paddingLength = 30 - $fullKey.Length
            if ($paddingLength -gt 0) {
                Write-Host (" " * $paddingLength) -NoNewline
            } else {
                Write-Host " " -NoNewline
            }

            $valueColor = switch ($setting.Value.GetType().Name) {
                "Boolean" { if ($setting.Value) { "Green" } else { "Red" } }
                "Int32" { "Yellow" }
                default { "White" }
            }

            Write-Host $setting.Value -NoNewline -ForegroundColor $valueColor

            # Get type and valid values information
            $typeInfo = ""
            $validValuesInfo = ""

            if ($groupName -eq "core") {
                # For core settings, infer type from default value
                $typeInfo = $script:defaultCoreSettings[$setting.Key].GetType().Name
            } else {
                # For extension settings, get from schema
                if ($script:extensionSettingsSchemas.ContainsKey($groupName)) {
                    $schema = $script:extensionSettingsSchemas[$groupName]
                    $settingKey = $setting.Key.Split('.', 2)[1]
                    if ($schema.ContainsKey($settingKey)) {
                        $settingSchema = $schema[$settingKey]
                        if ($settingSchema.ContainsKey('Type')) {
                            $typeInfo = $settingSchema.Type
                        }
                        if ($settingSchema.ContainsKey('ValidValues') -and $settingSchema.ValidValues) {
                            $validValuesInfo = " [" + ($settingSchema.ValidValues -join ', ') + "]"
                        }
                    }
                }
            }

            # Display type information
            if ($typeInfo) {
                Write-Host " (" -NoNewline -ForegroundColor DarkGray
                Write-Host $typeInfo -NoNewline -ForegroundColor DarkGray
                Write-Host ")" -NoNewline -ForegroundColor DarkGray
            }

            # Display valid values if available
            if ($validValuesInfo) {
                Write-Host $validValuesInfo -NoNewline -ForegroundColor DarkYellow
            }

            Write-Host "" # New line
        }
        Write-Host ""
    }
}

function Reset-Settings {
    param(
        [string]$Key,
        [switch]$All
    )

    if ($All) {
        if (Test-Path $script:settingsPath) {
            Remove-Item $script:settingsPath -Force
            Write-Host "All settings reset to defaults." -ForegroundColor Green
        } else {
            Write-Host "No settings file found. All settings are already at defaults." -ForegroundColor Yellow
        }
        return
    }

    if (-not $Key) {
        Write-Host "Specify a setting key to reset or use -All to reset all settings." -ForegroundColor Red
        return
    }

    $allSettings = Get-AllSettings
    if (-not $allSettings.ContainsKey($Key)) {
        Write-Host "Setting '$Key' not found." -ForegroundColor Red
        return
    }

    $settings = Get-SettingsData
    if ($settings.ContainsKey($Key)) {
        $settings.Remove($Key)
        if (Save-SettingsData -Settings $settings) {
            $defaultValue = $allSettings[$Key]
            Write-Host "Setting '$Key' reset to default: " -NoNewline -ForegroundColor Green
            Write-Host $defaultValue -ForegroundColor Cyan
        }
    } else {
        Write-Host "Setting '$Key' is already at default value." -ForegroundColor Yellow
    }
}

$script:ModuleCommands = @{
    "settings" = @{
        Aliases = @("config", "cfg")
        Action = {
            if (-not $Path) {
                Show-Settings
            } else {
                Show-Settings -Filter $Path
            }
        }
        Summary = "List all settings or filter by keyword."
        Options = @{
            0 = @(
                @{ Token = "filter"; Type = "OptionalArgument"; Description = "Filter settings by keyword." }
            )
        }
        Examples = @(
            "powertool settings",
            "powertool settings theme",
            "pt config core"
        )
    }
    "set" = @{
        Aliases = @("setting-set")
        Action = {
            if (-not $Path) {
                Write-Host "Setting key is required. Use 'powertool settings' to see available settings." -ForegroundColor Red
                return
            }
            if (-not $Value) {
                Write-Host "Setting value is required." -ForegroundColor Red
                return
            }
            Set-Setting -Key $Path -Value $Value
        }
        Summary = "Set a configuration setting value."
        Options = @{
            0 = @(
                @{ Token = "key"; Type = "Argument"; Description = "The setting key to modify." }
                @{ Token = "value"; Type = "Argument"; Description = "The new value for the setting." }
            )
        }
        Examples = @(
            "powertool set core.theme dark",
            "powertool set core.verbose true",
            "pt set core.max-history 50"
        )
    }
    "get" = @{
        Aliases = @("setting-get")
        Action = {
            if (-not $Path) {
                Write-Host "Setting key is required. Use 'powertool settings' to see available settings." -ForegroundColor Red
                return
            }
            $value = Get-Setting -Key $Path
            if ($null -ne $value) {
                Write-Host "$Path = " -NoNewline -ForegroundColor Cyan
                Write-Host $value -ForegroundColor White
            }
        }
        Summary = "Get the current value of a setting."
        Options = @{
            0 = @(
                @{ Token = "key"; Type = "Argument"; Description = "The setting key to retrieve." }
            )
        }
        Examples = @(
            "powertool get core.theme",
            "powertool get core.verbose",
            "pt get core.max-history"
        )
    }
    "reset" = @{
        Aliases = @("setting-reset")
        Action = {
            if ($Path -eq "all") {
                Reset-Settings -All
            } elseif ($Path) {
                Reset-Settings -Key $Path
            } else {
                Write-Host "Specify a setting key to reset or 'all' to reset all settings." -ForegroundColor Red
            }
        }
        Summary = "Reset a setting to its default value or reset all settings."
        Options = @{
            0 = @(
                @{ Token = "key-or-all"; Type = "Argument"; Description = "The setting key to reset, or 'all' to reset everything." }
            )
        }
        Examples = @(
            "powertool reset core.theme",
            "powertool reset all",
            "pt reset core.max-history"
        )
    }
}

Export-ModuleMember -Function Get-Setting, Set-Setting, Show-Settings, Reset-Settings, Register-ExtensionSettings, Get-AllSettings -Variable ModuleCommands
