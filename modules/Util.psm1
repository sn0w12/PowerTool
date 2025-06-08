<#
.SYNOPSIS
    PowerTool Utility Functions Module - Common helper functions for other modules

.TYPE
    Utility Module

.DESCRIPTION
    This is a UTILITY MODULE that provides shared helper functions for other PowerTool modules.
    It does NOT provide PowerTool commands directly.

    Purpose:
    - Provide common utility functions used across multiple modules
    - String manipulation and comparison functions
    - Path resolution and file system helpers
    - Data processing and transformation utilities
    - Shared algorithms and calculations

    This module exports individual functions that can be imported and used by other modules.
    Functions should be generic, reusable, and not specific to any particular domain.
#>

function Get-LevenshteinDistance {
    <#
        .SYNOPSIS
            Get the Levenshtein distance between two strings.
        .DESCRIPTION
            The Levenshtein Distance is a way of quantifying how dissimilar two strings (e.g., words) are to one another by counting the minimum number of operations required to transform one string into the other.
        .EXAMPLE
            Get-LevenshteinDistance 'kitten' 'sitting'
        .LINK
            http://en.wikibooks.org/wiki/Algorithm_Implementation/Strings/Levenshtein_distance#C.23
            http://en.wikipedia.org/wiki/Edit_distance
            https://communary.wordpress.com/
            https://github.com/gravejester/Communary.PASM
        .NOTES
            Author: Øyvind Kallstad
            Date: 07.11.2014
            Version: 1.0
    #>
    [CmdletBinding()]
    param(
        [Parameter(Position = 0)]
        [string]$String1,

        [Parameter(Position = 1)]
        [string]$String2,

        # Makes matches case-sensitive. By default, matches are not case-sensitive.
        [Parameter()]
        [switch] $CaseSensitive,

        # A normalized output will fall in the range 0 (perfect match) to 1 (no match).
        [Parameter()]
        [switch] $NormalizeOutput
    )

    if (-not($CaseSensitive)) {
        $String1 = $String1.ToLowerInvariant()
        $String2 = $String2.ToLowerInvariant()
    }

    $d = New-Object 'Int[,]' ($String1.Length + 1), ($String2.Length + 1)

    try {
        for ($i = 0; $i -le $d.GetUpperBound(0); $i++) {
            $d[$i,0] = $i
        }

        for ($i = 0; $i -le $d.GetUpperBound(1); $i++) {
            $d[0,$i] = $i
        }

        for ($i = 1; $i -le $d.GetUpperBound(0); $i++) {
            for ($j = 1; $j -le $d.GetUpperBound(1); $j++) {
                $cost = [Convert]::ToInt32((-not($String1[$i-1] -ceq $String2[$j-1])))
                $min1 = $d[($i-1),$j] + 1
                $min2 = $d[$i,($j-1)] + 1
                $min3 = $d[($i-1),($j-1)] + $cost
                $d[$i,$j] = [Math]::Min([Math]::Min($min1,$min2),$min3)
            }
        }

        $distance = ($d[$d.GetUpperBound(0),$d.GetUpperBound(1)])

        if ($NormalizeOutput) {
            Write-Output (1 - ($distance) / ([Math]::Max($String1.Length,$String2.Length)))
        }

        else {
            Write-Output $distance
        }
    }

    catch {
        Write-Warning $_.Exception.Message
    }
}

function Get-TargetPath($Path) {
    if ([string]::IsNullOrWhiteSpace($Path)) {
        return Get-Location
    } else {
        # Check if the path is already absolute (has drive letter or UNC path)
        if ([System.IO.Path]::IsPathRooted($Path)) {
            return $Path
        } else {
            # For relative paths, combine with current location
            return Join-Path (Get-Location) $Path
        }
    }
}

function Start-Loader {
    <#
        .SYNOPSIS
            Start an animated loader or static message to show progress.
        .DESCRIPTION
            Creates a visual indicator that runs in the background.
            If the host supports cursor visibility control, an animation is shown.
            Otherwise, a static message is displayed.
            Returns a loader object that can be used to stop the indicator.
        .EXAMPLE
            $loader = Start-Loader -Message "Searching files..."
            # ... do work ...
            Stop-Loader $loader
        .EXAMPLE
            $loader = Start-Loader -Style "Dots" -Message "Processing..." -Color "Yellow"
            # ... do work ...
            Stop-Loader $loader
    #>
    [CmdletBinding()]
    param(
        # Message to display with the loader
        [Parameter()]
        [string]$Message = "Working...",

        # Loader animation style
        [Parameter()]
        [ValidateSet("Spinner", "Dots", "Bar", "Pulse")]
        [string]$Style = "Spinner",

        # Color of the loader animation
        [Parameter()]
        [ValidateSet("White", "Gray", "DarkGray", "Red", "DarkRed", "Green", "DarkGreen", "Yellow", "DarkYellow", "Blue", "DarkBlue", "Magenta", "DarkMagenta", "Cyan", "DarkCyan")]
        [string]$Color = "Yellow",

        # Update interval in milliseconds
        [Parameter()]
        [int]$IntervalMs = 100
    )

    $animations = @{
        Spinner = @('|', '/', '-', '\')
        Dots = @('.', '..', '...', '....', '.....', '......')
        Bar = @('[    ]', '[■   ]', '[■■  ]', '[■■■ ]', '[■■■■]', '[■■■ ]', '[■■  ]', '[■   ]')
        Pulse = @([char]0x25CB, [char]0x25D0, [char]0x25CF, [char]0x25D1)
    }

    $frames = $animations[$Style]

    $loaderScript = {
        param($Message, $Frames, $Color, $IntervalMs)

        $frameIndex = 0
        $originalCursorVisible = $null
        $cursorHidden = $false
        $previousLineLength = 0

        try {
            if ($Host -and $Host.UI -and $Host.UI.RawUI -and $Host.UI.RawUI.PSObject.Properties['CursorVisible']) {
                $originalCursorVisible = $Host.UI.RawUI.CursorVisible
                $Host.UI.RawUI.CursorVisible = $false
                $cursorHidden = $true
            }

            while ($true) {
                if ($previousLineLength -gt 0) {
                    Write-Host "`r" -NoNewline
                    Write-Host ("".PadRight($previousLineLength, " ")) -NoNewline
                    Write-Host "`r" -NoNewline
                }

                $frame = $Frames[$frameIndex % $Frames.Length]
                $currentOutput = "$Message$frame"
                Write-Host $currentOutput -ForegroundColor $Color -NoNewline
                $previousLineLength = $currentOutput.Length

                Start-Sleep -Milliseconds $IntervalMs
                $frameIndex++
            }
        }
        catch [System.Management.Automation.PipelineStoppedException] {
            # Expected
        }
        catch {
            Write-Error "[Start-Loader Script Error] $($_.Exception.ToString())"
        }
        finally {
            if ($cursorHidden) {
                try {
                    $Host.UI.RawUI.CursorVisible = $originalCursorVisible
                } catch { /* Ignore */ }
            }

            Write-Host "`r" -NoNewline
            $maxFrameLength = 0
            if ($Frames -and $Frames.Count -gt 0) {
                foreach ($f_item in $Frames) {
                    if ($f_item -and $f_item.Length -gt $maxFrameLength) {
                        $maxFrameLength = $f_item.Length
                    }
                }
            }
            if ($maxFrameLength -eq 0) { $maxFrameLength = 5 }

            $lenToClear = if ($previousLineLength -gt 0) { $previousLineLength } else { $Message.Length + $maxFrameLength + 5 }

            Write-Host ("".PadRight($lenToClear + 5, " ")) -NoNewline
            Write-Host "`r" -NoNewline
        }
    }

    $runspace = [runspacefactory]::CreateRunspace($Host)
    $runspace.Open()

    $powerShell = [powershell]::Create()
    $powerShell.Runspace = $runspace
    $powerShell.AddScript($loaderScript).AddArgument($Message).AddArgument($frames).AddArgument($Color).AddArgument($IntervalMs)

    $asyncResult = $powerShell.BeginInvoke()

    return @{
        PowerShell = $powerShell
        AsyncResult = $asyncResult
        Runspace = $runspace
        Message = $Message
        CanControlCursor = $cursorHidden
        Frames = $Frames
    }
}

function Stop-Loader {
    <#
        .SYNOPSIS
            Stop a running loader/message indicator.
        .DESCRIPTION
            Stops the specified loader animation and cleans up resources.
        .EXAMPLE
            Stop-Loader $loader
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object]$Loader
    )

    if ($Loader -and $Loader.PowerShell -and $Loader.Runspace) {
        try {
            if ($Loader.PowerShell.InvocationStateInfo.State -eq [System.Management.Automation.PSInvocationState]::Running) {
                $Loader.PowerShell.Stop()
            }

            if ($Loader.AsyncResult) {
                try {
                    $Loader.PowerShell.EndInvoke($Loader.AsyncResult) | Out-Null
                }
                catch [System.Management.Automation.PipelineStoppedException] {
                    # Expected
                }
                catch {
                    Write-Warning "[Stop-Loader WARNING] Error during EndInvoke: $($_.Exception.Message)"
                }
            }
        }
        catch {
            Write-Warning "[Stop-Loader WARNING] Error during loader stop process: $($_.Exception.Message)"
        }
        finally {
            if ($Loader.PowerShell) {
                try { $Loader.PowerShell.Dispose() } catch {}
            }
            if ($Loader.Runspace) {
                try {
                    if ($Loader.Runspace.RunspaceStateInfo.State -ne [System.Management.Automation.Runspaces.RunspaceState]::Broken -and $Loader.Runspace.RunspaceStateInfo.State -ne [System.Management.Automation.Runspaces.RunspaceState]::Closed) {
                        $Loader.Runspace.Close()
                    }
                    $Loader.Runspace.Dispose()
                }
                catch {}
            }
        }
    }
}

function Invoke-WithLoader {
    <#
        .SYNOPSIS
            Execute a script block with a visual loader.
        .DESCRIPTION
            Runs the specified script block while displaying an animated loader.
            Automatically starts and stops the loader around the operation.
        .EXAMPLE
            Invoke-WithLoader -ScriptBlock { Start-Sleep 5 } -Message "Processing data..."
        .EXAMPLE
            $result = Invoke-WithLoader -ScriptBlock { Get-ChildItem -Recurse } -Message "Scanning files..." -Style "Dots"
    #>
    [CmdletBinding()]
    param(
        # The script block to execute
        [Parameter(Mandatory)]
        [scriptblock]$ScriptBlock,

        # Message to display with the loader
        [Parameter()]
        [string]$Message = "Working...",

        # Loader animation style
        [Parameter()]
        [ValidateSet("Spinner", "Dots", "Bar", "Pulse")]
        [string]$Style = "Spinner",

        # Color of the loader animation
        [Parameter()]
        [ValidateSet("White", "Gray", "DarkGray", "Red", "DarkRed", "Green", "DarkGreen", "Yellow", "DarkYellow", "Blue", "DarkBlue", "Magenta", "DarkMagenta", "Cyan", "DarkCyan")]
        [string]$Color = "Yellow"
    )

    $loader = Start-Loader -Message $Message -Style $Style -Color $Color

    try {
        # Execute the script block and capture results
        $result = & $ScriptBlock
        return $result
    }
    finally {
        Stop-Loader $loader
    }
}

Export-ModuleMember -Function Get-LevenshteinDistance, Get-TargetPath, Start-Loader, Stop-Loader, Invoke-WithLoader