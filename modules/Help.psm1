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
        [hashtable]$CommandModuleMap = @{} # Receives $commandModuleMap from powertool.ps1
    )

    if (-not $AllCommandData) {
        Write-Error "Command data not provided to Show-Help."
        return
    }

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
        } else {
            Write-Host "Unknown command: '$ForCommand'. Cannot show specific help." -ForegroundColor Red
            Write-Host "Use 'powertool help' to see all available commands." -ForegroundColor White
        }
    } else {
        Write-Header
        Write-UsageSection
        Write-Host ""
        Write-Host "Commands:" -ForegroundColor Blue

        # Group commands by module
        $moduleGroups = @{}
        foreach ($commandName in $AllCommandData.Keys) {
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

        # Define module display order (Help first, then others alphabetically)
        $moduleOrder = @("Help") + ($moduleGroups.Keys | Where-Object { $_ -ne "Help" } | Sort-Object)

        $isFirstModule = $true
        foreach ($moduleName in $moduleOrder) {
            if (-not $moduleGroups.ContainsKey($moduleName)) { continue }

            # Add spacing between modules (except before the first one)
            if (-not $isFirstModule) {
                Write-Host ""
            }
            $isFirstModule = $false

            # Display module header
            Write-Host "  ${moduleName}:" -ForegroundColor Magenta

            # Sort commands within each module
            $sortedCommands = $moduleGroups[$moduleName] | Sort-Object

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
        [hashtable]$AllCommandData
    )
    $validTypes = @("Argument", "OptionalArgument", "Parameter", "OptionalParameter", "Type")
    $allAliases = @{}
    $errors = @()
    $warnings = @()

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

    Write-Host "ModuleCommands Validation Results:" -ForegroundColor Blue
    if ($errors.Count -eq 0) {
        Write-Host "  No errors found." -ForegroundColor Green
    } else {
        Write-Host "  Errors:" -ForegroundColor Red
        foreach ($err in $errors) {
            Write-Host "    $err" -ForegroundColor Red
        }
    }
    if ($warnings.Count -gt 0) {
        Write-Host "  Warnings:" -ForegroundColor Yellow
        foreach ($warn in $warnings) {
            Write-Host "    $warn" -ForegroundColor Yellow
        }
    }
}

$script:ModuleCommands = @{
    "help" = @{
        Aliases = @("h")
        Action = {
            # $Path is the value of the -Path parameter from powertool.ps1, used as ForCommand here
            # Use $script:commandDefinitions to access the main script's command definitions
            Show-Help -ForCommand $Path -AllCommandData $script:commandDefinitions -CommandModuleMap $script:commandModuleMap
        }
        Summary = "Show this help message or help for a specific command."
        Options = @{
            0 = @(
                @{ Token = "command-name"; Type = "OptionalArgument"; Description = "The name of the command to get help for." }
            )
        }
        Examples = @(
            "powertool help rename-random",
            "powertool help filter-images"
        )
    }
    "search" = @{
        Aliases = @("find", "s")
        Action = {
            Search-Commands -SearchTerm $Path -AllCommandData $script:commandDefinitions -CommandModuleMap $script:commandModuleMap
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
    "version" = @{
        Aliases = @("v", "ver")
        Action = { Show-Version -version $version }
        Summary = "Show the current version of PowerTool."
        Options = @{}
        Examples = @(
            "powertool version",
            "powertool v"
        )
    }
    "validate" = @{
        Aliases = @("check", "val")
        Action = {
            Test-ModuleCommands -AllCommandData $script:commandDefinitions
        }
        Summary = "Validate all ModuleCommands for correct structure, option types, and duplicate aliases."
        Options = @{}
        Examples = @(
            "powertool validate",
            "pt val"
        )
    }
}

Export-ModuleMember -Function Show-Help, Write-ColoredOptions, Write-ColoredExample, Show-Version, Search-Commands, Test-ModuleCommands -Variable ModuleCommands