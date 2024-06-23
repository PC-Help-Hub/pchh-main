:: Copyright (c) 2024 ShinTheBean

@echo off
title DISM
echo Prompting UAC to user..
if not "%1"=="am_admin" (powershell start -verb runas '%0' am_admin & exit /b)
:starts
cls
echo                    Created by shinthebean for PC Help Hub Discord
echo                  Any issues/queries contact shinthebean on Discord
echo                      https://gitlab.com/shinthebean/batchfiles
echo                                Credits to: jheden
echo.
:: Tests network connection for DISM /ONLINE
echo Testing network connection...
curl www.google.com >nul 2>&1
if %errorlevel% neq 0 (
echo No active Network Connection detected..
echo Unable to check for corruption.
echo Performing System File Check...
goto sfc
)

echo Network Connection detected! Continuing with script...
echo.
echo -------------------------------------------
echo             STARTING COMMANDS
echo -------------------------------------------
echo.
echo Select N for a quick scan
set /p "scanprompt=Would you like to do a thorough scan for corruption? (Y/N) "
echo.
if /i "%scanprompt%"=="Y" goto scanhealth
if /i "%scanprompt%"=="N" goto checkhealth
echo The option you chose isn't valid; Please select Y or N
echo Press any key to go back to the prompt.
pause > nul
goto :starts

:scanhealth
echo Performing a thorough scan for corruption..
echo This will take some time to complete
powershell -ExecutionPolicy Bypass -Command "$output = & {DISM /Online /Cleanup-Image /ScanHealth}; if ($output -match 'No component store corruption detected') { exit 0 } else { exit 1 }"
if %errorlevel% EQU 0 (
	echo No file corruption detected, checking windows integrity..
	echo.
	goto sfc
) else (
	echo.
	goto corruption
)

:checkhealth
echo Performing quick scan for corruption..
powershell -ExecutionPolicy Bypass -Command "$output = & {DISM /Online /Cleanup-Image /CheckHealth}; if ($output -match 'No component store corruption detected') { exit 0 } else { exit 1 }"
if %errorlevel% EQU 0 (
	echo No file corruption detected, checking windows integrity..
	echo.
	goto sfc
) else (
	echo.
	goto corruption
)

:corruption
echo Corruption Detected, pushing fix..
echo Keep in mind this will take some time to complete (~15 minutes depending on system specs)
echo.
DISM /Online /Cleanup-Image /StartComponentCleanup >nul 2>&1
echo 1/2 Complete
DISM /Online /Cleanup-Image /RestoreHealth >nul 2>&1
echo 2/2 Complete
echo.
:sfc
echo Performing System File Check...
powershell -ExecutionPolicy Bypass -Command "$output = & {sfc /scannow}; if ($output -match 'restart') { exit 0 } else { exit 1 }"
if %errorlevel% EQU 0 (
	set restartneeded=true
)
echo System File Check has finished
echo.
echo -----------------------------------------
echo           COMMANDS FINISHED
echo -----------------------------------------
echo.
if "%restartneeded%"=="true" (
    echo Press OK on the prompt to restart your PC
    powershell -ExecutionPolicy Bypass -Command "Add-Type -AssemblyName PresentationFramework; $result = [System.Windows.MessageBox]::Show('Corruption has been fixed, but a restart is required for changes to apply; Press OK to Restart your PC', 'Restart Confirmation', [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Warning); if ($result -eq [System.Windows.MessageBoxResult]::OK) { shutdown /r /t 0 }"
)

echo Your Windows Integrity is OK!
echo Press any key to exit...
pause > nul
exit /b
