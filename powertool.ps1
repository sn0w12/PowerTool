param (
    [Parameter(Mandatory=$false, Position=0)][string]$Command = "help",
    [Parameter(Position=1)][string]$Path,
    [int]$MinWidth = 0,
    [int]$MinHeight = 0,
    [int]$MinSize = 0,
    [string]$Pattern,
    [switch]$Version
)

# Use current directory if no path provided for commands that need it
if (-not $Path -and $Command.ToLower() -notin @("help", "h", "version", "v")) {
    $Path = Get-Location
}

function Rename-FilesRandomly($dir, $recursive = $false) {
    # Resolve the full path
    $resolvedPath = Resolve-Path $dir -ErrorAction SilentlyContinue
    if (-not $resolvedPath) {
        Write-Error "Directory not found: $dir"
        return
    }

    $dir = $resolvedPath.Path

    $files = if ($recursive) {
        Get-ChildItem -Path $dir -File -Recurse
    } else {
        Get-ChildItem -Path $dir -File
    }

    foreach ($file in $files) {
        $ext = $file.Extension
        $newName = [guid]::NewGuid().ToString() + $ext
        Rename-Item -Path $file.FullName -NewName $newName
    }

    Write-Host "Renamed $($files.Count) file(s) in '$dir'" -ForegroundColor Green
}

function Merge-Directory($dir) {
    # Resolve the full path
    $resolvedPath = Resolve-Path $dir -ErrorAction SilentlyContinue
    if (-not $resolvedPath) {
        Write-Error "Directory not found: $dir"
        return
    }

    $dir = $resolvedPath.Path

    # Get all files recursively, excluding files already in the root
    $files = Get-ChildItem -Path $dir -File -Recurse | Where-Object { $_.DirectoryName -ne $dir }

    $movedCount = 0
    foreach ($file in $files) {
        $destinationPath = Join-Path $dir $file.Name

        # Handle name conflicts by appending a number
        $counter = 1
        while (Test-Path $destinationPath) {
            $nameWithoutExt = [System.IO.Path]::GetFileNameWithoutExtension($file.Name)
            $extension = $file.Extension
            $destinationPath = Join-Path $dir "$nameWithoutExt($counter)$extension"
            $counter++
        }

        Move-Item -Path $file.FullName -Destination $destinationPath
        $movedCount++
    }

    # Remove empty directories
    $removedDirs = 0
    do {
        $emptyDirs = Get-ChildItem -Path $dir -Directory -Recurse | Where-Object {
            (Get-ChildItem $_.FullName -Force | Measure-Object).Count -eq 0
        }
        foreach ($emptyDir in $emptyDirs) {
            Remove-Item -Path $emptyDir.FullName -Force
            $removedDirs++
        }
    } while ($emptyDirs.Count -gt 0)

    Write-Host "Moved $movedCount file(s) to top level and removed $removedDirs empty folder(s) from '$dir'" -ForegroundColor Green
}

function Remove-SmallImages($dir, $minWidth, $minHeight) {
    # Resolve the full path
    $resolvedPath = Resolve-Path $dir -ErrorAction SilentlyContinue
    if (-not $resolvedPath) {
        Write-Error "Directory not found: $dir"
        return
    }

    $dir = $resolvedPath.Path

    # Common image extensions
    $imageExtensions = @('.jpg', '.jpeg', '.png', '.gif', '.bmp', '.tiff', '.webp')

    # Get all image files recursively
    $imageFiles = Get-ChildItem -Path $dir -File -Recurse | Where-Object {
        $imageExtensions -contains $_.Extension.ToLower()
    }

    $removedCount = 0
    foreach ($imageFile in $imageFiles) {
        try {
            # Load image to get dimensions
            Add-Type -AssemblyName System.Drawing
            $image = [System.Drawing.Image]::FromFile($imageFile.FullName)

            $width = $image.Width
            $height = $image.Height

            # Dispose of image object to release file lock
            $image.Dispose()

            # Remove if either dimension is smaller than minimum
            if ($width -lt $minWidth -or $height -lt $minHeight) {
                Remove-Item -Path $imageFile.FullName -Force
                $removedCount++
                Write-Host "Removed: $($imageFile.Name) (${width}x${height})" -ForegroundColor Yellow
            }
        }
        catch {
            Write-Warning "Could not process image: $($imageFile.Name) - $($_.Exception.Message)"
        }
    }

    Write-Host "Removed $removedCount image(s) smaller than ${minWidth}x${minHeight} from '$dir'" -ForegroundColor Green
}

function Remove-TextFromFiles($dir, $pattern) {
    # Resolve the full path
    $resolvedPath = Resolve-Path $dir -ErrorAction SilentlyContinue
    if (-not $resolvedPath) {
        Write-Error "Directory not found: $dir"
        return
    }

    $dir = $resolvedPath.Path

    if (-not $pattern) {
        Write-Error "Pattern parameter is required"
        return
    }

    # Get all txt files recursively
    $txtFiles = Get-ChildItem -Path $dir -Filter "*.txt" -File -Recurse

    $processedCount = 0
    $modifiedCount = 0

    foreach ($txtFile in $txtFiles) {
        try {
            $content = Get-Content -Path $txtFile.FullName -Raw -Encoding UTF8
            $originalContent = $content

            # Remove text matching the regex pattern
            $content = $content -replace $pattern, ""

            # Only write back if content changed
            if ($content -ne $originalContent) {
                Set-Content -Path $txtFile.FullName -Value $content -Encoding UTF8 -NoNewline
                $modifiedCount++
                Write-Host "Modified: $($txtFile.Name)" -ForegroundColor Yellow
            }

            $processedCount++
        }
        catch {
            Write-Warning "Could not process file: $($txtFile.Name) - $($_.Exception.Message)"
        }
    }

    Write-Host "Processed $processedCount txt file(s), modified $modifiedCount file(s) in '$dir'" -ForegroundColor Green
}

function Show-Help {
    param([string]$ForCommand)

    $helpFilePath = Join-Path $PSScriptRoot "help.json"

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
        Write-Host $helpContent.preamble
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
            $shortcutsText = if ($foundCommand.shortcuts) { " ($($foundCommand.shortcuts -join ', '))" } else { "" }
            Write-Host "Command Details:"
            Write-Host "  $($foundCommandName)$shortcutsText"
            Write-Host "    $($foundCommand.summary)"
            Write-Host "    Options: $($foundCommand.options)"
            Write-Host ""
            Write-Host "Examples:"
            foreach ($example in $foundCommand.examples) {
                Write-Host "  $example"
            }
        } else {
            Write-Host "Unknown command: '$ForCommand'. Cannot show specific help." -ForegroundColor Red
            Write-Host "Use 'powertool help' to see all available commands."
        }
    } else {
        # Display full help
        Write-Host $helpContent.preamble
        Write-Host ""
        Write-Host "Commands:"
        foreach ($commandName in $helpContent.commands.PSObject.Properties.Name) {
            $command = $helpContent.commands.$commandName
            $shortcutsText = if ($command.shortcuts) { " ($($command.shortcuts -join ', '))" } else { "" }
            $commandWithShortcuts = "$commandName$shortcutsText"
            Write-Host "  $($commandWithShortcuts.PadRight(25)) $($command.summary)"
            Write-Host "    Options: $($command.options)"
        }
    }
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
        Show-Help -ForCommand $Path # $Path contains the function name, or is $null
    }
    default {
        Write-Host "Unknown command: '$Command'" -ForegroundColor Red
        Show-Help
    }
}
