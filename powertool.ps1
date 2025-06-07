param (
    [Parameter(Mandatory=$false, Position=0)][string]$Command = "help",
    [Parameter(Position=1)][string]$Path,
    [int]$MinWidth = 0,
    [int]$MinHeight = 0,
    [int]$MinSize = 0,
    [string]$Pattern
)

$script:version = "0.1.0"
$modules = @(
    "modules/Help.psm1",
    "modules/Util.psm1",
    "modules/fileops/FileOperations.psm1",
    "modules/content/ContentProcessing.psm1"
)

$script:commandDefinitions = @{}
$script:commandModuleMap = @{}
$script:aliasMap = @{}

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
                    # Extract module name from path for display
                    $moduleName = (Split-Path $modulePathString -Leaf) -replace '\.psm1$', ''

                    foreach ($key in $moduleCommandsValue.Keys) {
                        $commandEntry = $moduleCommandsValue[$key]
                        $script:commandDefinitions[$key] = $commandEntry
                        $script:commandModuleMap[$key] = $moduleName

                        # Check for duplicate aliases
                        if ($commandEntry -is [hashtable] -and $commandEntry.ContainsKey('Aliases') -and $null -ne $commandEntry.Aliases) {
                            foreach ($alias in $commandEntry.Aliases) {
                                if ($script:aliasMap.ContainsKey($alias)) {
                                    Write-Warning "Duplicate alias '$alias' found: used by both '$($script:aliasMap[$alias])' and '$key'"
                                } else {
                                    $script:aliasMap[$alias] = $key
                                }
                            }
                        }
                    }
                } else {
                    Write-Warning "ModuleCommands exported by '$modulePathString' is not a Hashtable."
                }
            }
        } else {
            # Module does not export 'ModuleCommands', which is fine.
        }
    } else {
        Write-Warning "Failed to load module: $modulePathString"
    }
}

$availableCommands = $script:commandDefinitions.Keys

$matchedCommand = $null
$inputCommand = $Command.ToLower()

foreach ($cmdKey in $script:commandDefinitions.Keys) {
    $commandEntry = $script:commandDefinitions[$cmdKey]
    # Ensure Aliases property exists and is not null before trying to use it
    $aliases = @()
    if ($commandEntry -is [hashtable] -and $commandEntry.ContainsKey('Aliases') -and $null -ne $commandEntry.Aliases) {
        $aliases = $commandEntry.Aliases
    }

    $allVariants = @($cmdKey) + $aliases
    if ($inputCommand -in $allVariants) {
        $matchedCommand = $cmdKey
        break
    }
}

if ($matchedCommand) {
    $actionScriptBlock = $script:commandDefinitions[$matchedCommand].Action
    # Recreate the scriptblock in the current scope to ensure $script: variables
    # (like $script:commandDefinitions used by the help action)
    # resolve to this (powertool.ps1) script's scope.
    $actionToExecute = [scriptblock]::Create($actionScriptBlock.ToString())
    & $actionToExecute
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