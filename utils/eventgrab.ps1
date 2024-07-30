Set-ExecutionPolicy -ExecutionPolicy Unrestricted -Scope Process -Force

Clear-Host

if (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Host "Script must be run as an Administrator for it to work correctly."
    Write-Host "Retry with PowerShell running as an Administrator.."
    Write-Host "Press any key to exit the script.."
    $null = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    exit
}

Write-Host ""
$Host.UI.RawUI.WindowTitle = "Event Grab Script"

$random = Get-Random -Minimum 1 -Maximum 10000
$tempFolder = "$env:TEMP\EventLogs"
$logfile = Join-Path $tempFolder "eventlogs_$random"
$syseventfile = Join-Path $logfile "SystemEvents.evtx"
$appeventfile = Join-Path $logfile "ApplicationEvents.evtx"
$ziptar = Join-Path $tempFolder "eventlogs_$random.zip"
$specsfile = Join-Path $logfile "specslist.txt"

function filecreate {
    Remove-Item -Path $tempFolder -Recurse -Force -ErrorAction SilentlyContinue 2>$null
    mkdir $logfile -ErrorAction SilentlyContinue | Out-Null

    if (-not (Test-Path $logfile)) {
        Write-Host "Failed to create log directory. Retrying..."
        filecreate
    } else {
        eventgrab
    }
}

function eventgrab {
    Write-Host "Grabbing your event logs..."

    $startDate = (Get-Date).AddDays(-14).ToString('s')
    $filterQuery = "*[System[TimeCreated[@SystemTime>='$startDate']]]"

    wevtutil epl System $syseventfile /q:$filterQuery
    wevtutil epl Application $appeventfile /q:$filterQuery

    Write-Host ""

    if (-not (Test-Path $syseventfile) -or -not (Test-Path $appeventfile)) {
        functionerror
    }

    specsgrab
}

function specsgrab {
    Write-Host ""
    Write-Host "Grabbing specs.."
    Write-Host ""
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
    } elseif ($secureBootState -eq "False") {
        $secureBootEabled = "Disabled"
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

    compression
}



function specs {
    param (
        [string]$value
    )
    Add-Content -Path $specsfile -Value "$value"
}

function compression {
    Write-Host "Compressing files..."
    Compress-Archive -Path "$logfile\*" -DestinationPath $ziptar
    Start-Sleep -Seconds 3

    if (Test-Path $ziptar) {
        Remove-Item $logfile -Recurse -Force
        eof
    } else {
        functionerror
    }
}

function eof {
    if (Test-Path $ziptar) {
        Add-Type -AssemblyName System.Windows.Forms
        [System.Windows.Forms.Clipboard]::SetFileDropList([System.Collections.Specialized.StringCollection]@($ziptar))

        Write-Host "------------------------------"
        Write-Host " FILES ARE READY TO BE SHARED "
        Write-Host "------------------------------"
        Start-Process explorer.exe -ArgumentList $tempFolder
        Write-Host "Press any key to exit the script.."
        $null = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        exit
    } else {
        functionerror
    }
}

function functionerror {
    Write-Host "An error has occurred within the script.."
    Write-Host "Retry the script | Press any key to exit the script."
    $null = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    exit
}

filecreate
