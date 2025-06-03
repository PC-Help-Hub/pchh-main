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
$newWindowSize.Height = 50
$pswindow.WindowSize = $newWindowSize


$Host.UI.RawUI.BackgroundColor = "Black"
$Host.UI.RawUI.ForegroundColor = "White"

Clear-Host

$Host.UI.RawUI.WindowTitle = "PCHH Crashlog Script"

# checks if script is running as admin
if (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Host "============================================" -ForegroundColor Red
    Write-Host "-- Script must be run as an Administrator --" -ForegroundColor Red
    Write-Host "-- Right-Click Start -> Terminal(Admin)   --" -ForegroundColor Red
    Write-Host "============================================" -ForegroundColor Red
    Write-Host ""
    Write-Host "Press any key to exit the script.." -ForegroundColor Yellow
    $null = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    Stop-Process -Id $PID -Force
}

Write-Host ""

# Variable setup
$random = Get-Random -Minimum 1 -Maximum 5000
$minidump = "$env:SystemRoot\minidump"
$source = "$env:SystemRoot\minidump\*.dmp"

$desktop = [Environment]::GetFolderPath("Desktop")

$File = "$desktop\Crash-LOGS"
$infofile = "$File\specs-programs.txt"

$ziptar = "$File\Crashlog-Files_$random.zip"

$sys_eventlog_path = "$File\system_eventlogs.evtx"

$dmpfound = $false

$errors = @{
    fileCreate = $false
    Compress   = $false
    event      = $false
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

function cmark {
    return [char]0x2705
}

function xmark {
    return [char]0x274C
}

function dmpcheck {
    Clear-Host 
    Write-Host ""
    Write-Host "============================================" -ForegroundColor DarkGreen
    Write-Host "-- Script is running as an Administrator --" -ForegroundColor Green
    Write-Host "--         Made by ShinTheBean           --" -ForegroundColor Green
    Write-Host "--       Updated by Solus Bellator       --" -ForegroundColor Green
    Write-Host "--           Updated 6/2/2025            --" -ForegroundColor Green
    Write-Host "============================================" -ForegroundColor DarkGreen
    Write-Host ""
    Write-Host "Making files..." -ForegroundColor Blue

    $limit = (Get-Date).AddDays(-60)

    Get-ChildItem -Path $env:systemroot -Filter "MEMORY.dmp" -File | Remove-Item  -Force -Recurse -ErrorAction SilentlyContinue > $null 2>&1

    if (Test-Path $minidump) {
        Get-ChildItem -Path $source -Recurse -Force | Where-Object { !$_.PSIsContainer -and $_.LastWriteTime -lt $limit } | Remove-Item -Force -ErrorAction SilentlyContinue > $null 2>&1

        if (Test-Path $source) {
            $dmpfound = $true
        }
    }
    
    filecreation
}

function filecreation {
    Remove-Item -Path "$File\*" -Force -Recurse -ErrorAction SilentlyContinue > $null 2>&1

    try {
        New-Item -Path $File -ItemType Directory -Force | Out-Null
        New-Item -Path $infofile -ItemType File -Force | Out-Null
    }
    catch {
        $errors.fileCreate = $true
    }

    fileadd
}

# Grabbing specs & info
function fileadd {

    $secCompat = $false
    $username = whoami
    $cpu = Get-WmiObject Win32_Processor
    $cpuName = $cpu | Select-Object -ExpandProperty Name
    $cpuSpeed = $cpu | Select-Object -ExpandProperty MaxClockSpeed
    $gpu = Get-WmiObject Win32_VideoController | Select-Object -ExpandProperty Name

    if ((Get-Tpm).TpmEnabled -eq "True") {
        $tpmEnabled = "Enabled"
    }
    else {
        $tpmEnabled = "Disabled"
    }

    $tpmVersion = (Get-CimInstance -Namespace "root\CIMV2\Security\MicrosoftTPM" -ClassName Win32_TPM).SpecVersion[0]

    $motherboardModel = Get-WmiObject Win32_BaseBoard | Select-Object -ExpandProperty Product
    $bios = Get-WmiObject Win32_BIOS
    $biosVersion = $bios | Select-Object -ExpandProperty SMBIOSBIOSVersion
    $biosDate = $bios | Select-Object -ExpandProperty ReleaseDate
    $os = Get-WmiObject Win32_OperatingSystem
    $osName = $os | Select-Object -ExpandProperty Caption
    $osVersion = $os | Select-Object -ExpandProperty Version
    $bootDevice = $os | Select-Object -ExpandProperty BootDevice
    $systemDirectory = $env:SystemDrive
    $secureBoot = try { Confirm-SecureBootUEFI } catch { $secCompat = $true }
    $fastboot = (Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power" -Name HiberbootEnabled).HiberbootEnabled

    $buildNumber = (Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion").CurrentBuild
    $ubr = (Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion").UBR
    $build = "$buildNumber.$ubr"


    $lboottime = (Get-CimInstance -ClassName Win32_OperatingSystem).LastBootUpTime
    $uptime = (Get-Date) - $lboottime

    $pgfile = Get-WmiObject -Query "SELECT * FROM Win32_PageFileUsage"
    $pgfilesize = $pgfile.AllocatedBaseSize

    $installedMemory = Get-WmiObject Win32_ComputerSystem | Select-Object -ExpandProperty TotalPhysicalMemory
    $ramSpeed = Get-WmiObject Win32_PhysicalMemory | Select-Object -ExpandProperty Speed

    $secureBootState = if ($secureBoot -match "True") { "Enabled" } elseif ($secureBoot -match "False") { "Disabled" } elseif ($secCompat -eq "$true") { "Not Supported" }
    $fastbootState = if ($fastboot -eq "1") { "Enabled" } else { "Disabled" }

    specs "Username: $username"
    specs "`nCPU: $cpuName"
    specs "CPU Speed: $cpuSpeed"
    specs "GPU: $gpu"
    specs "`nTPM Status: $tpmEnabled"
    if ($tpmEnabled -eq "Enabled") {
        specs "TPM Version: $tpmVersion"
    }
    specs "`nMotherboard: $motherboardModel"
    specs "BIOS Version: $biosVersion"
    specs "BIOS Date: $([System.Management.ManagementDateTimeConverter]::ToDateTime($biosDate))"
    specs "`nOS: $osName"
    specs "OS Version: $osVersion"
    specs "System Uptime: $($uptime.Days) days, $($uptime.Hours) hours, $($uptime.Minutes) minutes"
    specs "Build: $build"
    specs "Page File Size: $pgfilesize MB"
    specs "Boot Device: $bootDevice"
    specs "System Directory: $systemDirectory\"
    specs "Secure Boot State: $secureBootState"
    specs "Fast Boot State: $fastbootState"
    specs "`nRam Capacity: $([math]::Round($installedMemory/1GB)) GB"
    specs "RAM Speed: $ramSpeed MT/s"

    $drives = Get-WmiObject Win32_LogicalDisk | ForEach-Object {
        $logicalDisk = $_
        $windowsDrive = $logicalDisk.DeviceID.TrimEnd(':')

        $partition = Get-Partition | Where-Object { $_.DriveLetter -eq $windowsDrive }

        $diskNumber = if ($partition) {
            $partition.DiskNumber
        }
        else {
            $null
        }

        $disk = if ($null -ne $diskNumber) {
            Get-Disk -Number $diskNumber
        }

        $physicalDisk = if ($disk) {
            Get-PhysicalDisk | Where-Object { $_.DeviceId -eq $diskNumber }
        }

        $driveType = if ($physicalDisk) { $physicalDisk.MediaType } else { 'Unknown' }
        $operationalStatus = if ($physicalDisk) { $physicalDisk.OperationalStatus } else { 'Unknown' }
        $healthStatus = if ($physicalDisk) { $physicalDisk.HealthStatus } else { 'Unknown' }

        $totalSizeGB = if ($logicalDisk.Size) { [math]::Round($logicalDisk.Size / 1GB, 2) } else { 0 }
        $freeSpaceGB = if ($logicalDisk.FreeSpace) { [math]::Round($logicalDisk.FreeSpace / 1GB, 2) } else { 0 }
        $percentageFree = if ($totalSizeGB -ne 0) {
            [math]::Round(($freeSpaceGB / $totalSizeGB) * 100, 2)
        }
        else {
            'N/A'
        }

        [PSCustomObject]@{
            'Drive Label'         = $logicalDisk.DeviceID + '\'
            'Drive Name'          = if (-not [string]::IsNullOrEmpty($logicalDisk.VolumeName)) { $logicalDisk.VolumeName } else { 'No Name Found' }
            'Drive Status'        = "$operationalStatus, $healthStatus"
            'Windows Drive'       = ($logicalDisk.DeviceID -eq "$env:SystemDrive")
            'Drive ID'            = if ($null -ne $diskNumber) { $diskNumber } else { 'Unknown' }
            'Drive Type'          = $driveType
            'Total Size (GB)'     = $totalSizeGB
            'Free Space (GB)'     = $freeSpaceGB
            'Percentage Free (%)' = $percentageFree
        }
    }

    specs "`n`nDrive Information:`n`n"

    foreach ($drive in $drives) {
        specs "Drive Label: $($drive.'Drive Label')"
        specs "Drive Name: $($drive.'Drive Name')"
        specs "Drive Status: $($drive.'Drive Status')"
        specs "Windows Drive: $($drive.'Windows Drive')"
        specs "Drive ID: $($drive.'Drive ID')"
        specs "Drive Type: $($drive.'Drive Type')"
        specs "Total Size (GB): $($drive.'Total Size (GB)')"
        specs "Free Space (GB): $($drive.'Free Space (GB)')"
        specs "Percentage Free (%): $($drive.'Percentage Free (%)')`n"
    }



    $installedPrograms = Get-ItemProperty HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*,
    HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\* |
    Select-Object DisplayName |
    Where-Object { $null -ne $_.DisplayName }

    $programs = $installedPrograms | Out-String

    specs "`n`nPrograms Installed:`n $programs"
    
    Write-Host -NoNewline -ForegroundColor Green "$(cmark)"
    Write-Host " File Creation Complete"

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
    Write-Host "Grabbing event logs.." -ForegroundColor Blue

    $startTime = (Get-Date).AddDays(-14).ToString("yyyy-MM-ddTHH:mm:ss")

    try {
        wevtutil epl System $sys_eventlog_path /q:"*[System[TimeCreated[@SystemTime>='$startTime']]]"
    }
    catch {
        $errors.event = $true
        functionerror
    }

    Write-Host -NoNewline -ForegroundColor Green "$(cmark)"
    Write-Host " Event grab complete.."

    compression
}

# Compresses files
function compression {
    Write-Host ""
    Write-Host "Compressing the files.." -ForegroundColor Blue

    Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\CrashControl" -Name "DisplayParameters" -Value 1 -Type DWord -Force | Out-Null

    $filesToCompress = @($infofile, $sys_eventlog_path)

    if ($dmpfound) {
        $filesToCompress += Get-ChildItem -Path $source
    }

    try {
        Invoke-WithoutProgress {
            Compress-Archive -Path $filesToCompress -CompressionLevel Optimal -DestinationPath $ziptar -Force | Out-Null
        }
    }
    catch {


        Write-Host ""
        Write-Host "     Unable to compress files..." -ForegroundColor Red
        Write-Host "     Re-run the script to attempt to fix the issue." -ForegroundColor Red
        Write-Host ""

        $errors.Compress = $true
        functionerror
    }

    Remove-Item -Path $infofile, $sys_eventlog_path -Force -Recurse -ErrorAction SilentlyContinue > $null 2>&1

    Write-Host -NoNewline -ForegroundColor Green "$(cmark)"
    Write-Host " Compression complete.."

    eof
}

function eof {
    Write-Host ""
    Write-Host "==============================" -ForegroundColor DarkGreen
    Write-Host " FILES ARE READY TO BE SHARED " -ForegroundColor Green
    Write-Host "==============================" -ForegroundColor DarkGreen
    Start-Process explorer.exe -ArgumentList $File
    $eofcomplete = $true

    endmessage
}

function functionerror {
    Write-Host -NoNewline -ForegroundColor Red "$(xmark)"

    if ($errors.Compress -eq "true") {
        Write-Host " There was an error during compression.."
    }
    elseif ($errors.event -eq "true") {
        Write-Host "There was an error while grabbing the event logs.."
    }
    elseif ($errors.fileCreate -eq "true") {
        Write-Host "There was an error while creating files.."
    }

    Write-Host -NoNewline -ForegroundColor White "Error:"
    Write-Host " $_" -ForegroundColor Red

    Remove-Item -Path $infofile, $sys_eventlog_path -Force -Recurse -ErrorAction SilentlyContinue > $null 2>&1

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
    #exit   
    Stop-Process -Id $PID -Force
}

dmpcheck