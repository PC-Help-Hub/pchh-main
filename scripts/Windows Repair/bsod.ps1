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

$random = Get-Random -Minimum 1 -Maximum 10000
$minidumpFolder = Join-Path $env:systemroot "minidump"
$dumpsFolder = Join-Path $minidumpFolder "Dumps"
if (-not (Test-Path $dumpsFolder)) {
    New-Item -Path $dumpsFolder -ItemType Directory | Out-Null
}
$source = Join-Path $minidumpFolder "*.dmp"
$ziptar = Join-Path $dumpsFolder "Files_$random.zip"
$app_eventlog_path = Join-Path $dumpsFolder "application_logs.evtx"
$sys_eventlog_path = Join-Path $dumpsFolder "system_logs.evtx"

remove-item -path $env:systemroot\minidump\Dumps\*

Write-Host "Looking for any dump files.."

if (-not (Test-Path $source)) {
    Write-Host "No dump files have been found."
    Write-Host "Press any key to exit..."
    $null = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    exit
}

Write-Host "Dump files have been found at $minidumpFolder"
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

    Add-Type -AssemblyName System.Windows.Forms
    [System.Windows.Forms.Clipboard]::SetFileDropList([System.Collections.Specialized.StringCollection]@($ziptar))

    Write-Host "------------------------------"
    Write-Host " FILES ARE READY TO BE SHARED "
    Write-Host "------------------------------"
    Start-Process explorer.exe -ArgumentList $dumpsFolder
    Write-Host "Press any key to exit the script.."
    $null = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    exit
}
else {
    Write-Host "The files were unable to be archived.."
    Write-Host "Press any key to exit.."
    $null = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    exit
}
