:: Copyright (c) 2024 ShinTheBean

@echo off
title DISM
if not "%1"=="am_admin" (powershell start -verb runas '%0' am_admin & exit /b)
cls
echo                    Created by shinthebean for PC Help Hub Discord
echo                  Any issues/queries contact shinthebean on Discord
echo                               Credits to: jheden
echo                      https://gitlab.com/shinthebean/batchfiles
echo.
:: tests network connection
echo Testing network connection...
curl www.google.com >nul 2>&1
if %errorlevel% neq 0 (
	powershell -Command "Add-Type -AssemblyName PresentationFramework; [System.Windows.MessageBox]::Show('No active Network Connection has been detected, therefore the script cannot continue.', 'Network Issue', 'OK', 'Error');"
	exit /b
)
echo Network Connection detected! Continuing with script...
echo.
set filename=rslt_%random%.txt
echo -------------------------------------------
echo             STARTING COMMANDS
echo -------------------------------------------
echo.
echo Working on the commands, this will take a few minutes.
echo.
DISM /Online /Cleanup-Image /CheckHealth > %temp%\%filename%
findstr /c:"No component store corruption detected" %temp%\%filename% >nul 2>&1
if %errorlevel% EQU 0 (
	set nocorruption=true
)

del /q /f %temp%\%filename% >nul
if %nocorruption% EQU true (
    echo No Corruption detected!
    echo Running system file scan...
    echo.
    goto sfc
)

echo Corruption Detected, running proper commands..
DISM /Online /Cleanup-Image /ScanHealth >nul 2>&1
echo 1/3 Finished
DISM /Online /Cleanup-Image /RestoreHealth >nul 2>&1
echo 2/3 Finished
:sfc
sfc /scannow >nul 2>&1
echo 3/3 Finished	
echo.
echo -----------------------------------------
echo           COMMANDS FINISHED
echo -----------------------------------------
echo.
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
