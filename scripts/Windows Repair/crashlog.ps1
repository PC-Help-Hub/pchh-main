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

Write-Host ""

# Variable setup
$random = Get-Random -Minimum 1 -Maximum 5000
$minidump = "$env:SystemRoot\minidump"
$source = "$env:SystemRoot\minidump\*.dmp"
$appdmp = "$env:LOCALAPPDATA\CrashDumps\*.dmp"

$File = "$env:TEMP\Crash-LOGS"
$appDMPFile = "$File\App_Dumps"
$infofile = "$File\specs-programs.txt"
$ziptar = "$File\Crashlog-Files_$random.zip"

$sys_eventlog_path = "$File\system_eventlogs.evtx"

$dmpfound = $false
$appdmpfound = $false

$errors = @{
    fileCreate = $false
    Compress   = $false
    event      = $false
}

function dmpcheck {
    Clear-Host 
    Write-Host ""
    Write-Host "============================================" -ForegroundColor DarkGreen
    Write-Host "-- Script is running as an Administrator --" -ForegroundColor DarkGreen
    Write-Host "--         Made by ShinTheBean           --" -ForegroundColor DarkGreen
    Write-Host "============================================" -ForegroundColor DarkGreen
    Write-Host ""

    $limit = (Get-Date).AddDays(-60)

    # Handle minidump files
    if (Test-Path $minidump) {
        Get-ChildItem -Path $source -Recurse -Force | Where-Object { !$_.PSIsContainer -and $_.LastWriteTime -lt $limit } | Remove-Item -Force -ErrorAction SilentlyContinue > $null 2>&1
    }
    
    Get-ChildItem -Path $env:systemroot -Filter "MEMORY.dmp" -File | Remove-Item -Force -ErrorAction SilentlyContinue > $null 2>&1

    if (Test-Path $source) {
        $dmpfound = $true
    }

    # Handle application crash dumps
    if (Test-Path $appdmp) {
        Get-ChildItem -Path $appdmp -Recurse -Force | Where-Object { !$_.PSIsContainer -and $_.LastWriteTime -lt $limit } | Remove-Item -Force -ErrorAction SilentlyContinue > $null 2>&1
        
        if (Test-Path $appdmp) {
            $appdmpfound = $true
        }
    }

    filecreation
}

# Initial file creation
function filecreation {
    Write-Host "Creating required files.."
    Remove-Item -Path "$File\*" -Force -Recurse -ErrorAction SilentlyContinue > $null 2>&1

    try {
        New-Item -Path $File -ItemType Directory -Force | Out-Null
        New-Item -Path $infofile -ItemType File -Force | Out-Null

        if ($appdmpfound) {
            New-Item -Path $appDMPFile -ItemType Directory -Force | Out-Null
        }
    }
    catch {
        $errors.fileCreate = $true
    }
    
    if ($appdmpfound) {
        try {
            Get-ChildItem -Path $appdmp | Copy-Item -Destination $appDMPFile -Force -ErrorAction Stop
        }
        catch {
            $errors.fileCreate = $true
            functionerror
        }
    }

    fileadd
}

# Grabbing specs
function fileadd {
    # Grabbing system info
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

    # Grabbing installed programs
    $installedPrograms = Get-ItemProperty HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*,
    HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\* |
    Select-Object DisplayName |
    Where-Object { $null -ne $_.DisplayName }

    $programs = $installedPrograms | Out-String

    specs "`n`nPrograms Installed:`n $programs"
    
    Write-Host "File creation complete.." -ForegroundColor Green

    eventlogexport
}


function specs {
    param (
        [string]$value
    )
    Add-Content -Path $infofile -Value "$value"
}


function eventlogexport {
    Write-Host ""
    Write-Host "Grabbing event logs.."

    $startTime = (Get-Date).AddDays(-14).ToString("yyyy-MM-ddTHH:mm:ss")

    try {
        wevtutil epl System $sys_eventlog_path /q:"*[System[TimeCreated[@SystemTime>='$startTime']]]"
    }
    catch {
        $errors.event = $true
        functionerror
    }

    Write-Host "Event grab complete.." -ForegroundColor Green

    compression
}

# Compresses files
function compression {
    Write-Host ""
    Write-Host "Compressing files.."

    Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\CrashControl" -Name "DisplayParameters" -Value 1 -Type DWord -Force | Out-Null

    $filesToCompress = @($infofile, $sys_eventlog_path)

    if ($dmpfound) {
        $filesToCompress += Get-ChildItem -Path $source
    }

    if ($appdmpfound) {
        $filesToCompress += $appDMPFile
    }

    try {
        Compress-Archive -Path $filesToCompress -DestinationPath $ziptar -Force | Out-Null
    }
    catch {
        $errors.Compress = $true
        functionerror
    }

    Remove-Item -Path $infofile, $sys_eventlog_path, $appDMPFile -Force -Recurse -ErrorAction SilentlyContinue > $null 2>&1

    Write-Host "File compression complete.." -ForegroundColor Green

    eof
}

function eof {
    Write-Host ""
    
    Write-Host "------------------------------"
    Write-Host " FILES ARE READY TO BE SHARED "
    Write-Host "------------------------------"
    Start-Process explorer.exe -ArgumentList $File
    $eofcomplete = $true

    endmessage
}

function functionerror {
    if ($errors.Compress -eq "true") {
        Write-Host "There was an error while compressing the files.." -ForegroundColor Red
    }
    elseif ($errors.event -eq "true") {
        Write-Host "There was an error while exporting the event logs.." -ForegroundColor Red
    }
    elseif ($errors.fileCreate -eq "true") {
        Write-Host "There was an error while creating the required files.." -ForegroundColor Red
    }

    Remove-Item -Path $infofile, $sys_eventlog_path, $appDMPFile -Force -Recurse -ErrorAction SilentlyContinue > $null 2>&1

    endmessage
}

function endmessage {
    Write-Host ""
    Write-Host "Press any key to exit.."

    if ($eofcomplete) {
        Add-Type -AssemblyName System.Windows.Forms
        [System.Windows.Forms.Clipboard]::SetFileDropList([System.Collections.Specialized.StringCollection]@($ziptar))
    }
    $null = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    exit
}

dmpcheck
