Set-ExecutionPolicy -ExecutionPolicy Unrestricted -Scope Process -Force

Clear-Host

$Host.UI.RawUI.WindowTitle = "BSOD Script"

# admin check
if (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Host "Script must be run as an Administrator for it to work correctly." -ForegroundColor Yellow
    Write-Host "Retry with PowerShell running as an Administrator.." -ForegroundColor Yellow
    Write-Host "Press any key to exit the script.." -ForegroundColor Yellow
    $null = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    exit
}

Write-Host ""

# variable setup
$random = Get-Random -Minimum 1 -Maximum 10000
$dumpsFolder = "$env:SystemRoot\minidump\Dumps"
$minidumpFolder = "$env:SystemRoot\minidump"
$specsfile = "$env:SystemRoot\minidump\specsfile.txt"

$source = "$env:SystemRoot\minidump\*.dmp"
$ziptar = "$env:SystemRoot\minidump\Dumps\BSOD_FILES_$random.zip"

$sys_eventlog_path = "$env:SystemRoot\minidump\system_eventlogs.evtx"
$app_eventlog_path = "$env:SystemRoot\minidump\application_eventlogs.evtx"

$dumpsFolderErr = "false"
$specsErr = "false"
$compressErr = "false"
$syserror = "false"
$apperror = "false"


# checking for dump files
function dmpcheck {
    Write-Host "Checking for any .dmp files.."

    if (-not (Test-Path $source)) {
        Write-Host ""
        Write-Host "No .dmp files has been detected.."
        eof
    }

    Write-Host "The script has found .dmp files!"
    Write-Host "Starting file creation.."
    filecreation
}

# initial file creation
function filecreation {
    Remove-Item -Path "$env:SystemRoot\minidump\Dumps\*" -Force -ErrorAction SilentlyContinue > $null 2>&1

    if (-not (Test-Path $dumpsFolder)) {
        try {
            New-Item -Path $dumpsFolder -ItemType Directory -Force | Out-Null
        }
        catch {
             $dumpsFolderErr = "true"
            functionerror
        }
    }
    
    try {
        New-Item -Path $specsfile -ItemType File -Force | Out-Null
    } catch {
        $specsErr = "true"
        functionerror
    }
    
    specscreate
}

# grabbing specs
function specscreate {
    New-Item -Path $specsfile -ItemType File -Force | Out-Null
    
    # grabbing sys info
    $cpu = Get-WmiObject Win32_Processor | Select-Object -ExpandProperty Name
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
    $gpu = Get-WmiObject Win32_VideoController | Select-Object -ExpandProperty Name
    $ramSpeed = Get-WmiObject Win32_PhysicalMemory | Select-Object -ExpandProperty Speed

    if ($secureBootState -eq "True") {
        $secureBootEnabled = "Enabled"
    } else {
        $secureBootEnabled = "False"
    }

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

    Write-Host "File creation complete.." -ForegroundColor Green

    eventlogexport
}

function specs {
    param (
        [string]$value
    )
    Add-Content -Path $specsfile -Value "$value"
}

function eventlogexport {
    Write-Host ""
    Write-Host "Grabbing eventlogs.."

    try {
        wevtutil epl System $sys_eventlog_path
    } catch {
        $syserror = "true"
        functionerror
    }

    try {
        wevtutil epl Application $app_eventlog_path
    } catch {
        $apperror = "true"
        functionerror
    }

    Write-Host "Eventgrab complete.." -ForegroundColor Green

    compression
}




# compresses files
function compression {
    Write-Host ""
    Write-Host "Starting file compression.."

    # Compress the .dmp files
    try {
        Compress-Archive -Path $source -DestinationPath $ziptar -Force | Out-Null
    } catch {
        $compressErr = "true"
        functionerror
    }

    try {
        Compress-Archive -Path $specsfile -Update -DestinationPath $ziptar | Out-Null
        Remove-Item -Path $specsfile -Force -ErrorAction SilentlyContinue > $null 2>&1
    } catch {
        $compressErr = "true"
        functionerror
    }

    try {
        Compress-Archive -Path $sys_eventlog_path -Update -DestinationPath $ziptar | Out-Null
        Remove-Item -Path $sys_eventlog_path -Force -ErrorAction SilentlyContinue > $null 2>&1
    } catch {
        $compressErr = "true"
        functionerror
    }

    try {
        Compress-Archive -Path $app_eventlog_path -Update -DestinationPath $ziptar | Out-Null
        Remove-Item -Path $app_eventlog_path -Force -ErrorAction SilentlyContinue > $null 2>&1
    } catch {
        $compressErr = "true"
        functionerror
    }

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
    Start-Process explorer.exe -ArgumentList $dumpsFolder
    endmessage
}



function functionerror {
    if ($dumpsFolderErr -eq "true") {
        Write-Host "There was an error while creating the dumps folder.." -ForegroundColor Red
    } elseif ($specsErr -eq "true") {
        Write-Host "There was an error while creating the specs file.." -ForegroundColor Red
    } elseif ($compressErr -eq "true") {
        Write-Host "There was an error during compression.." -ForegroundColor Red
    } elseif ($syserror -eq "true") {
        Write-Host "There was an error while exporting the system event logs.." -ForegroundColor Red
    } elseif ($apperror -eq "true") {
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
