@echo off
title Minidump Folder Converter
echo Prompting UAC...
if not "%1"=="am_admin" (powershell start -verb runas '%0' am_admin & exit /b)
cls

set "dmp_src=%systemroot%\minidump\*.dmp"

FOR /F "tokens=* USEBACKQ" %%F IN (`powershell -NoProfile -Command "(get-date).tostring('HHmmss_ddMMyy')"`) DO (
    SET dtm=%%F
)
set "zip_tar=%systemroot%\minidump\dmp_%dtm%.zip"
set "log_path=%systemroot%\minidump\system.evtx"

echo Looking in %systemroot%\minidump for minidump files...
dir /b "%dmp_src%" > nul 2>&1

if %errorlevel% NEQ 0 (
    echo No dump files have been found.
    echo Press any key to exit...
    pause > nul
    exit 
)

echo Dump files have been found! Zipping them up...
echo.

powershell Compress-Archive -Path "%dmp_src%" -DestinationPath "%zip_tar%"

if exist "%zip_tar%" (
    wevtutil epl System "%log_path%"
    
    if exist "%log_path%" (
        powershell Compress-Archive -Update -Path "%log_path%" -DestinationPath "%zip_tar%"
        del "%log_path%"
    )

    echo FILES ARE READY TO BE SHARED
    echo FIND THEM AT: %zip_tar%
    start explorer.exe %systemroot%\minidump
    echo Press any key to exit...
    pause > nul
    exit 0
)

echo The files were not archived.
echo Press any key to exit...
pause > nul
exit 1
