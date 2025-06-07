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

$script:ModuleCommands = @{
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
}

Export-ModuleMember -Function Get-PowerToolFileHash -Variable ModuleCommands