@echo off
setlocal

echo PowerTool Setup Script
echo ======================

REM Check if running as administrator
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo This script requires administrator privileges.
    echo Please run as administrator.
    pause
    exit /b 1
)

REM Get the directory where this script is located
set "POWERTOOL_DIR=%~dp0"
REM Remove trailing backslash
set "POWERTOOL_DIR=%POWERTOOL_DIR:~0,-1%"

echo PowerTool directory: %POWERTOOL_DIR%

REM Check if PowerTool directory is already in PATH
echo %PATH% | findstr /i "%POWERTOOL_DIR%" >nul
if %errorLevel% neq 0 (
    echo Adding PowerTool directory to system PATH...
    setx PATH "%PATH%;%POWERTOOL_DIR%" /M >nul
    if %errorLevel% equ 0 (
        echo PowerTool directory added to PATH successfully.
    ) else (
        echo Failed to add PowerTool directory to PATH.
        pause
        exit /b 1
    )
) else (
    echo PowerTool directory is already in PATH.
)

REM Verify required files exist
if not exist "%POWERTOOL_DIR%\powertool.ps1" (
    echo ERROR: powertool.ps1 not found in %POWERTOOL_DIR%
    pause
    exit /b 1
)

if not exist "%POWERTOOL_DIR%\pt.ps1" (
    echo ERROR: pt.ps1 not found in %POWERTOOL_DIR%
    pause
    exit /b 1
)

echo.
echo Setup complete!
echo PowerTool is now available system-wide as both 'powertool' and 'pt'.
echo.
echo IMPORTANT: You need to restart your command prompt or PowerShell
echo session for the PATH changes to take effect.
echo.
echo After restarting, test by running:
echo   powertool help
echo   pt help
echo.
pause