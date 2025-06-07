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
}

Export-ModuleMember -Function Rename-FilesRandomly, Merge-Directory, Show-DirectoryTree, Show-FileMetadata, Read-PngMetadata, Read-WindowsRuntimeMetadata -Variable ModuleCommands
