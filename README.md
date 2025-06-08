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

## Extensions

PowerTool supports a powerful extension system that allows developers to create custom commands and functionality. Extensions are automatically loaded from the `extensions/` directory.

For detailed information on creating and developing extensions, see [EXTENSIONS.md](EXTENSIONS.md).

### Quick Extension Example

```
extensions/
└── my-extension/
    ├── extension.json
    └── modules/
        └── MyModule.psm1
```

Extensions integrate seamlessly with PowerTool's command system, settings, and utilities.
