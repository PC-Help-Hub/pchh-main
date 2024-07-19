Set-ExecutionPolicy -ExecutionPolicy Unrestricted -Scope Process -Force

$Host.UI.RawUI.WindowTitle = "Windows Update Fix Script"

Clear-Host
Write-Host "Checking if script is running as an administrator.."
if (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Host "Script must be ran as an Administrator for it to work correctly."
    Write-Host "Retry with Powershell running as an Administrator.."
    Write-Host "Press any key to exit the script.."
    $null = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    exit
}

Clear-Host
Write-Host "                  Created by shinthebean for PC Help Hub Discord"
Write-Host "                 Any issues/queries contact shinthebean on Discord"
Write-Host "             https://github.com/PC-Help-Hub/pchh-main/tree/main/scripts"
Write-Host "                        Credits of inspiration to: jheden"
Write-Host ""
Write-Host "---------------------------------"
Write-Host "        STARTING COMMANDS        "
Write-Host "---------------------------------"
Write-Host ""
Write-Host "Stopping the Windows Update services.."

function Stop-ServiceIfRunning {
    param (
        [string]$serviceName
    )
    $service = Get-Service -Name $serviceName
    if ($service.Status -eq 'Running') {
        try {
            Stop-Service -Name $serviceName -Force > $null 2>&1
        }
        catch {
            Stop-Service -Name $serviceName -Force > $null 2>&1
        }
    }
}

Stop-ServiceIfRunning -serviceName 'BITS' > $null 2>&1
Stop-ServiceIfRunning -serviceName 'wuauserv' > $null 2>&1
Stop-ServiceIfRunning -serviceName 'cryptsvc' > $null 2>&1

Write-Host "Services stopped.."
Write-Host ""
Write-Host "Renaming windows update folders.."
try {
    Remove-Item -Path "$env:ALLUSERSPROFILE\Application Data\Microsoft\Network\Downloader\qmgr*.dat" -Force > $null 2>&1
}
catch {
    Remove-Item -Path "$env:ALLUSERSPROFILE\Application Data\Microsoft\Network\Downloader\qmgr*.dat" -Force > $null 2>&1
}

try {
    Rename-Item -Path "$env:SystemRoot\SoftwareDistribution\DataStore" -NewName "DataStore.bak" -Force > $null 2>&1
}
catch {
    Rename-Item -Path "$env:SystemRoot\SoftwareDistribution\DataStore" -NewName "DataStore.bak" -Force > $null 2>&1
}
try {
    Rename-Item -Path "$env:SystemRoot\SoftwareDistribution\Download" -NewName "Download.bak" -Force > $null 2>&1
}
catch {
    Rename-Item -Path "$env:SystemRoot\SoftwareDistribution\Download" -NewName "Download.bak" -Force > $null 2>&1
}
try {
    Rename-Item -Path "$env:SystemRoot\System32\catroot2" -NewName "catroot2.bak" -Force > $null 2>&1
}
catch {
    Rename-Item -Path "$env:SystemRoot\System32\catroot2" -NewName "catroot2.bak" -Force > $null 2>&1
}

Write-Host "Folders have been renamed.."
Write-Host ""
Write-Host "Resetting BITS service & Update Service to default security descriptor.."
try {
    Start-Process -FilePath "sc.exe" -ArgumentList "sdset bits D:(A;CI;CCDCLCSWRPWPDTLOCRSDRCWDWO;;;SY)(A;;CCDCLCSWRPWPDTLOCRSDRCWDWO;;;BA)(A;;CCLCSWLOCRRC;;;IU)(A;;CCLCSWLOCRRC;;;SU)" -NoNewWindow -Wait | Out-Null
}
catch {
    Start-Process -FilePath "sc.exe" -ArgumentList "sdset bits D:(A;CI;CCDCLCSWRPWPDTLOCRSDRCWDWO;;;SY)(A;;CCDCLCSWRPWPDTLOCRSDRCWDWO;;;BA)(A;;CCLCSWLOCRRC;;;IU)(A;;CCLCSWLOCRRC;;;SU)" -NoNewWindow -Wait | Out-Null
}
try {
    Start-Process -FilePath "sc.exe" -ArgumentList "sdset wuauserv D:(A;;CCLCSWRPLORC;;;AU)(A;;CCDCLCSWRPWPDTLOCRSDRCWDWO;;;BA)(A;;CCDCLCSWRPWPDTLOCRSDRCWDWO;;;SY)" -NoNewWindow -Wait | Out-Null
}
catch {
    Start-Process -FilePath "sc.exe" -ArgumentList "sdset wuauserv D:(A;;CCLCSWRPLORC;;;AU)(A;;CCDCLCSWRPWPDTLOCRSDRCWDWO;;;BA)(A;;CCDCLCSWRPWPDTLOCRSDRCWDWO;;;SY)" -NoNewWindow -Wait | Out-Null
}

Write-Host "Successfully reset services to default security descriptor.."
Write-Host ""
Write-Host "Reregistering BITS & Windows Update files to the registry.."
Set-Location $env:windir\system32
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
Write-Host "Files have been rewritten to the registry.."
Write-Host ""
Write-Host "Resetting winsock then restarting the update services.."
netsh winsock reset > $null 2>&1

function Start-ServiceIfRunning {
    param (
        [string]$serviceName
    )
    $service = Get-Service -Name $serviceName
    if ($service.Status -eq 'Stopped') {
        try {
            Start-Service -Name $serviceName -Force > $null 2>&1
        }
        catch {
            Start-Service -Name $serviceName -Force > $null 2>&1
        }
    }
    else {
        try {
            Restart-Service -Name $serviceName -Force > $null 2>&1
        }
        catch {
            Restart-Service -Name $serviceName -Force > $null 2>&1
        }
    }
}

Start-ServiceIfRunning -serviceName 'BITS' > $null 2>&1
Start-ServiceIfRunning -serviceName 'wuauserv' > $null 2>&1
Start-ServiceIfRunning -serviceName 'cryptsvc' > $null 2>&1

Write-Host "Successfully reset winsock & restarted the update services.."
Write-Host ""
Write-Host "Peforming SFC & DISM.. (This will take a few minutes..)"
DISM /Online /Cleanup-Image /StartComponentCleanup > $null 2>&1
Write-Host "1/3 Complete"
DISM /Online /Cleanup-Image /RestoreHealth > $null 2>&1
Write-Host "2/3 Complete"
sfc /scannow > $null 2>&1
Write-Host "3/3 Complete"
Write-Host "Press OK on the prompt to restart your computer."
Add-Type -AssemblyName PresentationFramework; $result = [System.Windows.MessageBox]::Show('The Windows Update script has completed and will need a restart for it to work correctly. Press OK to restart your Computer.', 'Restart Confirmation', [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Warning); if ($result -eq [System.Windows.MessageBoxResult]::OK) { shutdown /r /t 0 }
pause > $null
