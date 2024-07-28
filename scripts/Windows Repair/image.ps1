Set-ExecutionPolicy -ExecutionPolicy Unrestricted -Scope Process -Force

if (-Not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] 'Administrator')) {
    Write-Host "Powershell needs to be run as an Administrator for this to work."
    Write-Host "Press any key to exit the script!"
    $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown") > $null
    exit
}

Clear-Host

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

function InternetCheck {
    Clear-Host
    Write-Host "                  Created by shinthebean for PC Help Hub Discord"
    Write-Host "                 Any issues/queries contact shinthebean on Discord"
    Write-Host "             https://github.com/PC-Help-Hub/pchh-main/tree/main/scripts"
    Write-Host "                        Credits of inspiration to: jheden"
    Write-Host ""

    Write-Host "Testing for an internet connection.."
    try {
        Invoke-WithoutProgress {
            Invoke-WebRequest google.com -ErrorAction Stop > $null
            Write-Host "Network Connection detected! Continuing with script..."
        }
    }
    catch {
        Write-Host "No active Network Connection detected.." -ForegroundColor Red
        Write-Host "Unable to check for corruption.." -ForegroundColor Red
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
    }
    elseif ($scanprompt -eq "N" -or $scanprompt -eq "n") {
        Write-Host ""
        QuickScan
    }
    else {
        Write-Host "The option you have chosen isn't valid, press any key to go back to the menu."
        $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown") > $null
        InternetCheck
    }
}

function ThoroughScan {
    Write-Host "Performing a thorough scan.."
    Write-Host ""
    try {
        & "DISM.exe" "/Online" "/Cleanup-Image" "/ScanHealth" > $null
        $thoroughExit = $LASTEXITCODE
    }
    catch {
        Write-Host "There was an error while performing DISM ScanHealth" -ForegroundColor Red
        Write-Host "Retry the script or head to the discord and show them the error." -ForegroundColor Red
        eof
    }

    if ($thoroughExit -eq 0) {
        Write-Host "No file corruption detected, checking windows integrity.." -ForegroundColor Green
        IntegCheck
    }
    elseif ($thoroughExit -eq 1) {
        corruption
    }
    elseif ($thoroughExit -eq 2) {
        Write-Host "The scan has indicated that your windows image is not repairable and can only be fixed with a Windows Reinstall." -ForegroundColor Red
        Write-Host "Head to the PCHH discord for directions on how to reinstall windows." -ForegroundColor Red
        eof
    }
    else {
        corruption
    }
}

function QuickScan {
    Write-Host "Performing a quick scan.."
    Write-Host ""
    try {
        & "DISM.exe" "/Online" "/Cleanup-Image" "/CheckHealth" > $null
        $quickExit = $LASTEXITCODE
    }
    catch {
        Write-Host "There was an error while performing DISM CheckHealth" -ForegroundColor Red
        Write-Host "Retry the script or head to the discord and show them the error." -ForegroundColor Red
        eof
    }

    if ($quickExit -eq 0) {
        Write-Host "No file corruption detected, checking windows integrity.." -ForegroundColor Green
        IntegCheck
    }
    elseif ($quickExit -eq 1) {
        corruption
    }
    elseif ($quickExit -eq 2) {
        Write-Host "The scan has indicated that your windows image is not repairable and can only be fixed with a Windows Reinstall." -ForegroundColor Red
        Write-Host "Head to the PCHH discord for directions on how to reinstall windows." -ForegroundColor Red
        eof
    }
    else {
        corruption
    }
}

function corruption {
    Write-Host "Corruption Detected, pushing fix.."
    Write-Host "Keep in mind this will take some time to complete (~15 minutes depending on system specs)"
    Write-Host ""
    try {
        DISM /Online /Cleanup-Image /StartComponentCleanup > $null
    }
    catch {
        Write-Host "There was an error while performing StartComponentCleanup" -ForegroundColor Red
        Write-Host "Retry the script or head to the discord and show them the error." -ForegroundColor Red
        eof
    }
    Write-Host "1/2 Complete"
    try {
        DISM /Online /Cleanup-Image /RestoreHealth > $null
    }
    catch {
        Write-Host "There was an error while performing RestoreHealth" -ForegroundColor Red
        Write-Host "Retry the script or head to the discord and show them the error." -ForegroundColor Red
        eof
    }
    Write-Host "2/2 Complete"
    Write-Host ""
    IntegCheck
}

function IntegCheck {
    Write-Host ""
    Write-Host "Checking file integrity.."
    Write-Host ""

    # Timeout script from: https://www.reddit.com/r/PowerShell/comments/82fl6g/how_do_you_set_timeouts_on_cmdlets/?rdt=53784

    $InitialTimeout = 1500
    $ExtendedTimeout = 4800

    $job = Start-Job -ScriptBlock {
        sfc /scannow
        $exitCode = $LASTEXITCODE
        [PSCustomObject]@{ ExitCode = $exitCode }
    }

    $JobTimer = 0
    while ($job.State -eq "Running" -and $JobTimer -le $InitialTimeout) {
        $JobTimer++
        Start-Sleep -Milliseconds 1000 # Sleep for 1 second increments
    }

    if ($job.State -eq "Running") {
        # Ask the user if they want to continue
        Write-Host "The integrity check is taking longer than usual, you may have encountered a Windows Bug or the process is taking long to complete." -ForegroundColor Yellow
        $userInput = Read-Host "Do you want to continue? It will timeout after 80 minutes; (Y/N)"
        
        if ($userInput -eq "Y" -or $userInput -eq "y") {
            Write-Host ""
            Write-Host "Continuing integrity check.."
            while ($job.State -eq "Running" -and $JobTimer -le ($InitialTimeout + $ExtendedTimeout)) {
                $JobTimer++
                Start-Sleep -Milliseconds 1000 # Sleep for 1 second increments
            }
        } else {
            # User chose not to continue
            Stop-Job -Job $job
            Remove-Job -Job $job
            timeout
        }
    }

    if ($job.State -eq "Running") {
        # Job is still running after extended timeout or user chose not to continue
        Stop-Job -Job $job
        Remove-Job -Job $job
        timeout
    } else {
        # Job completed within the allowed time, get the result
        $result = Receive-Job -Job $job
        Remove-Job -Job $job

        # Retrieve the exit code from the result
        $exitCode = $result.ExitCode
        exitcheck $exitCode
    }
}

function exitcheck {
    param (
        [int]$exitCode
    )

    if ($exitCode -eq 0) {
        Write-Host "Windows has found no corruption." -ForegroundColor Green
        eof
    }
    elseif ($exitCode -eq 1) {
        Write-Host "Windows has detected corruption and has successfully repaired it!" -ForegroundColor Green
        Write-Host "It is recommended to restart your computer for the changes to apply correctly." -ForegroundColor Green
        Write-Host "Press OK on the prompt to restart your PC." -ForegroundColor Green
        restart
    }
    elseif ($exitCode -eq 2) {
        Write-Host "Windows has detected corruption but was unable to repair it, a reinstallation of Windows is needed to repair these files." -ForegroundColor Red
    }
    else {
        Write-Host "There was an output of SFC that isn't common, let's perform a restart of your computer." -ForegroundColor Yellow   
        restart
    }
}



    function timeout {
        Write-Host ""
        Write-Host "The SFC scan has exceeded the expected timeout duration." -ForegroundColor Yellow
        Write-Host "You will need to restart your computer and manually open Command Prompt or PowerShell as an Administrator and run 'sfc /scannow'." -ForegroundColor Yellow
        eof
    }

    function eof {
        Write-Host ""
        Write-Host "Press any key to exit the script!"
        $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown") > $null
        exit
    }

    function unexpecterror {
        Clear-Host
        Write-Host "An unexpected result that isn't written to the script has occurred!"
        Write-Host "Ping @shinthebean for this issue, do not exit the script."
        $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown") > $null
        unexpecterror
    }

    function restart {
        Add-Type -AssemblyName PresentationFramework; 
        $result = [System.Windows.MessageBox]::Show('A restart is required in order for Windows to apply the made changes correctly. Press OK to restart your computer.', 'Restart Confirmation', [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Warning); 
        if ($result -eq [System.Windows.MessageBoxResult]::OK) { shutdown /r /t 0 }
        pause > $null
    }

    InternetCheck
