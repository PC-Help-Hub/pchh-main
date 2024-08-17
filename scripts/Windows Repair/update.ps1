Set-ExecutionPolicy -ExecutionPolicy Unrestricted -Scope Process -Force

$Host.UI.RawUI.BackgroundColor = "Black"
$Host.UI.RawUI.ForegroundColor = "White"

Clear-Host

$Host.UI.RawUI.WindowTitle = "PCHH Update Fix Script"

Remove-Item -Path "$env:temp\update-transcript.txt" -Force > $null 2>&1
Start-Transcript -Path "$env:temp\update-transcript.txt" -Force -ErrorAction SilentlyContinue > $null 2>&1

# admin check
if (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    #  Admin text from https://christitus.com/windows-tool/
    Write-Host ""
    Write-Host "============================================" -ForegroundColor Red
    Write-Host "-- Script must be ran as an Administrator --" -ForegroundColor Red
    Write-Host "--  Right-Click Start -> Terminal(Admin)  --" -ForegroundColor Red
    Write-Host "============================================" -ForegroundColor Red
    Write-Host ""
    Write-Host "Press any key to exit the script.." -ForegroundColor Yellow
    $null = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    exit
}

$null = New-Module {
    function Invoke-WithoutProgress {
        [CmdletBinding()]
        param (
            [Parameter(Mandatory)] [scriptblock] $ScriptBlock
        )

        $prevProgressPreference = $global:ProgressPreference
        $global:ProgressPreference = 'SilentlyContinue'

        try {
            . $ScriptBlock
        }
        finally {
            $global:ProgressPreference = $prevProgressPreference
        }
    }
}

$random = Get-Random -Minimum 1 -Maximum 10000

$errors = @{
    repair     = $false
    service    = $false
    file       = $false
    nointernet = $false
}

function InternetCheck {
    Clear-Host 
    Write-Host ""
    Write-Host "============================================" -ForegroundColor DarkGreen
    Write-Host "-- Script is running as an Administrator --" -ForegroundColor DarkGreen
    Write-Host "--         Made by ShinTheBean           --" -ForegroundColor DarkGreen
    Write-Host "============================================" -ForegroundColor DarkGreen
    Write-Host ""

    Write-Host "Testing for an internet connection.."

    try {
        #Invoke-WebRequest -UseBasicParsing -Uri www.google.com -ErrorAction Stop > $null
        Test-Connection -ComputerName "www.google.com" -ErrorAction SilentlyContinue > $null 2>&1
        Write-Host "A network connection has been detected, continuing with script.." -ForegroundColor Green
        Write-Host ""
    }
    catch {
        $errors.nointernet = "true"
        scripterror
    }

    restore-point
}

function restore-point {
    Write-Host "Creating a restore point before proceeding.."

    # enables system protection to have restorepoint on all drives
    try {
    $driveSpecs = 
    Get-CimInstance -Class Win32_LogicalDisk -ErrorAction SilentlyContinue |
    Where-Object { $_.DriveType -eq 3 } | 
    ForEach-Object { $_.Name + '\' }
  
    Enable-ComputerRestore $driveSpecs -ErrorAction SilentlyContinue

    # disables restorepoint frequency
    Remove-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\SystemRestore" -Name "SystemRestorePointCreationFrequency" -Force > $null
    New-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\SystemRestore\" -Name "SystemRestorePointCreationFrequency" -Value 0 -Force > $null
        
      Invoke-WithoutProgress {
        Checkpoint-Computer -Description "UPDATESCRIPT_$random" -RestorePointType MODIFY_SETTINGS > $null 2>&1
     }
    } catch {
        return
    }
    
    Write-Host "Successfully created a restore point." -ForegroundColor Green
    Write-Host ""
    servicecache
}

function servicecache {
    Write-Host "Stopping windows update services.."

    try {
        Stop-Service -Name 'BITS' -Force > $null 2>&1
        Stop-Service -Name 'msiserver' -Force > $null 2>&1
        Stop-Service -Name 'CryptSvc' -Force > $null 2>&1
        Stop-Service -Name 'wuauserv' -Force > $null 2>&1
    }
    catch {
        $errors.service = "true"
        scripterror
    }

    Write-Host "Successfully stopped the windows update services." -ForegroundColor Green
    Write-Host ""
    Write-Host "Clearing windows update cache.."

    try {
        Remove-Item -Path "$env:SystemRoot\SoftwareDistribution" -Recurse -Force > $null 2>&1
        Remove-Item -Path "$env:SystemRoot\System32\catroot2" -Recurse -Force > $null 2>&1
        Remove-Item -Path "$env:ALLUSERSPROFILE\Application Data\Microsoft\Network\Downloader\qmgr*.dat" -Recurse -Force > $null 2>&1
    }
    catch {
        $errors.file = "true"
        scripterror
    }

    Write-Host "Successfully cleared the update cache." -ForegroundColor Green
    Write-Host ""
    registrysecurity
}

function registrysecurity {
    Write-Host "Resetting update services to default security descriptor.."
    Start-Process -FilePath "sc.exe" -ArgumentList "sdset bits D:(A;CI;CCDCLCSWRPWPDTLOCRSDRCWDWO;;;SY)(A;;CCDCLCSWRPWPDTLOCRSDRCWDWO;;;BA)(A;;CCLCSWLOCRRC;;;IU)(A;;CCLCSWLOCRRC;;;SU)" -ErrorAction SilentlyContinue > $null 2>&1
    Start-Process -FilePath "sc.exe" -ArgumentList "sdset wuauserv D:(A;;CCLCSWRPLORC;;;AU)(A;;CCDCLCSWRPWPDTLOCRSDRCWDWO;;;BA)(A;;CCDCLCSWRPWPDTLOCRSDRCWDWO;;;SY)" -ErrorAction SilentlyContinue > $null 2>&1
    Write-Host "Successfully set security descriptor to default.." -ForegroundColor Green
    Write-Host ""
    Write-Host "Registering files to the registry.."

    regsvr32.exe /s atl.dll | Out-Null
    regsvr32.exe /s urlmon.dll | Out-Null
    regsvr32.exe /s mshtml.dll | Out-Null
    regsvr32.exe /s shdocvw.dll | Out-Null
    regsvr32.exe /s browseui.dll | Out-Null
    regsvr32.exe /s jscript.dll | Out-Null
    regsvr32.exe /s vbscript.dll | Out-Null
    regsvr32.exe /s scrrun.dll | Out-Null
    regsvr32.exe /s msxml.dll | Out-Null
    regsvr32.exe /s msxml3.dll | Out-Null
    regsvr32.exe /s msxml6.dll | Out-Null
    regsvr32.exe /s actxprxy.dll | Out-Null
    regsvr32.exe /s softpub.dll | Out-Null
    regsvr32.exe /s wintrust.dll | Out-Null
    regsvr32.exe /s dssenh.dll | Out-Null
    regsvr32.exe /s rsaenh.dll | Out-Null
    regsvr32.exe /s gpkcsp.dll | Out-Null
    regsvr32.exe /s sccbase.dll | Out-Null
    regsvr32.exe /s slbcsp.dll | Out-Null
    regsvr32.exe /s cryptdlg.dll | Out-Null
    regsvr32.exe /s oleaut32.dll | Out-Null
    regsvr32.exe /s ole32.dll | Out-Null
    regsvr32.exe /s shell32.dll | Out-Null
    regsvr32.exe /s initpki.dll | Out-Null
    regsvr32.exe /s wuapi.dll | Out-Null
    regsvr32.exe /s wuaueng.dll | Out-Null
    regsvr32.exe /s wuaueng1.dll | Out-Null
    regsvr32.exe /s wucltui.dll | Out-Null
    regsvr32.exe /s wups.dll | Out-Null
    regsvr32.exe /s wups2.dll | Out-Null
    regsvr32.exe /s wuweb.dll | Out-Null
    regsvr32.exe /s qmgr.dll | Out-Null
    regsvr32.exe /s qmgrprxy.dll | Out-Null
    regsvr32.exe /s wucltux.dll | Out-Null
    regsvr32.exe /s muweb.dll | Out-Null
    regsvr32.exe /s wuwebv.dll | Out-Null

    Write-Host "Successfully registered files to the registry.. " -ForegroundColor Green
    Write-Host ""
    startservicewinsock
}

function startservicewinsock {
    Write-Host "Resetting winsock.."

    netsh winsock reset > $null 2>&1
    Write-Host "Successfully reset the winsock.." -ForegroundColor Green 
    Write-Host ""
    Write-Host "Starting windows update services.."
    
    try {
        Start-Service -Name 'BITS' -ErrorAction SilentlyContinue > $null 2>&1
        Start-Service -Name 'CryptSvc' -ErrorAction SilentlyContinue > $null 2>&1
        Start-Service -Name 'msiserver' -ErrorAction SilentlyContinue > $null 2>&1
        Start-Service -Name 'wuauserv' -ErrorAction SilentlyContinue > $null 2>&1
    }
    catch {
        $errors.service = "true"
        scripterror
    }

    Write-Host "Successfully started the update services.." -ForegroundColor Green
    Write-Host ""

    repair
}

function repair {
    Write-Host "Performing DISM & System File Repair.."
    Write-Host "This will take some time to complete."
    Write-Host ""

    try {
        DISM /Online /Cleanup-Image /StartComponentCleanup /ResetBase > $null 2>&1
        Write-Host "1/3 Complete" -ForegroundColor Green
        DISM /Online /Cleanup-Image /RestoreHealth > $null 2>&1
        Write-Host "2/3 Complete" -ForegroundColor Green
        sfc /scannow > $null 2>&1
        Write-Host "3/3 Complete" -ForegroundColor Green
    } catch {
        $errors.repair = "true"
        scripterror
    }

    Write-Host ""
    Stop-Transcript | Out-Null
    Write-Host "Successfully performed the commands.." -ForegroundColor Green
    restart
}

function restart {
    Write-Host ""
    Write-Host "A restart of your system will be required to correctly apply the changes that the script has made."
    Write-Host "Press any key to restart your system."
    $null = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    Write-Host "Restarting your system in 60 seconds.."
    shutdown /r /t 60 > $null
    exit
}

function scripterror {
    if ($errors.repair = "true") {
        Write-Host "There was an error while performing DISM/SFC.." -ForegroundColor Red
    } elseif ($errors.service = "true") {
        Write-Host "There was an error while starting/stopping a windows update service." -ForegroundColor Red
        Write-Host "Rerun the script." -ForegroundColor Red
    } elseif ($errors.file = "true") {
        Write-Host "There was an error while clearing the windows update cache.." -ForegroundColor Red
        Write-Host "Rerun the script." -ForegroundColor Red
    } elseif ($errors.nointernet = "true") {
        Write-Host "No internet connection was detected." -ForegroundColor Yellow
        Write-Host "This script requires an active internet connection, retry the script when you meet the requirements." -ForegroundColor Yellow
    }

    endmessage
}

function endmessage {
    Write-Host ""
    Write-Host "Press any key to exit the script.." -ForegroundColor Yellow
    $null = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    Stop-Transcript | Out-Null
    exit
}

InternetCheck