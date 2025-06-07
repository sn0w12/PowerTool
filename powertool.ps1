param (
    [Parameter(Mandatory=$false, Position=0)][string]$Command = "help",
    [Parameter(Position=1)][string]$Path,
    [int]$MinWidth = 0,
    [int]$MinHeight = 0,
    [int]$MinSize = 0,
    [string]$Pattern,
    [switch]$Version
)

Import-Module (Join-Path $PSScriptRoot "modules/Help.psm1") -Force
Import-Module (Join-Path $PSScriptRoot "modules/fileops/FileOperations.psm1") -Force
Import-Module (Join-Path $PSScriptRoot "modules/content/ContentProcessing.psm1") -Force

# Use current directory if no path provided for commands that need it
if (-not $Path -and $Command.ToLower() -notin @("help", "h", "version", "v")) {
    $Path = Get-Location
}

function Show-Version {
    $version = "0.1.0"

    Write-Host "PowerTool v$version" -ForegroundColor Cyan
}

switch ($Command.ToLower()) {
    { $_ -in @("rename-random", "rr") } {
        Rename-FilesRandomly -dir $Path
    }
    { $_ -in @("rename-random-recursive", "rrr") } {
        Rename-FilesRandomly -dir $Path -recursive $true
    }
    { $_ -in @("flatten", "f") } {
        Merge-Directory -dir $Path
    }
    { $_ -in @("filter-images", "fi") } {
        # Use MinSize for both dimensions if provided, otherwise use individual parameters
        $effectiveMinWidth = if ($MinSize -gt 0) { $MinSize } else { $MinWidth }
        $effectiveMinHeight = if ($MinSize -gt 0) { $MinSize } else { $MinHeight }

        if ($effectiveMinWidth -eq 0 -or $effectiveMinHeight -eq 0) {
            Write-Error "Please specify either -MinSize or both -MinWidth and -MinHeight parameters"
            return
        }
        Remove-SmallImages -dir $Path -minWidth $effectiveMinWidth -minHeight $effectiveMinHeight
    }
    { $_ -in @("remove-text", "rt") } {
        Remove-TextFromFiles -dir $Path -pattern $Pattern
    }
    { $_ -in @("version", "v") } {
        Show-Version
    }
    { $_ -in @("help", "h") } {
        Show-Help -ForCommand $Path
    }
    default {
        Write-Host "Unknown command: '$Command'" -ForegroundColor Red
        Show-Help
    }
}
