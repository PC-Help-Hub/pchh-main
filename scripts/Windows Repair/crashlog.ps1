Set-ExecutionPolicy -ExecutionPolicy Unrestricted -Scope Process -Force

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

<# edit previous text template
    $filestart = "Creating required files.."
    $fileorigpos = $host.UI.RawUI.CursorPosition
    Write-Host $filestart -NoNewline
    $host.UI.RawUI.CursorPosition = $fileorigpos
    Write-Host (" " * $filestart.Length) -NoNewline
    $host.UI.RawUI.CursorPosition = $fileorigpos
    Write-Host "done create"
#>

Clear-Host

$Host.UI.RawUI.WindowTitle = "PCHH Crashlog Script"

# Admin check
if (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Host "============================================" -ForegroundColor Red
    Write-Host "-- Script must be run as an Administrator --" -ForegroundColor Red
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
#$kerneldmp = "$env:SystemRoot\LiveKernelReports\*.dmp"

$File = "$env:TEMP\Crash-LOGS"
#$kernelFile = "$File\Live-Kernel-Dumps"
$infofile = "$File\specs-programs.txt"

$ziptar = "$File\Crashlog-Files_$random.zip"

$transcript = "$env:temp\crashlog_transcript.txt"

$sys_eventlog_path = "$File\system_eventlogs.evtx"

$dmpfound = $false
$kerneldmpfound = $false

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
    Start-Transcript "$transcript" > $null 2>&1
    Clear-Host 
    Write-Host ""
    Write-Host "============================================" -ForegroundColor DarkGreen
    Write-Host "-- Script is running as an Administrator --" -ForegroundColor Green
    Write-Host "--         Made by ShinTheBean           --" -ForegroundColor Green
    Write-Host "--       Updated by Solus Bellator       --" -ForegroundColor Green
    Write-Host "============================================" -ForegroundColor DarkGreen
    Write-Host ""
    Write-Host "Creating required files.." -ForegroundColor Blue

    $limit = (Get-Date).AddDays(-60)

    Get-ChildItem -Path $env:systemroot -Filter "MEMORY.dmp" -File | Remove-Item  -Force -Recurse -ErrorAction SilentlyContinue > $null 2>&1

    if (Test-Path $minidump) {
        Get-ChildItem -Path $source -Recurse -Force | Where-Object { !$_.PSIsContainer -and $_.LastWriteTime -lt $limit } | Remove-Item -Force -ErrorAction SilentlyContinue > $null 2>&1

        if (Test-Path $source) {
            $dmpfound = $true
        }
    }
    

<#    if (Test-Path $kerneldmp) {
        Get-ChildItem -Path $kerneldmp -Recurse -Force | Where-Object { !$_.PSIsContainer -and $_.LastWriteTime -lt $limit } | Remove-Item -Force -ErrorAction SilentlyContinue > $null 2>&1
        
        if (Test-Path $kerneldmp) {
            $kerneldmpfound = $true
        }
    }
#>
    filecreation
}

function filecreation {
    Remove-Item -Path "$File\*" -Force -Recurse -ErrorAction SilentlyContinue > $null 2>&1

    try {
        New-Item -Path $File -ItemType Directory -Force | Out-Null
        New-Item -Path $infofile -ItemType File -Force | Out-Null

        # implicitly disabled through value of $kerneldmpfound

        if ($kerneldmpfound) {
            New-Item -Path $kernelFile -ItemType Directory -Force | Out-Null

            Get-ChildItem -Path $kerneldmp | Copy-Item -Destination $kernelFile -Force -ErrorAction Stop
        }
    }
    catch {
        $errors.fileCreate = $true
    }

    fileadd
}

# Grabbing specs
function fileadd {
    # Grabbing system info
    $secCompat = $false
    $username = whoami
    $cpu = Get-WmiObject Win32_Processor
    $cpuName = $cpu | Select-Object -ExpandProperty Name
    $cpuSpeed = $cpu | Select-Object -ExpandProperty MaxClockSpeed
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
    $secureBoot = try { Confirm-SecureBootUEFI } catch { $secCompat = $true }
    $fastboot = (Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power" -Name HiberbootEnabled).HiberbootEnabled

    $lboottime = (Get-CimInstance -ClassName Win32_OperatingSystem).LastBootUpTime
    $uptime = (Get-Date) - $lboottime

    $pgfile = Get-WmiObject -Query "SELECT * FROM Win32_PageFileUsage"
    $pgfilesize = $pgfile.AllocatedBaseSize

    $installedMemory = Get-WmiObject Win32_ComputerSystem | Select-Object -ExpandProperty TotalPhysicalMemory
    $ramSpeed = Get-WmiObject Win32_PhysicalMemory | Select-Object -ExpandProperty Speed

    $drives = Get-WmiObject Win32_LogicalDisk | ForEach-Object {
        $logicalDisk = $_
        $windowsDrive = $logicalDisk.DeviceID.TrimEnd(':')
    
        $disk = Get-PhysicalDisk | Where-Object {
            $physicalDisk = $_
            $partition = Get-Disk -Number $physicalDisk.DeviceId | Get-Partition | Where-Object { $_.DriveLetter -eq $windowsDrive }
            $null -ne $partition
        }
    
        $driveType = if ($disk) { $disk.MediaType } else { 'Unknown' }
        $diskNumber = if ($disk) { (Get-Disk -Number $disk.DeviceId).Number } else { 'Unknown' }
        $operationalStatus = if ($disk) { $disk.OperationalStatus } else { 'Unknown' }
        $healthStatus = if ($disk) { $disk.HealthStatus } else { 'Unknown' }
    
        $totalSizeGB = if ($logicalDisk.Size) { [math]::round($logicalDisk.Size / 1GB, 2) } else { 0 }
        $freeSpaceGB = if ($logicalDisk.FreeSpace) { [math]::round($logicalDisk.FreeSpace / 1GB, 2) } else { 0 }
    
        $percentageFree = if ($totalSizeGB -ne 0) {
            [math]::round(($freeSpaceGB / $totalSizeGB) * 100, 2)
        }
        else {
            'N/A'
        }
    
        [PSCustomObject]@{
            'Drive Label'         = $logicalDisk.DeviceID + '\'
            'Drive Name'          = if (-not [string]::IsNullOrEmpty($logicalDisk.VolumeName)) { $logicalDisk.VolumeName } else { 'No Name Found' }
            'Drive Status'        = "$operationalStatus, $healthStatus"
            'Windows Drive'       = $logicalDisk.DeviceID -eq "$env:SystemDrive"
            'Drive ID'            = $diskNumber
            'Drive Type'          = if ($driveType) { $driveType } else { 'Unknown' }
            'Total Size (GB)'     = $totalSizeGB
            'Free Space (GB)'     = $freeSpaceGB
            'Percentage Free (%)' = $percentageFree
        }
    }
    
    
    $driveInfo = $drives | Out-String

    $secureBootState = if ($secureBoot -match "True") { "Enabled" } elseif ($secureBoot -match "False") { "Disabled" } elseif ($secCompat -eq "$true") { "Not Supported" }
    $fastbootState = if ($fastboot -eq "1") { "Enabled" } else { "Disabled" }

    specs "Username: $username"
    specs "`nCPU Name: $cpuName"
    specs "CPU Max Speed: $cpuSpeed"
    specs "GPU Name: $gpu"
    specs "`nMotherboard Model: $motherboardModel"
    specs "BIOS Version: $biosVersion"
    specs "BIOS Date: $([System.Management.ManagementDateTimeConverter]::ToDateTime($biosDate))"
    specs "`nOS Name: $osName"
    specs "OS Version: $osVersion"
    specs "System Uptime: $($uptime.Days) days, $($uptime.Hours) hours, $($uptime.Minutes) minutes"
    specs "Page File Size: $pgfilesize MB"
    specs "Boot Device: $bootDevice"
    specs "System Directory: $systemDirectory\"
    specs "Secure Boot State: $secureBootState"
    specs "Fast Boot State: $fastbootState"
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

    # implicitly disabled through value of $kerneldmpfound

    if ($kerneldmpfound) {
        $filesToCompress += $kernelFile
    }

    try {
        Invoke-WithoutProgress {
            Compress-Archive -Path $filesToCompress -CompressionLevel Optimal -DestinationPath $ziptar -Force | Out-Null
        }
    }
    catch {


        Write-Host ""
        Write-Host "     Unable to compress the files, attempting different methods.." -ForegroundColor Yellow
        Write-Host "     Please wait.." -ForegroundColor Yellow
        Write-Host ""

        try {
            $7zdownload = 'https://www.dropbox.com/scl/fi/b3l5abfjph8rdyyz8cnig/7za.exe?rlkey=zykkpatjywlqwu3ikhbs1y1xk&st=yigowc6s&dl=1'

            $wc = New-Object System.Net.WebClient
            $wc.DownloadFile($7zdownload, "$env:temp\7za.exe")
            $wc.Dispose()      

            $7zPath = "$env:temp\7za.exe"
    
            $arguments = @("a", "`"$ziptar`"")
    
            $filesToCompress | ForEach-Object { $arguments += "`"$($_)`"" }
        
            Start-Process -FilePath $7zPath -ArgumentList $arguments -Wait -PassThru -WindowStyle Hidden -ErrorAction SilentlyContinue | Out-Null > $null 2>&1
        }
        catch {
            $errors.Compress = $true
            functionerror
        }

    }

    # Remove-Item -Path $infofile, $sys_eventlog_path, $kernelFile -Force -Recurse -ErrorAction SilentlyContinue > $null 2>&1
    Remove-Item -Path $infofile, $sys_eventlog_path, -Force -Recurse -ErrorAction SilentlyContinue > $null 2>&1

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
        # Write-Host "There was an error while compressing the files.." -ForegroundColor Red
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

    Remove-Item -Path $infofile, $sys_eventlog_path, $kernelFile, $7zPath -Force -Recurse -ErrorAction SilentlyContinue > $null 2>&1

    endmessage
}

function endmessage {
    Write-Host ""

    if (-Not (Test-Path ("$env:temp\clog-no.txt"))) {
        $issueprompt = Read-Host "Were there any issues within the script? (Y/N)"
    
        if ($issueprompt -eq "Y".ToLower()) {
            Write-Host "Redirecting you to the issue creation page.." 
            start "https://github.com/PC-Help-Hub/pchh-main/issues/new/choose"
    
            Write-Host ""
            $askagainprompt = Read-Host "Would you like to be asked this question again when running this script? (Y/N)"
    
            if ($askagainprompt -eq "N".ToLower()) {
                New-Item -Path "$env:temp\clog-no.txt" -ItemType File -Force > $null 2>&1
                Add-Content -Path "$env:temp\clog-no.txt" -Value "No" -Force > $null 2>&1
                Write-Host "You will no longer be asked this question.."
            }
        }
    }

    Write-Host ""
    Write-Host "Press any key to exit.."

    if ($eofcomplete) {
        Add-Type -AssemblyName System.Windows.Forms
        [System.Windows.Forms.Clipboard]::SetFileDropList([System.Collections.Specialized.StringCollection]@($ziptar))

        try {
            Stop-Transcript -ErrorAction SilentlyContinue | Out-Null

            if (Test-Path $transcript) {
                Compress-Archive -Path "$transcript" -DestinationPath "$ziptar" -Update | Out-Null
            }
        }
        catch { }
    }
        
    $null = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    exit
}

dmpcheck