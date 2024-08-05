Set-ExecutionPolicy -ExecutionPolicy Unrestricted -Scope Process -Force

$Host.UI.RawUI.BackgroundColor = "Black"
$Host.UI.RawUI.ForegroundColor = "White"

Clear-Host

$Host.UI.RawUI.WindowTitle = "Crashlog Script"

# admin check
if (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    #  Admin text from https://christitus.com/windows-tool/
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

# variable setup
$random = Get-Random -Minimum 1 -Maximum 5000
$source = "$env:SystemRoot\minidump\*.dmp"
$File = "$env:TEMP\FILE-LOGS"
$specsfile = "$File\specs_$random.txt"
$programsfile = "$File\InstalledPrograms_$random.txt"
$ziptar = "$File\INFO-FILES_$random.zip"

$sys_eventlog_path = "$File\system_eventlogs_$random.evtx"
$app_eventlog_path = "$File\application_eventlogs_$random.evtx"

$dmpfound = $false

$errors = @{
    Specs = $false
    EventsFolder = $false
    Programs = $false
    Compress = $false
    SysError = $false
    AppError = $false
}

function dmpcheck {
    Write-Host "Checking for any .dmp files.."

    if (-not (Test-Path $source)) {
        Write-Host ""
        Write-Host "No .dmp files have been detected."
        Write-Host "The script will still grab the event logs."
        Write-Host ""
    } else {
        Write-Host "Dumps have been found!"
        Write-Host ""
        $dmpfound = $true
    }

    filecreation
}

# initial file creation
function filecreation {
    Write-Host "Starting file creation.."
    Remove-Item -Path "$File\*" -Force -ErrorAction SilentlyContinue > $null 2>&1

    try {
        New-Item -Path $File -ItemType Directory -Force | Out-Null
    } catch {
        $errors.EventsFolder = $true
        functionerror
    }

    try {
        New-Item -Path $specsfile -ItemType File -Force | Out-Null
    } catch {
        $errors.Specs = $true
        functionerror
    }

    try {
        New-Item -Path $programsfile -ItemType File -Force | Out-Null
    } catch {
        $errors.Programs = $true
        functionerror
    }
    
    specscreate
}

# grabbing specs
function specscreate {
    # grabbing sys info
    $cpu = Get-WmiObject Win32_Processor | Select-Object -ExpandProperty Name
    $gpu = Get-WmiObject Win32_VideoController | Select-Object -ExpandProperty Name
    $motherboardModel = Get-WmiObject Win32_BaseBoard | Select-Object -ExpandProperty Product
    $bios = Get-WmiObject Win32_BIOS
    $biosVersion = $bios | Select-Object -ExpandProperty SMBIOSBIOSVersion
    $biosDate = $bios | Select-Object -ExpandProperty ReleaseDate
    $os = Get-WmiObject Win32_OperatingSystem
    $osName = $os | Select-Object -ExpandProperty Caption
    $osVersion = $os | Select-Object -ExpandProperty Version
    $bootDevice = $os | Select-Object -ExpandProperty BootDevice
    $systemDirectory = $os | Select-Object -ExpandProperty SystemDirectory
    $secureBootState = Confirm-SecureBootUEFI
    $installedMemory = Get-WmiObject Win32_ComputerSystem | Select-Object -ExpandProperty TotalPhysicalMemory
    $ramSpeed = Get-WmiObject Win32_PhysicalMemory | Select-Object -ExpandProperty Speed

    $secureBootEnabled = if ($secureBootState -eq $true) { "Enabled" } else { "Disabled" }

    specs "CPU Name: $cpu"
    specs "GPU Name: $gpu"
    specs "`nMotherboard Model: $motherboardModel"
    specs "BIOS Version: $biosVersion"
    specs "BIOS Date: $([System.Management.ManagementDateTimeConverter]::ToDateTime($biosDate))"
    specs "`nOS Name: $osName"
    specs "OS Version: $osVersion"
    specs "Boot Device: $bootDevice"
    specs "System Directory: $systemDirectory"
    specs "Secure Boot State: $secureBootEnabled"
    specs "`nRam Capacity: $([math]::Round($installedMemory/1GB)) GB"
    specs "RAM Speed: $ramSpeed MT/s"
    specs "----------"
    specs "Minidumps Found: $dmpfound"

    programs
}

function specs {
    param (
        [string]$value
    )
    Add-Content -Path $specsfile -Value "$value"
}

function programs {
    $installedPrograms = Get-ItemProperty HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*,
    HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\* |
    Select-Object DisplayName |
    Where-Object { $null -ne $_.DisplayName }

    $installedPrograms | Format-Table -AutoSize | Out-File -FilePath $programsfile
    
    Write-Host "File creation complete.." -ForegroundColor Green

    eventlogexport
}

function eventlogexport {
    Write-Host ""
    Write-Host "Grabbing event logs.."

    try {
        wevtutil epl System $sys_eventlog_path
    }
    catch {
        $errors.SysError = $true
        functionerror
    }

    try {
        wevtutil epl Application $app_eventlog_path
    }
    catch {
        $errors.AppError = $true
        functionerror
    }

    Write-Host "Event grab complete.." -ForegroundColor Green

    compression
}

# compresses files
function compression {
    Write-Host ""
    Write-Host "Starting file compression.."

    $filesToCompress = @($specsfile, $programsfile, $sys_eventlog_path, $app_eventlog_path)

    if ($dmpfound) {
        $filesToCompress += $source
    }

    try {
        Compress-Archive -Path $filesToCompress -DestinationPath $ziptar -Force | Out-Null
    }
    catch {
        $errors.Compress = $true
        functionerror
    }

    Remove-Item -Path $specsfile, $programsfile, $sys_eventlog_path, $app_eventlog_path -Force -ErrorAction SilentlyContinue > $null 2>&1

    Write-Host "File compression complete.." -ForegroundColor Green

    eof
}

function eof {
    Add-Type -AssemblyName System.Windows.Forms
    [System.Windows.Forms.Clipboard]::SetFileDropList([System.Collections.Specialized.StringCollection]@($ziptar))

    Write-Host ""
    
    Write-Host "------------------------------"
    Write-Host " FILES ARE READY TO BE SHARED "
    Write-Host "------------------------------"
    Start-Process explorer.exe -ArgumentList $File
    endmessage
}

function functionerror {
    if ($errors.EventsFolder) {
        Write-Host "There was an error while creating the events folder.." -ForegroundColor Red
    } elseif ($errors.Programs) {
        Write-Host "There was an error while creating the programs file.." -ForegroundColor Red
    } elseif ($errors.Specs) {
        Write-Host "There was an error while creating the specs file.." -ForegroundColor Red
    } elseif ($errors.Compress) {
        Write-Host "There was an error during compression.." -ForegroundColor Red
    } elseif ($errors.SysError) {
        Write-Host "There was an error while exporting the system event logs.." -ForegroundColor Red
    } elseif ($errors.AppError) {
        Write-Host "There was an error while exporting the application event logs.." -ForegroundColor Red
    }

    endmessage
}

function endmessage {
    Write-Host ""
    Write-Host "Press any key to exit.."
    $null = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    exit
}

dmpcheck
