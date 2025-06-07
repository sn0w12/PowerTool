param (
    [Parameter(Mandatory=$false, Position=0)][string]$Command = "help",
    [Parameter(Position=1)][string]$Path,
    [int]$MinWidth = 0,
    [int]$MinHeight = 0,
    [int]$MinSize = 0,
    [string]$Pattern,
    [switch]$Version
)

$modules = @(
    "modules/Help.psm1",
    "modules/Util.psm1",
    "modules/fileops/FileOperations.psm1",
    "modules/content/ContentProcessing.psm1"
)

# CommandDefinitions will store all commands from all modules
$commandDefinitions = @{}
foreach ($modulePathString in $modules) {
    # Use -PassThru to get the module object directly. -Force ensures it reloads.
    # -ErrorAction SilentlyContinue to handle if a module fails to import
    $loadedModule = Import-Module (Join-Path $PSScriptRoot $modulePathString) -Force -PassThru -ErrorAction SilentlyContinue

    if ($loadedModule) {
        if ($loadedModule.ExportedVariables.ContainsKey('ModuleCommands')) {
            $moduleCommandsInfo = $loadedModule.ExportedVariables['ModuleCommands']
            # Get the actual value of the 'ModuleCommands' variable
            $moduleCommandsValue = $moduleCommandsInfo.Value

            if ($null -ne $moduleCommandsValue) {
                if ($moduleCommandsValue.GetType().Name -eq "Hashtable") {
                    foreach ($key in $moduleCommandsValue.Keys) {
                        $commandDefinitions[$key] = $moduleCommandsValue[$key]
                    }
                }
            }
        }
    }
}

$availableCommands = $commandDefinitions.Keys

$matchedCommand = $null
$inputCommand = $Command.ToLower()
Write-Host "DEBUG: User input command: '$inputCommand'" -ForegroundColor DarkCyan

foreach ($cmdKey in $commandDefinitions.Keys) {
    $commandEntry = $commandDefinitions[$cmdKey]
    # Ensure Aliases property exists and is not null before trying to use it
    $aliases = @()
    if ($commandEntry -is [hashtable] -and $commandEntry.ContainsKey('Aliases') -and $null -ne $commandEntry.Aliases) {
        $aliases = $commandEntry.Aliases
    }

    $allVariants = @($cmdKey) + $aliases
    Write-Host "DEBUG: Checking against command '$cmdKey', Aliases: $($aliases -join ', ')" -ForegroundColor Gray
    if ($inputCommand -in $allVariants) {
        $matchedCommand = $cmdKey
        Write-Host "DEBUG: Matched command: '$matchedCommand'" -ForegroundColor Green
        break
    }
}

if ($matchedCommand) {
    Write-Host "DEBUG: Executing action for command: '$matchedCommand'" -ForegroundColor DarkCyan
    & $commandDefinitions[$matchedCommand].Action
} else {
    Write-Host "Unknown command: '$Command'" -ForegroundColor Red

    $suggestions = @()
    foreach ($cmdSugg in $availableCommands) {
        if ($null -ne $cmdSugg -and $cmdSugg -is [string]) {
            $distance = Get-LevenshteinDistance $inputCommand $cmdSugg
            $maxLength = [Math]::Max($inputCommand.Length, $cmdSugg.Length)
            if ($maxLength -gt 0) {
                 $similarity = 1 - ($distance / $maxLength)
                 if ($similarity -gt 0.6 -or $cmdSugg.Contains($inputCommand) -or $inputCommand.Contains($cmdSugg)) {
                    $suggestions += $cmdSugg
                }
            } elseif ($inputCommand -eq $cmdSugg) {
                 $suggestions += $cmdSugg
            }
        }
    }

    if ($suggestions.Count -gt 0) {
        Write-Host "Did you mean one of these?" -ForegroundColor Yellow
        $suggestions | Sort-Object | Get-Unique | ForEach-Object {
            Write-Host "  $($_)" -ForegroundColor Green
        }
    }
    Write-Host "Use 'powertool help' to see all available commands." -ForegroundColor White
}