<#
.SYNOPSIS
    PowerTool Content Processing Module - File content analysis and processing commands

.TYPE
    Command Module

.DESCRIPTION
    This is a COMMAND MODULE that provides PowerTool commands for processing and analyzing file content.
    This module focuses on the actual content within files rather than file system operations.

    Purpose:
    - Process and analyze file content based on specific criteria
    - Filter and manipulate files based on content properties
    - Image processing and analysis (dimensions, metadata, quality)
    - Document content processing and transformation
    - Media file analysis and filtering

    This module complements FileOperations.psm1 by focusing on file content rather than
    file system structure. Commands should analyze or modify files based on their actual
    content, properties, or metadata rather than just file system attributes.
#>

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
}

Export-ModuleMember -Function Remove-SmallImages -Variable ModuleCommands
