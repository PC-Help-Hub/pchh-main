Set-ExecutionPolicy -ExecutionPolicy Unrestricted -Scope Process -Force

$Host.UI.RawUI.BackgroundColor = "Black"
$Host.UI.RawUI.ForegroundColor = "White"

Clear-Host

$Host.UI.RawUI.WindowTitle = "PCHH Crashlog Script"

# Admin check
if (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Host "============================================" -ForegroundColor Red
    Write-Host "-- Script must be ran as an Administrator --" -ForegroundColor Red
    Write-Host "-- Right-Click Start -> Terminal(Admin)   --" -ForegroundColor Red
    Write-Host "============================================" -ForegroundColor Red
    Write-Host ""
    Write-Host "Press any key to exit the script.." -ForegroundColor Yellow
    $null = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    exit
}

$File = "$env:temp\Specs"
$infofile = "$File\specs.txt"

function specsgrab {
    Write-Host ""
    Write-Host "============================================" -ForegroundColor DarkGreen
    Write-Host "-- Script is running as an Administrator --" -ForegroundColor DarkGreen
    Write-Host "--         Made by ShinTheBean           --" -ForegroundColor DarkGreen
    Write-Host "============================================" -ForegroundColor DarkGreen
    Write-Host ""

    Write-Host "Grabbing specs.."

    if (Test-Path -Path "$File") {
        Remove-Item -Path "$File" -Recurse -Force | Out-Null
    }

    New-Item -Path "$File" -ItemType Directory -Force | Out-Null
    New-Item -Path "$infofile" -ItemType File -Force | Out-Null

    $username = whoami
    $cpu = Get-WmiObject Win32_Processor
    $cpuName = $cpu | Select-Object -ExpandProperty Name
    $cpuSpeed = $cpu | Select-Object -ExpandProperty MaxClockSpeed
    $cpuArch = $cpu | Select-Object -ExpandProperty Architecture
    $gpu = Get-WmiObject Win32_VideoController | Select-Object -ExpandProperty Name
    $motherboardModel = Get-WmiObject Win32_BaseBoard | Select-Object -ExpandProperty Product
    $bios = Get-WmiObject Win32_BIOS
    $biosVersion = $bios | Select-Object -ExpandProperty SMBIOSBIOSVersion
    $biosDate = $bios | Select-Object -ExpandProperty ReleaseDate
    $os = Get-WmiObject Win32_OperatingSystem
    $osName = $os | Select-Object -ExpandProperty Caption
    $osVersion = $os | Select-Object -ExpandProperty Version
    $bootDevice = $os | Select-Object -ExpandProperty BootDevice
    $systemDirectory = $env:SystemDrive
    $secureBoot = Confirm-SecureBootUEFI
    $installedMemory = Get-WmiObject Win32_ComputerSystem | Select-Object -ExpandProperty TotalPhysicalMemory
    $ramSpeed = Get-WmiObject Win32_PhysicalMemory | Select-Object -ExpandProperty Speed

    $drives = Get-WmiObject Win32_LogicalDisk | Select-Object DeviceID, VolumeName,
    @{Name = 'Total Size (GB)'; Expression = { [math]::round($_.Size / 1GB, 2) } },
    @{Name = 'Free Space (GB)'; Expression = { [math]::round($_.FreeSpace / 1GB, 2) } },
    @{Name = 'Percentage Free (%)'; Expression = { [math]::round(($_.FreeSpace / $_.Size) * 100, 2) } }
    
    $driveInfo = $drives | Out-String   

    $secureBootState = if ($secureBoot -eq $true) { "Enabled" } else { "Disabled" }

    specs "Username: $username"
    specs "`nCPU Name: $cpuName"
    specs "CPU Max Speed: $cpuSpeed"
    specs "CPU Architecture: $cpuArch"
    specs "GPU Name: $gpu"
    specs "`nMotherboard Model: $motherboardModel"
    specs "BIOS Version: $biosVersion"
    specs "BIOS Date: $([System.Management.ManagementDateTimeConverter]::ToDateTime($biosDate))"
    specs "`nOS Name: $osName"
    specs "OS Version: $osVersion"
    specs "Boot Device: $bootDevice"
    specs "System Directory: $systemDirectory\"
    specs "Secure Boot State: $secureBootState"
    specs "`nRam Capacity: $([math]::Round($installedMemory/1GB)) GB"
    specs "RAM Speed: $ramSpeed MT/s"
    specs "`nDrive Information: $driveInfo" | Out-Null

    Write-Host "Successfully grabbed specs.." -ForegroundColor Green
    endmessage
}

function specs {
    param (
        [string]$value
    )
    Add-Content -Path $infofile -Value "$value"
}

function endmessage {
    Write-Host ""
    Write-Host "------------------------------" -ForegroundColor DarkGreen
    Write-Host " FILES ARE READY TO BE SHARED " -ForegroundColor DarkGreen
    Write-Host "------------------------------" -ForegroundColor DarkGreen
    Start-Process explorer.exe -ArgumentList $File
    Write-Host ""
    Write-Host "Press any key to exit.."
    Add-Type -AssemblyName System.Windows.Forms
    [System.Windows.Forms.Clipboard]::SetFileDropList([System.Collections.Specialized.StringCollection]@($infofile))

    $null = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    exit
}

specsgrab