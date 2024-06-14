:: Copyright (c) 2024 ShinTheBean
@echo off
title DISM

>nul 2>&1 "%SYSTEMROOT%\system32\cacls.exe" "%SYSTEMROOT%\system32\config\system"

if '%errorlevel%' NEQ '0' (
    echo Requesting administrative privileges...
    goto UACPrompt
) else (
    goto gotAdmin
)

:UACPrompt
echo Set UAC = CreateObject("Shell.Application") > "%temp%\getadmin.vbs"
echo UAC.ShellExecute "%~s0", "", "", "runas", 1 >> "%temp%\getadmin.vbs"
"%temp%\getadmin.vbs"
cls
echo Command Prompt needs to be run as Administrator for this to work.
echo Closing in 3 seconds.
timeout 3 > nul
exit /B

:gotAdmin
if exist "%temp%\getadmin.vbs" ( del "%temp%\getadmin.vbs" )
pushd "%CD%"
CD /D "%~dp0"

echo Testing network connection..
timeout 3 > nul
curl www.microsoft.com >nul 2>&1
if %errorlevel% neq 0 (
powershell -window minimized -Command ""
powershell -Command "Add-Type -AssemblyName PresentationFramework; [System.Windows.MessageBox]::Show('No active Network Connection has been detected, therefore the script cannot continue.', 'Network Issue', 'OK', 'Information');"
exit /b
)
echo Network Connection detected! Continuing with script..
echo.

del /q /f %USERPROFILE%\Downloads\resulthealth.txt 2>nul

echo                    Created by shinthebean for PC Help Hub Discord
echo                  Any issues/queries contact shinthebean on Discord
echo                               Credits to: jheden
echo                      https://gitlab.com/shinthebean/batchfiles
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
