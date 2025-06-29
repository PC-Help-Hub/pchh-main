Set-ExecutionPolicy -ExecutionPolicy Unrestricted -Scope Process -Force

# change window size to fit textt
# change window color
$pshost = Get-Host
$pswindow = $pshost.UI.RawUI

$newBufferSize = $pswindow.BufferSize
$newBufferSize.Width = 170
$newBufferSize.Height = 3000
$pswindow.BufferSize = $newBufferSize

$newWindowSize = $pswindow.WindowSize
$newWindowSize.Width = 170
$newWindowSize.Height = 75
$pswindow.WindowSize = $newWindowSize

$Host.UI.RawUI.BackgroundColor = "Black"
$Host.UI.RawUI.ForegroundColor = "White"

# --------------------

Clear-Host
$Host.UI.RawUI.WindowTitle = "PCHH - SFREP Script"

# script elevation
if (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Host "This script requires Administrative Privileges in order to run." -ForegroundColor Yellow

    Start-Process powershell.exe -Verb RunAs -ArgumentList "-ExecutionPolicy Bypass -File `"$PSCommandPath`""
    Stop-Process -Id $PID
}

#variable setup
$elapsed = 0

$mediaType = (Get-PhysicalDisk -DeviceNumber (Get-Partition -DriveLetter C).DiskNumber).MediaType

#timeout is in seconds
if ($mediaType -eq "SSD") {
    <#SSD#> $timeout = "900"
}
else {
    <#HDD#> $timeout = "2700"
}

function cmark {
    return [char]0x2705
}

function xmark {
    return [char]0x274C
}

$errors = @{
    push         = $false
    timeout      = $false
    requirements = $false
}

Clear-Host

$asciiTitle = @'
 ____   ____ _   _ _   _           ____  _____ ____  _____ ____  
|  _ \ / ___| | | | | | |         / ___||  ___|  _ \| ____|  _ \ 
| |_) | |   | |_| | |_| |  _____  \___ \| |_  | |_) |  _| | |_) |
|  __/| |___|  _  |  _  | |_____|  ___) |  _| |  _ <| |___|  __/ 
|_|    \____|_| |_|_| |_|         |____/|_|   |_| \_\_____|_|    
'@

$asciiTitle.Split("`n") | ForEach-Object { Write-Host $_ -ForegroundColor Cyan }

Write-Host ""
Write-Host ""
Write-Host " ============================================" -ForegroundColor DarkGreen
Write-Host "|-- Script is running as an Administrator -- |" -ForegroundColor DarkGreen
Write-Host "|--         Made by ShinTheBean           -- |" -ForegroundColor DarkGreen
Write-Host "|--          Updated 06/29/2025           -- |" -ForegroundColor DarkGreen
Write-Host " ============================================" -ForegroundColor DarkGreen
Write-Host ""

Write-Host ""
Write-Host "Checking prerequisites..."
Write-Host ""

if (Test-Connection -ComputerName "www.google.com" -Count 3 -Quiet) {
    Write-Host "[$(cmark)] Internet Connection" -ForegroundColor Green
}
else {
    Write-Host "[$(xmark)] Internet Connection" -ForegroundColor Red
    $errors.requirements = "true"
    scripterror
}

if (Test-Path "$env:windir\System32\dism.exe") {
    Write-Host "[$(cmark)] DISM Installed" -ForegroundColor Green
}
else {
    Write-Host "[$(xmark)] DISM Installed" -ForegroundColor Red
    $errors.requirements = "true"
    scripterror
}

if (Test-Path "$env:windir\System32\sfc.exe") {
    Write-Host "[$(cmark)] SFC Installed" -ForegroundColor Green
}
else {
    Write-Host "[$(xmark)] SFC Installed" -ForegroundColor Red
    $errors.requirements = "true"
    scripterror
}

Write-Host ""
Write-Host "All requirements have been met to run the script" -ForegroundColor Green
Write-Host ""

Write-Host "Pushing fixes for system corruption.."
Write-Host ""
Write-Host "This will take a while to complete.."
Write-Host "Feel free to use your system while this script is running.."
Write-Host ""

try {
    # Fixes
    Dism /Online /Cleanup-Image /RevertPendingActions > $null 2>&1
    DISM /Online /Cleanup-Image /StartComponentCleanup /ResetBase $null 2>&1
    Write-Host "`n[1/3]" -ForegroundColor Green -NoNewline; Write-Host " Completed"
    DISM /Online /Cleanup-Image /RestoreHealth $null 2>&1
    Write-Host "`n[2/3]" -ForegroundColor Green -NoNewline; Write-Host " Completed"

    #---------------

    $process = Start-Process -FilePath "sfc.exe" -ArgumentList "/scannow" -NoNewWindow -PassThru

    while (-not $process.HasExited -and $elapsed -lt $timeout) {
        Start-Sleep -Seconds 1
        $elapsed++
    }

    if (-not $process.HasExited) {
        $process | Stop-Process -Force
        Write-Host "`n`n[3/3]" -ForegroundColor Red -NoNewline; Write-Host " Completed"
            
        $errors.timeout = "true"
        scripterror
    }
    else {
        Write-Host "`n[3/3]" -ForegroundColor Green -NoNewline; Write-Host " Completed"
        Write-Host ""
        Write-Host "A restart of your system is required to apply the changes made.." -ForegroundColor Green
        Write-Host ""
        $prompt = Read-Host "Would you like to restart your system? (Y/N)"
        if ($prompt.ToLower() -eq "y") {
            shutdown /r /c "System restart is required to apply changes made to your system.." /t 60
        }
        endmessage
    }

}
catch {
    $errors.push = "true"
    scripterror
}

function scripterror {
    Write-Host ""
        
    if ($errors.timeout -eq "true") {
        Write-Host "You have encountered a Windows bug where running 'sfc /scannow' takes infinitely long to run." -ForegroundColor Red
        Write-Host "A restart of your system will be needed to perform the command." -ForegroundColor Red
        Write-Host "Rerun the script once you restart your system." -ForegroundColor Red
        Write-Host ""
        $prompt = Read-Host "Would you like to restart your system? (Y/N)"
        if ($prompt -eq "Y".ToLower()) {
            Write-Host "Restarting your system in 60 seconds.."
            shutdown /r /c "System restart is required to fix sfc /scannow bug, rerun the script after the restart." /t 60
        }
    }
    elseif ($errors.push -eq "true") {
        Write-Host "[!]" -ForegroundColor Red -NoNewline
        Write-Host " There was an issue while fixing system files.."
    }
    elseif ($errors.requirements -eq "true") {
        Write-Host "[!]" -ForegroundColor Red -NoNewline
        Write-Host " You failed to meet one of the requirements needed to run the script.."
    }

    endmessage
}

function endmessage {
    Write-Host ""
    Write-Host "Press any key to exit.."
    $null = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    Stop-Process -Id $PID -Force
}