<#
.SYNOPSIS
    PowerTool Help System Module - Help, documentation, and command discovery

.TYPE
    Command Module

.DESCRIPTION
    This is a COMMAND MODULE that provides PowerTool commands for help and documentation.
    It also exports utility functions for displaying formatted help content.

    Purpose:
    - Provide comprehensive help and documentation commands
    - Enable command discovery and search functionality
    - Display version and system information
    - Validate command definitions and module structure
    - Format and display command help content

    This module is essential for user experience and should provide clear,
    well-formatted help content that makes PowerTool easy to discover and use.
#>

function Write-ColoredOptions {
    param([object]$OptionsData)

    if (-not $OptionsData -or ($OptionsData -is [hashtable] -and $OptionsData.Count -eq 0)) {
        Write-Host "None" -ForegroundColor DarkGray
        return
    }

    $syntaxLines = @()

    if ($OptionsData -is [hashtable]) {
        # New numeric group format - sort by keys (0, 1, 2, etc.)
        $sortedKeys = $OptionsData.Keys | Sort-Object { [int]$_ }
        foreach ($key in $sortedKeys) {
            $syntaxLines += ,$OptionsData[$key]  # Use comma operator to preserve array structure
        }
    } else {
        # Single syntax line (array of hashtables/tokens)
        $syntaxLines = @($OptionsData)
    }

    for ($groupIndex = 0; $groupIndex -lt $syntaxLines.Count; $groupIndex++) {
        $tokens = $syntaxLines[$groupIndex]
        $isFirstTokenInGroup = $true

        foreach ($tokenInfo in $tokens) {
            if (-not $isFirstTokenInGroup) {
                Write-Host " " -NoNewline # Space between tokens within the same group
            }
            $isFirstTokenInGroup = $false

            $textToPrint = ""
            $color = "White" # Default color

            switch ($tokenInfo.Type) {
                "Argument" {
                    $textToPrint = "[$($tokenInfo.Token)]"
                    $color = "DarkCyan"
                }
                "OptionalArgument" {
                    $textToPrint = "[$($tokenInfo.Token)?]"
                    $color = "DarkCyan"
                }
                "Parameter" {
                    $textToPrint = "-$($tokenInfo.Token)"
                    $color = "Green"
                }
                "OptionalParameter" {
                    $textToPrint = "-$($tokenInfo.Token)?"
                    $color = "Green"
                }
                "Type" {
                    $textToPrint = "<$($tokenInfo.Token)>"
                    $color = "DarkYellow"
                }
                default { # Should not happen with proper definitions
                    $textToPrint = $tokenInfo.Token
                }
            }
            Write-Host $textToPrint -NoNewline -ForegroundColor $color
        }

        # Only add pipe separator between different groups (not after the last group)
        if ($syntaxLines.Count -gt 1 -and $groupIndex -lt $syntaxLines.Count - 1) {
            Write-Host " | " -NoNewline -ForegroundColor DarkGray
        }
    }
    Write-Host "" # Ensure a newline after all options are printed
}

function Write-Header {
    Write-Host "PowerTool" -ForegroundColor Cyan -NoNewline
    Write-Host " - Utility CLI for Windows"
    Write-Host ""
}

function Write-UsageSection {
    Write-Host "Usage:" -ForegroundColor Blue
    Write-Host "  " -NoNewline
    Write-Host "powertool" -NoNewline -ForegroundColor Yellow
    Write-Host " " -NoNewline
    Write-Host "<command>" -NoNewline -ForegroundColor White
    Write-Host " " -NoNewline
    Write-Host "[input]" -NoNewline -ForegroundColor DarkCyan
    Write-Host " " -NoNewline
    Write-Host "[options]" -ForegroundColor Green

    Write-Host "  " -NoNewline
    Write-Host "pt" -NoNewline -ForegroundColor Yellow
    Write-Host " " -NoNewline
    Write-Host "<command>" -NoNewline -ForegroundColor White
    Write-Host " " -NoNewline
    Write-Host "[input]" -NoNewline -ForegroundColor DarkCyan
    Write-Host " " -NoNewline
    Write-Host "[options]" -ForegroundColor Green
}

function Write-ColoredExample {
    param([string]$ExampleText)

    if (-not $ExampleText) { return }

    # Split the example into parts
    $parts = $ExampleText -split ' '

    for ($i = 0; $i -lt $parts.Count; $i++) {
        $part = $parts[$i]

        if ($i -eq 0) {
            # First part is usually "powertool" or "pt"
            Write-Host $part -NoNewline -ForegroundColor Yellow
        } elseif ($i -eq 1) {
            # Second part is the command
            Write-Host $part -NoNewline -ForegroundColor White
        } elseif ($part.StartsWith('-')) {
            # Options/flags
            Write-Host $part -NoNewline -ForegroundColor Green
        } elseif ($part.StartsWith('[') -and $part.EndsWith(']')) {
            # Optional parameters
            Write-Host $part -NoNewline -ForegroundColor DarkCyan
        } elseif ($part.StartsWith('<') -and $part.EndsWith('>')) {
            # Required parameters
            Write-Host $part -NoNewline -ForegroundColor DarkYellow
        } else {
            # Regular arguments/values
            Write-Host $part -NoNewline -ForegroundColor Gray
        }

        # Add space between parts (except for the last one)
        if ($i -lt $parts.Count - 1) {
            Write-Host " " -NoNewline
        }
    }
    Write-Host "" # Newline at the end
}

function Show-Help {
    param(
        [string]$ForCommand,
        [hashtable]$AllCommandData, # Receives $commandDefinitions from powertool.ps1
        [hashtable]$CommandModuleMap = @{}, # Receives $commandModuleMap from powertool.ps1
        [hashtable]$ExtensionCommands = @{}, # Receives $extensionCommands from powertool.ps1
        [hashtable]$Extensions = @{}, # Receives $extensions from powertool.ps1
        [string]$Module, # New parameter to filter by module
        [int]$Page = 1 # Page number for pagination
    )

    if (-not $AllCommandData) {
        Write-Error "Command data not provided to Show-Help."
        return
    }

    $verboseMode = Get-Setting -Key "core.verbose"

    if ($ForCommand) {
        Write-Header
        $commandKey = $ForCommand.ToLower()
        $foundCommandDetails = $null
        $foundCommandName = $null

        foreach ($cmdNameEntry in $AllCommandData.Keys) {
            $commandEntry = $AllCommandData[$cmdNameEntry]
            $currentAliases = @()
            if ($commandEntry -is [hashtable] -and $commandEntry.ContainsKey('Aliases') -and $null -ne $commandEntry.Aliases) {
                $currentAliases = $commandEntry.Aliases
            }

            if ($cmdNameEntry -eq $commandKey -or ($currentAliases -contains $commandKey)) {
                $foundCommandDetails = $commandEntry
                $foundCommandName = $cmdNameEntry
                break
            }
        }

        if ($foundCommandDetails) {
            $shortcutsText = if ($foundCommandDetails.Aliases) { " (" + ($foundCommandDetails.Aliases -join ', ') + ")" } else { "" }
            Write-Host "Command Details:" -ForegroundColor Blue
            Write-Host "  " -NoNewline
            Write-Host $foundCommandName -NoNewline -ForegroundColor Cyan
            Write-Host $shortcutsText -ForegroundColor Yellow
            Write-Host "    $($foundCommandDetails.Summary)" -ForegroundColor White
            Write-Host "    Options: " -NoNewline -ForegroundColor White
            Write-ColoredOptions -OptionsData $foundCommandDetails.Options
            Write-Host ""
            Write-Host "Examples:" -ForegroundColor Blue
            if ($foundCommandDetails.Examples -is [array]) {
                foreach ($example in $foundCommandDetails.Examples) {
                    Write-Host "  " -NoNewline
                    Write-ColoredExample -ExampleText $example
                }
            }

            if ($verboseMode) {
                Write-Host ""
                Write-Host "Settings Info:" -ForegroundColor DarkGray
                Write-Host "  Verbose mode: enabled" -ForegroundColor DarkGray
                Write-Host "  Confirmation prompts: $((Get-Setting -Key 'core.confirm-destructive'))" -ForegroundColor DarkGray
            }
        } else {
            Write-Host "Unknown command: '$ForCommand'. Cannot show specific help." -ForegroundColor Red
            Write-Host "Use 'powertool help' to see all available commands." -ForegroundColor White
        }
    } else {
        Write-Header
        Write-UsageSection
        Write-Host ""
        Write-Host "Commands:" -ForegroundColor Blue

        # Group commands by module and extension
        $moduleGroups = @{}
        $extensionGroups = @{}

        foreach ($commandName in $AllCommandData.Keys) {
            if ($ExtensionCommands.ContainsKey($commandName)) {
                # This is an extension command
                $extensionName = $ExtensionCommands[$commandName]
                if (-not $extensionGroups.ContainsKey($extensionName)) {
                    $extensionGroups[$extensionName] = @()
                }
                $extensionGroups[$extensionName] += $commandName
            } else {
                # This is a core module command
                $moduleName = if ($CommandModuleMap.ContainsKey($commandName)) {
                    $CommandModuleMap[$commandName]
                } else {
                    "Unknown"
                }

                if (-not $moduleGroups.ContainsKey($moduleName)) {
                    $moduleGroups[$moduleName] = @()
                }
                $moduleGroups[$moduleName] += $commandName
            }
        }

        # Filter by module if specified
        if ($Module) {
            $moduleFound = $false

            # Check if it's a core module
            if ($moduleGroups.ContainsKey($Module)) {
                $moduleFound = $true
                $moduleGroups = @{ $Module = $moduleGroups[$Module] }
                $extensionGroups = @{
                }
            }
            # Check if it's an extension
            elseif ($extensionGroups.ContainsKey($Module)) {
                $moduleFound = $true
                $moduleGroups = @{
                }
                $extensionGroups = @{ $Module = $extensionGroups[$Module] }
            }

            if (-not $moduleFound) {
                Write-Host "Module '$Module' not found." -ForegroundColor Red
                Write-Host ""
                Write-Host "Available modules:" -ForegroundColor White
                $allModules = @($moduleGroups.Keys) + @($extensionGroups.Keys) | Sort-Object | Get-Unique
                foreach ($availableModule in $allModules) {
                    Write-Host "  $availableModule" -ForegroundColor Cyan
                }
                return
            }

            Write-Host "Showing commands for module: " -NoNewline -ForegroundColor White
            Write-Host $Module -ForegroundColor Cyan
            Write-Host ""
        }

        # Show with pagination
        Show-PaginatedHelp -ModuleGroups $moduleGroups -ExtensionGroups $extensionGroups -AllCommandData $AllCommandData -Extensions $Extensions -Page $Page
    }
}

function Show-PaginatedHelp {
    param(
        [hashtable]$ModuleGroups,
        [hashtable]$ExtensionGroups,
        [hashtable]$AllCommandData,
        [hashtable]$Extensions,
        [int]$Page = 1
    )

    # Dynamically calculate max lines per page based on terminal height
    $terminalHeight = $Host.UI.RawUI.WindowSize.Height
    # Reserve space for: header (3 lines), usage (3 lines), "Commands:" (2 lines), pagination footer (4 lines)
    # This leaves room for dynamic content while ensuring pagination controls are visible
    $reservedLines = 12
    $maxLinesPerPage = [Math]::Max(($terminalHeight - $reservedLines), 10)  # Minimum of 10 lines for content

    # Calculate module sizes and create page groups
    $moduleOrder = @("Help") + ($ModuleGroups.Keys | Where-Object { $_ -ne "Help" } | Sort-Object)
    $extensionOrder = $ExtensionGroups.Keys | Sort-Object

    $pageGroups = @()
    $currentPageModules = @()
    $currentPageExtensions = @()
    $currentPageLines = 0

    # Process core modules
    foreach ($moduleName in $moduleOrder) {
        if (-not $ModuleGroups.ContainsKey($moduleName)) { continue }

        $moduleSize = Get-ModuleDisplaySize -ModuleName $moduleName -Commands $ModuleGroups[$moduleName] -AllCommandData $AllCommandData -IsExtension $false

        # If adding this module would exceed page limit and we already have content, start new page
        if ($currentPageLines + $moduleSize -gt $maxLinesPerPage -and ($currentPageModules.Count -gt 0 -or $currentPageExtensions.Count -gt 0)) {
            $pageGroups += @{
                Modules = $currentPageModules
                Extensions = $currentPageExtensions
            }
            $currentPageModules = @()
            $currentPageExtensions = @()
            $currentPageLines = 0
        }

        $currentPageModules += $moduleName
        $currentPageLines += $moduleSize
    }

    # Process extensions
    foreach ($extensionName in $extensionOrder) {
        $extensionSize = Get-ModuleDisplaySize -ModuleName $extensionName -Commands $ExtensionGroups[$extensionName] -AllCommandData $AllCommandData -IsExtension $true -Extensions $Extensions

        # If adding this extension would exceed page limit and we already have content, start new page
        if ($currentPageLines + $extensionSize -gt $maxLinesPerPage -and ($currentPageModules.Count -gt 0 -or $currentPageExtensions.Count -gt 0)) {
            $pageGroups += @{
                Modules = $currentPageModules
                Extensions = $currentPageExtensions
            }
            $currentPageModules = @()
            $currentPageExtensions = @()
            $currentPageLines = 0
        }

        $currentPageExtensions += $extensionName
        $currentPageLines += $extensionSize
    }

    # Add final page if it has content
    if ($currentPageModules.Count -gt 0 -or $currentPageExtensions.Count -gt 0) {
        $pageGroups += @{
            Modules = $currentPageModules
            Extensions = $currentPageExtensions
        }
    }

    $totalPages = $pageGroups.Count

    # Validate page number
    if ($Page -lt 1) {
        $Page = 1
    } elseif ($Page -gt $totalPages) {
        $Page = $totalPages
    }

    # If no pagination needed (single page), show without page info
    if ($totalPages -le 1) {
        Show-ModuleGroups -ModuleGroups $ModuleGroups -ExtensionGroups $ExtensionGroups -AllCommandData $AllCommandData -Extensions $Extensions
        return
    }

    # Show the requested page
    $pageIndex = $Page - 1

    # Show current page content
    $currentModuleGroups = @{
    }
    $currentExtensionGroups = @{
    }

    foreach ($moduleName in $pageGroups[$pageIndex].Modules) {
        $currentModuleGroups[$moduleName] = $ModuleGroups[$moduleName]
    }

    foreach ($extensionName in $pageGroups[$pageIndex].Extensions) {
        $currentExtensionGroups[$extensionName] = $ExtensionGroups[$extensionName]
    }

    Show-ModuleGroups -ModuleGroups $currentModuleGroups -ExtensionGroups $currentExtensionGroups -AllCommandData $AllCommandData -Extensions $Extensions

    # Show pagination info
    Write-Host ""
    Write-Separator -ForegroundColor DarkGray
    Write-Host "Page $Page of $totalPages" -ForegroundColor Cyan -NoNewline
    Write-Host " | Terminal: $terminalHeight lines, Content: $maxLinesPerPage lines" -ForegroundColor DarkGray -NoNewline
    if ($Page -lt $totalPages) {
        Write-Host " | Next: " -ForegroundColor DarkGray -NoNewline
        Write-Host "powertool help -Page $($Page + 1)" -ForegroundColor Yellow
    } else {
        Write-Host ""
    }
    Write-Separator -ForegroundColor DarkGray
}

function Get-ModuleDisplaySize {
    param(
        [string]$ModuleName,
        [array]$Commands,
        [hashtable]$AllCommandData,
        [bool]$IsExtension = $false,
        [hashtable]$Extensions = @{
        }
    )

    # Module header line + spacing
    $lines = 2

    # Each command takes 2 lines (command line + options line)
    $lines += $Commands.Count * 2

    return $lines
}

function Show-ModuleGroups {
    param(
        [hashtable]$ModuleGroups,
        [hashtable]$ExtensionGroups,
        [hashtable]$AllCommandData,
        [hashtable]$Extensions
    )

    # Define module display order (Help first, then others alphabetically)
    $moduleOrder = @("Help") + ($ModuleGroups.Keys | Where-Object { $_ -ne "Help" } | Sort-Object)
    $isFirstGroup = $true

    # Display core modules first
    foreach ($moduleName in $moduleOrder) {
        if (-not $ModuleGroups.ContainsKey($moduleName)) { continue }

        # Add spacing between groups (except before the first one)
        if (-not $isFirstGroup) {
            Write-Host ""
        }
        $isFirstGroup = $false

        # Display module header
        Write-Host "  ${moduleName}:" -ForegroundColor Magenta

        # Sort commands within each module by Position first, then alphabetically
        $commandsInModule = $ModuleGroups[$moduleName]
        $sortedCommands = $commandsInModule | Sort-Object {
            $cmd = $AllCommandData[$_]
            # Primary sort key: Position (if exists), otherwise use a high number to sort last
            $position = if ($cmd.ContainsKey('Position') -and $null -ne $cmd.Position) {
                [int]$cmd.Position
            } else {
                999999
            }
            return $position
        }, {
            # Secondary sort key: Command name (alphabetical)
            $_
        }

        foreach ($commandNameKey in $sortedCommands) {
            $command = $AllCommandData[$commandNameKey]
            $shortcutsText = if ($command.Aliases) { " (" + ($command.Aliases -join ', ') + ")" } else { "" }
            Write-Host "    " -NoNewline
            Write-Host $commandNameKey -NoNewline -ForegroundColor Cyan
            Write-Host $shortcutsText -NoNewline -ForegroundColor Yellow
            $paddingLength = 23 - ($commandNameKey.Length + $shortcutsText.Length)
            if ($paddingLength -gt 0) {
                Write-Host (" " * $paddingLength) -NoNewline
            } else {
                Write-Host " " -NoNewline
            }
            Write-Host $command.Summary -ForegroundColor White
            Write-Host "      Options: " -NoNewline -ForegroundColor White
            Write-ColoredOptions -OptionsData $command.Options
        }
    }

    # Display extensions
    $sortedExtensions = $ExtensionGroups.Keys | Sort-Object
    foreach ($extensionName in $sortedExtensions) {
        # Add spacing between groups
        if (-not $isFirstGroup) {
            Write-Host ""
        }
        $isFirstGroup = $false

        # Display extension header with version
        $extensionVersion = if ($Extensions.ContainsKey($extensionName)) {
            "v$($Extensions[$extensionName].Version)"
        } else {
            ""
        }
        Write-Host "  ${extensionName} " -NoNewline -ForegroundColor DarkMagenta
        Write-Host "(${extensionVersion}):" -ForegroundColor DarkGray

        # Sort commands within each extension by Position first, then alphabetically
        $commandsInExtension = $ExtensionGroups[$extensionName]
        $sortedCommands = $commandsInExtension | Sort-Object {
            $cmd = $AllCommandData[$_]
            # Primary sort key: Position (if exists), otherwise use a high number to sort last
            $position = if ($cmd.ContainsKey('Position') -and $null -ne $cmd.Position) {
                [int]$cmd.Position
            } else {
                999999
            }
            return $position
        }, {
            # Secondary sort key: Command name (alphabetical)
            $_
        }

        foreach ($commandNameKey in $sortedCommands) {
            $command = $AllCommandData[$commandNameKey]
            $shortcutsText = if ($command.Aliases) { " (" + ($command.Aliases -join ', ') + ")" } else { "" }
            Write-Host "    " -NoNewline
            Write-Host $commandNameKey -NoNewline -ForegroundColor Cyan
            Write-Host $shortcutsText -NoNewline -ForegroundColor Yellow
            $paddingLength = 23 - ($commandNameKey.Length + $shortcutsText.Length)
            if ($paddingLength -gt 0) {
                Write-Host (" " * $paddingLength) -NoNewline
            } else {
                Write-Host " " -NoNewline
            }
            Write-Host $command.Summary -ForegroundColor White
            Write-Host "      Options: " -NoNewline -ForegroundColor White
            Write-ColoredOptions -OptionsData $command.Options
        }
    }
}

function Show-Version {
    param(
        [string]$version
    )
    Write-Host "PowerTool" -ForegroundColor Cyan -NoNewline
    Write-Host " v$version"
}

function Search-Commands {
    param(
        [string]$SearchTerm,
        [hashtable]$AllCommandData,
        [hashtable]$CommandModuleMap = @{}
    )

    if (-not $SearchTerm -or $SearchTerm.Trim() -eq "") {
        Write-Host "Please provide a search term." -ForegroundColor Red
        return
    }

    if (-not $AllCommandData) {
        Write-Error "Command data not provided to Search-Commands."
        return
    }

    $verboseMode = Get-Setting -Key "core.verbose"
    $searchTerm = $SearchTerm.ToLower()
    $matchingCommands = @()

    foreach ($commandName in $AllCommandData.Keys) {
        $command = $AllCommandData[$commandName]
        $relevanceScore = 0
        $isMatch = $false

        # Exact command name match (highest priority)
        if ($commandName.ToLower() -eq $searchTerm) {
            $relevanceScore += 100
            $isMatch = $true
        }
        # Command name starts with search term
        elseif ($commandName.ToLower().StartsWith($searchTerm)) {
            $relevanceScore += 75
            $isMatch = $true
        }
        # Command name contains search term
        elseif ($commandName.ToLower().Contains($searchTerm)) {
            $relevanceScore += 50
            $isMatch = $true
        }

        # Exact alias match
        if ($command.Aliases) {
            foreach ($alias in $command.Aliases) {
                if ($alias.ToLower() -eq $searchTerm) {
                    $relevanceScore += 90
                    $isMatch = $true
                }
                elseif ($alias.ToLower().StartsWith($searchTerm)) {
                    $relevanceScore += 65
                    $isMatch = $true
                }
                elseif ($alias.ToLower().Contains($searchTerm)) {
                    $relevanceScore += 40
                    $isMatch = $true
                }
            }
        }

        # Summary contains search term (word boundary preferred)
        if ($command.Summary) {
            $summaryLower = $command.Summary.ToLower()
            if ($summaryLower -match "\b$([regex]::Escape($searchTerm))\b") {
                $relevanceScore += 30
                $isMatch = $true
            }
            elseif ($summaryLower.Contains($searchTerm)) {
                $relevanceScore += 20
                $isMatch = $true
            }
        }

        # Options contains search term
        if ($command.Options) {
            $optionsStringForSearch = ""

            if ($command.Options -is [hashtable]) {
                # New numeric group format
                $sortedKeys = $command.Options.Keys | Sort-Object { [int]$_ }
                foreach ($key in $sortedKeys) {
                    $line = $command.Options[$key]
                    foreach ($tokenInfo in $line) {
                        $optionsStringForSearch += $tokenInfo.Token + " "
                        if ($tokenInfo.Description) {
                            $optionsStringForSearch += $tokenInfo.Description + " "
                        }
                    }
                    $optionsStringForSearch += "| "
                }
            }

            if ($optionsStringForSearch.ToLower().Contains($searchTerm)) {
                $relevanceScore += 10
                $isMatch = $true
            }
        }

        if ($isMatch) {
            $matchingCommands += @{
                Name = $commandName
                Command = $command
                Module = if ($CommandModuleMap.ContainsKey($commandName)) { $CommandModuleMap[$commandName] } else { "Unknown" }
                RelevanceScore = $relevanceScore
            }
        }
    }

    Write-Header
    Write-Host "Search Results for: " -NoNewline -ForegroundColor Blue
    Write-Host "'$SearchTerm'" -ForegroundColor Yellow
    Write-Host ""

    if ($matchingCommands.Count -eq 0) {
        Write-Host "No commands found matching '$SearchTerm'." -ForegroundColor Red
        Write-Host "Use 'powertool help' to see all available commands." -ForegroundColor White
        return
    }

    Write-Host "Found $($matchingCommands.Count) matching command(s):" -ForegroundColor Green
    if ($verboseMode) {
        Write-Host "Search performed in: command names, aliases, summaries, and options" -ForegroundColor DarkGray
    }
    Write-Host ""

    # Sort by relevance score (highest first), then by name
    $sortedMatches = $matchingCommands | Sort-Object @{Expression={$_.RelevanceScore}; Descending=$true}, @{Expression={$_.Name}; Ascending=$true}

    foreach ($match in $sortedMatches) {
        $commandName = $match.Name
        $command = $match.Command
        $moduleName = $match.Module
        $shortcutsText = if ($command.Aliases) { " (" + ($command.Aliases -join ', ') + ")" } else { "" }

        Write-Host "  " -NoNewline
        Write-Host $commandName -NoNewline -ForegroundColor Cyan
        Write-Host $shortcutsText -NoNewline -ForegroundColor Yellow
        Write-Host " [" -NoNewline -ForegroundColor DarkGray
        Write-Host $moduleName -NoNewline -ForegroundColor Magenta
        Write-Host "]" -NoNewline -ForegroundColor DarkGray

        $paddingLength = 18 - ($commandName.Length + $shortcutsText.Length + $moduleName.Length + 3)
        if ($paddingLength -gt 0) {
            Write-Host (" " * $paddingLength) -NoNewline
        } else {
            Write-Host " " -NoNewline
        }

        Write-Host $command.Summary -ForegroundColor White
        Write-Host "    Options: " -NoNewline -ForegroundColor White
        Write-ColoredOptions -OptionsData $command.Options
    }
}

function Test-ModuleCommands {
    param(
        [hashtable]$AllCommandData,
        [hashtable]$Extensions = @{},
        [string]$PowerToolVersion
    )
    $validTypes = @("Argument", "OptionalArgument", "Parameter", "OptionalParameter", "Type")
    $allAliases = @{}
    $errors = @()
    $warnings = @()

    # Validate command definitions
    foreach ($cmdName in $AllCommandData.Keys) {
        $cmd = $AllCommandData[$cmdName]
        # Check for Summary and Options
        if (-not $cmd.ContainsKey('Summary')) {
            $errors += "Command '$cmdName' is missing a 'Summary'."
        }
        if (-not $cmd.ContainsKey('Options')) {
            $errors += "Command '$cmdName' is missing an 'Options' key."
        }
        # Check aliases for duplicates
        if ($cmd.Aliases) {
            foreach ($alias in $cmd.Aliases) {
                $aliasLower = $alias.ToLower()
                if ($allAliases.ContainsKey($aliasLower)) {
                    $errors += "Duplicate alias '$alias' found in commands '$cmdName' and '$($allAliases[$aliasLower])'."
                } else {
                    $allAliases[$aliasLower] = $cmdName
                }
            }
        }
        # Check option types
        if ($cmd.Options) {
            if ($cmd.Options -is [hashtable] -and $cmd.Options.Count -gt 0) {
                # New numeric group format
                foreach ($key in $cmd.Options.Keys) {
                    $group = $cmd.Options[$key]
                    if ($group -is [array]) {
                        foreach ($token in $group) {
                            if ($token -is [hashtable] -and $token.ContainsKey('Type') -and $token.Type) {
                                if ($validTypes -notcontains $token.Type) {
                                    $errors += "Command '$cmdName' has invalid option type '$($token.Type)' for token '$($token.Token)'. Valid types are: $($validTypes -join ', ')."
                                }
                            }
                        }
                    }
                }
            } elseif ($cmd.Options -is [array]) {
                # Legacy array format
                foreach ($token in $cmd.Options) {
                    if ($token -is [hashtable] -and $token.ContainsKey('Type') -and $token.Type) {
                        if ($validTypes -notcontains $token.Type) {
                            $errors += "Command '$cmdName' has invalid option type '$($token.Type)' for token '$($token.Token)'. Valid types are: $($validTypes -join ', ')."
                        }
                    }
                }
            }
        }
    }

    # Validate extension dependencies
    foreach ($extensionName in $Extensions.Keys) {
        $extension = $Extensions[$extensionName]

        if ($extension.Dependencies -and $extension.Dependencies.Count -gt 0) {
            foreach ($depName in $extension.Dependencies.Keys) {
                $requiredVersion = $extension.Dependencies[$depName]

                if ($depName -eq "powertool") {
                    # Check PowerTool version requirement
                    Write-Verbose "Checking PowerTool version: current='$PowerToolVersion', required='$requiredVersion'"

                    $versionCheck = Test-VersionRequirement -CurrentVersion $PowerToolVersion -RequiredVersion $requiredVersion
                    Write-Verbose "Version check result: $versionCheck"

                    if (-not $versionCheck) {
                        $errors += "Extension '$extensionName' requires PowerTool $requiredVersion, but current version is $PowerToolVersion."
                    }
                } else {
                    # Check other extension dependencies
                    if (-not $Extensions.ContainsKey($depName)) {
                        $errors += "Extension '$extensionName' depends on extension '$depName' which is not loaded."
                    } else {
                        $depExtension = $Extensions[$depName]
                        if (-not (Test-VersionRequirement -CurrentVersion $depExtension.Version -RequiredVersion $requiredVersion)) {
                            $errors += "Extension '$extensionName' requires '$depName' $requiredVersion, but loaded version is $($depExtension.Version)."
                        }
                    }
                }
            }
        }

        # Validate extension manifest structure
        if (-not $extension.Name) {
            $errors += "Extension '$extensionName' is missing a name."
        }
        if (-not $extension.Description) {
            $errors += "Extension '$extensionName' is missing a description."
        }
        if (-not $extension.Modules -or $extension.Modules.Count -eq 0) {
            $errors += "Extension '$extensionName' has no modules defined."
        }

        # Check for loaded commands vs expected commands
        if ($extension.LoadedCommands.Count -eq 0) {
            $warnings += "Extension '$extensionName' loaded but did not register any commands."
        }
    }

    Write-Host "Validation Results:" -ForegroundColor Blue
    Write-Host ""

    # Debug information
    Write-Host "Debug Information:" -ForegroundColor DarkGray
    Write-Host "  PowerTool version: $PowerToolVersion" -ForegroundColor DarkGray
    Write-Host "  Extensions loaded: $($Extensions.Count)" -ForegroundColor DarkGray
    foreach ($extName in $Extensions.Keys) {
        $ext = $Extensions[$extName]
        $depCount = if ($ext.Dependencies) { $ext.Dependencies.Count } else { 0 }
        Write-Host "    $extName v$($ext.Version) - Dependencies: $depCount" -ForegroundColor DarkGray
        if ($ext.Dependencies -and $ext.Dependencies.Count -gt 0) {
            foreach ($depName in $ext.Dependencies.Keys) {
                $depVersion = $ext.Dependencies[$depName]
                Write-Host "      ${depName}: $depVersion" -ForegroundColor DarkGray
            }
        }
    }
    Write-Host ""

    # Module Commands validation
    Write-Host "ModuleCommands:" -ForegroundColor Cyan
    $commandErrors = $errors | Where-Object { $_ -notlike "Extension*" }
    if ($commandErrors.Count -eq 0) {
        Write-Host "  [OK] No command definition errors found." -ForegroundColor Green
    } else {
        Write-Host "  [ERROR] Command definition errors:" -ForegroundColor Red
        foreach ($err in $commandErrors) {
            Write-Host "    - $err" -ForegroundColor Red
        }
    }

    # Extension validation
    if ($Extensions.Count -gt 0) {
        Write-Host ""
        Write-Host "Extensions:" -ForegroundColor Cyan
        $extensionErrors = $errors | Where-Object { $_ -like "Extension*" }
        $extensionWarnings = $warnings | Where-Object { $_ -like "Extension*" }

        if ($extensionErrors.Count -eq 0) {
            Write-Host "  [OK] No extension errors found." -ForegroundColor Green
        } else {
            Write-Host "  [ERROR] Extension errors:" -ForegroundColor Red
            foreach ($err in $extensionErrors) {
                Write-Host "    - $err" -ForegroundColor Red
            }
        }

        if ($extensionWarnings.Count -gt 0) {
            Write-Host "  [WARNING] Extension warnings:" -ForegroundColor Yellow
            foreach ($warn in $extensionWarnings) {
                Write-Host "    - $warn" -ForegroundColor Yellow
            }
        }

        # Extension dependency summary
        Write-Host ""
        Write-Host "Extension Dependencies:" -ForegroundColor Cyan
        $hasAnyDeps = $false
        foreach ($extName in ($Extensions.Keys | Sort-Object)) {
            $ext = $Extensions[$extName]
            if ($ext.Dependencies -and $ext.Dependencies.Count -gt 0) {
                $hasAnyDeps = $true
                Write-Host "  ${extName}:" -ForegroundColor White
                foreach ($depName in $ext.Dependencies.Keys) {
                    $depVersion = $ext.Dependencies[$depName]
                    $status = "[OK]"
                    $color = "Green"

                    if ($depName -eq "powertool") {
                        $versionCheck = Test-VersionRequirement -CurrentVersion $PowerToolVersion -RequiredVersion $depVersion
                        if (-not $versionCheck) {
                            $status = "[FAIL]"
                            $color = "Red"
                        }
                    } elseif (-not $Extensions.ContainsKey($depName)) {
                        $status = "[FAIL]"
                        $color = "Red"
                    } elseif (-not (Test-VersionRequirement -CurrentVersion $Extensions[$depName].Version -RequiredVersion $depVersion)) {
                        $status = "[FAIL]"
                        $color = "Red"
                    }

                    Write-Host "    $status ${depName} $depVersion" -ForegroundColor $color
                }
            }
        }

        if (-not $hasAnyDeps) {
            Write-Host "  No extension dependencies defined." -ForegroundColor DarkGray
        }
    }

    Write-Host ""
    Write-Host "Summary:" -ForegroundColor Blue
    if ($errors.Count -eq 0) {
        Write-Host "  [OK] All validations passed successfully!" -ForegroundColor Green
    } else {
        Write-Host "  [ERROR] Found $($errors.Count) error(s) that need attention." -ForegroundColor Red
    }

    if ($warnings.Count -gt 0) {
        Write-Host "  [WARNING] $($warnings.Count) warning(s) to review." -ForegroundColor Yellow
    }
}

function Test-VersionRequirement {
    param(
        [string]$CurrentVersion,
        [string]$RequiredVersion
    )

    # Simple version comparison - supports basic semantic versioning
    # Handles requirements like ">=1.0.0", "1.2.0", ">2.0.0", etc.

    Write-Verbose "Test-VersionRequirement: Current='$CurrentVersion', Required='$RequiredVersion'"

    if (-not $RequiredVersion) {
        Write-Verbose "No required version specified, returning true"
        return $true
    }
    if (-not $CurrentVersion) {
        Write-Verbose "No current version specified, returning false"
        return $false
    }

    # Extract operator and version
    $operator = "="
    $targetVersion = $RequiredVersion

    if ($RequiredVersion -match '^(>=|<=|>|<|=)(.+)$') {
        $operator = $matches[1]
        $targetVersion = $matches[2].Trim()
        Write-Verbose "Parsed operator: '$operator', target version: '$targetVersion'"
    } else {
        Write-Verbose "No operator found, using exact match"
    }

    try {
        $current = [System.Version]::Parse($CurrentVersion)
        $target = [System.Version]::Parse($targetVersion)

        Write-Verbose "Parsed versions - Current: $current, Target: $target"

        $result = switch ($operator) {
            ">=" { $current -ge $target }
            "<=" { $current -le $target }
            ">" { $current -gt $target }
            "<" { $current -lt $target }
            "=" { $current -eq $target }
            default { $current -eq $target }
        }

        Write-Verbose "Version comparison result: $result"
        return $result
    } catch {
        Write-Verbose "Version parsing failed, falling back to string comparison: $($_.Exception.Message)"
        # Fallback to string comparison if version parsing fails
        $result = switch ($operator) {
            ">=" { $CurrentVersion -ge $targetVersion }
            "<=" { $CurrentVersion -le $targetVersion }
            ">" { $CurrentVersion -gt $targetVersion }
            "<" { $CurrentVersion -lt $targetVersion }
            "=" { $CurrentVersion -eq $targetVersion }
            default { $CurrentVersion -eq $targetVersion }
        }

        Write-Verbose "String comparison result: $result"
        return $result
    }
}

function Update-Extension {
    param(
        [string]$ExtensionName,
        [hashtable]$Extensions = @{
        }
    )

    if (-not $ExtensionName) {
        Write-Host "Please specify an extension name to update." -ForegroundColor Red
        Write-Host "Usage: powertool extension [extension-name] -Update" -ForegroundColor White
        return
    }

    if (-not $Extensions.ContainsKey($ExtensionName)) {
        Write-Host "Extension '$ExtensionName' not found." -ForegroundColor Red
        Write-Host "Use 'powertool extension' to see all loaded extensions." -ForegroundColor White
        return
    }

    $extension = $Extensions[$ExtensionName]
    $extensionPath = $extension.Path

    # Check if the extension directory is a git repository
    $gitPath = Join-Path $extensionPath ".git"
    if (-not (Test-Path $gitPath)) {
        Write-Host "Extension '$ExtensionName' is not a git repository. Cannot update." -ForegroundColor Red
        return
    }

    Write-Host "Updating extension: " -NoNewline -ForegroundColor White
    Write-Host $ExtensionName -ForegroundColor Cyan

    # Get current version before update
    $currentVersion = $extension.Version
    Write-Host "Current version: " -NoNewline -ForegroundColor White
    Write-Host "v$currentVersion" -ForegroundColor Yellow

    # Perform git pull
    try {
        $originalLocation = Get-Location
        Set-Location $extensionPath

        Write-Host "Checking for updates..." -ForegroundColor DarkGray

        # Check if there are any changes to pull
        $gitStatus = & git status --porcelain 2>$null
        if ($LASTEXITCODE -ne 0) {
            Write-Host "Failed to check git status. Make sure git is installed and accessible." -ForegroundColor Red
            return
        }

        if ($gitStatus) {
            Write-Host "Warning: Extension has local changes. Continuing with update..." -ForegroundColor Yellow
        }

        # Fetch latest changes
        $fetchResult = & git fetch 2>&1
        if ($LASTEXITCODE -ne 0) {
            Write-Host "Failed to fetch from remote repository." -ForegroundColor Red
            Write-Host $fetchResult -ForegroundColor Red
            return
        }

        # Check if there are updates available
        $behindCommits = & git rev-list --count HEAD..@{u} 2>$null
        if ($LASTEXITCODE -ne 0) {
            Write-Host "Could not determine update status. Attempting pull anyway..." -ForegroundColor Yellow
            $behindCommits = "unknown"
        }

        if ($behindCommits -eq "0") {
            Write-Host "Already up to date." -ForegroundColor Green
            return
        }

        if ($behindCommits -ne "unknown") {
            Write-Host "Found $behindCommits new commit(s). Pulling changes..." -ForegroundColor Green
        }

        # Perform git pull
        $pullResult = & git pull 2>&1
        if ($LASTEXITCODE -ne 0) {
            Write-Host "Failed to pull updates:" -ForegroundColor Red
            Write-Host $pullResult -ForegroundColor Red
            return
        }

        Write-Host "Successfully pulled updates." -ForegroundColor Green

        # Re-read the manifest to get the new version
        $manifestPath = Join-Path $extensionPath "extension.json"
        if (Test-Path $manifestPath) {
            try {
                $newManifest = Get-Content $manifestPath -Raw | ConvertFrom-Json
                $newVersion = if ($newManifest.version) { $newManifest.version } else { "1.0.0" }

                Write-Host "Updated version: " -NoNewline -ForegroundColor White
                Write-Host "v$newVersion" -ForegroundColor Yellow

                if ($newVersion -ne $currentVersion) {
                    Write-Host "Extension updated from v$currentVersion to v$newVersion" -ForegroundColor Green
                    Write-Host "Note: Restart PowerTool to load the updated extension." -ForegroundColor Yellow
                } else {
                    Write-Host "Version unchanged (v$currentVersion)" -ForegroundColor DarkGray
                }
            } catch {
                Write-Host "Updated successfully, but could not read new version from manifest." -ForegroundColor Yellow
            }
        } else {
            Write-Host "Updated successfully, but extension.json not found." -ForegroundColor Yellow
        }

    } catch {
        Write-Host "An error occurred during update: $($_.Exception.Message)" -ForegroundColor Red
    } finally {
        Set-Location $originalLocation
    }
}

function Update-PowerTool {
    param(
        [string]$PowerToolVersion,
        [string]$ToVersion,
        [switch]$Nightly
    )

    # Check if git is available
    try {
        $null = & git --version 2>$null
        if ($LASTEXITCODE -ne 0) {
            throw "Git not found"
        }
    } catch {
        Write-Host "Git is required to update PowerTool. Please install Git and ensure it's in your PATH." -ForegroundColor Red
        return
    }

    # Get PowerTool root directory (assuming Help.psm1 is in modules/ subdirectory)
    $powerToolRoot = (Get-Item $PSScriptRoot).Parent.FullName

    # Check if PowerTool directory is a git repository
    $gitPath = Join-Path $powerToolRoot ".git"
    if (-not (Test-Path $gitPath)) {
        Write-Host "PowerTool is not a git repository. Cannot update via git pull." -ForegroundColor Red
        Write-Host "Consider downloading the latest version manually from GitHub." -ForegroundColor White
        return
    }

    Write-Host "Updating PowerTool..." -ForegroundColor White
    Write-Host "Current version: " -NoNewline -ForegroundColor White
    Write-Host "v$PowerToolVersion" -ForegroundColor Yellow

    if ($ToVersion) {
        Write-Host "Target version: " -NoNewline -ForegroundColor White
        Write-Host $ToVersion -ForegroundColor Yellow
    } elseif ($Nightly) {
        Write-Host "Target: " -NoNewline -ForegroundColor White
        Write-Host "Latest nightly (HEAD)" -ForegroundColor Magenta
    } else {
        Write-Host "Target: " -NoNewline -ForegroundColor White
        Write-Host "Latest tagged version" -ForegroundColor Green
    }

    try {
        $originalLocation = Get-Location
        Set-Location $powerToolRoot

        Write-Host "Checking for updates..." -ForegroundColor DarkGray

        # Check git status for local changes
        $gitStatus = & git status --porcelain 2>$null
        if ($LASTEXITCODE -ne 0) {
            Write-Host "Failed to check git status. Make sure git is installed and accessible." -ForegroundColor Red
            return
        }

        if ($gitStatus) {
            Write-Host "Warning: PowerTool has local changes. Continuing with update..." -ForegroundColor Yellow
        }

        # Fetch latest changes
        $fetchResult = & git fetch --tags 2>&1
        if ($LASTEXITCODE -ne 0) {
            Write-Host "Failed to fetch from remote repository." -ForegroundColor Red
            Write-Host $fetchResult -ForegroundColor Red
            return
        }

        if ($ToVersion) {
            # Update to specific version
            Write-Host "Attempting to checkout version: '$ToVersion'..." -ForegroundColor Green

            $checkoutResult = & git checkout $ToVersion 2>&1
            if ($LASTEXITCODE -ne 0) {
                # Try with "v" prefix if not already present
                if (-not $ToVersion.StartsWith("v")) {
                    $vPrefixedVersion = "v$ToVersion"
                    Write-Host "Attempting to checkout version: '$vPrefixedVersion'..." -ForegroundColor DarkGray
                    $checkoutResult = & git checkout $vPrefixedVersion 2>&1
                    if ($LASTEXITCODE -ne 0) {
                        Write-Host "Failed to checkout version '$vPrefixedVersion':" -ForegroundColor Red
                        Write-Host $checkoutResult -ForegroundColor Red
                        return
                    } else {
                        Write-Host "Successfully checked out version '$vPrefixedVersion'." -ForegroundColor Green
                    }
                } else {
                    Write-Host "Failed to checkout version '$ToVersion':" -ForegroundColor Red
                    Write-Host $checkoutResult -ForegroundColor Red
                    return
                }
            } else {
                Write-Host "Successfully checked out version '$ToVersion'." -ForegroundColor Green
            }
        } elseif ($Nightly) {
            # Update to latest commit on default branch (nightly)
            Write-Host "Updating to latest nightly version..." -ForegroundColor Magenta

            # Get the default branch name
            $defaultBranch = & git symbolic-ref refs/remotes/origin/HEAD 2>$null
            if ($LASTEXITCODE -eq 0) {
                $defaultBranch = $defaultBranch -replace '^refs/remotes/origin/', ''
            } else {
                # Fallback to common default branch names
                $defaultBranch = "main"
                $branchExists = & git show-ref --verify --quiet "refs/remotes/origin/main" 2>$null
                if ($LASTEXITCODE -ne 0) {
                    $branchExists = & git show-ref --verify --quiet "refs/remotes/origin/master" 2>$null
                    if ($LASTEXITCODE -eq 0) {
                        $defaultBranch = "master"
                    }
                }
            }

            Write-Host "Switching to branch: $defaultBranch" -ForegroundColor DarkGray
            $checkoutResult = & git checkout $defaultBranch 2>&1
            if ($LASTEXITCODE -ne 0) {
                Write-Host "Failed to checkout branch '$defaultBranch':" -ForegroundColor Red
                Write-Host $checkoutResult -ForegroundColor Red
                return
            }

            # Pull latest changes
            $pullResult = & git pull origin $defaultBranch 2>&1
            if ($LASTEXITCODE -ne 0) {
                Write-Host "Failed to pull latest changes:" -ForegroundColor Red
                Write-Host $pullResult -ForegroundColor Red
                return
            }

            Write-Host "Successfully updated to latest nightly version." -ForegroundColor Green
        } else {
            # Update to latest tagged version (default behavior)
            Write-Host "Finding latest tagged version..." -ForegroundColor DarkGray

            # Get the latest tag
            $latestTag = & git describe --tags --abbrev=0 2>$null
            if ($LASTEXITCODE -ne 0) {
                Write-Host "No tags found in the repository. Use -Nightly to update to the latest commit." -ForegroundColor Yellow
                return
            }

            Write-Host "Latest tagged version: " -NoNewline -ForegroundColor White
            Write-Host $latestTag -ForegroundColor Green

            # Check if we're already on the latest tag
            $currentTag = & git describe --tags --exact-match HEAD 2>$null
            if ($LASTEXITCODE -eq 0 -and $currentTag -eq $latestTag) {
                Write-Host "Already on the latest tagged version ($latestTag)." -ForegroundColor Green
                return
            }

            # Compare current version with latest tag
            $currentVersionClean = $PowerToolVersion -replace '^v', ''
            $latestVersionClean = $latestTag -replace '^v', ''

            try {
                $current = [System.Version]::Parse($currentVersionClean)
                $latest = [System.Version]::Parse($latestVersionClean)

                if ($current -ge $latest) {
                    Write-Host "Current version (v$currentVersionClean) is already up to date or newer than the latest tag ($latestTag)." -ForegroundColor Green
                    return
                }
            } catch {
                # If version parsing fails, proceed with the update
                Write-Host "Could not parse versions for comparison. Proceeding with update..." -ForegroundColor DarkGray
            }

            # Checkout the latest tag
            Write-Host "Updating to tagged version: $latestTag" -ForegroundColor Green
            $checkoutResult = & git checkout $latestTag 2>&1
            if ($LASTEXITCODE -ne 0) {
                Write-Host "Failed to checkout tag '$latestTag':" -ForegroundColor Red
                Write-Host $checkoutResult -ForegroundColor Red
                return
            }

            Write-Host "Successfully updated to version $latestTag." -ForegroundColor Green
        }

        Write-Host "PowerTool updated successfully!" -ForegroundColor Green
        Write-Host "Note: You may need to restart your PowerShell session for changes to take effect." -ForegroundColor Yellow

    } catch {
        Write-Host "An error occurred during update: $($_.Exception.Message)" -ForegroundColor Red
    } finally {
        Set-Location $originalLocation
    }
}

function Get-LatestVersion {
    param(
        [string]$CurrentVersion
    )

    Write-Host "Checking latest version..." -ForegroundColor White
    Write-Host "Current version: " -NoNewline -ForegroundColor White
    Write-Host "v$CurrentVersion" -ForegroundColor Yellow

    try {
        # Query GitHub API for latest tags
        $apiUrl = "https://api.github.com/repos/sn0w12/PowerTool/tags"

        # Use Invoke-RestMethod with error handling
        $response = Invoke-RestMethod -Uri $apiUrl -Method Get -ErrorAction Stop

        if ($response.Count -eq 0) {
            Write-Host "No tags found in the repository." -ForegroundColor Yellow
            return
        }

        # Get the latest tag (first in the array as GitHub returns them in descending order)
        $latestTag = $response[0]
        $latestVersion = $latestTag.name

        Write-Host "Latest version: " -NoNewline -ForegroundColor White
        Write-Host $latestVersion -ForegroundColor Green

        # Compare versions
        $currentVersionClean = $CurrentVersion -replace '^v', ''
        $latestVersionClean = $latestVersion -replace '^v', ''

        try {
            $current = [System.Version]::Parse($currentVersionClean)
            $latest = [System.Version]::Parse($latestVersionClean)

            if ($current -lt $latest) {
                Write-Host ""
                Write-Host "A newer version is available!" -ForegroundColor Yellow
                Write-Host "You can update by running: " -NoNewline -ForegroundColor White
                Write-Host "powertool update" -ForegroundColor Green
            } elseif ($current -eq $latest) {
                Write-Host ""
                Write-Host "You are running the latest version!" -ForegroundColor Green
            } else {
                Write-Host ""
                Write-Host "You are running a newer version than the latest tag." -ForegroundColor Cyan
            }
        } catch {
            # Fallback to string comparison if version parsing fails
            if ($currentVersionClean -ne $latestVersionClean) {
                Write-Host ""
                Write-Host "Version comparison: Current '$currentVersionClean' vs Latest '$latestVersionClean'" -ForegroundColor DarkGray
            } else {
                Write-Host ""
                Write-Host "You are running the latest version!" -ForegroundColor Green
            }
        }

        # Show commit info for the latest tag
        Write-Host ""
        Write-Host "Latest tag info:" -ForegroundColor Blue
        Write-Host "  Commit: " -NoNewline -ForegroundColor White
        Write-Host $latestTag.commit.sha.Substring(0, 7) -ForegroundColor DarkGray
        if ($latestTag.commit.url) {
            Write-Host "  View on GitHub: " -NoNewline -ForegroundColor White
            Write-Host "https://github.com/sn0w12/PowerTool/commit/$($latestTag.commit.sha)" -ForegroundColor Blue
        }

    } catch {
        Write-Host "Failed to check latest version: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "Please check your internet connection or try again later." -ForegroundColor White

        # Suggest manual check
        Write-Host ""
        Write-Host "You can manually check for updates at:" -ForegroundColor White
        Write-Host "https://github.com/sn0w12/PowerTool/tags" -ForegroundColor Blue
    }
}

$script:ModuleCommands = @{
    "help" = @{
        Position = 0
        Aliases = @("h")
        Action = {
            # Use the -Page parameter directly from the main script
            Show-Help -ForCommand $Value1 -AllCommandData $script:commandDefinitions -CommandModuleMap $script:commandModuleMap -ExtensionCommands $script:extensionCommands -Extensions $script:extensions -Module $Module -Page $Page
        }
        Summary = "Show this help message or help for a specific command."
        Options = @{
            0 = @(
                @{ Token = "command-name"; Type = "OptionalArgument"; Description = "The name of the command to get help for." }
                @{ Token = "Module"; Type = "OptionalParameter"; Description = "Show only commands from the specified module or extension." }
                @{ Token = "Page"; Type = "OptionalParameter"; Description = "Page number for paginated help display." }
            )
        }
        Examples = @(
            "powertool help",
            "powertool help -Page 2",
            "powertool help rename-random",
            "powertool help -Module Help",
            "powertool help -Module ImageProcessing"
        )
    }
    "version" = @{
        Position = 1
        Aliases = @("v", "ver")
        Action = { Show-Version -version $version }
        Summary = "Show the current version of PowerTool."
        Options = @{}
        Examples = @(
            "powertool version",
            "powertool v"
        )
    }
    "search" = @{
        Position = 2
        Aliases = @("find", "s")
        Action = {
            Search-Commands -SearchTerm $Value1 -AllCommandData $script:commandDefinitions -CommandModuleMap $script:commandModuleMap
        }
        Summary = "Search through all available commands by name, aliases, or description."
        Options = @{
            0 = @(
                @{ Token = "search-term"; Type = "Argument"; Description = "The term to search for in commands, aliases, summaries, or options." }
            )
        }
        Examples = @(
            "powertool search image",
            "powertool find rename",
            "pt f file"
        )
    }
    "validate" = @{
        Aliases = @("check", "val")
        Action = {
            Test-ModuleCommands -AllCommandData $script:commandDefinitions -Extensions $script:extensions -PowerToolVersion $version
        }
        Summary = "Validate all ModuleCommands for correct structure, option types, duplicate aliases, and extension dependencies."
        Options = @{}
        Examples = @(
            "powertool validate",
            "pt val"
        )
    }
    "update" = @{
        Aliases = @("upgrade", "up")
        Action = {
            Update-PowerTool -PowerToolVersion $version -ToVersion $Value1 -Nightly:$Nightly
        }
        Summary = "Update PowerTool to the latest tagged version, a specific version, or latest nightly using git."
        Options = @{
            0 = @(
                @{ Token = "version"; Type = "OptionalArgument"; Description = "Specific version, tag, or branch to update to. If not specified, updates to latest tagged version." }
                @{ Token = "Nightly"; Type = "OptionalParameter"; Description = "Update to the latest commit on the default branch instead of latest tag." }
            )
        }
        Examples = @(
            "powertool update",
            "powertool update v1.2.0",
            "powertool update -Nightly",
            "powertool update main",
            "pt up -Nightly"
        )
    }
    "latest" = @{
        Aliases = @("checkout", "newest")
        Action = {
            Get-LatestVersion -CurrentVersion $version
        }
        Summary = "Check the latest available version of PowerTool on GitHub."
        Options = @{}
        Examples = @(
            "powertool latest",
            "pt check"
        )
    }
    "colors" = @{
        Aliases = @("c", "color")
        Action = {
            Write-Host "PowerShell Console Colors Reference" -ForegroundColor Cyan
            Write-Host ("=" * 35) -ForegroundColor DarkGray
            Write-Host ""

            $colors = [enum]::GetValues([System.ConsoleColor])
            Foreach ($bgcolor in $colors){
                Foreach ($fgcolor in $colors) { Write-Host "$fgcolor|"  -ForegroundColor $fgcolor -BackgroundColor $bgcolor -NoNewLine }
                Write-Host " on $bgcolor"
            }
        }
        Summary = "Show available colors for command options and examples."
        Options = @{
        }
        Examples = @(
            "powertool colors",
            "pt c"
        )
    }
}

Export-ModuleMember -Function Show-Help, Write-ColoredOptions, Write-ColoredExample, Show-Version, Search-Commands, Test-ModuleCommands, Test-VersionRequirement, Update-PowerTool, Get-LatestVersion, Write-Header -Variable ModuleCommands