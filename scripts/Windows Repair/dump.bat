:: Copyright (c) 2024 ShinTheBean
@echo off
title Minidump Folder Converter
echo Promting UAC..
if not "%1"=="am_admin" (powershell start -verb runas '%0' am_admin & exit /b)
cls
:: %[varname]:[char]=% for removing all occurences of a single char in a string
:: source folder for the minidumps
set dmp_src=%systemroot%\minidump\*.dmp
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
set zip_tar=%userprofile%\Desktop\dmp_%random%.zip
:: figure out where Desktop is
if exist %onedrive%\Desktop (
    set zip_tar=%OneDrive%\Desktop\dmp_%random%.zip
)

powershell Compress-Archive -Path %dmp_src% -DestinationPath %zip_tar%
cls
if exist %zip_tar% (
    echo ----------------------------------------------------------
    echo  FILES ARE READY TO BE SHARED, FIND THEM ON YOUR DESKTOP!
    echo ----------------------------------------------------------
    echo Press any key to exit...
    pause > nul
    exit 0
) 
echo The files were not archived
echo Press any key to exit...
pause > nul
exit 1
