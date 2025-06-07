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
}

function Show-Help {
    param([string]$ForCommand)

    $helpFilePath = Join-Path $PSScriptRoot "../help.json"

    if (-not (Test-Path $helpFilePath)) {
        Write-Error "Help file not found: $helpFilePath"
        return
    }

    try {
        $helpContent = Get-Content -Path $helpFilePath -Raw | ConvertFrom-Json
    }
    catch {
        Write-Error "Error reading or parsing help file: $($_.Exception.Message)"
        return
    }

    # --- Logic to Display Help ---
    if ($ForCommand) {
        Write-Host $helpContent.preamble -ForegroundColor White
        Write-Host ""
        $commandKey = $ForCommand.ToLower()

        # Find command by name or shortcut
        $foundCommand = $null
        $foundCommandName = $null
        foreach ($commandName in $helpContent.commands.PSObject.Properties.Name) {
            $command = $helpContent.commands.$commandName
            if ($commandName -eq $commandKey -or ($command.shortcuts -and $command.shortcuts -contains $commandKey)) {
                $foundCommand = $command
                $foundCommandName = $commandName
                break
            }
        }

        if ($foundCommand) {
            $shortcutsText = if ($foundCommand.shortcuts) { " (" + ($foundCommand.shortcuts -join ', ') + ")" } else { "" }
            Write-Host "Command Details:" -ForegroundColor Blue
            Write-Host "  " -NoNewline
            Write-Host $foundCommandName -NoNewline -ForegroundColor Cyan
            Write-Host $shortcutsText -ForegroundColor Yellow
            Write-Host "    $($foundCommand.summary)" -ForegroundColor White
            Write-Host "    Options: " -NoNewline -ForegroundColor White
            Write-ColoredOptions -OptionsText $foundCommand.options
            Write-Host ""
            Write-Host ""
            Write-Host "Examples:" -ForegroundColor Blue
            foreach ($example in $foundCommand.examples) {
                Write-Host "  $example"
            }
        } else {
            Write-Host "Unknown command: '$ForCommand'. Cannot show specific help." -ForegroundColor Red
            Write-Host "Use 'powertool help' to see all available commands." -ForegroundColor White
        }
    } else {
        # Display full help
        Write-Host $helpContent.preamble -ForegroundColor White
        Write-Host ""
        Write-Host "Commands:" -ForegroundColor Blue
        foreach ($commandName in $helpContent.commands.PSObject.Properties.Name) {
            $command = $helpContent.commands.$commandName
            $shortcutsText = if ($command.shortcuts) { " (" + ($command.shortcuts -join ', ') + ")" } else { "" }
            Write-Host "  " -NoNewline
            Write-Host $commandName -NoNewline -ForegroundColor Cyan
            Write-Host $shortcutsText -NoNewline -ForegroundColor Yellow
            $paddingLength = 25 - ($commandName.Length + $shortcutsText.Length)
            if ($paddingLength -gt 0) {
                Write-Host (" " * $paddingLength) -NoNewline
            } else {
                Write-Host " " -NoNewline
            }
            Write-Host $command.summary -ForegroundColor White
            Write-Host "    Options: " -NoNewline -ForegroundColor White
            Write-ColoredOptions -OptionsText $command.options
            Write-Host ""
        }
    }
}

Export-ModuleMember -Function Show-Help, Write-ColoredOptions