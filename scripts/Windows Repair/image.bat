:: Copyright (c) 2024 ShinTheBean

@echo off
title DISM
if not "%1"=="am_admin" (powershell start -verb runas '%0' am_admin & exit /b)
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
echo No active Network Connection detected.. Script will not check for corruption.
echo Running System File Check..
goto sfc
)

echo Network Connection detected! Continuing with script...
echo.
echo -------------------------------------------
echo             STARTING COMMANDS
echo -------------------------------------------
echo.
echo Working on the commands, this will take a few minutes.
echo.
DISM /Online /Cleanup-Image /CheckHealth | findstr "No component store corruption detected" 
if %errorlevel% EQU 0 (
	echo Running System File Check...
	goto sfc
)

echo Corruption Detected, pushing fix..
DISM /Online /Cleanup-Image /ScanHealth
DISM /Online /Cleanup-Image /RestoreHealth
DISM /Online /Cleanup-Image /StartComponentCleanup
:sfc
sfc /scannow
echo.
echo -----------------------------------------
echo           COMMANDS FINISHED
echo -----------------------------------------
echo.
powershell -Command "Add-Type -AssemblyName PresentationFramework; $result = [System.Windows.MessageBox]::Show('Do you wish to restart your PC? (recommended)', 'Restart Confirmation', 'YesNo', 'Warning'); if ($result -eq 'Yes') { exit 0 } else { exit 1 }"

if %errorlevel% EQU 0 (
    	shutdown /r /t 2
	exit /B
)
powershell -Command "Add-Type -AssemblyName PresentationFramework; $result = [System.Windows.MessageBox]::Show('Are you sure? Press No to Restart your PC', 'Restart Confirmation', 'YesNo', 'Warning'); if ($result -eq 'No') { exit 0 } else { exit 1 }"
if %errorlevel% EQU 0 (
	shutdown /r /t 2
)
exit /B
