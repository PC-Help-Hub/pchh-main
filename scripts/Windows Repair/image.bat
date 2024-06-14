:: Copyright (c) 2024 ShinTheBean

@echo off
title DISM

echo Press OK on the prompt to run as an Administrator!
if not "%1"=="am_admin" (powershell -Command "Add-Type -AssemblyName PresentationFramework; [System.Windows.MessageBox]::Show('This script needs to be ran as an Admin. Press OK to run as Admin.', 'Admin Prompt', 'OK', 'Information');")
if not "%1"=="am_admin" (powershell start -verb runas '%0' am_admin & exit /b)

cls
del /q /f %USERPROFILE%\Downloads\resulthealth.txt 2>nul

echo                    Created by shinthebean for PC Help Hub Discord
echo                  Any issues/queries contact shinthebean on Discord
echo                               Credits to: jheden
echo                      https://gitlab.com/shinthebean/batchfiles
echo.
:: tests network connection
echo Testing network connection..
curl www.microsoft.com >nul 2>&1
if %errorlevel% neq 0 (
powershell -window minimized -Command
powershell -Command "Add-Type -AssemblyName PresentationFramework; [System.Windows.MessageBox]::Show('No active Network Connection has been detected, therefore the script cannot continue.', 'Network Issue', 'OK', 'Information');"
exit /b
)
echo Network Connection detected! Continuing with script..
echo.

echo -------------------------------------------
echo             STARTING COMMANDS
echo -------------------------------------------
echo.
echo Working on the commands, this will take a few minutes.
echo.
DISM /Online /Cleanup-Image /CheckHealth > %USERPROFILE%\Downloads\resulthealth.txt 2>nul

set "corruption=false"
set "nocorruption=false"

findstr /c:"The component store is repairable" %USERPROFILE%\Downloads\resulthealth.txt >nul 2>&1
if "%errorlevel%"=="0" (
    set "corruption=true"
)

findstr /c:"No component store corruption detected" %USERPROFILE%\Downloads\resulthealth.txt >nul 2>&1
if "%errorlevel%"=="0" (
    set "nocorruption=true"
)

del /q /f %USERPROFILE%\Downloads\resulthealth.txt >nul

if "%corruption%"=="true" (
    goto scan
) else if "%nocorruption%"=="true" (
    echo No Corruption detected!
    echo Running system file scan..
    sfc /scannow > nul 2>&1
    echo.
    goto restartpc
)

:scan
echo Corruption Detected, running proper commands..
DISM /Online /Cleanup-Image /ScanHealth >nul 2>&1
echo 1/3 Finished
DISM /Online /Cleanup-Image /RestoreHealth >nul 2>&1
echo 2/3 Finished
sfc /scannow >nul 2>&1
echo 3/3 Finished	
echo.
echo -----------------------------------------
echo           COMMANDS FINISHED
echo -----------------------------------------
echo.
goto restartpc

:restartpc
powershell -window minimized -Command ""
powershell -Command "Add-Type -AssemblyName PresentationFramework; $result = [System.Windows.MessageBox]::Show('Do you wish to restart your PC? (recommended)', 'Restart Confirmation', 'YesNo', 'Warning'); if ($result -eq 'Yes') { exit 0 } else { exit 1 }"

if %errorlevel%==0 (
    shutdown /r /t 0
) else (
	goto secondcheck
)
:secondcheck
powershell -Command "Add-Type -AssemblyName PresentationFramework; $result = [System.Windows.MessageBox]::Show('Are you sure? Press No to Restart your PC', 'Restart Confirmation', 'YesNo', 'Warning'); if ($result -eq 'No') { exit 0 } else { exit 1 }"
if %errorlevel%==0 (
	shutdown /r /t 0
) else (
exit /b
)
