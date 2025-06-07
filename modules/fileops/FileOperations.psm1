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

    # Check core settings for confirmation and verbose mode
    $confirmDestructive = Get-Setting -Key "core.confirm-destructive"
    $verboseMode = Get-Setting -Key "core.verbose"

    if ($confirmDestructive -and $files.Count -gt 0) {
        $recursiveText = if ($recursive) { " recursively" } else { "" }
        $response = Read-Host "Are you sure you want to rename $($files.Count) file(s)${recursiveText} in '$dir' with random names? (y/N)"
        if ($response -notmatch '^[Yy]([Ee][Ss])?$') {
            Write-Host "Operation cancelled." -ForegroundColor Yellow
            return
        }
    }

    foreach ($file in $files) {
        $ext = $file.Extension
        $newName = [guid]::NewGuid().ToString() + $ext

        if ($verboseMode) {
            Write-Host "Renaming '$($file.Name)' to '$newName'" -ForegroundColor DarkGray
        }

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

    # Check core settings
    $confirmDestructive = Get-Setting -Key "core.confirm-destructive"
    $verboseMode = Get-Setting -Key "core.verbose"

    if ($confirmDestructive -and $files.Count -gt 0) {
        $response = Read-Host "Are you sure you want to flatten directory '$dir' and move $($files.Count) file(s) to the root? (y/N)"
        if ($response -notmatch '^[Yy]([Ee][Ss])?$') {
            Write-Host "Operation cancelled." -ForegroundColor Yellow
            return
        }
    }

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

        if ($verboseMode) {
            Write-Host "Moving '$($file.FullName)' to '$destinationPath'" -ForegroundColor DarkGray
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
            if ($verboseMode) {
                Write-Host "Removing empty directory '$($emptyDir.FullName)'" -ForegroundColor DarkGray
            }
            Remove-Item -Path $emptyDir.FullName -Force
            $removedDirs++
        }
    } while ($emptyDirs.Count -gt 0)

    Write-Host "Moved $movedCount file(s) to top level and removed $removedDirs empty folder(s) from '$dir'" -ForegroundColor Green
}

function Show-TreeRecursive($path, $prefix = "", $depth = 0, $verboseMode = $false, $maxDepth = $null) {
    if ($maxDepth -and $depth -gt $maxDepth) {
        return
    }

    try {
        $items = Get-ChildItem -Path $path -ErrorAction Stop | Sort-Object @{Expression={$_.PSIsContainer}; Descending=$true}, Name

        for ($i = 0; $i -lt $items.Count; $i++) {
            $item = $items[$i]
            $isLast = ($i -eq ($items.Count - 1))

            $connector = if ($isLast) { "+-- " } else { "|-- " }
            $itemName = $item.Name

            if ($item.PSIsContainer) {
                Write-Host "$prefix$connector" -NoNewline -ForegroundColor DarkGray
                Write-Host $itemName -ForegroundColor Yellow

                if ($isLast) {
                    $newPrefix = $prefix + "    "
                } else {
                    $newPrefix = $prefix + "|   "
                }

                Show-TreeRecursive -path $item.FullName -prefix $newPrefix -depth ($depth + 1) -verboseMode $verboseMode -maxDepth $maxDepth
            } else {
                Write-Host "$prefix$connector" -NoNewline -ForegroundColor DarkGray
                Write-Host $itemName -ForegroundColor White

                if ($verboseMode) {
                    if ($item.Length -lt 1KB) {
                        $size = "$($item.Length)B"
                    } elseif ($item.Length -lt 1MB) {
                        $size = "{0:N1}KB" -f ($item.Length / 1KB)
                    } elseif ($item.Length -lt 1GB) {
                        $size = "{0:N1}MB" -f ($item.Length / 1MB)
                    } else {
                        $size = "{0:N1}GB" -f ($item.Length / 1GB)
                    }
                    Write-Host " ($size)" -ForegroundColor DarkGray
                }
            }
        }
    }
    catch [System.UnauthorizedAccessException] {
        Write-Host "$prefix+-- " -NoNewline -ForegroundColor DarkGray
        Write-Host "[Access Denied]" -ForegroundColor Red
    }
    catch [System.IO.DirectoryNotFoundException] {
        Write-Host "$prefix+-- " -NoNewline -ForegroundColor DarkGray
        Write-Host "[Directory Not Found]" -ForegroundColor Red
    }
    catch {
        Write-Host "$prefix+-- " -NoNewline -ForegroundColor DarkGray
        Write-Host "[Error: $($_.Exception.Message)]" -ForegroundColor Red
        if ($verboseMode) {
            Write-Host "$prefix    Exception Type: $($_.Exception.GetType().Name)" -ForegroundColor DarkRed
        }
    }
}

function Show-DirectoryTree($dir, $maxDepth = $null) {
    $resolvedPath = Resolve-Path $dir -ErrorAction SilentlyContinue
    if (-not $resolvedPath) {
        Write-Error "Directory not found: $dir"
        return
    }

    $dir = $resolvedPath.Path
    $verboseMode = Get-Setting -Key "core.verbose"

    Write-Host "Directory tree for: " -NoNewline -ForegroundColor Blue
    Write-Host $dir -ForegroundColor Cyan
    Write-Host ""

    Show-TreeRecursive -path $dir -verboseMode $verboseMode -maxDepth $maxDepth
}

$script:ModuleCommands = @{
    "rename-random" = @{
        Aliases = @("rr")
        Action = {
            $targetPath = Get-TargetPath $Value1
            $useRecursive = $PSBoundParameters.ContainsKey('Recursive') -and $Recursive
            Rename-FilesRandomly -dir $targetPath -recursive $useRecursive
        }
        Summary = "Rename all files in a folder with random names."
        Options = @{
            0 = @(
                @{ Token = "path"; Type = "OptionalArgument"; Description = "Target directory. Defaults to current location if omitted." }
                @{ Token = "Recursive"; Type = "OptionalParameter"; Description = "Process files in subdirectories recursively." }
            )
        }
        Examples = @(
            "powertool rename-random",
            "powertool rr `"C:\MyFolder`"",
            "powertool rename-random -recursive",
            "powertool rr `"C:\MyFolder`" -recursive"
        )
    }
    "flatten" = @{
        Aliases = @("f")
        Action = {
            $targetPath = Get-TargetPath $Value1
            Merge-Directory -dir $targetPath
        }
        Summary = "Move all files from subdirectories to the top level."
        Options = @{
            0 = @(
                @{ Token = "path"; Type = "OptionalArgument"; Description = "Target directory. Defaults to current location if omitted." }
            )
        }
        Examples = @(
            "powertool flatten",
            "powertool f `"C:\MyFolder`""
        )
    }
    "tree" = @{
        Aliases = @("tr")
        Action = {
            $targetPath = Get-TargetPath $Value1
            $depth = if ($Value2 -and $Value2 -match '^\d+$') { [int]$Value2 } else { $null }
            Show-DirectoryTree -dir $targetPath -maxDepth $depth
        }
        Summary = "Display directory structure in a tree format."
        Options = @{
            0 = @(
                @{ Token = "path"; Type = "OptionalArgument"; Description = "Target directory. Defaults to current location if omitted." }
                @{ Token = "maxDepth"; Type = "OptionalArgument"; Description = "Maximum depth to display. Unlimited if omitted." }
            )
        }
        Examples = @(
            "powertool tree",
            "powertool tr `"C:\MyFolder`"",
            "powertool tree . 3",
            "powertool tr `"C:\Projects`" 2"
        )
    }
}

Export-ModuleMember -Function Rename-FilesRandomly, Merge-Directory, Show-DirectoryTree -Variable ModuleCommands
