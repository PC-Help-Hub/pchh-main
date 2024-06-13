:: MIT License

:: Copyright (c) 2024 ShinTheBean

:: Permission is hereby granted, free of charge, to any person obtaining a copy
:: of this software and associated documentation files (the "Software"), to deal
:: in the Software without restriction, including without limitation the rights
:: to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
:: copies of the Software, and to permit persons to whom the Software is
:: furnished to do so, subject to the following conditions:

:: The above copyright notice and this permission notice shall be included in all
:: copies or substantial portions of the Software.

:: THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
:: IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
:: FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
:: AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
:: LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
:: OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
:: SOFTWARE.

@echo off
title Minidump Folder Converter
set dump_folder=%systemroot%\minidump
dir /b "%dump_folder%\*.dmp" > nul 2>&1
if errorlevel 1 (
    echo Looking in %systemroot%\minidump for minidump files..
    echo No dump files have been found.
    echo Press any key to exit this prompt
    pause > nul
    exit /b
) else (
    echo Dump files have been found!
    goto filecheck
)

:filecheck
rd /s /q %USERPROFILE%\Desktop\minidumps 2>nul
rd /s /q %systemroot%\minidump\files 2>nul

mkdir "%systemroot%\minidump\files"
mkdir "%USERPROFILE%\Desktop\minidumps"
timeout 1 > nul

MOVE "%systemroot%\minidump\*.dmp" "%systemroot%\minidump\files" > nul 2>&1
MOVE "%systemroot%\minidump\files\*.dmp" "%USERPROFILE%\Desktop\minidumps" > nul 2>&1
timeout 1 > nul

setlocal enabledelayedexpansion
set folder="%USERPROFILE%\Desktop\minidumps"
set zip="%USERPROFILE%\Desktop\minidumps.zip"
if exist %zip% del %zip%

powershell Compress-Archive -Path "%folder%\*" -DestinationPath %zip%

if exist "%OneDrive%\Desktop\minidumps" (
    MOVE "%OneDrive%\Desktop\minidumps" "%USERPROFILE%\Desktop\minidumps" > nul 2>&1
)

cls
echo --------------------------
echo  FILES READY TO BE SHARED
echo --------------------------
echo.
echo Deleting excess files in a few seconds..
timeout 2 > nul

rd /s /q %USERPROFILE%\Desktop\minidumps 2>nul
rd /s /q %systemroot%\minidump\files 2>nul
echo.
echo.
echo --------------------------
echo    EXCESS FILES DELETED
echo --------------------------
echo.
goto EndScript

:EndScript
echo Now deleting batch file..
timeout 3 > nul
del "%~f0"
