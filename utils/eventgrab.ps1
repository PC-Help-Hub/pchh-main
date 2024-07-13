Set-ExecutionPolicy -ExecutionPolicy Unrestricted -Scope Process -Force

Clear-Host
$Host.UI.RawUI.WindowTitle = "Event Grab Script"

$random = Get-Random -Minimum 1 -Maximum 1000
$logfile = "$env:TEMP\eventlogs_$random"
$syseventfile = "$logfile\SystemEvents.evtx"
$appeventfile = "$logfile\ApplicationEvents.evtx"
$ziptar = "$env:TEMP\eventlogs_$random.zip"

mkdir $logfile > $null

Write-Host "Grabbing your event logs.."
wevtutil epl System $syseventfile > $null
wevtutil epl Application $appeventfile > $null
Write-Host ""

Compress-Archive -Path $logfile\* -DestinationPath $ziptar
timeout 2 > $null

    if (Test-Path $ziptar) {
        Remove-Item $logfile\* -Force > $null
    }


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
    Write-Host "Unable to grab your events.."
    Write-Host "Retry the script | Press any key to exit the script."
    $null = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    exit
}
