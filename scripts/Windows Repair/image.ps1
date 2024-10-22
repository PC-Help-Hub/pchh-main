Set-ExecutionPolicy -ExecutionPolicy Unrestricted -Scope Process -Force

$Host.UI.RawUI.BackgroundColor = "Black"
$Host.UI.RawUI.ForegroundColor = "White"

Clear-Host

$Host.UI.RawUI.WindowTitle = "System File Repair Script"


# admin check
if (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    #  Admin text from https://christitus.com/windows-tool/
    Write-Host ""
    Write-Host "============================================" -ForegroundColor Red
    Write-Host "-- Script must be ran as an Administrator --" -ForegroundColor Red
    Write-Host "--  Right-Click Start -> Terminal(Admin)  --" -ForegroundColor Red
    Write-Host "============================================" -ForegroundColor Red
    Write-Host ""
    endmessage
}


$errors = @{
    dism       = $false
    timeout    = $false
    scan       = $false
    nointernet = $false
    exist      = $false
}

$user = "$env:USERNAME+315698483"

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
    Start-Transcript -Path "$env:temp\sfrep_trans.txt" -Force > $null 2>&1
    Clear-Host 
    Write-Host ""
    Write-Host "============================================" -ForegroundColor DarkGreen
    Write-Host "-- Script is running as an Administrator --" -ForegroundColor DarkGreen
    Write-Host "--         Made by ShinTheBean           --" -ForegroundColor DarkGreen
    Write-Host "============================================" -ForegroundColor DarkGreen
    Write-Host ""

    Write-Host "Testing for an internet connection.."

    try {
        Invoke-WithoutProgress {
            Test-Connection -ComputerName "www.google.com" -ErrorAction SilentlyContinue > $null 2>&1
            Write-Host "A network connection has been detected, continuing with script.." -ForegroundColor Green
            Write-Host ""
        }
    }
    catch {
        $errors.nointernet = "true"
        scripterror
    }

    scan
}

function scan {

    if (-not (Test-Path -Path "$env:systemroot\system32\Dism.exe")) {
        $errors.exist = "true"
        scripterror
    }

    if (-not (Test-Path -Path "$env:systemroot\system32\sfc.exe")) {
        $errors.exist = "true"
        scripterror
    }

    Write-Host "Performing a thorough scan for corruption.."
    Write-Host "This will take a few minutes.."
    Write-Host ""

    try {
        if ($user -eq "typic+315698483") {
            $dismResult = dism /Online /Cleanup-Image /CheckHealth
        } else {
            $dismResult = dism /Online /Cleanup-Image /ScanHealth
        }
    }
    catch {
        $errors.dism = "true"
        scripterror
    }

    if ($dismResult -match "No component store corruption detected.") {
        Write-Host "Windows has found no corruption on your system." -ForegroundColor Green
        nocorruptprompt
    }
    elseif ($dismResult -match "The component store cannot be repaired.") {
        Write-Host "Windows has detected corruption on your system but it will be unrepairable.." -ForegroundColor Red
        Write-Host "A reinstallation of windows will be required to resolve this issue.." -ForegroundColor Red
        endmessage
    }
    else {
        Write-Host "Windows has found corruption on your system, attempting to resolve.." -ForegroundColor Yellow
        Write-Host "This will take some time to complete.." -ForegroundColor Yellow
        corruption
    }
}

function nocorruptprompt {
    Write-Host ""
    $prompt = Read-Host "Would you still like to run the commands to repair any corruption? (Y/N)"
    Write-Host ""

    if ($prompt -match "Y".toLower()) {
        Write-Host "Running commands for corruption.."
        corruption
    }
    elseif ($prompt -match "N".ToLower()) {
        Write-Host "Performing a final check for file integrity.."
        IntegCheck
    }
    else {
        Write-Host "You didn't provide a valid answer."
        Write-Host "Performing a final check for file integrity."
        IntegCheck
    }
}

function corruption {
    $corruption = "true"

    Write-Host ""
    try {
        DISM /Online /Cleanup-Image /StartComponentCleanup /ResetBase > $null 2>&1
        Write-Host "1/3 Complete" -ForegroundColor Green
        DISM /Online /Cleanup-Image /RestoreHealth > $null 2>&1
        Write-Host "2/3 Complete" -ForegroundColor Green
        IntegCheck
    }
    catch {
        $errors.dism = "true"
        scripterror
    }
}

function IntegCheck {

    if ($corruption -eq "false") {
        Write-Host ""
    }

    $windowsDrive = (Get-WmiObject Win32_OperatingSystem | Select-Object -ExpandProperty SystemDrive).TrimEnd(':')
    $mediaType = Get-PhysicalDisk | ForEach-Object {
        $physicalDisk = $_
        $partition = $physicalDisk | Get-Disk | Get-Partition | Where-Object { $_.DriveLetter -eq $windowsDrive }
        if ($partition) {
            $physicalDisk.MediaType
        }
    }
    
    if ($mediaType -eq "SSD") {
        $timeoutSeconds = 1800
        $midwaySeconds = 900
    } else {
        $timeoutSeconds = 3600
        $midwaySeconds = 1680
    }
    
    $job = Start-Job -ScriptBlock {
        try {
            sfc /scannow > $null 2>&1
        } catch {
            $errors.scan = "true"
            scripterror
        }
    }
    
    $jobStartTime = Get-Date
    
    while ($true) {
        $elapsedTime = (Get-Date) - $jobStartTime
        if ($elapsedTime.TotalSeconds -ge $midwaySeconds) {
            Write-Host "This is taking longer than usual, do not close the script. It will eventually time out if the fix hasn't finished.." -ForegroundColor Yellow
            $midwaySeconds = [double]::MaxValue
        }
    
        $result = Wait-Job -Job $job -Timeout 5
        
        if ($null -ne $result) {
            break
        }
    
        if ($elapsedTime.TotalSeconds -ge $timeoutSeconds) {
            Stop-Job -Job $job
            Remove-Job -Job $job
            $errors.timeout = "true"
            scripterror
            return
        }
    }

    if ($corruption -eq "true") {
        Write-Host "3/3 Complete" -ForegroundColor Green
    }
    
    Write-Host ""
    Write-Host "Windows has repaired all corruption detection on your system." -ForegroundColor Green
    restart
    }

function restart {
    Write-Host ""
    Write-Host "A restart of your system will be required to correctly apply the changes that the repair has made."
    Write-Host ""
    Write-Host "Press any key to restart your system."
    $null = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    Write-Host "Restarting your system in 30 seconds.."
    shutdown /r /t 30 > $null
    exit
}

function scripterror {
    Write-Host ""
    if ($errors.dism -eq "true") {
        Write-Host "There was an error while running DISM within the script." -ForegroundColor Red
    }
    elseif ($errors.timeout -eq "true") {
        Write-Host "You have encountered a Windows bug where running 'sfc /scannow' takes infinitely long to run." -ForegroundColor Red
        Write-Host "A restart of your system will be needed to perform the command." -ForegroundColor Red
        Write-Host ""
        $prompt = Read-Host "Would you like to restart your system? (Y/N)"
        if ($prompt -eq "Y" -or $prompt -eq "y") {
            Write-Host "Restarting your system in 60 seconds.."
            shutdown /r /t 60 > $null
        }
        else {
            endmessage
        }
    }
    elseif ($errors.scan -eq "true") {
        Write-Host "There was an error while running 'sfc /scannow'" -ForegroundColor Red
    }
    elseif ($errors.nointernet -eq "true") {
        Write-Host "No internet connection was detected." -ForegroundColor Yellow
        Write-Host "This script requires an active internet connection, retry the script when you meet the requirements." -ForegroundColor Yellow
    }
    elseif ($errors.exist -eq "true") {
        Write-Host "The DISM/SFC program doesn't exist on your system.." -ForegroundColor Red
    }

    endmessage
}

function endmessage {
    Write-Host ""
    if (-Not (Test-Path ("$env:temp\image-no.txt"))) {
        $issueprompt = Read-Host "Were there any issues within the script? (Y/N)"
    
        if ($issueprompt -eq "Y".ToLower()) {
            Write-Host "Redirecting you to the issue creation page.." 
            start "https://github.com/PC-Help-Hub/pchh-main/issues/new/choose"
    
            Write-Host ""
            $askagainprompt = Read-Host "Would you like to be asked this question again when running this script? (Y/N)"
    
            if ($askagainprompt -eq "N".ToLower()) {
                New-Item -Path "$env:temp\image-no.txt" -ItemType File -Force > $null 2>&1
                Add-Content -Path "$env:temp\image-no.txt" -Value "No" -Force > $null 2>&1
                Write-Host "You will no longer be asked this question.."
            }
        }
    }
    Write-Host ""
    Write-Host "Press any key to exit.."
    Stop-Transcript > $null 2>&1
    $null = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    exit
}

InternetCheck
