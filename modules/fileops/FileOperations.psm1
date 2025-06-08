<#
.SYNOPSIS
    PowerTool File Operations Module - Core file and directory manipulation commands

.TYPE
    Command Module

.DESCRIPTION
    This is a COMMAND MODULE that provides PowerTool commands for file and directory operations.

    Purpose:
    - File and directory manipulation (rename, move, merge, etc.)
    - File metadata inspection and analysis
    - File integrity and hashing operations

    This module exports PowerTool commands through the $ModuleCommands variable.
    Each command should have a well-defined purpose related to file/directory operations
    and should follow PowerTool's command structure with proper aliases, summaries,
    options, and examples.
#>

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

    # Check core settings for verbose mode
    $verboseMode = Get-Setting -Key "core.verbose"

    if ($files.Count -gt 0) {
        $recursiveText = if ($recursive) { " recursively" } else { "" }
        $confirmed = Confirm-DestructiveOperation -Message "Are you sure you want to rename $($files.Count) file(s)${recursiveText} in '$dir' with random names?"
        if (-not $confirmed) {
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
    $verboseMode = Get-Setting -Key "core.verbose"
    $confirmed = Confirm-DestructiveOperation -Message "Are you sure you want to flatten directory '$dir' and move $($files.Count) file(s) to the root?"
    if (-not $confirmed) {
        return
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

function Show-FileMetadata($path, $pattern = $null, $recursive = $false) {
    # Resolve the full path
    $resolvedPath = Resolve-Path $path -ErrorAction SilentlyContinue
    if (-not $resolvedPath) {
        Write-Error "Path not found: $path"
        return
    }

    $targetPath = $resolvedPath.Path
    $verboseMode = Get-Setting -Key "core.verbose"

    # Get files based on parameters
    if (Test-Path $targetPath -PathType Leaf) {
        # Single file
        $files = @(Get-Item $targetPath)
    } else {
        # Directory - get files with optional pattern and recursion
        $getChildItemParams = @{
            Path = $targetPath
            File = $true
        }

        if ($recursive) {
            $getChildItemParams.Recurse = $true
        }

        if ($pattern) {
            $getChildItemParams.Filter = $pattern
        }

        $files = Get-ChildItem @getChildItemParams
    }

    if ($files.Count -eq 0) {
        Write-Host "No files found." -ForegroundColor Yellow
        return
    }

    foreach ($file in $files) {
        Write-Host ""
        Write-Host "File: " -NoNewline -ForegroundColor Blue
        Write-Host $file.FullName -ForegroundColor Cyan
        Write-Host ("=" * ($file.FullName.Length + 6)) -ForegroundColor DarkGray

        # Basic file properties
        Write-Host "Name:           " -NoNewline -ForegroundColor Green
        Write-Host $file.Name

        Write-Host "Size:           " -NoNewline -ForegroundColor Green
        if ($file.Length -lt 1KB) {
            Write-Host "$($file.Length) bytes"
        } elseif ($file.Length -lt 1MB) {
            Write-Host ("{0:N2} KB ({1:N0} bytes)" -f ($file.Length / 1KB), $file.Length)
        } elseif ($file.Length -lt 1GB) {
            Write-Host ("{0:N2} MB ({1:N0} bytes)" -f ($file.Length / 1MB), $file.Length)
        } else {
            Write-Host ("{0:N2} GB ({1:N0} bytes)" -f ($file.Length / 1GB), $file.Length)
        }

        Write-Host "Extension:      " -NoNewline -ForegroundColor Green
        Write-Host $(if ($file.Extension) { $file.Extension } else { "(none)" })

        Write-Host "Directory:      " -NoNewline -ForegroundColor Green
        Write-Host $file.DirectoryName

        Write-Host "Created:        " -NoNewline -ForegroundColor Green
        Write-Host $file.CreationTime.ToString("yyyy-MM-dd HH:mm:ss")

        Write-Host "Modified:       " -NoNewline -ForegroundColor Green
        Write-Host $file.LastWriteTime.ToString("yyyy-MM-dd HH:mm:ss")

        Write-Host "Accessed:       " -NoNewline -ForegroundColor Green
        Write-Host $file.LastAccessTime.ToString("yyyy-MM-dd HH:mm:ss")

        Write-Host "Attributes:     " -NoNewline -ForegroundColor Green
        Write-Host $file.Attributes

        # Security information
        try {
            $acl = Get-Acl $file.FullName -ErrorAction Stop
            Write-Host "Owner:          " -NoNewline -ForegroundColor Green
            Write-Host $acl.Owner

            if ($verboseMode) {
                Write-Host ""
                Write-Host "Access Rules:" -ForegroundColor Yellow
                foreach ($access in $acl.Access) {
                    Write-Host "  $($access.IdentityReference): $($access.FileSystemRights) ($($access.AccessControlType))" -ForegroundColor DarkCyan
                }
            }
        }
        catch {
            Write-Host "Owner:          " -NoNewline -ForegroundColor Green
            Write-Host "(Unable to retrieve)" -ForegroundColor DarkRed
        }

        # File hash (for single files or when verbose)
        if ($files.Count -eq 1 -or $verboseMode) {
            try {
                Write-Host "MD5 Hash:       " -NoNewline -ForegroundColor Green
                $hash = Get-FileHash $file.FullName -Algorithm MD5 -ErrorAction Stop
                Write-Host $hash.Hash -ForegroundColor DarkGray

                Write-Host "SHA256 Hash:    " -NoNewline -ForegroundColor Green
                $hash = Get-FileHash $file.FullName -Algorithm SHA256 -ErrorAction Stop
                Write-Host $hash.Hash -ForegroundColor DarkGray
            }
            catch {
                Write-Host "Hash:           " -NoNewline -ForegroundColor Green
                Write-Host "(Unable to calculate)" -ForegroundColor DarkRed
            }
        }

        # Extended metadata - always show custom metadata
        Write-Host ""
        Write-Host "Extended Properties:" -ForegroundColor Yellow

        try {
            # Get Shell COM object for extended properties
            $shell = New-Object -ComObject Shell.Application -ErrorAction SilentlyContinue
            $folder = $shell.Namespace($file.DirectoryName)
            $fileItem = $folder.ParseName($file.Name)

            # Get all available properties (0-400+ range)
            $customProperties = @{}
            for ($i = 0; $i -lt 400; $i++) {
                try {
                    $propName = $folder.GetDetailsOf($null, $i)
                    if ($propName -and $propName.Trim() -ne "") {
                        $propValue = $folder.GetDetailsOf($fileItem, $i)
                        if ($propValue -and $propValue.Trim() -ne "") {
                            $customProperties[$propName] = $propValue
                        }
                    }
                }
                catch {
                    # Ignore individual property errors
                    continue
                }
            }

            # Display properties in organized sections
            $basicProps = @("Name", "Size", "Type", "Date modified", "Date created", "Date accessed")
            $mediaProps = @("Length", "Frame width", "Frame height", "Bit rate", "Audio sample rate", "Channels", "Video compression", "Audio format", "Total bitrate")
            $documentProps = @("Title", "Subject", "Author", "Category", "Keywords", "Comments", "Template", "Last saved by", "Revision number", "Version", "Program name", "Company", "Manager")
            $imageProps = @("Dimensions", "Width", "Height", "Horizontal resolution", "Vertical resolution", "Bit depth", "Compression", "Resolution unit", "Color representation", "Camera maker", "Camera model", "Date taken", "Orientation", "Exposure time", "F-stop", "ISO speed", "Exposure bias", "Focal length", "Max aperture", "Metering mode", "Subject distance", "Flash mode", "Light source", "35mm focal length", "Lens maker", "Lens model")

            # Basic properties
            $basicFound = $false
            foreach ($prop in $basicProps) {
                if ($customProperties.ContainsKey($prop)) {
                    if (-not $basicFound) {
                        Write-Host "  Basic Properties:" -ForegroundColor Cyan
                        $basicFound = $true
                    }
                    Write-Host "    $prop" -NoNewline -ForegroundColor DarkCyan
                    Write-Host ": $($customProperties[$prop])"
                }
            }

            # Document properties
            $docFound = $false
            foreach ($prop in $documentProps) {
                if ($customProperties.ContainsKey($prop)) {
                    if (-not $docFound) {
                        Write-Host "  Document Properties:" -ForegroundColor Cyan
                        $docFound = $true
                    }
                    Write-Host "    $prop" -NoNewline -ForegroundColor DarkCyan
                    Write-Host ": $($customProperties[$prop])"
                }
            }

            # Image/Camera properties (EXIF)
            $imageFound = $false
            foreach ($prop in $imageProps) {
                if ($customProperties.ContainsKey($prop)) {
                    if (-not $imageFound) {
                        Write-Host "  Image/Camera Properties:" -ForegroundColor Cyan
                        $imageFound = $true
                    }
                    Write-Host "    $prop" -NoNewline -ForegroundColor DarkCyan
                    Write-Host ": $($customProperties[$prop])"
                }
            }

            # Media properties
            $mediaFound = $false
            foreach ($prop in $mediaProps) {
                if ($customProperties.ContainsKey($prop)) {
                    if (-not $mediaFound) {
                        Write-Host "  Media Properties:" -ForegroundColor Cyan
                        $mediaFound = $true
                    }
                    Write-Host "    $prop" -NoNewline -ForegroundColor DarkCyan
                    Write-Host ": $($customProperties[$prop])"
                }
            }

            # Other custom properties
            $otherProps = @{}
            foreach ($prop in $customProperties.Keys) {
                if ($prop -notin ($basicProps + $documentProps + $imageProps + $mediaProps)) {
                    $otherProps[$prop] = $customProperties[$prop]
                }
            }

            if ($otherProps.Count -gt 0) {
                Write-Host "  Other Properties:" -ForegroundColor Cyan
                foreach ($prop in $otherProps.Keys | Sort-Object) {
                    Write-Host "    $prop" -NoNewline -ForegroundColor DarkCyan
                    Write-Host ": $($otherProps[$prop])"
                }
            }

            # Try to read additional custom metadata using .NET (improved EXIF handling)
            try {
                Add-Type -AssemblyName System.Drawing -ErrorAction SilentlyContinue

                # For image files, try to read EXIF data directly with better handling
                if ($file.Extension -match '\.(jpg|jpeg|tiff|tif)$') {
                    try {
                        $image = [System.Drawing.Image]::FromFile($file.FullName)
                        $exifFound = $false
                        $validExifCount = 0

                        # Define common EXIF property IDs and their meanings
                        $exifTags = @{
                            0x010F = "Camera Manufacturer"
                            0x0110 = "Camera Model"
                            0x0112 = "Orientation"
                            0x011A = "X Resolution"
                            0x011B = "Y Resolution"
                            0x0128 = "Resolution Unit"
                            0x0132 = "Date Taken"
                            0x829A = "Exposure Time"
                            0x829D = "F Number"
                            0x8822 = "Exposure Program"
                            0x8827 = "ISO Speed"
                            0x9003 = "Date Original"
                            0x9004 = "Date Digitized"
                            0x920A = "Focal Length"
                            0x9209 = "Flash"
                        }

                        foreach ($propItem in $image.PropertyItems) {
                            try {
                                $propId = $propItem.Id
                                $propName = if ($exifTags.ContainsKey($propId)) { $exifTags[$propId] } else { "Property ID $propId" }

                                # Handle different data types
                                $propValue = $null
                                switch ($propItem.Type) {
                                    1 { # Byte
                                        if ($propItem.Value.Length -eq 1) {
                                            $propValue = $propItem.Value[0]
                                        }
                                    }
                                    2 { # ASCII string
                                        $propValue = [System.Text.Encoding]::ASCII.GetString($propItem.Value).TrimEnd([char]0)
                                    }
                                    3 { # Short (16-bit)
                                        if ($propItem.Value.Length -ge 2) {
                                            $propValue = [BitConverter]::ToUInt16($propItem.Value, 0)
                                        }
                                    }
                                    4 { # Long (32-bit)
                                        if ($propItem.Value.Length -ge 4) {
                                            $propValue = [BitConverter]::ToUInt32($propItem.Value, 0)
                                        }
                                    }
                                    5 { # Rational (two 32-bit values)
                                        if ($propItem.Value.Length -ge 8) {
                                            $numerator = [BitConverter]::ToUInt32($propItem.Value, 0)
                                            $denominator = [BitConverter]::ToUInt32($propItem.Value, 4)
                                            if ($denominator -ne 0) {
                                                $propValue = "$numerator/$denominator"
                                                if ($numerator % $denominator -eq 0) {
                                                    $propValue += " ($($numerator / $denominator))"
                                                }
                                            }
                                        }
                                    }
                                    default {
                                        # For other types, try to display as hex if small enough
                                        if ($propItem.Value.Length -le 16) {
                                            $propValue = "0x" + [BitConverter]::ToString($propItem.Value).Replace("-", "")
                                        }
                                    }
                                }

                                # Only display if we have a valid, readable value
                                if ($propValue -and $propValue.ToString().Length -gt 0 -and $propValue.ToString().Length -lt 200) {
                                    # Check if the value contains only printable characters
                                    $valueStr = $propValue.ToString()
                                    $isPrintable = $true
                                    foreach ($char in $valueStr.ToCharArray()) {
                                        if ([int]$char -lt 32 -and $char -ne "`t" -and $char -ne "`n" -and $char -ne "`r") {
                                            $isPrintable = $false
                                            break
                                        }
                                    }

                                    if ($isPrintable) {
                                        if (-not $exifFound) {
                                            Write-Host "  EXIF Data:" -ForegroundColor Cyan
                                            $exifFound = $true
                                        }
                                        Write-Host "    $propName" -NoNewline -ForegroundColor DarkCyan
                                        Write-Host ": $valueStr"
                                        $validExifCount++
                                    }
                                }
                            }
                            catch {
                                # Ignore individual EXIF property errors
                                continue
                            }
                        }

                        if ($exifFound -and $validExifCount -eq 0) {
                            Write-Host "    No readable EXIF data found" -ForegroundColor DarkGray
                        }

                        $image.Dispose()
                    }
                    catch {
                        # Ignore errors when reading EXIF data
                    }
                }

                # For PNG files, try to read custom metadata chunks
                if ($file.Extension -match '\.(png)$') {
                    try {
                        $pngMetadata = Read-PngMetadata -FilePath $file.FullName
                        if ($pngMetadata.Count -gt 0) {
                            Write-Host "  PNG Metadata:" -ForegroundColor Cyan
                            foreach ($key in $pngMetadata.Keys | Sort-Object) {
                                Write-Host "    $key" -NoNewline -ForegroundColor DarkCyan
                                Write-Host ": $($pngMetadata[$key])"
                            }
                        }
                    }
                    catch {
                        # Ignore PNG metadata reading errors
                    }
                }
            }
            catch {
                # Ignore if System.Drawing is not available
            }

            # Try Windows Runtime metadata (for modern file formats)
            try {
                Add-Type -AssemblyName Windows.Storage -ErrorAction SilentlyContinue
                $wrtMetadata = Read-WindowsRuntimeMetadata -FilePath $file.FullName
                if ($wrtMetadata.Count -gt 0) {
                    Write-Host "  Windows Runtime Metadata:" -ForegroundColor Cyan
                    foreach ($key in $wrtMetadata.Keys | Sort-Object) {
                        Write-Host "    $key" -NoNewline -ForegroundColor DarkCyan
                        Write-Host ": $($wrtMetadata[$key])"
                    }
                }
            }
            catch {
                # Ignore WRT metadata errors
            }

            # Clean up COM object
            try {
                [System.Runtime.InteropServices.Marshal]::ReleaseComObject($shell) | Out-Null
            }
            catch {
                # Ignore cleanup errors
            }

            if ($customProperties.Count -eq 0) {
                Write-Host "  No extended properties found." -ForegroundColor DarkGray
            }
        }
        catch {
            Write-Host "  Could not retrieve extended properties: $($_.Exception.Message)" -ForegroundColor DarkRed
        }

        # Alternative Stream Information (for files with custom metadata streams)
        try {
            $streams = Get-Item $file.FullName -Stream * -ErrorAction SilentlyContinue | Where-Object { $_.Stream -ne ':$DATA' }
            if ($streams) {
                Write-Host "  Alternate Data Streams:" -ForegroundColor Cyan
                foreach ($stream in $streams) {
                    Write-Host "    $($stream.Stream)" -NoNewline -ForegroundColor DarkCyan
                    Write-Host " ($($stream.Length) bytes)"

                    # Try to read small text streams
                    if ($stream.Length -lt 1KB -and $stream.Length -gt 0) {
                        try {
                            $streamContent = Get-Content -Path $file.FullName -Stream $stream.Stream -Raw -ErrorAction SilentlyContinue
                            if ($streamContent -and $streamContent.Trim() -ne "") {
                                Write-Host "      Content: $($streamContent.Trim())" -ForegroundColor DarkGray
                            }
                        }
                        catch {
                            # Ignore stream read errors
                        }
                    }
                }
            }
        }
        catch {
            # Ignore if alternate streams are not supported
        }
    }

    Write-Host ""
    Write-Host "Total: $($files.Count) file(s)" -ForegroundColor Blue
}

function Read-PngMetadata($FilePath) {
    $metadata = @{}

    try {
        $bytes = [System.IO.File]::ReadAllBytes($FilePath)

        # PNG signature check
        if ($bytes.Length -lt 8 -or $bytes[0] -ne 0x89 -or $bytes[1] -ne 0x50 -or $bytes[2] -ne 0x4E -or $bytes[3] -ne 0x47) {
            return $metadata
        }

        $offset = 8  # Skip PNG signature

        while ($offset -lt ($bytes.Length - 12)) {  # Need at least 12 bytes for chunk header + CRC
            try {
                # Read chunk length (4 bytes, big-endian)
                if ($offset + 4 -gt $bytes.Length) { break }
                $lengthBytes = $bytes[$offset..($offset + 3)]
                [Array]::Reverse($lengthBytes)  # Convert from big-endian
                $chunkLength = [BitConverter]::ToUInt32($lengthBytes, 0)
                $offset += 4

                # Read chunk type (4 bytes)
                if ($offset + 4 -gt $bytes.Length) { break }
                $chunkType = [System.Text.Encoding]::ASCII.GetString($bytes, $offset, 4)
                $offset += 4

                # Handle text chunks
                if ($chunkType -eq "tEXt" -or $chunkType -eq "zTXt" -or $chunkType -eq "iTXt") {
                    if ($chunkLength -gt 0 -and $chunkLength -lt 65536 -and ($offset + $chunkLength) -le $bytes.Length) {  # Reasonable size limit
                        $chunkData = $bytes[$offset..($offset + $chunkLength - 1)]

                        if ($chunkType -eq "tEXt") {
                            # Uncompressed Latin-1 text
                            try {
                                $textData = [System.Text.Encoding]::GetEncoding("ISO-8859-1").GetString($chunkData)
                                $nullIndex = $textData.IndexOf([char]0)
                                if ($nullIndex -gt 0 -and $nullIndex -lt $textData.Length - 1) {
                                    $key = $textData.Substring(0, $nullIndex)
                                    $value = $textData.Substring($nullIndex + 1)
                                    if ($key.Length -gt 0 -and $value.Length -gt 0) {
                                        $metadata[$key] = $value
                                    }
                                }
                            }
                            catch {
                                # Try UTF-8 as fallback
                                try {
                                    $textData = [System.Text.Encoding]::UTF8.GetString($chunkData)
                                    $nullIndex = $textData.IndexOf([char]0)
                                    if ($nullIndex -gt 0 -and $nullIndex -lt $textData.Length - 1) {
                                        $key = $textData.Substring(0, $nullIndex)
                                        $value = $textData.Substring($nullIndex + 1)
                                        if ($key.Length -gt 0 -and $value.Length -gt 0) {
                                            $metadata[$key] = $value
                                        }
                                    }
                                }
                                catch {
                                    # Ignore encoding errors
                                }
                            }
                        }
                        elseif ($chunkType -eq "zTXt") {
                            # Compressed Latin-1 text
                            try {
                                # Find null separator between keyword and compressed data
                                $nullIndex = -1
                                for ($i = 0; $i -lt $chunkData.Length; $i++) {
                                    if ($chunkData[$i] -eq 0) {
                                        $nullIndex = $i
                                        break
                                    }
                                }

                                if ($nullIndex -gt 0 -and $nullIndex + 2 -lt $chunkData.Length) {
                                    $key = [System.Text.Encoding]::GetEncoding("ISO-8859-1").GetString($chunkData[0..($nullIndex - 1)])
                                    $compressionMethod = $chunkData[$nullIndex + 1]

                                    if ($compressionMethod -eq 0) {  # zlib compression
                                        $compressedData = $chunkData[($nullIndex + 2)..($chunkData.Length - 1)]

                                        # Try to decompress using .NET DeflateStream (skip zlib header)
                                        if ($compressedData.Length -gt 2) {
                                            try {
                                                $deflateData = $compressedData[2..($compressedData.Length - 1)]  # Skip zlib header
                                                $inputStream = New-Object System.IO.MemoryStream($deflateData)
                                                $deflateStream = New-Object System.IO.Compression.DeflateStream($inputStream, [System.IO.Compression.CompressionMode]::Decompress)
                                                $outputStream = New-Object System.IO.MemoryStream
                                                $deflateStream.CopyTo($outputStream)
                                                $decompressedBytes = $outputStream.ToArray()
                                                $value = [System.Text.Encoding]::GetEncoding("ISO-8859-1").GetString($decompressedBytes)

                                                if ($key.Length -gt 0 -and $value.Length -gt 0) {
                                                    $metadata[$key] = $value
                                                }

                                                $deflateStream.Close()
                                                $inputStream.Close()
                                                $outputStream.Close()
                                            }
                                            catch {
                                                # Ignore decompression errors
                                            }
                                        }
                                    }
                                }
                            }
                            catch {
                                # Ignore zTXt parsing errors
                            }
                        }
                        elseif ($chunkType -eq "iTXt") {
                            # International text (UTF-8)
                            try {
                                # Find null separators
                                $nullPositions = @()
                                for ($i = 0; $i -lt $chunkData.Length; $i++) {
                                    if ($chunkData[$i] -eq 0) {
                                        $nullPositions += $i
                                    }
                                }

                                if ($nullPositions.Length -ge 3) {
                                    $key = [System.Text.Encoding]::UTF8.GetString($chunkData[0..($nullPositions[0] - 1)])
                                    $compressionFlag = $chunkData[$nullPositions[0] + 1]
                                    $compressionMethod = $chunkData[$nullPositions[0] + 2]

                                    # Skip language tag and translated keyword
                                    $textStart = $nullPositions[2] + 1
                                    if ($textStart -lt $chunkData.Length) {
                                        if ($compressionFlag -eq 0) {
                                            # Uncompressed
                                            $value = [System.Text.Encoding]::UTF8.GetString($chunkData[$textStart..($chunkData.Length - 1)])
                                        } else {
                                            # Compressed (similar to zTXt but UTF-8)
                                            if ($compressionMethod -eq 0 -and $chunkData.Length -gt $textStart + 2) {
                                                try {
                                                    $compressedData = $chunkData[($textStart + 2)..($chunkData.Length - 1)]
                                                    $inputStream = New-Object System.IO.MemoryStream($compressedData)
                                                    $deflateStream = New-Object System.IO.Compression.DeflateStream($inputStream, [System.IO.Compression.CompressionMode]::Decompress)
                                                    $outputStream = New-Object System.IO.MemoryStream
                                                    $deflateStream.CopyTo($outputStream)
                                                    $decompressedBytes = $outputStream.ToArray()
                                                    $value = [System.Text.Encoding]::UTF8.GetString($decompressedBytes)

                                                    $deflateStream.Close()
                                                    $inputStream.Close()
                                                    $outputStream.Close()
                                                }
                                                catch {
                                                    $value = $null
                                                }
                                            }
                                        }

                                        if ($key.Length -gt 0 -and $value -and $value.Length -gt 0) {
                                            $metadata[$key] = $value
                                        }
                                    }
                                }
                            }
                            catch {
                                # Ignore iTXt parsing errors
                            }
                        }
                    }
                }
                elseif ($chunkType -eq "IEND") {
                    # End of PNG file
                    break
                }

                # Move to next chunk
                $offset += $chunkLength + 4  # Skip chunk data and CRC

                # Safety check to prevent infinite loops
                if ($chunkLength -gt 1000000 -or $offset -ge $bytes.Length) {
                    break
                }
            }
            catch {
                # If we hit any error parsing a chunk, try to continue
                $offset += 1
                continue
            }
        }
    }
    catch {
        # Ignore file reading errors
    }

    return $metadata
}

function Read-WindowsRuntimeMetadata($FilePath) {
    $metadata = @{
    }

    try {
        # Try to use Windows.Storage.FileProperties for modern metadata
        if ([System.Environment]::OSVersion.Version.Major -ge 10) {
            # This is a simplified approach - full WRT implementation would be more complex
            $fileInfo = New-Object System.IO.FileInfo($FilePath)

            # Try to read extended file properties using WMI
            $wmiQuery = "SELECT * FROM CIM_DataFile WHERE Name = '$($FilePath.Replace('\', '\\'))'"
            $wmiFile = Get-WmiObject -Query $wmiQuery -ErrorAction SilentlyContinue

            if ($wmiFile) {
                $properties = @{
                    "File Version" = $wmiFile.Version
                    "Description" = $wmiFile.Description
                    "Manufacturer" = $wmiFile.Manufacturer
                    "Product Name" = $wmiFile.ProductName
                    "Product Version" = $wmiFile.ProductVersion
                    "Copyright" = $wmiFile.Copyright
                }

                foreach ($prop in $properties.Keys) {
                    if ($properties[$prop] -and $properties[$prop].Trim() -ne "") {
                        $metadata[$prop] = $properties[$prop]
                    }
                }
            }
        }
    }
    catch {
        # Ignore WRT metadata errors
    }

    return $metadata
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
    $verboseMode = Get-Setting -Key "core.verbose"

    if ($txtFiles.Count -gt 0) {
        $confirmed = Confirm-DestructiveOperation -Message "Are you sure you want to modify $($txtFiles.Count) text file(s) in '$dir' using pattern '$pattern'?"
        if (-not $confirmed) {
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

function Get-PowerToolFileHash($path, $algorithm = "SHA256") {
    # Resolve the full path
    $resolvedPath = Resolve-Path $path -ErrorAction SilentlyContinue
    if (-not $resolvedPath) {
        Write-Error "File or directory not found: $path"
        return
    }

    $path = $resolvedPath.Path
    $verboseMode = Get-Setting -Key "core.verbose"

    # Validate algorithm
    $validAlgorithms = @("MD5", "SHA1", "SHA256", "SHA384", "SHA512")
    $algorithm = $algorithm.ToUpper()
    if ($algorithm -notin $validAlgorithms) {
        Write-Error "Invalid algorithm '$algorithm'. Valid options: $($validAlgorithms -join ', ')"
        return
    }

    # Check if it's a directory or file
    $isDirectory = (Get-Item $path).PSIsContainer

    if ($isDirectory) {
        # Process directory
        $files = Get-ChildItem -Path $path -File -Recurse | Sort-Object FullName

        if ($files.Count -eq 0) {
            Write-Host "No files found in directory: $path" -ForegroundColor Yellow
            return
        }

        Write-Host "Computing $algorithm hashes for $($files.Count) file(s) in: " -NoNewline -ForegroundColor Blue
        Write-Host $path -ForegroundColor Cyan
        Write-Host ""

        foreach ($file in $files) {
            try {
                # Use Microsoft.PowerShell.Utility\Get-FileHash to explicitly call the built-in cmdlet
                $hash = Microsoft.PowerShell.Utility\Get-FileHash -Path $file.FullName -Algorithm $algorithm -ErrorAction Stop
                $relativePath = $file.FullName.Substring($path.Length + 1)

                Write-Host $hash.Hash.ToLower() -NoNewline -ForegroundColor Green
                Write-Host "  " -NoNewline
                Write-Host $relativePath -ForegroundColor White

                if ($verboseMode) {
                    $size = if ($file.Length -lt 1KB) { "$($file.Length)B" }
                           elseif ($file.Length -lt 1MB) { "{0:N1}KB" -f ($file.Length / 1KB) }
                           elseif ($file.Length -lt 1GB) { "{0:N1}MB" -f ($file.Length / 1MB) }
                           else { "{0:N1}GB" -f ($file.Length / 1GB) }
                    Write-Host "    Size: $size, Modified: $($file.LastWriteTime)" -ForegroundColor DarkGray
                }
            }
            catch {
                Write-Host "ERROR" -NoNewline -ForegroundColor Red
                Write-Host "  " -NoNewline
                Write-Host $file.Name -NoNewline -ForegroundColor White
                Write-Host " - $($_.Exception.Message)" -ForegroundColor Red
            }
        }

        Write-Host ""
        Write-Host "Processed $($files.Count) file(s) with $algorithm algorithm" -ForegroundColor Green
    }
    else {
        # Process single file
        try {
            # Use Microsoft.PowerShell.Utility\Get-FileHash to explicitly call the built-in cmdlet
            $hash = Microsoft.PowerShell.Utility\Get-FileHash -Path $path -Algorithm $algorithm -ErrorAction Stop
            $fileInfo = Get-Item $path

            # Header with file info
            Write-Host "File: " -NoNewline -ForegroundColor Blue
            Write-Host $fileInfo.Name -ForegroundColor Cyan
            Write-Host "Algorithm: " -NoNewline -ForegroundColor Blue
            Write-Host $algorithm -ForegroundColor White

            # File size
            $size = if ($fileInfo.Length -lt 1KB) { "$($fileInfo.Length) bytes" }
                   elseif ($fileInfo.Length -lt 1MB) { "{0:N1} KB" -f ($fileInfo.Length / 1KB) }
                   elseif ($fileInfo.Length -lt 1GB) { "{0:N1} MB" -f ($fileInfo.Length / 1MB) }
                   else { "{0:N1} GB" -f ($fileInfo.Length / 1GB) }

            Write-Host "Size: " -NoNewline -ForegroundColor Blue
            Write-Host $size -ForegroundColor White
            Write-Host ""

            Write-Host "Hash:" -ForegroundColor Blue
            Write-Host $hash.Hash.ToLower() -ForegroundColor Green

            if ($verboseMode) {
                Write-Host ""
                Write-Host "Details:" -ForegroundColor Blue
                Write-Host "  Full Path: $($fileInfo.FullName)" -ForegroundColor DarkGray
                Write-Host "  Modified: $($fileInfo.LastWriteTime.ToString('yyyy-MM-dd HH:mm:ss'))" -ForegroundColor DarkGray
                Write-Host "  Created: $($fileInfo.CreationTime.ToString('yyyy-MM-dd HH:mm:ss'))" -ForegroundColor DarkGray
            }
        }
        catch {
            Write-Error "Failed to compute hash for '$path': $($_.Exception.Message)"
        }
    }
}

function Search-Files($path, $name = $null, $content = $null, $extension = $null, $minSize = $null, $maxSize = $null, $modifiedAfter = $null, $modifiedBefore = $null, $recursive = $true, $caseSensitive = $false) {
    # Resolve the full path
    $resolvedPath = Resolve-Path $path -ErrorAction SilentlyContinue
    if (-not $resolvedPath) {
        Write-Error "Directory not found: $path"
        return
    }

    $path = $resolvedPath.Path
    $verboseMode = Get-Setting -Key "core.verbose"
    $isPs7OrGreater = $PSVersionTable.PSVersion.Major -ge 7

    # Check if any search criteria were provided
    $hasSearchCriteria = $name -or $content -or $extension -or $minSize -or $maxSize -or $modifiedAfter -or $modifiedBefore

    if (-not $hasSearchCriteria) {
        Write-Host "No search criteria specified. Please provide at least one filter option:" -ForegroundColor Yellow
        Write-Host "  -Name (filename pattern or text)" -ForegroundColor Green
        Write-Host "  -Content (text content)" -ForegroundColor Green
        Write-Host "  -Extension (file extension)" -ForegroundColor Green
        Write-Host "  -MinSize / -MaxSize (file size)" -ForegroundColor Green
        Write-Host "  -ModifiedAfter / -ModifiedBefore (date)" -ForegroundColor Green
        Write-Host ""
        Write-Host "Examples:" -ForegroundColor Cyan
        Write-Host "  pt sf -Name `"*.txt`"" -ForegroundColor White
        Write-Host "  pt sf -Name `"inanna`"" -ForegroundColor White
        return
    }

    $initialLoader = $null
    $filteredFiles = @()
    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    $searchStats = @{
        FilesInitiallyFound = 0
        FilesAfterMetadataFilters = 0
        FilesConsideredForContentSearch = 0
        TotalDurationMs = 0
    }

    try {
        # Build Get-ChildItem parameters
        $getChildItemParams = @{
            Path = $path
            File = $true
        }

        if ($recursive) {
            $getChildItemParams.Recurse = $true
        }

        if ($hasSearchCriteria) {
            # Start a general loader for file gathering and initial filtering
            $initialLoader = Start-Loader -Message "Searching files " -Style "Spinner" -Color "Cyan"
        }

        # Get all files first
        $allFiles = Get-ChildItem @getChildItemParams
        $searchStats.FilesInitiallyFound = $allFiles.Count

        # Apply filters
        $filteredFiles = $allFiles

        # Name filter (supports wildcards, exact contains, and fuzzy matching)
        if ($name) {
            if ($name.Contains('*') -or $name.Contains('?')) {
                # Use wildcard matching
                if ($caseSensitive) {
                    $filteredFiles = $filteredFiles | Where-Object { $_.Name -clike $name }
                } else {
                    $filteredFiles = $filteredFiles | Where-Object { $_.Name -like $name }
                }
            } else {
                # For simple text, use contains first, then fuzzy matching for broader results
                $exactMatches = @()
                $fuzzyMatches = @()

                foreach ($file in $filteredFiles) {
                    # First try exact contains matching
                    $fileName = if ($caseSensitive) { $file.Name } else { $file.Name.ToLower() }
                    $searchName = if ($caseSensitive) { $name } else { $name.ToLower() }

                    if ($fileName.Contains($searchName)) {
                        $exactMatches += $file
                    } else {
                        # Use fuzzy matching for potential matches
                        $distance = Get-LevenshteinDistance -String1 $fileName -String2 $searchName -CaseSensitive:$caseSensitive
                        $maxLength = [Math]::Max($fileName.Length, $searchName.Length)
                        if ($maxLength -gt 0) {
                            $similarity = 1 - ($distance / $maxLength)
                            # Include files with reasonable similarity or partial matches
                            if ($similarity -gt 0.3 -or $fileName.Contains($searchName.Substring(0, [Math]::Min(3, $searchName.Length)))) {
                                $fuzzyMatches += $file
                            }
                        }
                    }
                }

                # Combine exact matches first, then fuzzy matches
                $filteredFiles = $exactMatches + $fuzzyMatches | Sort-Object Name -Unique
            }
        }

        # Extension filter
        if ($extension) {
            if (-not $extension.StartsWith('.')) {
                $extension = ".$extension"
            }
            if ($caseSensitive) {
                $filteredFiles = $filteredFiles | Where-Object { $_.Extension -ceq $extension }
            } else {
                $filteredFiles = $filteredFiles | Where-Object { $_.Extension -ieq $extension }
            }
        }

        # Size filters
        if ($minSize) {
            $minSizeBytes = Convert-SizeToBytes $minSize
            if ($minSizeBytes -ne $null) {
                $filteredFiles = $filteredFiles | Where-Object { $_.Length -ge $minSizeBytes }
            }
        }

        if ($maxSize) {
            $maxSizeBytes = Convert-SizeToBytes $maxSize
            if ($maxSizeBytes -ne $null) {
                $filteredFiles = $filteredFiles | Where-Object { $_.Length -le $maxSizeBytes }
            }
        }

        # Date filters
        if ($modifiedAfter) {
            try {
                $afterDate = [DateTime]::Parse($modifiedAfter)
                $filteredFiles = $filteredFiles | Where-Object { $_.LastWriteTime -ge $afterDate }
            }
            catch {
                Write-Warning "Invalid date format for modifiedAfter: $modifiedAfter"
            }
        }

        if ($modifiedBefore) {
            try {
                $beforeDate = [DateTime]::Parse($modifiedBefore)
                $filteredFiles = $filteredFiles | Where-Object { $_.LastWriteTime -le $beforeDate }
            }
            catch {
                Write-Warning "Invalid date format for modifiedBefore: $modifiedBefore"
            }
        }

        $searchStats.FilesAfterMetadataFilters = $filteredFiles.Count

        # If content search is requested, pre-filter $filteredFiles to only include text-searchable file types
        if ($content) {
            $filteredFiles = $filteredFiles | Where-Object { $_.Length -lt 50MB -and $_.Extension -match '\.(txt|log|md|xml|json|csv|html?|css|js|ps1|psm1|psd1|py|java|c|cpp|h|cs|vb|sql|ini|cfg|conf|config)$' }
        }

        # Stop the initial loader before content search or final display
        if ($initialLoader) {
            Stop-Loader $initialLoader
            $initialLoader = $null
        }

        # Content search (for text files)
        if ($content) {
            if ($filteredFiles.Count -gt 0) {
                $searchStats.FilesConsideredForContentSearch = $filteredFiles.Count

                if ($isPs7OrGreater) {
                    # PowerShell 7+ : Use ForEach-Object -Parallel with memory management
                    $contentMatchesBag = [System.Collections.Concurrent.ConcurrentBag[System.IO.FileInfo]]::new()

                    # Memory-aware throttling
                    $availableMemoryGB = [Math]::Max(1, ([System.GC]::GetTotalMemory($false) / 1GB))
                    $maxThrottle = [Math]::Min([System.Environment]::ProcessorCount, [Math]::Max(2, [int]($availableMemoryGB * 2)))

                    $progressCounterBox = [pscustomobject]@{ Value = 0 }
                    $totalFilesToSearch = $searchStats.FilesConsideredForContentSearch

                    try {
                        $filteredFiles | ForEach-Object -Parallel {
                            $localFilesSearched = [System.Threading.Interlocked]::Increment([ref]$using:progressCounterBox.Value)
                            Write-Progress -Activity "Searching file contents (Parallel)" -Status "Scanning $($_.Name)" -Id 1

                            if ($_.Length -lt 50MB -and $_.Extension -match '\.(txt|log|md|xml|json|csv|html?|css|js|ps1|psm1|psd1|py|java|c|cpp|h|cs|vb|sql|ini|cfg|conf|config)$') {
                                try {
                                    $fileContent = $null
                                    try {
                                        $fileContent = Get-Content -Path $_.FullName -Raw -ErrorAction SilentlyContinue
                                        if ($fileContent -and $fileContent.Length -gt 0) {
                                            $matchFound = if ($using:caseSensitive) {
                                                $fileContent -cmatch [regex]::Escape($using:content)
                                            } else {
                                                $fileContent -imatch [regex]::Escape($using:content)
                                            }

                                            if ($matchFound) {
                                                $bag = $using:contentMatchesBag
                                                $bag.Add($_)
                                            }
                                        }
                                    }
                                    finally {
                                        # Explicitly clear file content reference
                                        $fileContent = $null
                                    }
                                }
                                catch {
                                    if ($using:verboseMode) {
                                        Write-Warning "[Thread $([System.Threading.Thread]::CurrentThread.ManagedThreadId)] Could not search content in: $($_.Name) - $($_.Exception.Message)"
                                    }
                                }
                            }
                        } -ThrottleLimit $maxThrottle

                        # Convert results and cleanup
                        $filteredFiles = $contentMatchesBag.ToArray()
                    }
                    finally {
                        # Force garbage collection to clean up parallel operation memory
                        $contentMatchesBag = $null
                        $progressCounterBox = $null
                        [System.GC]::Collect()
                        [System.GC]::WaitForPendingFinalizers()
                        [System.GC]::Collect()
                    }

                    if ($searchStats.FilesConsideredForContentSearch -gt 0) {
                        Write-Progress -Activity "Searching file contents (Parallel)" -Completed -Id 1
                    }
                }
                else {
                    # Existing single-threaded logic for PS < 7 with better memory management
                    $contentMatches = @()
                    $filesSearched = 0
                    $totalFilesToSearch = $searchStats.FilesConsideredForContentSearch

                    Write-Progress -Activity "Searching file contents" -Status "Preparing to search..." -PercentComplete 0 -Id 1

                    foreach ($file in $filteredFiles) {
                        $filesSearched++
                        Write-Progress -Activity "Searching file contents" -Status "($filesSearched of $totalFilesToSearch) Scanning $($file.Name)" -PercentComplete (($filesSearched / $totalFilesToSearch) * 100) -Id 1

                        if ($file.Length -lt 50MB -and $file.Extension -match '\.(txt|log|md|xml|json|csv|html?|css|js|ps1|psm1|psd1|py|java|c|cpp|h|cs|vb|sql|ini|cfg|conf|config)$') {
                            try {
                                $fileContent = $null
                                try {
                                    $fileContent = Get-Content -Path $file.FullName -Raw -ErrorAction SilentlyContinue
                                    if ($fileContent -and $fileContent.Length -gt 0) {
                                        $matchFound = if ($caseSensitive) {
                                            $fileContent -cmatch [regex]::Escape($content)
                                        } else {
                                            $fileContent -imatch [regex]::Escape($content)
                                        }

                                        if ($matchFound) {
                                            $contentMatches += $file
                                        }
                                    }
                                }
                                finally {
                                    # Explicitly clear file content reference
                                    $fileContent = $null
                                }

                                # Periodic garbage collection for large searches
                                if ($filesSearched % 100 -eq 0) {
                                    [System.GC]::Collect()
                                }
                            }
                            catch {
                                if ($verboseMode) {
                                    Write-Host "Could not search content in: $($file.Name) - $($_.Exception.Message)" -ForegroundColor DarkRed
                                }
                            }
                        }
                    }
                    if ($searchStats.FilesConsideredForContentSearch -gt 0) {
                        Write-Progress -Activity "Searching file contents" -Completed -Id 1
                    }
                    $filteredFiles = $contentMatches
                }
            } else {
                $filteredFiles = @()
            }
        }
    }
    finally {
        $stopwatch.Stop()
        $searchStats.TotalDurationMs = $stopwatch.ElapsedMilliseconds
        if ($initialLoader) {
            Stop-Loader $initialLoader
        }
    }

    # Display results
    if ($filteredFiles.Count -eq 0) {
        Write-Host "No files found matching the criteria." -ForegroundColor Yellow
        return
    }

    # Sort files by directory then name
    $sortedFiles = $filteredFiles | Sort-Object DirectoryName, Name

    Write-Host "Found $($sortedFiles.Count) file(s) matching criteria:" -ForegroundColor Green
    Write-Host ""

    $currentDir = ""
    foreach ($file in $sortedFiles) {
        # Group by directory for better readability
        if ($file.DirectoryName -ne $currentDir) {
            $currentDir = $file.DirectoryName
            $relativePath = if ($currentDir.StartsWith($path)) {
                $currentDir.Substring($path.Length).TrimStart('\')
            } else {
                $currentDir
            }
            if ($relativePath -eq "") { $relativePath = "." }
            Write-Host "[$relativePath]" -ForegroundColor Blue
        }

        # File info
        Write-Host "  " -NoNewline
        Write-Host $file.Name -ForegroundColor White -NoNewline

        # Size
        $size = if ($file.Length -lt 1KB) { "$($file.Length)B" }
               elseif ($file.Length -lt 1MB) { "{0:N1}KB" -f ($file.Length / 1KB) }
               elseif ($file.Length -lt 1GB) { "{0:N1}MB" -f ($file.Length / 1MB) }
               else { "{0:N1}GB" -f ($file.Length / 1GB) }

        Write-Host " ($size)" -ForegroundColor DarkGray -NoNewline

        # Modified date
        Write-Host " - Modified: $($file.LastWriteTime.ToString('yyyy-MM-dd HH:mm'))" -ForegroundColor DarkGray

        # Show full path in verbose mode
        if ($verboseMode) {
            Write-Host "    Full path: $($file.FullName)" -ForegroundColor DarkGray
        }
    }

    Write-Host ""
    Write-Host "Total: $($sortedFiles.Count) file(s)" -ForegroundColor Green

    Write-Host ""
    Write-Host "Search Statistics:" -ForegroundColor Cyan
    Write-Host ("-" * 18) -ForegroundColor DarkGray
    Write-Host ("  Total search duration: {0:N2} seconds ({1:N0} ms)" -f ($searchStats.TotalDurationMs / 1000.0), $searchStats.TotalDurationMs)
    Write-Host "  Files initially found by Get-ChildItem: $($searchStats.FilesInitiallyFound)"
    Write-Host "  Files after metadata filters: $($searchStats.FilesAfterMetadataFilters)"

    if ($content) {
        $searchMode = if ($isPs7OrGreater) { 'Parallel' } else { 'Sequential' }
        Write-Host "  Files considered for content search: $($searchStats.FilesConsideredForContentSearch) ($searchMode)"
        if ($searchStats.FilesConsideredForContentSearch -gt 0) {
            $avgTimeContentMs = $searchStats.TotalDurationMs / $searchStats.FilesConsideredForContentSearch # This is overall time / content files, not content search time
            # To get more accurate content search time, we'd need another stopwatch around the content search block itself.
            # For now, this gives a rough idea.
            Write-Host ("  Avg. overall time per file considered for content: {0:N3} ms" -f $avgTimeContentMs)
        }
    }

    if ($searchStats.FilesInitiallyFound -gt 0) {
        $avgTimeMs = $searchStats.TotalDurationMs / $searchStats.FilesInitiallyFound
        Write-Host ("  Avg. time per initially found file: {0:N3} ms" -f $avgTimeMs)
    }
}

function Convert-SizeToBytes($sizeString) {
    if (-not $sizeString) { return $null }

    # Remove spaces and convert to uppercase
    $sizeString = $sizeString.Replace(" ", "").ToUpper()

    # Extract number and unit
    if ($sizeString -match '^(\d+(?:\.\d+)?)([KMGT]?B?)$') {
        $number = [double]$matches[1]
        $unit = $matches[2]

        switch ($unit) {
            { $_ -in @("", "B") } { return [long]$number }
            { $_ -in @("K", "KB") } { return [long]($number * 1KB) }
            { $_ -in @("M", "MB") } { return [long]($number * 1MB) }
            { $_ -in @("G", "GB") } { return [long]($number * 1GB) }
            { $_ -in @("T", "TB") } { return [long]($number * 1TB) }
            default { return $null }
        }
    }

    return $null
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
    "metadata" = @{
        Aliases = @("meta", "info")
        Action = {
            $targetPath = Get-TargetPath $Value1
            $useRecursive = $PSBoundParameters.ContainsKey('Recursive') -and $Recursive
            $filterPattern = if ($PSBoundParameters.ContainsKey('Pattern') -and $Pattern) { $Pattern } else { $null }
            Show-FileMetadata -path $targetPath -pattern $filterPattern -recursive $useRecursive
        }
        Summary = "Display detailed metadata information for files."
        Options = @{
            0 = @(
                @{ Token = "path"; Type = "OptionalArgument"; Description = "Target file or directory. Defaults to current location if omitted." }
                @{ Token = "Pattern"; Type = "OptionalParameter"; Description = "Filter files by pattern (e.g., *.txt, *.jpg)." }
                @{ Token = "Recursive"; Type = "OptionalParameter"; Description = "Process files in subdirectories recursively." }
            )
        }
        Examples = @(
            "powertool metadata myfile.txt",
            "powertool meta `"C:\MyFolder`" -Pattern *.jpg",
            "powertool info . -Pattern *.dll -Recursive",
            "powertool metadata"
        )
    }
    "remove-text" = @{
        Aliases = @("rt")
        Action = {
            $targetPath = Get-TargetPath $Value1
            Remove-TextFromFiles -dir $targetPath -pattern $Pattern
        }
        Summary = "Remove text from all txt files using regex pattern."
        Options = @{
            0 = @(
                @{ Token = "path"; Type = "OptionalArgument"; Description = "Target directory. Defaults to current location." }
                @{ Token = "Pattern"; Type = "Parameter"; Description = "The regular expression pattern to match text for removal." }
                @{ Token = "regex"; Type = "Type"; Description = "A valid regex string." }
            )
        }
        Examples = @(
            "powertool remove-text -Pattern `"Advertisement.*?End`"",
            "powertool rt `"C:\MyFolder`" -Pattern `"\d{4}-\d{2}-\d{2}\`""
        )
    }
    "hash" = @{
        Aliases = @("checksum", "md5", "sha1", "sha256")
        Action = {
            $targetPath = Get-TargetPath $Value1
            $hashAlgorithm = if ($Value2) { $Value2 } else { "SHA256" }

            # Handle alias-based algorithm selection
            switch ($Command.ToLower()) {
                "md5"    { $hashAlgorithm = "MD5" }
                "sha1"   { $hashAlgorithm = "SHA1" }
                "sha256" { $hashAlgorithm = "SHA256" }
                default  { }
            }

            Get-PowerToolFileHash -path $targetPath -algorithm $hashAlgorithm
        }
        Summary = "Generate cryptographic hashes for files or directories."
        Options = @{
            0 = @(
                @{ Token = "path"; Type = "OptionalArgument"; Description = "File or directory path. Defaults to current location if omitted." }
                @{ Token = "algorithm"; Type = "OptionalArgument"; Description = "Hash algorithm: MD5, SHA1, SHA256 (default), SHA384, SHA512." }
            )
        }
        Examples = @(
            "powertool hash",
            "powertool hash `"myfile.txt`"",
            "powertool hash `"C:\MyFolder`" SHA1",
            "powertool md5 `"document.pdf`"",
            "powertool sha256 ."
        )
    }
    "search-files" = @{
        Aliases = @("locate", "sf")
        Action = {
            $targetPath = Get-TargetPath $Value1
            $useRecursive = -not $NoRecursive
            $useCaseSensitive = $CaseSensitive

            $searchParams = @{
                path = $targetPath
                recursive = $useRecursive
                caseSensitive = $useCaseSensitive
            }

            # Debug: Show what parameters we received
            if (Get-Setting -Key "core.verbose") {
                Write-Host "Debug: Received parameters:" -ForegroundColor DarkGray
                Write-Host "  Name: '$Name'" -ForegroundColor DarkGray
                Write-Host "  Content: '$Content'" -ForegroundColor DarkGray
                Write-Host "  Extension: '$Extension'" -ForegroundColor DarkGray
                Write-Host "  NoRecursive value: $NoRecursive" -ForegroundColor DarkGray
                Write-Host "  useRecursive calculated: $useRecursive" -ForegroundColor DarkGray
            }

            if ($Name) { $searchParams.name = $Name }
            if ($Content) { $searchParams.content = $Content }
            if ($Extension) { $searchParams.extension = $Extension }
            if ($MinSize) { $searchParams.minSize = $MinSize }
            if ($MaxSize) { $searchParams.maxSize = $MaxSize }
            if ($ModifiedAfter) { $searchParams.modifiedAfter = $ModifiedAfter }
            if ($ModifiedBefore) { $searchParams.modifiedBefore = $ModifiedBefore }

            Search-Files @searchParams
        }
        Summary = "Search for files using various criteria."
        Options = @{
            0 = @(
                @{ Token = "path"; Type = "OptionalArgument"; Description = "Directory to search in. Defaults to current location if omitted." }
                @{ Token = "Name"; Type = "OptionalParameter"; Description = "Search by filename (supports wildcards like *.txt or simple text)." }
                @{ Token = "Content"; Type = "OptionalParameter"; Description = "Search for text content within files." }
                @{ Token = "Extension"; Type = "OptionalParameter"; Description = "Filter by file extension (e.g., txt, .pdf)." }
                @{ Token = "MinSize"; Type = "OptionalParameter"; Description = "Minimum file size (e.g., 1MB, 500KB, 1024)." }
                @{ Token = "MaxSize"; Type = "OptionalParameter"; Description = "Maximum file size (e.g., 10MB, 2GB)." }
                @{ Token = "ModifiedAfter"; Type = "OptionalParameter"; Description = "Files modified after this date (e.g., '2024-01-01')." }
                @{ Token = "ModifiedBefore"; Type = "OptionalParameter"; Description = "Files modified before this date (e.g., '2024-12-31')." }
                @{ Token = "NoRecursive"; Type = "OptionalParameter"; Description = "Search only in the specified directory, not subdirectories." }
                @{ Token = "CaseSensitive"; Type = "OptionalParameter"; Description = "Make name and content searches case-sensitive." }
            )
        }
        Examples = @(
            "powertool search-files -Name `"report*.docx`" -Content `"Quarterly report`" -MinSize 1MB -MaxSize 10MB -ModifiedAfter `"2024-01-01`" -ModifiedBefore `"2024-12-31`""
        )
    }
}

Export-ModuleMember -Function Rename-FilesRandomly, Merge-Directory, Show-DirectoryTree, Show-FileMetadata, Read-PngMetadata, Read-WindowsRuntimeMetadata, Remove-TextFromFiles, Get-PowerToolFileHash, Search-Files, Convert-SizeToBytes -Variable ModuleCommands
