Set-ExecutionPolicy -ExecutionPolicy Unrestricted -Scope Process -Force

Write-Host "Prompting UAC.."
# Check if the script is running as Administrator
if (-Not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] 'Administrator')) {
    if ([int](Get-CimInstance -Class Win32_OperatingSystem | Select-Object -ExpandProperty BuildNumber) -ge 6000) {
        $CommandLine = "-File `"" + $MyInvocation.MyCommand.Path + "` " + $MyInvocation.UnboundArguments
        Start-Process -FilePath PowerShell.exe -Verb Runas -ArgumentList $CommandLine
        Exit
    }
}

Clear-Host

# Invoke-WithoutProgress function from https://stackoverflow.com/questions/18770723/hide-progress-of-invoke-webrequest
$null = New-Module {
    function Invoke-WithoutProgress {
        [CmdletBinding()]
        param (
            [Parameter(Mandatory)] [scriptblock] $ScriptBlock
        )

        # Save current progress preference and hide the progress
        $prevProgressPreference = $global:ProgressPreference
        $global:ProgressPreference = 'SilentlyContinue'

        try {
            # Run the script block in the scope of the caller of this module function
            . $ScriptBlock
        }
        finally {
            # Restore the original behavior
            $global:ProgressPreference = $prevProgressPreference
        }
    }
}

function InternetCheck {
    Clear-Host
    Write-Host "                  Created by shinthebean for PC Help Hub Discord"
    Write-Host "                 Any issues/queries contact shinthebean on Discord"
    Write-Host "             https://github.com/PC-Help-Hub/pchh-main/tree/main/scripts"
    Write-Host "                        Credits of inspiration to: jheden"
    Write-Host ""

    # checks for internet
    Write-Host "Testing for an internet connection.."
    try {
        Invoke-WithoutProgress {
        Invoke-WebRequest google.com -ErrorAction Stop > $null
        Write-Host "Network Connection detected! Continuing with script..."
    }
    } catch {
        Write-Host "No active Network Connection detected.."
        Write-Host "Unable to check for corruption.."
        Write-Host "Performing an offline check for corrupted file integrity.."
        IntegCheck
    }
    script
}

function script {
    Write-Host ""
    Write-Host "---------------------------------"
    Write-Host "        STARTING COMMANDS        "
    Write-Host "---------------------------------"
    Write-Host ""
    $scanprompt = Read-Host "Do you wish to do a thorough scan for corruption? (Y for thorough scan | N for quick scan)"

    if ($scanprompt -eq "Y" -or $scanprompt -eq "y") {
        Write-Host ""
        ThoroughScan
    } elseif ($scanprompt -eq "N" -or $scanprompt -eq "n") {
        Write-Host ""
        QuickScan
    } else {
        Write-Host "The option you have chosen isn't valid, press any key to go back to the menu."
        $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown") > $null
        InternetCheck
    }
}

function ThoroughScan {
     Write-Host "Performing a thorough scan.."
     try {
     $thoroughOutput = DISM /Online /Cleanup-Image /ScanHealth
     } catch {
        Write-Host "There was an error while performing DISM Scanhealth" -ForegroundColor Red
        Write-Host "Retry the script or head to the discord and show them the error." -ForegroundColor Red
        eof
     }

     if ($thoroughOutput -like "*No component store corruption detected*") {
        Write-Host "No file corruption detected, checking windows integrity.."
        IntegCheck
     }

     if ($thoroughOutput -like "*The component store is repairable*") {
        corruption
     }

     if ($thoroughOutput -like "*The component store is not repairable*") {
        Write-Host "The scan has indidcated that your windows image is not repairable, and can only be fixed with a Windows Reinstall." -ForegroundColor Red
        Write-Host "Head to the PCHH discord for directions on how to reinstall windows." -ForegroundColor Red
        eof
     }
}

function QuickScan {
    Write-Host "Performing a quick scan.."
    try {
        $quickOutput = DISM /Online /Cleanup-Image /Checkhealth
    } catch {
        Write-Host "There was an error while performing DISM Checkhealth" -ForegroundColor Red
        Write-Host "Retry the script or head to the discord and show them the error." -ForegroundColor Red
        eof
    }

    if ($quickOutput -like "*No component store corruption detected*") {
        Write-Host "No file corruption detected, checking windows integrity.."
        IntegCheck
    }

    if ($quickOutput -like "*The component store is repairable*") {
        corruption
    }

    if ($thoroughOutput -like "*The component store is not repairable*") {
        Write-Host "The scan has indidcated that your windows image is not repairable, and can only be fixed with a Windows Reinstall." -ForegroundColor Red
        Write-Host "Head to the PCHH discord for directions on how to reinstall windows." -ForegroundColor Red
        eof
     }
}

function corruption {
    Write-Host "Corruption Detected, pushing fix.."
    Write-Host "Keep in mind this will take some time to complete (~15 minutes depending on system specs)"
    Write-Host ""
    try {
        DISM /Online /Cleanup-Image /StartComponentCleanup > $null
    } catch {
        Write-Host "There was an error while performing StartComponentCleanup" -ForegroundColor Red
        Write-Host "Retry the script or head to the discord and show them the error." -ForegroundColor Red
        eof
    }
    Write-Host "1/2 Complete"
    try {
        DISM /Online /Cleanup-Image /RestoreHealth > $null
    } catch {
        Write-Host "There was an error while performing StartComponentCleanup" -ForegroundColor Red
        Write-Host "Retry the script or head to the discord and show them the error." -ForegroundColor Red
        eof
    }
    Write-Host "2/2 Complete"
    Write-Host ""
    IntegCheck
}

function IntegCheck {
    try {
        sfc /scannow
    } catch {
        Write-Host "There was an error while doing sfc /scannow" -ForegroundColor Red
        Write-Host "Retry the script or head to the discord and show them the error." -ForegroundColor Red
        eof
    }
    eof
}

function eof {
    Write-Host ""
    Write-Host "Press any key to exit the script!"
    $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown") > $null
    exit
}


InternetCheck
