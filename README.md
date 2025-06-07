# PowerTool

A powerful and extensible command-line utility for Windows PowerShell that provides common file operations, content processing, and system management tasks.

## Features

-   **File Operations**: Rename files randomly, flatten directory structures
-   **Content Processing**: Filter images by size, remove text patterns from files
-   **Modular Architecture**: Core modules with extension support
-   **Smart Command Matching**: Fuzzy command matching with suggestions

## Installation

1. Clone or download the PowerTool repository
2. Run setup.bat

## Quick Start

```powershell
# Show all available commands
powertool help

# Get help for a specific command
powertool help rename-random

# Search for commands
powertool search image

# View current settings
powertool settings

# Use short aliases
pt rr "C:\MyFolder" -recursive
```

## Core Commands

### File Operations

-   **`rename-random` (rr)** - Rename all files with random GUID names
-   **`flatten` (f)** - Move all files from subdirectories to the top level

### Content Processing

-   **`filter-images` (fi)** - Remove images smaller than specified dimensions
-   **`remove-text` (rt)** - Remove text from txt files using regex patterns

### System & Help

-   **`help` (h)** - Show help information
-   **`search` (find, s)** - Search commands by name or description
-   **`version` (v)** - Show PowerTool version
-   **`settings` (config)** - Manage configuration settings
-   **`validate`** - Validate module command definitions

## Usage Examples

### File Operations

```powershell
# Rename all files in current directory with random names
powertool rename-random

# Rename files recursively in a specific folder
powertool rr "C:\MyFolder" -recursive

# Flatten directory structure (move all files to root level)
powertool flatten "C:\DeepFolder"
```

### Content Processing

```powershell
# Remove images smaller than 800x600 pixels
powertool filter-images -MinWidth 800 -MinHeight 600

# Remove images smaller than 1920x1080 from specific folder
powertool fi "C:\Images" -MinWidth 1920 -MinHeight 1080

# Remove images where both width AND height are less than 800px
powertool fi -MinSize 800

# Remove advertisement text from all txt files
powertool remove-text -Pattern "Advertisement.*?End"

# Remove date patterns from txt files in specific folder
powertool rt "C:\Documents" -Pattern "\d{4}-\d{2}-\d{2}"
```

### Settings Management

```powershell
# View all settings
powertool settings

# Filter settings by keyword
powertool settings core

# Change a setting
powertool set core.verbose true
powertool set core.confirm-destructive false

# Get current value of a setting
powertool get core.verbose

# Reset settings to defaults
powertool reset core.verbose
powertool reset all
```

## Configuration

PowerTool stores settings in `%APPDATA%\PowerTool\settings.json`. Key settings include:

-   **`core.verbose`** - Enable detailed output (default: false)
-   **`core.confirm-destructive`** - Prompt before destructive operations (default: true)
-   **`core.max-history`** - Maximum command history entries (default: 100)

## Extension System

PowerTool supports extensions through the `extensions/` directory. Each extension requires:

### Extension Structure

```
extensions/
└── my-extension/
    ├── extension.json
    └── modules/
        └── MyModule.psm1
```

### extension.json Format

```json
{
    "name": "my-extension",
    "description": "My custom extension",
    "version": "1.0.0",
    "modules": ["modules/MyModule.psm1"]
}
```

### Extension Module Format

```powershell
# MyModule.psm1
function My-CustomFunction {
    # Implementation
}

$script:ModuleCommands = @{
    "my-command" = @{
        Aliases = @("mc")
        Action = { My-CustomFunction }
        Summary = "My custom command description"
        Options = @{
            0 = @(
                @{ Token = "parameter"; Type = "OptionalArgument"; Description = "Parameter description" }
            )
        }
        Examples = @("powertool my-command")
    }
}

Export-ModuleMember -Function My-CustomFunction -Variable ModuleCommands
```

## Module Development

### Command Definition Structure

```powershell
$script:ModuleCommands = @{
    "command-name" = @{
        Aliases = @("alias1", "alias2")  # Optional short names
        Action = {
            # PowerShell script block to execute
            # Access parameters via $Value1, $Value2, etc.
        }
        Summary = "Brief description of what the command does"
        Options = @{
            0 = @(  # Syntax group 0
                @{ Token = "param1"; Type = "Argument"; Description = "Required parameter" }
                @{ Token = "param2"; Type = "OptionalArgument"; Description = "Optional parameter" }
            )
            1 = @(  # Alternative syntax group 1
                @{ Token = "Mode"; Type = "Parameter"; Description = "Alternative mode parameter" }
            )
        }
        Examples = @(
            "powertool command-name value1",
            "powertool command-name -Mode alternative"
        )
    }
}
```

### Option Types

-   **`Argument`** - Required parameter `[value]`
-   **`OptionalArgument`** - Optional parameter `[value?]`
-   **`Parameter`** - Named parameter `-Parameter`
-   **`OptionalParameter`** - Optional named parameter `-Parameter?`
-   **`Type`** - Type hint `<type>`
