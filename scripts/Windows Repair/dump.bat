:: Copyright (c) 2024 ShinTheBean
@echo off
title Minidump Folder Converter
if not "%1"=="am_admin" (powershell start -verb runas '%0' am_admin & exit /b)
cls
:: %[varname]:[char]=% for removing all occurences of a single char in a string
:: source folder for the minidumps
set dmp_src=%systemroot%\minidump\*.dmp
:: target folder for the minidumps
:: graciously provided by Anthony Miller @ https://stackoverflow.com/a/6362922 
FOR /F "tokens=* USEBACKQ" %%F IN (`powershell -NoProfile -Command "(get-date).tostring('HHmmss_ddMMyy')"`) DO (
    SET dtm=%%F
)
set "zip_tar=%systemroot%\minidump\dmp_%dtm%.zip"
echo Looking in %systemroot%\minidump for minidump files..
dir /b "%dmp_src%" > nul 2>&1
:: dir should only have error levels 1 and 0 but might as well make this a != 0 so it dies in literally any but 'working' case
if %errorlevel% NEQ 0 (
    echo No dump files have been found
    echo Press any key to exit...
    pause > nul
    exit 
)
echo Dump files have been found! Zipping them up...
powershell Compress-Archive -Path %dmp_src% -DestinationPath %zip_tar%
if exist %zip_tar% (
    echo ----------------------------------------------------------
    echo  FILES ARE READY TO BE SHARED (%zip_tar%)!
    echo ----------------------------------------------------------
    start explorer.exe %systemroot%\minidump
    echo Press any key to exit...
    pause > nul
    exit 0
) 
echo The files were not archived
echo Press any key to exit...
pause > nul
exit 1
