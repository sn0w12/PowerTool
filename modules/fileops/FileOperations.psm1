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

Export-ModuleMember -Function Rename-FilesRandomly, Merge-Directory
