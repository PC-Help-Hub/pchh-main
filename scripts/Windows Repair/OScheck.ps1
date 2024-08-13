Set-ExecutionPolicy -ExecutionPolicy Unrestricted -Scope Process -Force

$Host.UI.RawUI.BackgroundColor = "Black"
$Host.UI.RawUI.ForegroundColor = "White"

Clear-Host

$Host.UI.RawUI.WindowTitle = "Windows OS Requirement Check"

# admin check
if (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    #  Admin text from https://christitus.com/windows-tool/
    Write-Host "============================================" -ForegroundColor Red
    Write-Host "-- Script must be ran as an Administrator --" -ForegroundColor Red
    Write-Host "-- Right-Click Start -> Terminal(Admin)   --" -ForegroundColor Red
    Write-Host "============================================" -ForegroundColor Red
    Write-Host ""
    Write-Host "Press any key to exit the script.." -ForegroundColor Yellow
    $null = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    exit
}

    $w10  = "false"
    $w11  = "false"
    $tpm  = "false"
    $ram  = "false"
    $cpu  = "false"
    $disk = "false"
    $secure = "false"
    $uefi = "false"

#Start-Transcript "$env:temp\winos.txt" -Force | Out-Null

function CheckMark {
    return [char]0x2705
}

function XMark {
    return [char]0x274C
}

#Write-Host "$(Get-CheckMark) Success" -ForegroundColor Green
#Write-Host "$(Get-XMark) Denied" -ForegroundColor Red

function info {
    Clear-Host 
    Write-Host ""
    Write-Host "============================================" -ForegroundColor DarkGreen
    Write-Host "-- Script is running as an Administrator --" -ForegroundColor DarkGreen
    Write-Host "--         Made by ShinTheBean           --" -ForegroundColor DarkGreen
    Write-Host "============================================" -ForegroundColor DarkGreen
    Write-Host ""
    $prompt = Read-Host "What Operating System are you looking to compare with? (10/11)"
    Write-Host ""

    if ($prompt -eq "10") {
        Write-Host "You have selected Windows 10"
        Write-Host "Looking at your specs to see if it's compatible with Windows 10.."
        $w10 = $true
    }
    elseif ($prompt -eq "11") {
        Write-Host "You have selected Windows 11"
        Write-Host "Looking at your specs to see if it's compatible with Windows 11.."
        $w11 = $true
    }
    else {
        Write-Host "The text you have provided isn't a valid option." -ForegroundColor Yellow
        Write-Host "Press any key to go back to the prompt."
        $null = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        info
    }

    Write-Host ""

    # gets tpm version
    $tpmver = get-WmiObject -Namespace root\cimv2\security\microsofttpm -Class Win32_Tpm | Select-Object ManufacturerVersion

    if ($tpmver.ManufacturerVersion -gt 2) {
        $tpm = "true"
    }
    if ($w10 -eq $true) {
        w10
    }
    else {
        w11
    }
}

function w10 {
    # checks drive size, must be more than 32gb
    $drives = Get-PSDrive -PSProvider FileSystem | Select-Object -ExpandProperty Root

    for ($i = 0; $i -lt $drives.Count; $i++) {
        Write-Host "[$($i + 1)] $($drives[$i])"
    }

    Write-Host ""
    $selection = Read-Host "Select a drive that you would like to use for the windows installation"
    
    if ($selection -match '^\d+$' -and $selection -gt 0 -and $selection -le $drives.Count) {
        $selectedDrive = $drives[$selection - 1]
    
        $driveInfo = Get-PSDrive -PSProvider FileSystem | Where-Object { $_.Root -eq $selectedDrive }
        $totalSizeGB = [math]::Round(($driveInfo.Used + $driveInfo.Free) / 1GB, 2)
    
        if ($totalSizeGB -gt 32) {
            $disk = "true"
        }
    
    }
    else {
        Write-Host ""
        Write-Host "The drive you have provided isn't a valid option." -ForegroundColor Yellow
        Write-Host "Press any key to go back to the prompt."
        $null = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        info
    }

    # checking ram size
    $ramcheck = Get-WmiObject Win32_ComputerSystem | Select-Object -ExpandProperty TotalPhysicalMemory
    $ram = $([math]::Round($ramcheck / 1GB))

    if ($ram -gt 2) {
        $ram = "true"
    }

    #checking cpu clock speed
    $cpu = Get-CimInstance Win32_Processor | Select-Object -Expand MaxClockSpeed

    if ($cpu -gt 1000) {
        $cpu = "true"
    }

    results

}

function w11 {
        # checks drive size, must be more than 32gb
        $drives = Get-PSDrive -PSProvider FileSystem | Select-Object -ExpandProperty Root

        for ($i = 0; $i -lt $drives.Count; $i++) {
            Write-Host "[$($i + 1)] $($drives[$i])"
        }
    
        Write-Host ""
        $selection = Read-Host "Select a drive that you would like to use for the windows installation"
        
        if ($selection -match '^\d+$' -and $selection -gt 0 -and $selection -le $drives.Count) {
            $selectedDrive = $drives[$selection - 1]
        
            $driveInfo = Get-PSDrive -PSProvider FileSystem | Where-Object { $_.Root -eq $selectedDrive }
            $totalSizeGB = [math]::Round(($driveInfo.Used + $driveInfo.Free) / 1GB, 2)
        
            if ($totalSizeGB -gt 64) {
                $disk = "true"
            }
        
        }
        else {
            Write-Host ""
            Write-Host "The drive you have provided isn't a valid option." -ForegroundColor Yellow
            Write-Host "Press any key to go back to the prompt."
            $null = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
            info
        }
    
        # checking ram size
        $ramcheck = Get-WmiObject Win32_ComputerSystem | Select-Object -ExpandProperty TotalPhysicalMemory
        $ram = $([math]::Round($ramcheck / 1GB))
    
        if ($ram -gt 4) {
            $ram = "true"
        }
    
        #checking cpu clock speed
        $cpu = Get-CimInstance Win32_Processor | Select-Object -Expand MaxClockSpeed
        $cpuCore = (Get-WmiObject -Class Win32_Processor).NumberOfCores
    
        if ($cpu -gt 1000 -or $cpuCore -gt 2) {
            $cpu = "true"
        }

        #check uefi and secureboot

        $secureBoot = Confirm-SecureBootUEFI
        if ($secureBoot) {
            $secure = "true"
        }

        $uefic = $env:firmware_type

        if ($uefic -eq "UEFI") {
            $uefi = "true"
        }
    
        results
}

function results {
    Write-Host ""
    Write-Host "=====================" -ForegroundColor DarkGreen
    Write-Host "--     RESULTS     --" -ForegroundColor Green
    Write-Host "=====================" -ForegroundColor DarkGreen
    Write-Host ""

    $install = @()

    if ($tpm -eq "true") {
        Write-Host "$(CheckMark) TPM Requirement" -ForegroundColor Green
    } else {
        Write-Host "$(XMark) TPM Requirement" -ForegroundColor Red
        $install += "1"
    }

    if ($cpu -eq "true") {
        Write-Host "$(CheckMark) CPU Requirement" -ForegroundColor Green
    } else {
        Write-Host "$(XMark) CPU Requirement" -ForegroundColor Red
        $install += "1"
    }

    if ($ram -eq "true") {
        Write-Host "$(CheckMark) RAM Requirement" -ForegroundColor Green
    } else {
        Write-Host "$(XMark) RAM Requirement" -ForegroundColor Red
        $install += "1"
    }

    if ($disk -eq "true") {
        Write-Host "$(CheckMark) Disk Storage Requirement" -ForegroundColor Green
    } else {
        Write-Host "$(XMark) Disk Storage Requirement" -ForegroundColor Red
        $install += "1"
    }

    if ($w11 -eq "true") {
        if ($secure -eq "true") {
            Write-Host "$(CheckMark) Secure Boot Requirement" -ForegroundColor Green
        } else {
            Write-Host "$(XMark) Secure Boot Requirement" -ForegroundColor Red
            $install += "1"
        }

        if ($uefi -eq "true") {
            Write-Host "$(CheckMark) UEFI Requirement" -ForegroundColor Green
        } else {
            Write-Host "$(XMark) UEFI Requirement" -ForegroundColor Red
            $install += "1"
        }
    }

    Write-Host ""
    if ($install.Count -eq 0) {
            if ($w10 -eq "true") {
                Write-Host "You are eligible to install the Windows 10 Operating System!"
                userprompt
            } else {
                Write-Host "You are eligible to install the Windows 11 Operating System!"
                userprompt
            }
    } else {
        if ($w10 -eq "true") {
            Write-Host "You are NOT eligible to install the Windows 10 Operating System!"
        } else {
            Write-Host "You are NOT eligible to install the Windows 11 Operating System!"
        }
    }

    endmessage
}

function userprompt {
    Write-Host ""
    
    $prompt = Read-Host "Do you want to open an article on how to install the Operating System? (Y/N)"

    if ($prompt -eq "Y" -or $prompt -eq "y") {
        Write-Host "Read the article that has opened up on your browser."
        Start-Process "https://pchelphub.com/kbase/windows-in-place-install-upgrade-iso/"
        endmessage
    } else {
        Write-Host "The script will not open the article."
        endmessage
    }
}

function endmessage {
    Write-Host ""
    Write-Host "Press any key to exit.."
    $null = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    exit
}

info