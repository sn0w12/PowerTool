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

    # Check core settings
    $confirmDestructive = Get-Setting -Key "core.confirm-destructive"
    $verboseMode = Get-Setting -Key "core.verbose"

    # Pre-scan to count files that will be removed
    $filesToRemove = @()
    foreach ($imageFile in $imageFiles) {
        try {
            Add-Type -AssemblyName System.Drawing
            $image = [System.Drawing.Image]::FromFile($imageFile.FullName)
            $width = $image.Width
            $height = $image.Height
            $image.Dispose()

            if ($width -lt $minWidth -or $height -lt $minHeight) {
                $filesToRemove += @{
                    File = $imageFile
                    Width = $width
                    Height = $height
                }
            }
        }
        catch {
            if ($verboseMode) {
                Write-Warning "Could not process image: $($imageFile.Name) - $($_.Exception.Message)"
            }
        }
    }

    if ($confirmDestructive -and $filesToRemove.Count -gt 0) {
        $response = Read-Host "Are you sure you want to delete $($filesToRemove.Count) image(s) smaller than ${minWidth}x${minHeight} from '$dir'? (y/N)"
        if ($response -notmatch '^[Yy]([Ee][Ss])?$') {
            Write-Host "Operation cancelled." -ForegroundColor Yellow
            return
        }
    }

    $removedCount = 0
    foreach ($fileInfo in $filesToRemove) {
        try {
            if ($verboseMode) {
                Write-Host "Removing: $($fileInfo.File.Name) ($($fileInfo.Width)x$($fileInfo.Height))" -ForegroundColor DarkGray
            }
            Remove-Item -Path $fileInfo.File.FullName -Force
            $removedCount++
            if (-not $verboseMode) {
                Write-Host "Removed: $($fileInfo.File.Name) ($($fileInfo.Width)x$($fileInfo.Height))" -ForegroundColor Yellow
            }
        }
        catch {
            Write-Warning "Failed to remove image: $($fileInfo.File.Name) - $($_.Exception.Message)"
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

    # Check core settings
    $confirmDestructive = Get-Setting -Key "core.confirm-destructive"
    $verboseMode = Get-Setting -Key "core.verbose"

    if ($confirmDestructive -and $txtFiles.Count -gt 0) {
        $response = Read-Host "Are you sure you want to modify $($txtFiles.Count) text file(s) in '$dir' using pattern '$pattern'? (y/N)"
        if ($response -notmatch '^[Yy]([Ee][Ss])?$') {
            Write-Host "Operation cancelled." -ForegroundColor Yellow
            return
        }
    }

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
                if ($verboseMode) {
                    Write-Host "Modified: $($txtFile.Name)" -ForegroundColor DarkGray
                } else {
                    Write-Host "Modified: $($txtFile.Name)" -ForegroundColor Yellow
                }
            } elseif ($verboseMode) {
                Write-Host "No changes: $($txtFile.Name)" -ForegroundColor DarkGray
            }

            $processedCount++
        }
        catch {
            Write-Warning "Could not process file: $($txtFile.Name) - $($_.Exception.Message)"
        }
    }

    Write-Host "Processed $processedCount txt file(s), modified $modifiedCount file(s) in '$dir'" -ForegroundColor Green
}

$script:ModuleCommands = @{
    "filter-images" = @{
        Aliases = @("fi")
        Action = {
            $targetPath = Get-TargetPath $Value1
            $effectiveMinWidth = if ($MinSize -gt 0) { $MinSize } else { $MinWidth }
            $effectiveMinHeight = if ($MinSize -gt 0) { $MinSize } else { $MinHeight }

            if ($effectiveMinWidth -eq 0 -or $effectiveMinHeight -eq 0) {
                Write-Error "Please specify either -MinSize or both -MinWidth and -MinHeight parameters"
                return
            }
            Remove-SmallImages -dir $targetPath -minWidth $effectiveMinWidth -minHeight $effectiveMinHeight
        }
        Summary = "Remove images smaller than specified dimensions."
        Options = @{
            0 = @(
                @{ Token = "path"; Type = "OptionalArgument"; Description = "Target directory. Defaults to current location." }
                @{ Token = "MinWidth"; Type = "Parameter"; Description = "Minimum width of images to keep." }
                @{ Token = "int"; Type = "Type"; Description = "Integer value for minimum width." }
                @{ Token = "MinHeight"; Type = "Parameter"; Description = "Minimum height of images to keep." }
                @{ Token = "int"; Type = "Type"; Description = "Integer value for minimum height." }
            )
            1 = @(
                @{ Token = "MinSize"; Type = "Parameter"; Description = "Minimum width AND height for images to keep." }
                @{ Token = "int"; Type = "Type"; Description = "Integer value for minimum size (applies to both width and height)." }
            )
        }
        Examples = @(
            "powertool filter-images -MinWidth 800 -MinHeight 600",
            "powertool fi `"C:\MyFolder`" -MinWidth 1920 -MinHeight 1080",
            "powertool fi -MinSize 800"
        )
    }
    "remove-text" = @{
        Aliases = @("rt")
        Action = {
            $targetPath = Get-TargetPath $Value1
            Remove-TextFromFiles -dir $targetPath -pattern $Value2
        }
        Summary = "Remove text from all txt files using regex pattern."
        Options = @{
            0 = @(
                @{ Token = "path"; Type = "OptionalArgument"; Description = "Target directory. Defaults to current location." }
                @{ Token = "pattern"; Type = "Argument"; Description = "The regular expression pattern to match text for removal." }
            )
        }
        Examples = @(
            "powertool remove-text `"Advertisement.*?End`"",
            "powertool rt `"C:\MyFolder`" `"\d{4}-\d{2}-\d{2}\`""
        )
    }
}

Export-ModuleMember -Function Remove-SmallImages, Remove-TextFromFiles -Variable ModuleCommands
