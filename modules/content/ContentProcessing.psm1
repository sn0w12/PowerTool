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

$script:ModuleCommands = @{
    "filter-images" = @{
        Aliases = @("fi")
        Action = {
            $targetPath = Get-TargetPath -Path $Path
            $effectiveMinWidth = if ($MinSize -gt 0) { $MinSize } else { $MinWidth }
            $effectiveMinHeight = if ($MinSize -gt 0) { $MinSize } else { $MinHeight }

            if ($effectiveMinWidth -eq 0 -or $effectiveMinHeight -eq 0) {
                Write-Error "Please specify either -MinSize or both -MinWidth and -MinHeight parameters"
                return
            }
            Remove-SmallImages -dir $targetPath -minWidth $effectiveMinWidth -minHeight $effectiveMinHeight
        }
        Summary = "Remove images smaller than specified dimensions."
        Options = "[path] -MinWidth <int> -MinHeight <int> | [path] -MinSize <int>"
        Examples = @(
            "powertool filter-images -MinWidth 800 -MinHeight 600",
            "powertool fi `"C:\MyFolder`" -MinWidth 1920 -MinHeight 1080",
            "powertool fi -MinSize 800"
        )
    }
    "remove-text" = @{
        Aliases = @("rt")
        Action = {
            $targetPath = Get-TargetPath -Path $Path
            Remove-TextFromFiles -dir $targetPath -pattern $Pattern
        }
        Summary = "Remove text from all txt files using regex pattern."
        Options = "[path] -Pattern <regex>"
        Examples = @(
            "powertool remove-text -Pattern `"Advertisement.*?End`"",
            "powertool rt `"C:\MyFolder`" -Pattern `"\d{4}-\d{2}-\d{2}\`""
        )
    }
}

Export-ModuleMember -Function Remove-SmallImages, Remove-TextFromFiles -Variable ModuleCommands
