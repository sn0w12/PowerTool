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

Export-ModuleMember -Function Get-LevenshteinDistance, Get-TargetPath