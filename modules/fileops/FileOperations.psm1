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

$script:ModuleCommands = @{
    "rename-random" = @{
        Aliases = @("rr")
        Action = {
            $targetPath = Get-TargetPath -Path $Path
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
            $targetPath = Get-TargetPath -Path $Path
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
}

Export-ModuleMember -Function Rename-FilesRandomly, Merge-Directory -Variable ModuleCommands
