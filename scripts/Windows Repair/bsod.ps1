Set-ExecutionPolicy -ExecutionPolicy Unrestricted -Scope Process -Force

# Function to set full control permissions
function Set-FullControlPermissions {
    param (
        [string]$Path
    )

    # Check if the path exists
    if (-not (Test-Path -Path $Path)) {
        return
    }

        $currentUser = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name

        $acl = Get-Acl -Path $Path
        $permissions = "FullControl"
        $inheritanceFlags = [System.Security.AccessControl.InheritanceFlags]::ContainerInherit, [System.Security.AccessControl.InheritanceFlags]::ObjectInherit
        $propagationFlags = [System.Security.AccessControl.PropagationFlags]::None

        $adminRule = New-Object System.Security.AccessControl.FileSystemAccessRule("Administrators", $permissions, $inheritanceFlags, $propagationFlags, [System.Security.AccessControl.AccessControlType]::Allow)
        $systemRule = New-Object System.Security.AccessControl.FileSystemAccessRule("SYSTEM", $permissions, $inheritanceFlags, $propagationFlags, [System.Security.AccessControl.AccessControlType]::Allow)
        $userRule = New-Object System.Security.AccessControl.FileSystemAccessRule($currentUser, $permissions, $inheritanceFlags, $propagationFlags, [System.Security.AccessControl.AccessControlType]::Allow)

        $acl.SetAccessRule($adminRule)
        $acl.SetAccessRule($systemRule)
        $acl.SetAccessRule($userRule)

        Set-Acl -Path $Path -AclObject $acl

    }

# Set the window title
$Host.UI.RawUI.WindowTitle = "Minidump Grabber"

if (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Host "Script must be run as an Administrator for it to work correctly."
    Write-Host "Retry with PowerShell running as an Administrator.."
    Write-Host "Press any key to exit the script.."
    $null = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    exit
}

Clear-Host

$dumpsFolder = Join-Path $env:systemroot "minidump\Dumps"
Set-FullControlPermissions -Path $dumpsFolder
$random = Get-Random -Minimum 1 -Maximum 10000
$minidumpFolder = Join-Path $env:systemroot "minidump"
$dumpsFolder = Join-Path $minidumpFolder "Dumps"
try {
    if (-not (Test-Path $dumpsFolder)) {
        New-Item -Path $dumpsFolder -ItemType Directory -Force | Out-Nullrer
        
    }
} catch {
    Write-Host "Failed to create/access the Dumps directory: $_"
    Write-Host "Press any key to exit the script.."
    $null = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    exit
}

$source = Join-Path $minidumpFolder "*.dmp"
$ziptar = Join-Path $dumpsFolder "BSOD_FILES_$random.zip"
$app_eventlog_path = Join-Path $dumpsFolder "application_logs.evtx"
$sys_eventlog_path = Join-Path $dumpsFolder "system_logs.evtx"

    Remove-Item -Path "$dumpsFolder\*" -Force -ErrorAction Stop

Write-Host ""
Write-Host "Looking for any dump files.."

# Check if any dump files exist
if (-not (Test-Path $source)) {
    Write-Host "No dump files have been found."
    Write-Host "Press any key to exit..."
    $null = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    exit
}

Write-Host "Dump files have been found at $minidumpFolder"
Write-Host "Zipping them up!"
Write-Host ""

# Compress the dump files
try {
    Compress-Archive -Path $source -DestinationPath $ziptar -Force
} catch {
    Write-Host "Failed to compress dump files: $_"
    Write-Host "Press any key to exit.."
    $null = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    exit
}

if (Test-Path $ziptar) {
    try {

        Write-Host "Exporting system event logs..."
        wevtutil epl System $sys_eventlog_path
        Write-Host "Exporting application event logs..."
        wevtutil epl Application $app_eventlog_path

        Write-Host "Adding system event logs to zip file..."
        if (Test-Path $sys_eventlog_path) {
            Compress-Archive -Update -Path $sys_eventlog_path -DestinationPath $ziptar
            Remove-Item $sys_eventlog_path -Force
        }
        Write-Host "Adding application event logs to zip file..."
        if (Test-Path $app_eventlog_path) {
            Compress-Archive -Update -Path $app_eventlog_path -DestinationPath $ziptar
            Remove-Item $app_eventlog_path -Force
        }

        Add-Type -AssemblyName System.Windows.Forms
        [System.Windows.Forms.Clipboard]::SetFileDropList([System.Collections.Specialized.StringCollection]@($ziptar))

        Write-Host ""
        Write-Host "------------------------------"
        Write-Host " FILES ARE READY TO BE SHARED "
        Write-Host "------------------------------"
        Start-Process explorer.exe -ArgumentList $dumpsFolder
        Write-Host "Press any key to exit the script.."
        $null = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        exit
    } catch {
        Write-Host "An error occurred while processing event logs or zipping files: $_"
        Write-Host "Press any key to exit.."
        $null = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        exit
    }
} else {
    Write-Host "The files were unable to be archived.."
    Write-Host "Press any key to exit.."
    $null = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    exit
}
