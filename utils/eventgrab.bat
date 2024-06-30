@echo off

title System Event Grabber

set logfile=C:\eventlogs
set eventfile=%logfile%\SystemEvents_%random%.evtx

if not exist %logfile% mkdir %logfile%

echo Grabbing System Events..
wevtutil epl System %eventfile%
echo.

if exist %eventfile% (
    echo ------------------------------
    echo  FILES ARE READY TO BE SHARED
    echo ------------------------------
    start explorer.exe %logfile%
    echo Press any key to exit..
    pause > nul
    exit
)

echo %eventfile% failed to create..
echo Press any key to exit..
pause > nul
exit