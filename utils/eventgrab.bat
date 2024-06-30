@echo off
setlocal enabledelayedexpansion

title System Event Grabber

set logfile=%USERPROFILE%\Documents\eventlogs_%random%
set systemeventfile=%logfile%\SystemEvents.evtx
set applicationeventfile=%logfile%\ApplicationEvents.evtx
set zipfile=%logfile%.zip

if not exist %logfile% mkdir %logfile%

echo Grabbing System Events..
wevtutil epl System !systemeventfile! >nul 2>&1
wevtutil epl Application !applicationeventfile! >nul 2>&1
echo.

powershell -ExecutionPolicy Bypass -Command "Compress-Archive -Path !logfile!\* -DestinationPath !zipfile!"

:filecheck
if exist !zipfile! (
    del /q /f !logfile!\*
    rmdir !logfile!
) else (
    goto filecheck
)

if exist %zipfile% (
    powershell -ExecutionPolicy Bypass -Command "Set-Clipboard -Path !zipfile!"
    echo ------------------------------
    echo  FILES ARE READY TO BE SHARED
    echo ------------------------------
    start explorer.exe !zipfile!
    echo Press any key to exit..
    pause > nul
    exit
)

if not exist !zipfile! (
echo %zipfile% failed to create..
echo Press any key to exit..
pause > nul
exit
)

if not exist !systemeventfile! (
    echo System Event Log failed to export..
    echo Press any key to exit..
    pause > nul
    exit
)

if not exist !applicationeventfile (
    echo Application Event Log failed to export..
    echo Press any key to exit..
    pause > nul
    exit
)
