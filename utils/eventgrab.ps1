Set-ExecutionPolicy -ExecutionPolicy Unrestricted -Scope Process -Force

$Host.UI.RawUI.WindowTitle = "Event Grab Script"

$random = Get-Random -Minimum 1 -Maximum 10000
$logfile = "$env:TEMP\eventlogs_$random"
$syseventfile = "$logfile\SystemEvents.evtx"
$appeventfile = "$logfile\ApplicationEvents.evtx"
$ziptar = "$env:TEMP\eventlogs_$random.zip"

function filecreate {
mkdir $logfile > $null 2>&1

if (-not (Test-Path $logfile)) {
    filecreate
    } else {
        eventgrab
    }
}

function eventgrab {
Write-Host "Grabbing your event logs.."
wevtutil epl System $syseventfile > $null
wevtutil epl Application $appeventfile > $null
Write-Host ""

if (-not (Test-Path $syseventfile)) {
    functionerror
}

if (-not (Test-Path $appeventfile)) {
    functionerror
}

compression
}

function compression {
Compress-Archive -Path $logfile\* -DestinationPath $ziptar
timeout 2 > $null

    if (Test-Path $ziptar) {
        Remove-Item $logfile\* -Force > $null
        eof
    } else {
        functionerror
    }
}

function eof {
if (Test-Path $ziptar) {
    Set-Clipboard -Path $ziptar
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
    Write-Host "An error has occured within the script.."
    Write-Host "Retry the script | Press any key to exit the script."
    $null = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    exit
}

filecreate