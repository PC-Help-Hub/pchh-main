@echo off
title Program Installer

if not "%1"=="am_admin" (powershell start -verb runas '%0' am_admin & exit /b)

:: Check if winget is installed
where winget >nul 2>&1
if %errorlevel% neq 0 (
    echo Winget not installed, is requried to run
	echo Installing Winget, do not close the script.
	timeout 2 > nul
	powershell -Command "$progressPreference = 'silentlyContinue'"
	powershell -Command "Invoke-WebRequest -Uri https://aka.ms/getwinget -OutFile Microsoft.DesktopAppInstaller_8wekyb3d8bbwe.msixbundle"
	powershell -Command "Invoke-WebRequest -Uri https://aka.ms/Microsoft.VCLibs.x64.14.00.Desktop.appx -OutFile Microsoft.VCLibs.x64.14.00.Desktop.appx"
	powershell -Command "Invoke-WebRequest -Uri https://github.com/microsoft/microsoft-ui-xaml/releases/download/v2.8.6/Microsoft.UI.Xaml.2.8.x64.appx -OutFile Microsoft.UI.Xaml.2.8.x64.appx"
	powershell -Command "Add-AppxPackage Microsoft.VCLibs.x64.14.00.Desktop.appx"
	powershell -Command "Add-AppxPackage Microsoft.UI.Xaml.2.8.x64.appx"
	powershell -Command "Add-AppxPackage Microsoft.DesktopAppInstaller_8wekyb3d8bbwe.msixbundle"
)

:menu
cls
echo ------------------------------
echo [1] 7-Zip           [2] WinRAR
echo [3] Discord         [4] Steam
echo [5] Spotify         [6] Gimp
echo [7] Blender         [8] Chrome
echo ------------------------------

set /p "pchoice=Please type the program number you would like to install: "

if %pchoice%==1 goto 1
if %pchoice%==2 goto 2
if %pchoice%==3 goto 3
if %pchoice%==4 goto 4
if %pchoice%==5 goto 5
if %pchoice%==6 goto 6
if %pchoice%==7 goto 7
if %pchoice%==8 goto 8

echo Please choose a valid option (1-8)
echo Press any key to go back to the menu;
pause > nul
goto menu

:: 7-Zip -> complete
:1
cd %ProgramFiles%
if exist "7-Zip" (
    echo 7-Zip is already installed, installation will not continue.
	goto menuconfirm
)

echo 7-Zip is not installed on this computer, proceeding with installation..
winget install 7zip.7zip -h >nul 2>&1
echo 7-Zip has been installed!
goto menuconfirm

:: WinRar -> complete
:2
cd %ProgramFiles%
if exist "WinRAR" (
	echo WinRAR is already installed, installation will not continue.
	goto menuconfirm
)

echo WinRAR is not installed on this computer, proceeding with installation..
winget install RARLab.WinRAR -h >nul 2>&1
echo WinRAR has been installed!
goto menuconfirm

:: Discord -> complete
:3
cd %AppData%
if exist "Discord" (
    echo Discord is already installed, installation will not continue.
	goto menuconfirm
)

echo Discord is not installed on this computer, proceeding with installation..
winget install Discord.Discord.PTB  -h >nul 2>&1
echo Discord has been installed!
goto menuconfirm

:: Steam -> complete
:4
cd %USERPROFILE%\AppData\Local
if exist "Steam" (
	echo Steam is already installed, installation will not continue.
	goto menuconfirm
)

echo Steam is not installed on this computer, proceeding with installation..
winget install Valve.Steam -h >nul 2>&1
echo Steam has been installed!
goto menuconfirm

:: Spotify -> complete
:5
cd %appdata%
if exist "Spotify" (
	echo Spotify is already installed, installation will not continue.
	goto menuconfirm
)

echo Spotify is not installed on this computer, proceeding with installation..
winget install Spotify.Spotify -h >nul 2>&1
echo Spotify has been installed!
goto menuconfirm

:: Gimp -> complete
:6
cd %AppData%
if exist "GIMP" (
	echo GIMP is already installed, installation will not continue.
	goto menuconfirm
)

echo GIMP is not installed on this computer, proceeding with installation..
winget install GIMP.GIMP -h >nul 2>&1
echo GIMP has been installed!
goto menuconfirm

:: Blender
:7

cd %ProgramFiles%
if exist "Blender Foundation" (
	echo Blender is already installed, installation will not continue.
	goto menuconfirm
)

echo Blender is not installed on this computer, proceeding with installation..
winget install BlenderFoundation.Blender -h >nul 2>&1
echo Blender has been installed!
goto menuconfirm

:: Chrome
:8
cd AppData\Local\Google
if exist "Chrome" (
	echo Chrome is already installed, installation will not continue.
	goto menuconfirm
)

echo Chrome is not installed on this computer, proceeding with installation..
winget install Google.Chrome -h >nul 2>&1
echo Chrome has been installed!
goto menu



:menuconfirm
echo Press any key to go back to the menu.
pause > nul
goto menu