<#
.SYNOPSIS
    PowerTool Settings Utility Functions Module

.TYPE
    Utility Module

.DESCRIPTION
    Purpose:
    - Provide common settings utility functions used across multiple modules

    This module exports individual functions that can be imported and used by other modules.
    Functions should be useful for managing and using the core settings.
#>

function Confirm-DestructiveOperation {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,

        [Parameter(Mandatory = $false)]
        [string]$DefaultChoice = "N"
    )

    $confirmDestructive = Get-Setting -Key "core.confirm-destructive"

    if (-not $confirmDestructive) {
        return $true
    }

    $response = Read-Host "$Message (y/N)"
    if ($response -match '^[Yy]([Ee][Ss])?$') {
        return $true
    }

    Write-Host "Operation cancelled." -ForegroundColor Yellow
    return $false
}

Export-ModuleMember -Function Confirm-DestructiveOperation