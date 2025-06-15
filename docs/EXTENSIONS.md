# PowerTool Extensions

PowerTool supports a robust extension system that allows developers to create custom commands and functionality. Extensions are loaded automatically from the `extensions/` directory and integrate seamlessly with the core PowerTool system.

## Extension Structure

Each extension must be contained in its own directory under `extensions/` with the following structure:

```
extensions/
└── my-extension/
    ├── extension.json          # Required manifest file
    ├── modules/               # PowerShell modules directory
    │   ├── MyModule.psm1      # Main module file
    │   └── MyUtilities.psm1   # Additional modules (optional)
    ├── resources/             # Optional resources directory
    │   ├── templates/
    │   └── data/
    └── README.md              # Optional documentation
```

## Extension Manifest (extension.json)

The `extension.json` file is required and defines the extension metadata and module loading configuration.

### Basic Manifest

```json
{
    "name": "my-extension",
    "description": "My custom PowerTool extension",
    "version": "1.0.0",
    "author": "Your Name",
    "modules": ["modules/MyModule.psm1"]
}
```

### Advanced Manifest

```json
{
    "name": "advanced-extension",
    "description": "An advanced PowerTool extension with multiple modules",
    "version": "2.1.0",
    "author": "Developer Name",
    "license": "MIT",
    "homepage": "https://github.com/user/powertool-extension",
    "source": "https://github.com/user/powertool-extension.git",
    "modules": [
        "modules/CoreModule.psm1",
        "modules/UtilityModule.psm1",
        "modules/ThirdPartyIntegration.psm1"
    ],
    "dependencies": {
        "powertool": ">=0.1.0",
        "sn0w12/PowerToolUtilities": ">=1.0.0",
        "https://gitlab.com/user/custom-extension.git": ">=2.1.0"
    },
    "keywords": ["utility", "automation", "files"]
}
```

### Manifest Properties

| Property       | Required | Type   | Description                                                       |
| -------------- | -------- | ------ | ----------------------------------------------------------------- |
| `name`         | Yes      | string | Unique extension identifier (lowercase, hyphens)                  |
| `description`  | Yes      | string | Brief description of extension functionality                      |
| `version`      | No       | string | Semantic version (default: "1.0.0"). Should align with a Git tag. |
| `author`       | No       | string | Extension author name                                             |
| `license`      | No       | string | License identifier (e.g., "MIT", "GPL-3.0")                       |
| `homepage`     | No       | string | Extension homepage or repository URL                              |
| `source`       | No       | string | Git repository URL for cloning the extension source               |
| `modules`      | Yes      | array  | List of PowerShell module files to load                           |
| `dependencies` | No       | object | Extension dependencies (see format requirements below)            |
| `keywords`     | No       | array  | Keywords for extension discovery                                  |

### Dependency Format Requirements

Dependencies must follow specific format rules:

1. **PowerTool Core**: Use `"powertool"` as the key (special case)

    ```json
    "powertool": ">=0.1.0"
    ```

2. **GitHub Extensions**: Use `"username/repository"` format

    ```json
    "sn0w12/PowerToolExtension": ">=1.0.0",
    "microsoft/PowerToys-Extension": ">=2.1.0"
    ```

3. **Other Git Providers**: Use full Git URL
    ```json
    "https://gitlab.com/user/extension.git": ">=1.5.0",
    "https://bitbucket.org/team/powertool-ext.git": ">=0.8.0",
    "https://git.example.com/dev/pt-extension.git": ">=1.0.0"
    ```

**Invalid Examples:**

```json
// ❌ Invalid - local names without provider
"my-extension": ">=1.0.0",
"custom-tools": ">=2.0.0",

// ❌ Invalid - incomplete GitHub format
"PowerToolExtension": ">=1.0.0",
"sn0w12": ">=1.0.0",

// ❌ Invalid - non-git URLs
"https://example.com/extension": ">=1.0.0"
```

**Valid Examples:**

```json
// ✅ Valid
"powertool": ">=0.1.0",
"sn0w12/PowerToolExtension": ">=1.0.0",
"user123/my-powertool-ext": ">=0.5.0",
"https://gitlab.com/company/internal-extension.git": ">=2.0.0",
"https://git.company.com/~user/powertool-addon": ">=1.2.0",
"https://any-git-provider.com/path/to/repo.git": ">=1.0.0"
```

## Creating Extension Modules

Extension modules are standard PowerShell modules (.psm1 files) that export a `$ModuleCommands` variable containing command definitions. PowerTool automatically provides access to all built-in functions and settings - no manual imports are needed.

### Basic Module Template

```powershell
# MyModule.psm1
<#
.SYNOPSIS
    My Custom PowerTool Extension Module

.DESCRIPTION
    This module provides custom commands for PowerTool.
#>

function Invoke-MyCustomCommand {
    param(
        [Parameter(Mandatory = $false)]
        [string]$InputPath,

        [Parameter(Mandatory = $false)]
        [string]$OutputFormat = "json",

        [Parameter(Mandatory = $false)]
        [switch]$Verbose
    )

    # Use PowerTool's built-in path utility (no import needed)
    $targetPath = Get-TargetPath $InputPath

    if ($Verbose) {
        Write-Host "Processing: $targetPath" -ForegroundColor Green
    }

    # Your custom logic here
    Write-Host "Custom command executed successfully!" -ForegroundColor Green
}

function Get-MyData {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Source
    )

    # Example data retrieval function
    return @{
        Source = $Source
        Timestamp = Get-Date
        Data = "Sample data"
    }
}

# Define commands that PowerTool will recognize
$script:ModuleCommands = @{
    "my-command" = @{
        Position = 0
        Aliases = @("mc", "mycmd")
        Action = {
            $inputPath = if ($Value1) { $Value1 } else { "" }
            # Access settings directly (no import needed)
            $verbose = Get-Setting -Key "core.verbose"
            Invoke-MyCustomCommand -InputPath $inputPath -OutputFormat "json" -Verbose:$verbose
        }
        Summary = "Execute my custom command with optional path"
        Options = @{
            0 = @(
                @{ Token = "path"; Type = "OptionalArgument"; Description = "Input path to process" }
            )
        }
        Examples = @(
            "powertool my-command",
            "powertool mc C:\MyFolder",
            "pt mycmd ."
        )
    }
    "get-data" = @{
        Aliases = @("gd")
        Action = {
            if (-not $Value1) {
                Write-Host "Error: Source parameter is required" -ForegroundColor Red
                return
            }

            $result = Get-MyData -Source $Value1
            $result | ConvertTo-Json -Depth 2 | Write-Host
        }
        Summary = "Retrieve data from specified source"
        Options = @{
            0 = @(
                @{ Token = "source"; Type = "Argument"; Description = "Data source identifier" }
            )
        }
        Examples = @(
            "powertool get-data database",
            "powertool gd api-endpoint"
        )
    }
}

# Export functions and command definitions
Export-ModuleMember -Function Invoke-MyCustomCommand, Get-MyData -Variable ModuleCommands
```

## Command Definition Reference

### Command Structure

```powershell
$script:ModuleCommands = @{
    "command-name" = @{
        Aliases = @("alias1", "alias2")  # Optional short names
        Action = {
            # PowerShell script block to execute
            # Access parameters via $Value1, $Value2, etc.
            # Access settings via Get-Setting -Key "setting.name"
        }
        Summary = "Brief description of what the command does"
        Options = @{
            0 = @(  # Primary syntax group
                @{ Token = "param1"; Type = "Argument"; Description = "Required parameter" }
                @{ Token = "param2"; Type = "OptionalArgument"; Description = "Optional parameter" }
            )
            1 = @(  # Alternative syntax group
                @{ Token = "Mode"; Type = "Parameter"; Description = "Alternative mode parameter" }
            )
        }
        Examples = @(
            "powertool command-name value1",
            "powertool command-name value1 value2",
            "pt alias1 value1"
        )
    }
}
```

### Parameter Types

| Type                | Syntax        | Description                   | Example      |
| ------------------- | ------------- | ----------------------------- | ------------ |
| `Argument`          | `[param]`     | Required positional parameter | `[path]`     |
| `OptionalArgument`  | `[param?]`    | Optional positional parameter | `[output?]`  |
| `Parameter`         | `-Parameter`  | Named parameter (switch-like) | `-Recursive` |
| `OptionalParameter` | `-Parameter?` | Optional named parameter      | `-Format?`   |
| `Type`              | `<type>`      | Type hint for documentation   | `<string>`   |

### Accessing Parameters in Actions

Parameters are accessible in the `Action` script block through predefined variables:

```powershell
Action = {
    # Positional parameters
    $inputPath = $Value1      # First argument
    $outputPath = $Value2     # Second argument

    # Named parameters (from powertool.ps1 param block)
    $isRecursive = $Recursive
    $minWidth = $MinWidth
    $pattern = $Pattern

    # Settings access (correct way)
    $verbose = Get-Setting -Key "core.verbose"
    $confirmDestructive = Get-Setting -Key "core.confirm-destructive"
    $customSetting = Get-Setting -Key "my-extension.custom-option"

    # Your command logic here
}
```

## Extension Settings

Extensions can define their own custom settings that integrate with PowerTool's settings system. Users can view, modify, and reset these settings using the standard PowerTool settings commands.

### Defining Extension Settings

Create a settings registration function in your extension module:

```powershell
# MyModule.psm1

# Register extension settings when module loads
function Initialize-MyExtensionSettings {
    $settingsSchema = @{
        "auto-backup" = @{
            Type = "Boolean"
            Default = $true
            Description = "Automatically create backups before operations"
        }
        "backup-location" = @{
            Type = "String"
            Default = "C:\Backups"
            Description = "Default location for backup files"
        }
        "compression-level" = @{
            Type = "Int32"
            Default = 5
            ValidValues = @(1, 2, 3, 4, 5, 6, 7, 8, 9)
            Description = "Compression level (1-9, higher = better compression)"
        }
        "output-format" = @{
            Type = "String"
            Default = "json"
            ValidValues = @("json", "xml", "csv", "txt")
            Description = "Default output format for data export"
        }
    }

    # Register settings with PowerTool
    Register-ExtensionSettings -ExtensionName "my-extension" -SettingsSchema $settingsSchema
}

# Call initialization when module loads
Initialize-MyExtensionSettings

# Use settings in your commands
$script:ModuleCommands = @{
    "backup-files" = @{
        Action = {
            # Get extension settings
            $autoBackup = Get-Setting -Key "my-extension.auto-backup"
            $backupLocation = Get-Setting -Key "my-extension.backup-location"
            $compressionLevel = Get-Setting -Key "my-extension.compression-level"

            if ($autoBackup) {
                Write-Host "Creating backup in: $backupLocation" -ForegroundColor Green
                Write-Host "Compression level: $compressionLevel" -ForegroundColor Yellow
                # Perform backup operation
            } else {
                Write-Host "Auto-backup disabled. Use 'powertool set my-extension.auto-backup true' to enable." -ForegroundColor Yellow
            }
        }
        Summary = "Backup files with configurable settings"
        # ...rest of command definition
    }
}
```

### Settings Schema Properties

Each setting in your schema can have the following properties:

| Property      | Required | Type   | Description                               |
| ------------- | -------- | ------ | ----------------------------------------- |
| `Type`        | Yes      | string | Data type: "String", "Boolean", "Int32"   |
| `Default`     | Yes      | any    | Default value for the setting             |
| `Description` | No       | string | Human-readable description of the setting |
| `ValidValues` | No       | array  | List of allowed values (for validation)   |

### Using Extension Settings

Once registered, extension settings work exactly like core settings:

```powershell
# View all settings (including extension settings)
powertool settings

# View only your extension's settings
powertool settings my-extension

# Get a specific setting value
powertool get my-extension.auto-backup

# Set a setting value
powertool set my-extension.backup-location "D:\MyBackups"

# Reset a setting to default
powertool reset my-extension.compression-level

# Reset all extension settings
powertool reset my-extension.*
```

### Settings Best Practices

1. **Naming**: Use descriptive names with hyphens (e.g., `auto-backup`, `max-retries`)
2. **Defaults**: Provide sensible default values that work for most users
3. **Validation**: Use `ValidValues` for settings with limited options
4. **Documentation**: Always include descriptions for your settings
5. **Grouping**: Prefix all your settings with your extension name

## Advanced Features

### Using PowerTool Utilities

Extensions have automatic access to PowerTool's built-in utility functions:

```powershell
function My-DestructiveOperation {
    param([string]$Path)

    # Use PowerTool's confirmation utility (no import needed)
    if (-not (Confirm-DestructiveOperation "Delete all files in $Path?")) {
        return
    }

    # Use PowerTool's path resolution utility (no import needed)
    $targetPath = Get-TargetPath $Path

    # Perform operation
    Remove-Item "$targetPath\*" -Force
}
```

### Available Built-in Functions

PowerTool provides these utility functions to extensions:

-   `Get-TargetPath` - Resolve relative paths to absolute paths
-   `Get-LevenshteinDistance` - Calculate string similarity
-   `Confirm-DestructiveOperation` - Prompt user for confirmation
-   `Get-Setting` - Get configuration setting values
-   `Set-Setting` - Modify setting values
-   `Register-ExtensionSettings` - Register custom settings

### Error Handling

Implement proper error handling in your extension commands:

```powershell
function Invoke-SafeOperation {
    param([string]$Path)

    try {
        if (-not (Test-Path $Path)) {
            throw "Path does not exist: $Path"
        }

        # Perform operation
        Write-Host "Operation completed successfully" -ForegroundColor Green
    }
    catch {
        Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
        Write-Verbose $_.ScriptStackTrace
    }
}
```

## Testing Extensions

### Manual Testing

```powershell
# Reload PowerTool to pick up extension changes
& .\powertool.ps1 help

# Test your commands
& .\powertool.ps1 my-command
& .\powertool.ps1 mc C:\TestFolder

# Test settings
& .\powertool.ps1 settings my-extension
& .\powertool.ps1 set my-extension.auto-backup false
& .\powertool.ps1 get my-extension.auto-backup
```

### Extension Validation

Use PowerTool's built-in validation:

```powershell
# Validate all module definitions
& .\powertool.ps1 validate

# Check for command conflicts
& .\powertool.ps1 help | Where-Object { $_ -match "Duplicate" }
```

## Best Practices

### 1. Naming Conventions

-   **Extension names**: Use lowercase with hyphens (e.g., `file-tools`, `git-helper`)
-   **Command names**: Use descriptive verb-noun format (e.g., `compress-files`, `sync-data`)
-   **Aliases**: Keep short but memorable (e.g., `cf` for `compress-files`)
-   **Settings**: Use descriptive names with hyphens (e.g., `auto-backup`, `max-retries`)

### 2. Parameter Design

-   Use consistent parameter names across commands
-   Provide sensible defaults
-   Make destructive operations require confirmation

### 3. Documentation

```powershell
<#
.SYNOPSIS
    Brief description of the function

.DESCRIPTION
    Detailed description of what the function does

.PARAMETER Path
    Description of the Path parameter

.EXAMPLE
    Invoke-MyFunction -Path "C:\Example"
    Description of what this example does

.NOTES
    Author: Your Name
    Version: 1.0.0
#>
```

### 4. Module Organization

-   Keep related functions in the same module
-   Use separate modules for different functional areas
-   Export only necessary functions and variables
-   Initialize settings in module load, not in commands

### 5. Resource Management

```powershell
# Clean up resources in finally blocks
try {
    $fileStream = [System.IO.File]::OpenRead($Path)
    # Process file
}
finally {
    if ($fileStream) {
        $fileStream.Dispose()
    }
}
```

### 6. Extension Versioning with Git Tags

Proper versioning is crucial for PowerTool's extension installation system. Follow these practices to ensure users can install specific versions of your extension:

#### Version Format

Use [semantic versioning](https://semver.org/) in your `extension.json`:

```json
{
    "name": "my-extension",
    "version": "1.2.3",
    "description": "My awesome extension"
}
```

#### Git Tag Creation Process

When releasing a new version of your extension:

1. **Update the version in `extension.json`**:

    ```json
    {
        "version": "1.1.0"
    }
    ```

2. **Commit the version change**:

    ```bash
    git add extension.json
    git commit -m "Bump version to 1.1.0"
    ```

3. **Create a Git tag that matches the version**:

    ```bash
    # Create an annotated tag (recommended)
    git tag -a v1.1.0 -m "Release version 1.1.0"

    # Or create a lightweight tag
    git tag v1.1.0
    ```

4. **Push both the commit and the tag**:

    ```bash
    git push origin main
    git push origin v1.1.0

    # Or push all tags at once
    git push --tags
    ```

#### Tag Naming Conventions

PowerTool's installation system supports flexible tag naming:

-   **Recommended**: Use `v` prefix (e.g., `v1.0.0`, `v2.1.3`)
-   **Also supported**: Without prefix (e.g., `1.0.0`, `2.1.3`)
-   **Pre-release**: Use semantic versioning pre-release format (e.g., `v1.0.0-alpha.1`, `v2.0.0-beta.2`)

The install command will automatically try both formats:

```bash
# These commands will work for either v1.0.0 or 1.0.0 tags
powertool install username/extension 1.0.0
powertool install username/extension v1.0.0
```

#### Version Examples

**Basic versioning workflow**:

```bash
# Initial release
echo '{"name": "my-ext", "version": "1.0.0"}' > extension.json
git add extension.json
git commit -m "Initial release v1.0.0"
git tag v1.0.0
git push origin main --tags

# Bug fix release
echo '{"name": "my-ext", "version": "1.0.1"}' > extension.json
git add extension.json
git commit -m "Fix critical bug - v1.0.1"
git tag v1.0.1
git push origin main --tags

# Feature release
echo '{"name": "my-ext", "version": "1.1.0"}' > extension.json
git add extension.json
git commit -m "Add new commands - v1.1.0"
git tag v1.1.0
git push origin main --tags
```

**Pre-release versioning**:

```bash
# Alpha release
echo '{"name": "my-ext", "version": "2.0.0-alpha.1"}' > extension.json
git add extension.json
git commit -m "Alpha release for v2.0.0"
git tag v2.0.0-alpha.1
git push origin main --tags

# Beta release
echo '{"name": "my-ext", "version": "2.0.0-beta.1"}' > extension.json
git add extension.json
git commit -m "Beta release for v2.0.0"
git tag v2.0.0-beta.1
git push origin main --tags

# Final release
echo '{"name": "my-ext", "version": "2.0.0"}' > extension.json
git add extension.json
git commit -m "Release v2.0.0"
git tag v2.0.0
git push origin main --tags
```

#### User Installation Examples

Once you've properly tagged your releases, users can install specific versions:

```bash
# Install latest version (from default branch)
powertool install username/my-extension

# Install specific stable release
powertool install username/my-extension v1.2.0
powertool install username/my-extension 1.2.0

# Install pre-release version
powertool install username/my-extension v2.0.0-beta.1

# Install from specific branch (for development)
powertool install username/my-extension develop

# Install from specific commit hash
powertool install username/my-extension a1b2c3d4
```

#### Version Validation

PowerTool will validate that the version in your `extension.json` matches what users expect:

-   When users install a tagged version, PowerTool checks that the `version` field in `extension.json` is consistent
-   This helps prevent confusion and ensures users get the version they intended

#### Best Practices Summary

1. **Always update `extension.json` before tagging**
2. **Use consistent tag naming** (preferably with `v` prefix)
3. **Create annotated tags with descriptive messages**
4. **Push both commits and tags to your repository**
5. **Follow semantic versioning principles**
6. **Test your extension before creating release tags**
7. **Document breaking changes in major version updates**

#### Troubleshooting Version Issues

If users report installation issues:

1. **Check that tags exist**: `git tag -l`
2. **Verify tag is pushed**: Check your repository's tags on GitHub/GitLab
3. **Ensure version in `extension.json` matches tag name** (minus the `v` prefix)
4. **Test installation yourself**: `powertool install yourusername/yourextension tagname`

Example debugging commands:

```bash
# List all tags
git tag -l

# Show tag details
git show v1.0.0

# Check if tag exists on remote
git ls-remote --tags origin

# Force push tags if needed
git push origin --tags --force
```

## Example: Complete File Management Extension

This example demonstrates a complete extension with custom settings:

### Directory Structure

```
extensions/
└── file-manager/
    ├── extension.json
    ├── modules/
    │   ├── FileOperations.psm1
    │   └── FileUtilities.psm1
    └── README.md
```

### extension.json

```json
{
    "name": "file-manager",
    "description": "Advanced file management operations for PowerTool",
    "version": "1.2.0",
    "author": "PowerTool Developer",
    "modules": ["modules/FileOperations.psm1", "modules/FileUtilities.psm1"],
    "dependencies": {
        "powertool": ">=0.1.0",
        "sn0w12/PowerToolUtilities": ">=1.0.0"
    },
    "keywords": ["files", "management", "utility"]
}
```

### FileOperations.psm1

```powershell
# Register extension settings
function Initialize-FileManagerSettings {
    $settingsSchema = @{
        "auto-overwrite" = @{
            Type = "Boolean"
            Default = $false
            Description = "Automatically overwrite existing files without confirmation"
        }
        "backup-before-overwrite" = @{
            Type = "Boolean"
            Default = $true
            Description = "Create backup before overwriting files"
        }
        "default-backup-suffix" = @{
            Type = "String"
            Default = ".backup"
            Description = "Default suffix for backup files"
        }
    }

    Register-ExtensionSettings -ExtensionName "file-manager" -SettingsSchema $settingsSchema
}

# Initialize settings when module loads
Initialize-FileManagerSettings

function Invoke-FileDuplication {
    param(
        [string]$SourcePath,
        [string]$DestinationPath,
        [switch]$Force
    )

    $source = Get-TargetPath $SourcePath
    $destination = Get-TargetPath $DestinationPath

    if (-not (Test-Path $source)) {
        Write-Host "Source path not found: $source" -ForegroundColor Red
        return
    }

    # Use extension settings
    $autoOverwrite = Get-Setting -Key "file-manager.auto-overwrite"
    $backupBeforeOverwrite = Get-Setting -Key "file-manager.backup-before-overwrite"
    $backupSuffix = Get-Setting -Key "file-manager.default-backup-suffix"

    if ((Test-Path $destination)) {
        if (-not $autoOverwrite -and -not $Force) {
            if (-not (Confirm-DestructiveOperation "Destination exists. Overwrite $destination?")) {
                return
            }
        }

        if ($backupBeforeOverwrite) {
            $backupPath = $destination + $backupSuffix
            Write-Host "Creating backup: $backupPath" -ForegroundColor Yellow
            Copy-Item $destination $backupPath -Force
        }
    }

    try {
        Copy-Item $source $destination -Recurse -Force
        Write-Host "Successfully copied $source to $destination" -ForegroundColor Green
    }
    catch {
        Write-Host "Error copying files: $($_.Exception.Message)" -ForegroundColor Red
    }
}

$script:ModuleCommands = @{
    "duplicate-file" = @{
        Aliases = @("dup", "copy-file")
        Action = {
            Invoke-FileDuplication -SourcePath $Value1 -DestinationPath $Value2 -Force:$Force
        }
        Summary = "Duplicate files or directories with configurable backup and overwrite behavior"
        Options = @{
            0 = @(
                @{ Token = "source"; Type = "Argument"; Description = "Source file or directory path" }
                @{ Token = "destination"; Type = "Argument"; Description = "Destination path" }
            )
        }
        Examples = @(
            "powertool duplicate-file source.txt backup.txt",
            "powertool dup C:\MyFolder C:\Backup\MyFolder"
        )
    }
}

Export-ModuleMember -Function Invoke-FileDuplication -Variable ModuleCommands
```

This comprehensive extension system allows for powerful customization while maintaining consistency with PowerTool's core architecture and user experience. Extensions can define their own settings that integrate seamlessly with PowerTool's configuration system.
