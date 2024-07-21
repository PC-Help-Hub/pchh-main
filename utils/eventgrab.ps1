Set-ExecutionPolicy -ExecutionPolicy Unrestricted -Scope Process -Force

Clear-Host
$Host.UI.RawUI.WindowTitle = "Event Grab Script"

$random = Get-Random -Minimum 1 -Maximum 10000
$logfile = "$env:TEMP\eventlogs_$random"
$syseventfile = "$logfile\SystemEvents.evtx"
$appeventfile = "$logfile\ApplicationEvents.evtx"
$ziptar = "$env:TEMP\eventlogs_$random.zip"

function filecreate {
    mkdir $logfile -ErrorAction SilentlyContinue | Out-Null

    if (-not (Test-Path $logfile)) {
        filecreate
    } else {
        eventgrab
    }
}

function eventgrab {
    Write-Host "Grabbing your event logs.."

    $startDate = (Get-Date).AddDays(-14).ToString('s')
    $filterQuery = "*[System[TimeCreated[@SystemTime>='$startDate']]]"

    wevtutil epl System $syseventfile /q:$filterQuery
    wevtutil epl Application $appeventfile /q:$filterQuery

    Write-Host ""

    if (-not (Test-Path $syseventfile) -or -not (Test-Path $appeventfile)) {
        functionerror
    }

    compression
}

function compression {
    Compress-Archive -Path "$logfile\*" -DestinationPath $ziptar
    Start-Sleep -Seconds 2

    if (Test-Path $ziptar) {
        Remove-Item "$logfile\*" -Force
        eof
    } else {
        functionerror
    }
}

function eof {
    if (Test-Path $ziptar) {
        Add-Type -AssemblyName System.Windows.Forms
        $clipboard = [System.Windows.Forms.Clipboard]::SetFileDropList([System.Collections.Specialized.StringCollection]@($ziptar))
        Write-Host "------------------------------"
        Write-Host " FILES ARE READY TO BE SHARED "
        Write-Host "------------------------------"
        Start-Process explorer.exe -ArgumentList $ziptar
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
