Set-ExecutionPolicy -ExecutionPolicy Unrestricted -Scope Process -Force

$Host.UI.RawUI.WindowTitle = "Minidump Grabber"

 Write-Host "Checking if script is running as an administrator.."
 if (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Host "Script must be ran as an Administrator for it to work correctly."
    Write-Host "Retry with Powershell running as an Administrator.."
    Write-Host "Press any key to exit the script.."
    $null = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    exit
}

Clear-Host

$random = Get-Random -Minimum 1 -Maximum 500
$source = Join-Path $env:systemroot "minidump\*.dmp"
$ziptar = Join-Path $env:systemroot "minidump\dumps_$random.zip"
$app_eventlog_path = Join-Path $env:systemroot "minidump\application_logs.evtx"
$sys_eventlog_path = Join-Path $env:systemroot "minidump\system_logs.evtx"

Write-Host "Looking for any dump files.."

if (-not (Test-Path $source)) {
    Write-Host "No dump files have been found."
    Write-Host "Press any key to exit..."
    $null = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    exit
}

Write-Host "Dump files have been found at $env:SystemRoot\minidump"
Write-Host "Zipping them up!"
Write-Host ""

Compress-Archive -Path $source -DestinationPath $ziptar

if (Test-Path $ziptar) {
    wevtutil epl System $sys_eventlog_path
    wevtutil epl Application $app_eventlog_path

    if (Test-Path $sys_eventlog_path) {
        Compress-Archive -Update -Path $sys_eventlog_path -DestinationPath $ziptar
        Remove-Item $sys_eventlog_path
    }
    if (Test-Path $app_eventlog_path) {
        Compress-Archive -Update -Path $app_eventlog_path -DestinationPath $ziptar
        Remove-Item $app_eventlog_path
    }

    Set-Clipboard -Path $ziptar

    Start-Process explorer.exe -ArgumentList $env:systemroot\minidump

    Write-Host "FOLDER AUTOMATICALLY COPIED TO YOUR CLIPBOARD"
    Write-Host "FILES ARE READY TO BE SHARED"
    Write-Host "FIND THEM AT: $ziptar"
    Write-Host "Press any key to exit the script.."
    $null = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    exit
} else {
    Write-Host "The files were unable to be archived.."
    Write-Host "Press any key to exit.."
    $null = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    exit
}
