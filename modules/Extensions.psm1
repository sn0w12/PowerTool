function Show-ExtensionInfo {
    param(
        [string]$ExtensionName,
        [hashtable]$Extensions = @{},
        [switch]$Update
    )

    if ($Update) {
        Update-Extension -ExtensionName $ExtensionName -Extensions $Extensions
        return
    }

    if ($ExtensionName) {
        # Show details for specific extension
        if ($Extensions.ContainsKey($ExtensionName)) {
            $extension = $Extensions[$ExtensionName]

            Write-Host "Extension Details:" -ForegroundColor Blue
            Write-Host "  Name: " -NoNewline -ForegroundColor White
            Write-Host $extension.Name -ForegroundColor Cyan
            Write-Host "  Description: " -NoNewline -ForegroundColor White
            Write-Host $extension.Description -ForegroundColor White
            Write-Host "  Version: " -NoNewline -ForegroundColor White
            Write-Host $extension.Version -ForegroundColor Yellow
            Write-Host "  Author: " -NoNewline -ForegroundColor White
            Write-Host $extension.Author -ForegroundColor White

            if ($extension.License) {
                Write-Host "  License: " -NoNewline -ForegroundColor White
                Write-Host $extension.License -ForegroundColor White
            }

            if ($extension.Homepage) {
                Write-Host "  Homepage: " -NoNewline -ForegroundColor White
                Write-Host $extension.Homepage -ForegroundColor Blue
            }

            if ($extension.Source) {
                Write-Host "  Source: " -NoNewline -ForegroundColor White
                Write-Host $extension.Source -ForegroundColor Green
            }

            Write-Host "  Path: " -NoNewline -ForegroundColor White
            Write-Host $extension.Path -ForegroundColor DarkGray

            if ($extension.Keywords -and $extension.Keywords.Count -gt 0) {
                Write-Host "  Keywords: " -NoNewline -ForegroundColor White
                Write-Host ($extension.Keywords -join ", ") -ForegroundColor DarkYellow
            }

            Write-Host "  Modules: " -NoNewline -ForegroundColor White
            Write-Host ($extension.Modules -join ", ") -ForegroundColor DarkCyan

            Write-Host "  Commands: " -NoNewline -ForegroundColor White
            Write-Host ($extension.LoadedCommands -join ", ") -ForegroundColor Cyan

            if ($extension.Dependencies -and $extension.Dependencies.Count -gt 0) {
                Write-Host "  Dependencies:" -ForegroundColor White
                foreach ($depName in $extension.Dependencies.Keys) {
                    $depVersion = $extension.Dependencies[$depName]
                    Write-Host "    ${depName}: $depVersion" -ForegroundColor DarkGray
                }
            }
        } else {
            Write-Host "Extension '$ExtensionName' not found." -ForegroundColor Red
            Write-Host "Use 'powertool extension' to see all loaded extensions." -ForegroundColor White
        }
    } else {
        # Show list of all extensions
        Write-Header
        Write-Host "Loaded Extensions:" -ForegroundColor Blue
        Write-Host ""

        if ($Extensions.Count -eq 0) {
            Write-Host "No extensions are currently loaded." -ForegroundColor DarkGray
            Write-Host "Extensions should be placed in the 'extensions/' directory." -ForegroundColor White
            return
        }

        $sortedExtensions = $Extensions.Keys | Sort-Object
        foreach ($extName in $sortedExtensions) {
            $extension = $Extensions[$extName]

            Write-Host "  " -NoNewline
            Write-Host $extension.Name -NoNewline -ForegroundColor Cyan
            Write-Host " v$($extension.Version)" -NoNewline -ForegroundColor Yellow
            Write-Host " by " -NoNewline -ForegroundColor DarkGray
            Write-Host $extension.Author -ForegroundColor White
            Write-Host "    $($extension.Description)" -ForegroundColor White
            Write-Host "    Commands: " -NoNewline -ForegroundColor DarkGray
            Write-Host ($extension.LoadedCommands -join ", ") -ForegroundColor DarkCyan

            if ($extension.Source) {
                Write-Host "    Source: " -NoNewline -ForegroundColor DarkGray
                Write-Host $extension.Source -ForegroundColor Green
            }

            Write-Host ""
        }
    }
}

function Install-Extension {
    param(
        [string]$ExtensionSource,
        [string]$VersionToInstall, # e.g., v1.0.0, main, a_commit_hash
        [switch]$Force
    )

    if (-not $ExtensionSource) {
        Write-Host "Please specify an extension source to install." -ForegroundColor Red
        Write-Host "Usage: powertool install <username/repository_or_git-url> [version] [-Force]" -ForegroundColor White
        return
    }

    # Check if git is available
    try {
        $null = & git --version 2>$null
        if ($LASTEXITCODE -ne 0) {
            throw "Git not found"
        }
    } catch {
        Write-Host "Git is required to install extensions. Please install Git and ensure it's in your PATH." -ForegroundColor Red
        return
    }

    # Determine the Git URL and extension name
    $gitUrl = ""
    $extensionName = ""

    if ($ExtensionSource -match "^[a-zA-Z0-9_.-]+/[a-zA-Z0-9_.-]+$") {
        # GitHub shorthand format: username/repository
        $gitUrl = "https://github.com/$ExtensionSource.git"
        $extensionName = ($ExtensionSource -split '/')[1]
    } elseif ($ExtensionSource -match "^https?://.*") {
        # Full Git URL
        $gitUrl = $ExtensionSource
        if ($ExtensionSource -match "/([^/]+?)(\.git)?/?$") {
            $extensionName = $matches[1] -replace '\.git$', ''
        } else {
            Write-Host "Could not determine extension name from URL: $ExtensionSource" -ForegroundColor Red
            return
        }
    } else {
        Write-Host "Invalid extension source format: $ExtensionSource" -ForegroundColor Red
        Write-Host "Use either 'username/repository' or a full Git URL." -ForegroundColor White
        return
    }

    # Determine extensions directory (assuming Help.psm1 is in 'modules' one level down from PSScriptRoot of powertool.ps1)
    # $PSScriptRoot for a module file is the module's directory.
    $powerToolRoot = (Get-Item $PSScriptRoot).Parent.FullName
    $extensionsPath = Join-Path $powerToolRoot "extensions"

    if (-not (Test-Path $extensionsPath)) {
        try {
            New-Item -Path $extensionsPath -ItemType Directory -Force | Out-Null
            Write-Host "Created extensions directory: $extensionsPath" -ForegroundColor Green
        } catch {
            Write-Host "Failed to create extensions directory: $($_.Exception.Message)" -ForegroundColor Red
            return
        }
    }

    $targetPath = Join-Path $extensionsPath $extensionName

    if (Test-Path $targetPath) {
        if (-not $Force) {
            Write-Host "Extension '$extensionName' already exists at: $targetPath" -ForegroundColor Yellow
            Write-Host "Use -Force to overwrite the existing extension." -ForegroundColor White
            return
        } else {
            Write-Host "Removing existing extension '$extensionName' due to -Force flag..." -ForegroundColor Yellow
            try {
                Remove-Item -Path $targetPath -Recurse -Force
            } catch {
                Write-Host "Failed to remove existing extension: $($_.Exception.Message)" -ForegroundColor Red
                return
            }
        }
    }

    Write-Host "Installing extension: " -NoNewline -ForegroundColor White
    Write-Host $extensionName -ForegroundColor Cyan
    Write-Host "Source: " -NoNewline -ForegroundColor White
    Write-Host $gitUrl -ForegroundColor Blue
    if ($VersionToInstall) {
        Write-Host "Version: " -NoNewline -ForegroundColor White
        Write-Host $VersionToInstall -ForegroundColor Yellow
    }

    try {
        Write-Host "Cloning repository..." -ForegroundColor DarkGray
        $cloneResult = & git clone $gitUrl $targetPath 2>&1

        if ($LASTEXITCODE -ne 0) {
            Write-Host "Failed to clone repository:" -ForegroundColor Red
            Write-Host $cloneResult -ForegroundColor Red
            return
        }
        Write-Host "Successfully cloned repository to $targetPath" -ForegroundColor Green

        if ($VersionToInstall) {
            Write-Host "Attempting to checkout version: '$VersionToInstall'..." -ForegroundColor DarkGray
            $originalLocation = Get-Location
            try {
                Set-Location $targetPath
                $checkoutResult = & git checkout $VersionToInstall 2>&1
                if ($LASTEXITCODE -ne 0) {
                    Write-Host "Failed to checkout version '$VersionToInstall'." -ForegroundColor Yellow
                    # Try with "v" prefix if not already present
                    if (-not $VersionToInstall.StartsWith("v")) {
                        $vPrefixedVersion = "v$VersionToInstall"
                        Write-Host "Attempting to checkout version: '$vPrefixedVersion'..." -ForegroundColor DarkGray
                        $checkoutResult = & git checkout $vPrefixedVersion 2>&1
                        if ($LASTEXITCODE -ne 0) {
                            Write-Host "Failed to checkout version '$vPrefixedVersion':" -ForegroundColor Red
                            Write-Host $checkoutResult -ForegroundColor Red
                            Write-Host "The repository is cloned, but it might be on the default branch." -ForegroundColor Yellow
                        } else {
                            Write-Host "Successfully checked out version '$vPrefixedVersion'." -ForegroundColor Green
                        }
                    } else {
                        # Original version already had "v", and it failed.
                        Write-Host $checkoutResult -ForegroundColor Red
                        Write-Host "The repository is cloned, but it might be on the default branch." -ForegroundColor Yellow
                    }
                } else {
                    Write-Host "Successfully checked out version '$VersionToInstall'." -ForegroundColor Green
                }
            } catch {
                Write-Host "An error occurred during git checkout: $($_.Exception.Message)" -ForegroundColor Red
            } finally {
                Set-Location $originalLocation
            }
        }

        $manifestPath = Join-Path $targetPath "extension.json"
        if (-not (Test-Path $manifestPath)) {
            Write-Host "Warning: No extension.json manifest found in the repository. This may not be a valid PowerTool extension." -ForegroundColor Yellow
            Write-Host "Extension files are located at: $targetPath" -ForegroundColor White
            return
        }

        $manifest = Get-Content $manifestPath -Raw | ConvertFrom-Json
        Write-Host ""
        Write-Host "Extension '$($manifest.name)' installed successfully!" -ForegroundColor Green
        Write-Host "  Description: $($manifest.description)" -ForegroundColor White
        Write-Host "  Version: $(if ($manifest.version) { $manifest.version } else { 'N/A' })" -ForegroundColor Yellow
        Write-Host "  Author: $(if ($manifest.author) { $manifest.author } else { 'Unknown' })" -ForegroundColor White

        # Check dependencies
        if ($manifest.dependencies) {
            Write-Host ""
            Write-Host "Checking dependencies..." -ForegroundColor Blue

            $missingDependencies = @()
            $deps = @{}

            # Convert dependencies to hashtable if it's a PSCustomObject
            if ($manifest.dependencies -is [PSCustomObject]) {
                $manifest.dependencies.PSObject.Properties | ForEach-Object {
                    $deps[$_.Name] = $_.Value
                }
            } else {
                $deps = $manifest.dependencies
            }

            foreach ($depName in $deps.Keys) {
                $requiredVersion = $deps[$depName]

                if ($depName -eq "powertool") {
                    # Check PowerTool version - we'll assume current version is compatible for installation
                    Write-Host "  PowerTool: " -NoNewline -ForegroundColor White
                    Write-Host "Required $requiredVersion" -NoNewline -ForegroundColor Yellow
                    Write-Host " [SKIP - Core dependency]" -ForegroundColor DarkGray
                } else {
                    # Check if extension dependency exists
                    $dependencyFound = $false

                    # Try to match by source URL first, then fall back to folder name
                    foreach ($extName in (Get-ChildItem $extensionsPath -Directory).Name) {
                        $extManifestPath = Join-Path $extensionsPath $extName "extension.json"

                        if (Test-Path $extManifestPath) {
                            try {
                                $extManifest = Get-Content $extManifestPath -Raw | ConvertFrom-Json

                                # Check if the dependency matches the extension's source field
                                if ($extManifest.source -and $extManifest.source -eq $depName) {
                                    $dependencyFound = $true
                                    break
                                }

                                # Fallback: check if dependency name matches folder name (when no source is available)
                                if (-not $extManifest.source -and $extName -eq (Split-Path $depName -Leaf)) {
                                    $dependencyFound = $true
                                    break
                                }
                            } catch {
                                # Skip extensions with invalid manifests
                                continue
                            }
                        }
                    }

                    if ($dependencyFound) {
                        Write-Host "  ${depName}: " -NoNewline -ForegroundColor White
                        Write-Host "[FOUND]" -ForegroundColor Green
                    } else {
                        Write-Host "  ${depName}: " -NoNewline -ForegroundColor White
                        Write-Host "[MISSING]" -ForegroundColor Red
                        $missingDependencies += $depName
                    }
                }
            }

            if ($missingDependencies.Count -gt 0) {
                Write-Host ""
                Write-Host "Missing dependencies found: $($missingDependencies.Count)" -ForegroundColor Yellow
                foreach ($dep in $missingDependencies) {
                    Write-Host "  - $dep" -ForegroundColor Yellow
                }

                Write-Host ""
                $response = Read-Host "Would you like to install the missing dependencies? (y/N)"

                if ($response -match "^[yY]([eE][sS])?$") {
                    Write-Host ""
                    Write-Host "Installing dependencies..." -ForegroundColor Green

                    foreach ($dep in $missingDependencies) {
                        Write-Host ""
                        Write-Host "Installing dependency: " -NoNewline -ForegroundColor White
                        Write-Host $dep -ForegroundColor Cyan

                        # Recursively call Install-Extension for each dependency
                        Install-Extension -ExtensionSource $dep
                    }
                } else {
                    Write-Host "Skipping dependency installation." -ForegroundColor Yellow
                    Write-Host "Note: The extension may not work correctly without its dependencies." -ForegroundColor Yellow
                }
            } else {
                Write-Host "All dependencies satisfied!" -ForegroundColor Green
            }
        }

        Write-Host ""
        Write-Host "Note: Restart PowerTool to load the new extension and its commands." -ForegroundColor Yellow

    } catch {
        Write-Host "An error occurred during installation: $($_.Exception.Message)" -ForegroundColor Red
        if (Test-Path $targetPath) {
            Write-Host "Cleaning up failed installation attempt at $targetPath..." -ForegroundColor DarkGray
            Remove-Item -Path $targetPath -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}

function Update-Extension {
    param(
        [string]$ExtensionName,
        [hashtable]$Extensions = @{},
        [string]$ToVersion,
        [switch]$All,
        [switch]$Nightly
    )

    if ($All) {
        # Update all extensions
        Write-Host "Updating all extensions..." -ForegroundColor White
        Write-Host ""

        if ($Extensions.Count -eq 0) {
            Write-Host "No extensions are currently loaded." -ForegroundColor DarkGray
            return
        }

        $updatedCount = 0
        $failedCount = 0
        $skippedCount = 0

        foreach ($extName in ($Extensions.Keys | Sort-Object)) {
            Write-Host "Updating extension: " -NoNewline -ForegroundColor White
            Write-Host $extName -ForegroundColor Cyan

            $result = Update-SingleExtension -ExtensionName $extName -Extensions $Extensions -ToVersion $ToVersion -Nightly:$Nightly

            switch ($result) {
                "updated" { $updatedCount++ }
                "failed" { $failedCount++ }
                "skipped" { $skippedCount++ }
            }
            Write-Host ""
        }

        Write-Host "Update Summary:" -ForegroundColor Blue
        Write-Host "  Updated: $updatedCount" -ForegroundColor Green
        Write-Host "  Failed: $failedCount" -ForegroundColor Red
        Write-Host "  Skipped: $skippedCount" -ForegroundColor Yellow

        if ($updatedCount -gt 0) {
            Write-Host "Note: Restart PowerTool to load updated extensions." -ForegroundColor Yellow
        }
        return
    }

    if (-not $ExtensionName) {
        Write-Host "Please specify an extension name to update, or use -All to update all extensions." -ForegroundColor Red
        Write-Host "Usage: powertool update-extension <extension-name> [version] [-Nightly] [-All]" -ForegroundColor White
        return
    }

    $result = Update-SingleExtension -ExtensionName $ExtensionName -Extensions $Extensions -ToVersion $ToVersion -Nightly:$Nightly

    if ($result -eq "updated") {
        Write-Host "Note: Restart PowerTool to load the updated extension." -ForegroundColor Yellow
    }
}

function Update-SingleExtension {
    param(
        [string]$ExtensionName,
        [hashtable]$Extensions,
        [string]$ToVersion,
        [switch]$Nightly
    )

    if (-not $Extensions.ContainsKey($ExtensionName)) {
        Write-Host "Extension '$ExtensionName' not found." -ForegroundColor Red
        return "failed"
    }

    $extension = $Extensions[$ExtensionName]
    $extensionPath = $extension.Path

    # Check if the extension directory is a git repository
    $gitPath = Join-Path $extensionPath ".git"
    if (-not (Test-Path $gitPath)) {
        Write-Host "Extension '$ExtensionName' is not a git repository. Cannot update." -ForegroundColor Yellow
        return "skipped"
    }

    # Get current version before update
    $currentVersion = $extension.Version
    Write-Host "Current version: " -NoNewline -ForegroundColor White
    Write-Host "v$currentVersion" -ForegroundColor Yellow

    if ($ToVersion) {
        Write-Host "Target version: " -NoNewline -ForegroundColor White
        Write-Host $ToVersion -ForegroundColor Yellow
    } elseif ($Nightly) {
        Write-Host "Target: " -NoNewline -ForegroundColor White
        Write-Host "Latest commit" -ForegroundColor Magenta
    } else {
        Write-Host "Target: " -NoNewline -ForegroundColor White
        Write-Host "Latest tagged version" -ForegroundColor Green
    }

    try {
        $originalLocation = Get-Location
        Set-Location $extensionPath

        Write-Host "Checking for updates..." -ForegroundColor DarkGray

        # Check git status for local changes
        $gitStatus = & git status --porcelain 2>$null
        if ($LASTEXITCODE -ne 0) {
            Write-Host "Failed to check git status." -ForegroundColor Red
            return "failed"
        }

        if ($gitStatus) {
            Write-Host "Warning: Extension has local changes. Continuing with update..." -ForegroundColor Yellow
        }

        # Fetch latest changes
        $fetchResult = & git fetch --tags 2>&1
        if ($LASTEXITCODE -ne 0) {
            Write-Host "Failed to fetch from remote repository." -ForegroundColor Red
            Write-Host $fetchResult -ForegroundColor Red
            return "failed"
        }

        if ($ToVersion) {
            # Update to specific version
            Write-Host "Attempting to checkout version: '$ToVersion'..." -ForegroundColor Green

            $checkoutResult = & git checkout $ToVersion 2>&1
            if ($LASTEXITCODE -ne 0) {
                # Try with "v" prefix if not already present
                if (-not $ToVersion.StartsWith("v")) {
                    $vPrefixedVersion = "v$ToVersion"
                    Write-Host "Attempting to checkout version: '$vPrefixedVersion'..." -ForegroundColor DarkGray
                    $checkoutResult = & git checkout $vPrefixedVersion 2>&1
                    if ($LASTEXITCODE -ne 0) {
                        Write-Host "Failed to checkout version '$vPrefixedVersion':" -ForegroundColor Red
                        Write-Host $checkoutResult -ForegroundColor Red
                        return "failed"
                    } else {
                        Write-Host "Successfully checked out version '$vPrefixedVersion'." -ForegroundColor Green
                    }
                } else {
                    Write-Host "Failed to checkout version '$ToVersion':" -ForegroundColor Red
                    Write-Host $checkoutResult -ForegroundColor Red
                    return "failed"
                }
            } else {
                Write-Host "Successfully checked out version '$ToVersion'." -ForegroundColor Green
            }
        } elseif ($Nightly) {
            # Update to latest commit on default branch
            Write-Host "Updating to latest commit..." -ForegroundColor Magenta

            # Get the default branch name
            $defaultBranch = & git symbolic-ref refs/remotes/origin/HEAD 2>$null
            if ($LASTEXITCODE -eq 0) {
                $defaultBranch = $defaultBranch -replace '^refs/remotes/origin/', ''
            } else {
                # Fallback to common default branch names
                $defaultBranch = "main"
                $branchExists = & git show-ref --verify --quiet "refs/remotes/origin/main" 2>$null
                if ($LASTEXITCODE -ne 0) {
                    $branchExists = & git show-ref --verify --quiet "refs/remotes/origin/master" 2>$null
                    if ($LASTEXITCODE -eq 0) {
                        $defaultBranch = "master"
                    }
                }
            }

            Write-Host "Switching to branch: $defaultBranch" -ForegroundColor DarkGray
            $checkoutResult = & git checkout $defaultBranch 2>&1
            if ($LASTEXITCODE -ne 0) {
                Write-Host "Failed to checkout branch '$defaultBranch':" -ForegroundColor Red
                Write-Host $checkoutResult -ForegroundColor Red
                return "failed"
            }

            # Pull latest changes
            $pullResult = & git pull origin $defaultBranch 2>&1
            if ($LASTEXITCODE -ne 0) {
                Write-Host "Failed to pull latest changes:" -ForegroundColor Red
                Write-Host $pullResult -ForegroundColor Red
                return "failed"
            }

            Write-Host "Successfully updated to latest commit." -ForegroundColor Green
        } else {
            # Update to latest tagged version (default behavior)
            Write-Host "Finding latest tagged version..." -ForegroundColor DarkGray

            # Get the latest tag
            $latestTag = & git describe --tags --abbrev=0 2>$null
            if ($LASTEXITCODE -ne 0) {
                Write-Host "No tags found. Use -Nightly to update to the latest commit." -ForegroundColor Yellow
                return "skipped"
            }

            Write-Host "Latest tagged version: " -NoNewline -ForegroundColor White
            Write-Host $latestTag -ForegroundColor Green

            # Check if we're already on the latest tag
            $currentTag = & git describe --tags --exact-match HEAD 2>$null
            if ($LASTEXITCODE -eq 0 -and $currentTag -eq $latestTag) {
                Write-Host "Already on the latest tagged version ($latestTag)." -ForegroundColor Green
                return "skipped"
            }

            # Compare current version with latest tag
            $currentVersionClean = $currentVersion -replace '^v', ''
            $latestVersionClean = $latestTag -replace '^v', ''

            try {
                $current = [System.Version]::Parse($currentVersionClean)
                $latest = [System.Version]::Parse($latestVersionClean)

                if ($current -ge $latest) {
                    Write-Host "Current version (v$currentVersionClean) is already up to date or newer than the latest tag ($latestTag)." -ForegroundColor Green
                    return "skipped"
                }
            } catch {
                # If version parsing fails, proceed with the update
                Write-Host "Could not parse versions for comparison. Proceeding with update..." -ForegroundColor DarkGray
            }

            # Checkout the latest tag
            Write-Host "Updating to tagged version: $latestTag" -ForegroundColor Green
            $checkoutResult = & git checkout $latestTag 2>&1
            if ($LASTEXITCODE -ne 0) {
                Write-Host "Failed to checkout tag '$latestTag':" -ForegroundColor Red
                Write-Host $checkoutResult -ForegroundColor Red
                return "failed"
            }

            Write-Host "Successfully updated to version $latestTag." -ForegroundColor Green
        }

        # Re-read the manifest to get the new version
        $manifestPath = Join-Path $extensionPath "extension.json"
        if (Test-Path $manifestPath) {
            try {
                $newManifest = Get-Content $manifestPath -Raw | ConvertFrom-Json
                $newVersion = if ($newManifest.version) { $newManifest.version } else { "1.0.0" }

                Write-Host "Updated version: " -NoNewline -ForegroundColor White
                Write-Host "v$newVersion" -ForegroundColor Yellow

                if ($newVersion -ne $currentVersion) {
                    Write-Host "Extension updated from v$currentVersion to v$newVersion" -ForegroundColor Green
                } else {
                    Write-Host "Version unchanged (v$currentVersion)" -ForegroundColor DarkGray
                }
            } catch {
                Write-Host "Updated successfully, but could not read new version from manifest." -ForegroundColor Yellow
            }
        } else {
            Write-Host "Updated successfully, but extension.json not found." -ForegroundColor Yellow
        }

        return "updated"

    } catch {
        Write-Host "An error occurred during update: $($_.Exception.Message)" -ForegroundColor Red
        return "failed"
    } finally {
        Set-Location $originalLocation
    }
}

$script:ModuleCommands = @{
    "extension" = @{
        Aliases = @("ext", "extensions")
        Action = {
            Show-ExtensionInfo -ExtensionName $Value1 -Extensions $script:extensions -Update:$Update
        }
        Summary = "Show information about loaded extensions or details for a specific extension."
        Options = @{
            0 = @(
                @{ Token = "extension-name"; Type = "OptionalArgument"; Description = "The name of the extension to get details for." }
                @{ Token = "Update"; Type = "OptionalParameter"; Description = "Update the specified extension using git pull." }
            )
        }
        Examples = @(
            "powertool extension",
            "powertool extension example-extension",
            "powertool ext file-manager -Update",
            "pt ext my-extension -Update"
        )
    }
    "install" = @{
        Aliases = @("i", "add", "get")
        Action = {
            # $Value1 is source, $Value2 is version/git-ref, $Force is global switch
            Install-Extension -ExtensionSource $Value1 -VersionToInstall $Value2 -Force:$Force
        }
        Summary = "Install an extension from a GitHub repository or Git URL, optionally at a specific version/tag/branch."
        Options = @{
            0 = @( # First syntax group
                @{ Token = "source"; Type = "Argument"; Description = "GitHub repo (username/repository) or full Git URL." }
                @{ Token = "version"; Type = "OptionalArgument"; Description = "Specific git ref (branch, tag, commit) to install." }
                @{ Token = "Force"; Type = "OptionalParameter"; Description = "Overwrite if the extension already exists." }
            )
        }
        Examples = @(
            "powertool install username/my-extension",
            "powertool install username/another-extension v1.2.0",
            "powertool install https://github.com/user/extension.git main-branch",
            "pt add user/tool specific-commit-hash -Force",
            "pt get someuser/some-repo"
        )
    }
    "update-extension" = @{
        Aliases = @("update-ext", "upgrade-extension", "upgrade-ext")
        Action = {
            Update-Extension -ExtensionName $Value1 -Extensions $script:extensions -ToVersion $Value2 -All:$All -Nightly:$Nightly
        }
        Summary = "Update an extension to the latest tagged version, a specific version, or latest commit using git."
        Options = @{
            0 = @(
                @{ Token = "extension-name"; Type = "OptionalArgument"; Description = "The name of the extension to update. Required unless using -All." }
                @{ Token = "version"; Type = "OptionalArgument"; Description = "Specific version, tag, or branch to update to. If not specified, updates to latest tagged version." }
                @{ Token = "All"; Type = "OptionalParameter"; Description = "Update all loaded extensions." }
                @{ Token = "Nightly"; Type = "OptionalParameter"; Description = "Update to the latest commit on the default branch instead of latest tag." }
            )
        }
        Examples = @(
            "powertool update-extension my-extension",
            "powertool update-extension file-manager v2.1.0",
            "powertool update-extension -All",
            "powertool update-ext image-tools -Nightly",
            "pt upgrade-ext -All -Nightly",
            "pt update-ext my-ext main"
        )
    }
}

Export-ModuleMember -Function Show-ExtensionInfo, Install-Extension, Update-Extension -Variable ModuleCommands
