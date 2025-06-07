function Write-ColoredOptions {
    param([string]$OptionsText)

    if (-not $OptionsText -or $OptionsText.Trim() -eq "") {
        Write-Host "None" -ForegroundColor DarkGray
        return
    }

    # Split by pipe (|) for multiple option sets
    $optionSets = $OptionsText -split '\|'

    for ($i = 0; $i -lt $optionSets.Count; $i++) {
        $optionSet = $optionSets[$i].Trim()

        # Parse the option set character by character
        $j = 0
        while ($j -lt $optionSet.Length) {
            $char = $optionSet[$j]

            switch ($char) {
                '[' {
                    # Find the closing bracket
                    $endBracket = $optionSet.IndexOf(']', $j)
                    if ($endBracket -ne -1) {
                        $bracketContent = $optionSet.Substring($j, $endBracket - $j + 1)
                        Write-Host $bracketContent -NoNewline -ForegroundColor DarkCyan
                        $j = $endBracket + 1
                    } else {
                        Write-Host $char -NoNewline
                        $j++
                    }
                }
                '<' {
                    # Find the closing angle bracket
                    $endAngle = $optionSet.IndexOf('>', $j)
                    if ($endAngle -ne -1) {
                        $angleContent = $optionSet.Substring($j, $endAngle - $j + 1)
                        Write-Host $angleContent -NoNewline -ForegroundColor DarkYellow
                        $j = $endAngle + 1
                    } else {
                        Write-Host $char -NoNewline
                        $j++
                    }
                }
                '-' {
                    # Find the parameter name (until space or < or end)
                    $paramStart = $j
                    $j++
                    while ($j -lt $optionSet.Length -and $optionSet[$j] -notin @(' ', '<')) {
                        $j++
                    }
                    $paramName = $optionSet.Substring($paramStart, $j - $paramStart)
                    Write-Host $paramName -NoNewline -ForegroundColor Green
                }
                ' ' {
                    Write-Host $char -NoNewline
                    $j++
                }
                default {
                    Write-Host $char -NoNewline
                    $j++
                }
            }
        }

        # Add pipe separator between option sets
        if ($i -lt $optionSets.Count - 1) {
            Write-Host " | " -NoNewline -ForegroundColor DarkGray
        }
    }
    Write-Host "" # Ensure a newline after options are printed
}

$script:HeaderText = "PowerTool - Utility CLI for Windows"

function Write-UsageSection {
    Write-Host "Usage:" -ForegroundColor Blue
    Write-Host "  " -NoNewline
    Write-Host "powertool" -NoNewline -ForegroundColor Yellow
    Write-Host " " -NoNewline
    Write-Host "<command>" -NoNewline -ForegroundColor White
    Write-Host " " -NoNewline
    Write-Host "[input]" -NoNewline -ForegroundColor DarkCyan
    Write-Host " " -NoNewline
    Write-Host "[options]" -ForegroundColor Gray

    Write-Host "  " -NoNewline
    Write-Host "pt" -NoNewline -ForegroundColor Yellow
    Write-Host " " -NoNewline
    Write-Host "<command>" -NoNewline -ForegroundColor White
    Write-Host " " -NoNewline
    Write-Host "[input]" -NoNewline -ForegroundColor DarkCyan
    Write-Host " " -NoNewline
    Write-Host "[options]" -ForegroundColor Gray
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
        Write-Host $script:HeaderText -ForegroundColor Cyan
        Write-Host ""
        Write-UsageSection
        Write-Host ""
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
            Write-ColoredOptions -OptionsText $foundCommandDetails.Options
            Write-Host ""
            Write-Host "Examples:" -ForegroundColor Blue
            if ($foundCommandDetails.Examples -is [array]) {
                foreach ($example in $foundCommandDetails.Examples) {
                    Write-Host "  $example"
                }
            }
        } else {
            Write-Host "Unknown command: '$ForCommand'. Cannot show specific help." -ForegroundColor Red
            Write-Host "Use 'powertool help' to see all available commands." -ForegroundColor White
        }
    } else {
        Write-Host $script:HeaderText -ForegroundColor Cyan
        Write-Host ""
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
                Write-ColoredOptions -OptionsText $command.Options
            }
        }
    }
}

function Show-Version {
    $version = "0.1.0" # Consider making this configurable or part of module data
    Write-Host "PowerTool v$version" -ForegroundColor Cyan
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
        Options = "[command-name]"
        Examples = @(
            "powertool help rename-random",
            "powertool help filter-images"
        )
    }
    "version" = @{
        Aliases = @("v", "ver")
        Action = { Show-Version }
        Summary = "Show the current version of PowerTool."
        Options = ""
        Examples = @(
            "powertool version",
            "powertool v"
        )
    }
}

Export-ModuleMember -Function Show-Help, Write-ColoredOptions, Show-Version -Variable ModuleCommands