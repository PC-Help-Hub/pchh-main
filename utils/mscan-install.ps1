Set-ExecutionPolicy -ExecutionPolicy Unrestricted -Scope Process -Force

$pshost = Get-Host
$pswindow = $pshost.UI.RawUI

$newBufferSize = $pswindow.BufferSize
$newBufferSize.Width = 170
$newBufferSize.Height = 3000
$pswindow.BufferSize = $newBufferSize

$newWindowSize = $pswindow.WindowSize
$newWindowSize.Width = 170
$newWindowSize.Height = 50
$pswindow.WindowSize = $newWindowSize

$Host.UI.RawUI.BackgroundColor = "Black"
$Host.UI.RawUI.ForegroundColor = "White"

Clear-Host

$Host.UI.RawUI.WindowTitle = "Malware Scanners & Tools Installer"

# Admin check
if (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Host "============================================" -ForegroundColor Red
    Write-Host "-- Script must be ran as an Administrator --" -ForegroundColor Red
    Write-Host "-- Right-Click Start -> Terminal(Admin)   --" -ForegroundColor Red
    Write-Host "============================================" -ForegroundColor Red
    Write-Host ""
    Write-Host "Press any key to exit the script.." -ForegroundColor Yellow
    $null = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    exit
}

$frstlink = "https://github.com/PC-Help-Hub/pchh-main/raw/refs/heads/main/utils/mscan-install-assets/FRSTEnglish.exe"
$hitmanlink = "https://github.com/PC-Help-Hub/pchh-main/raw/refs/heads/main/utils/mscan-install-assets/HitmanPro_x64.exe"
$adwcleanerlink = "https://github.com/PC-Help-Hub/pchh-main/raw/refs/heads/main/utils/mscan-install-assets/adwcleaner.exe"
$npelink = "https://github.com/PC-Help-Hub/pchh-main/raw/refs/heads/main/utils/mscan-install-assets/NPE.exe"
$esetlink = "https://github.com/PC-Help-Hub/pchh-main/raw/refs/heads/main/utils/mscan-install-assets/esetonlinescanner.exe"
$emsisoftlink = "https://dl.emsisoft.com/EmsisoftEmergencyKit.exe" # needs new link
$msertlink = "https://go.microsoft.com/fwlink/?LinkId=212732" # needs new link
$trojankillerlink = "https://github.com/PC-Help-Hub/pchh-main/raw/refs/heads/main/utils/mscan-install-assets/TrojanKiller.exe"
$revolink = "https://github.com/PC-Help-Hub/pchh-main/raw/refs/heads/main/utils/mscan-install-assets/RevoUninstaller_Portable.zip"
$securitychecklink = "https://github.com/PC-Help-Hub/pchh-main/raw/refs/heads/main/utils/mscan-install-assets/SecurityCheck.exe"
$rkilllink = "https://github.com/PC-Help-Hub/pchh-main/raw/refs/heads/main/utils/mscan-install-assets/rkill.exe"

function scriptstart {
    Clear-Host
    Write-Host ""
    Write-Host "===================================" -ForegroundColor Yellow
    Write-Host "      -- MALWARE TOOL MENU --      " -ForegroundColor Yellow
    Write-Host "      --  By ShinTheBean   --      " -ForegroundColor Yellow
    Write-Host "===================================" -ForegroundColor Yellow
    Write-Host ""

    Write-Host "[0]  RKILL" -ForegroundColor Cyan
    Write-Host "[1]  FRST" -ForegroundColor Cyan
    Write-Host "[2]  Hitman Pro" -ForegroundColor Cyan
    Write-Host "[3]  Adw Cleaner" -ForegroundColor Cyan
    Write-Host "[4]  NPE" -ForegroundColor Cyan
    Write-Host "[5]  ESET" -ForegroundColor Cyan
    Write-Host "[6]  MSERT" -ForegroundColor Cyan
    Write-Host "[7]  Trojan Killer" -ForegroundColor Cyan
    Write-Host "[8]  Security Checker" -ForegroundColor Cyan
    Write-Host "[9]  Emsisoft" -ForegroundColor Cyan
    Write-Host "[10] Revo Uninstaller" -ForegroundColor Cyan
    Write-Host "[11] Remove Tools" -ForegroundColor Cyan
    Write-Host ""

    Write-Host "===================================" -ForegroundColor Yellow
    Write-Host ""

    Write-Host "Select what you want to install using the menu above. Multiple can be selected at once:" -ForegroundColor Green
    $selection = Read-Host
    Write-Host ""

    $download = [Environment]::GetFolderPath('MyDocuments').Replace("Documents", "Downloads")
    $downloads = $download + "\PCHH-Malware-Tools"
    if (-not (Test-Path $downloads)) {
        New-Item -Path $downloads -ItemType Directory | Out-Null
    }

    $digits = @()
    $i = 0
    while ($i -lt $selection.Length) {
        if ($i + 1 -lt $selection.Length -and (($selection[$i] + $selection[$i + 1]) -eq '10' -or ($selection[$i] + $selection[$i + 1]) -eq '11')) {
            $digits += $selection[$i] + $selection[$i + 1]
            $i += 2
        }
        else {
            $digits += $selection[$i]
            $i++
        }
    }

    Write-Host "This may take some time to complete.."
    Write-Host ""

    foreach ($digit in $digits) {
        Write-Host ""
        if ($digit -contains '0') {
            Write-Host "Installing Rkill.." -ForegroundColor Green
            try {
                $wc = New-Object System.Net.WebClient
                $wc.DownloadFile($rkilllink, "$downloads\rkill.exe")
                Write-Host "Rkill downloaded successfully." -ForegroundColor Cyan
            }
            catch {
                Write-Host "Failed to download Rkill." -ForegroundColor Red
            }
            finally {
                $wc.Dispose()
            }
        }
        if ($digit -contains '1') {
            Write-Host "Installing FRST.." -ForegroundColor Green
            try {
                $wc = New-Object System.Net.WebClient
                $wc.DownloadFile($frstlink, "$downloads\FRSTEnglish.exe")
                Write-Host "FRST downloaded successfully." -ForegroundColor Cyan
            }
            catch {
                Write-Host "Failed to download FRST." -ForegroundColor Red
            }
            finally {
                $wc.Dispose()
            }
        }
        elseif ($digit -contains '2') {
            Write-Host "Installing Hitman Pro.." -ForegroundColor Green
            try {
                $wc = New-Object System.Net.WebClient
                $wc.DownloadFile($hitmanlink, "$downloads\HitmanPro_x64.exe")
                Write-Host "Hitman Pro downloaded successfully." -ForegroundColor Cyan
            }
            catch {
                Write-Host "Failed to download Hitman Pro." -ForegroundColor Red
            }
            finally {
                $wc.Dispose()
            }
        }
        elseif ($digit -contains '3') {
            Write-Host "Installing AdwCleaner.." -ForegroundColor Green
            try {
                $wc = New-Object System.Net.WebClient
                $wc.DownloadFile($adwcleanerlink, "$downloads\adwcleaner.exe")
                Write-Host "AdwCleaner downloaded successfully." -ForegroundColor Cyan
            }
            catch {
                Write-Host "Failed to download AdwCleaner." -ForegroundColor Red
            }
            finally {
                $wc.Dispose()
            }
        }
        elseif ($digit -eq '4') {
            Write-Host "Installing NPE.." -ForegroundColor Green
            try {
                $wc = New-Object System.Net.WebClient
                $wc.DownloadFile($npelink, "$downloads\NPE.exe")
                Write-Host "NPE downloaded successfully." -ForegroundColor Cyan
            }
            catch {
                Write-Host "Failed to download NPE." -ForegroundColor Red
            }
            finally {
                $wc.Dispose()
            }
        }
        elseif ($digit -eq '5') {
            Write-Host "Installing ESET.." -ForegroundColor Green
            try {
                $wc = New-Object System.Net.WebClient
                $wc.DownloadFile($esetlink, "$downloads\esetonlinescanner.exe")
                Write-Host "ESET downloaded successfully." -ForegroundColor Cyan
            }
            catch {
                Write-Host "Failed to download ESET." -ForegroundColor Red
            }
            finally {
                $wc.Dispose()
            }
        }
        elseif ($digit -eq '6') {
            Write-Host "Installing MSERT.." -ForegroundColor Green
            try {
                $wc = New-Object System.Net.WebClient
                $wc.DownloadFile($msertlink, "$downloads\msert.exe")
                Write-Host "MSERT downloaded successfully." -ForegroundColor Cyan
            }
            catch {
                Write-Host "Failed to download MSERT." -ForegroundColor Red
            }
            finally {
                $wc.Dispose()
            }
        }
        elseif ($digit -eq '7') {
            Write-Host "Installing Trojan Killer.." -ForegroundColor Green
            try {
                $wc = New-Object System.Net.WebClient
                $wc.DownloadFile($trojankillerlink, "$downloads\TrojanKiller.exe")
                Write-Host "Trojan Killer downloaded successfully." -ForegroundColor Cyan
            }
            catch {
                Write-Host "Failed to download Trojan Killer." -ForegroundColor Red
            }
            finally {
                $wc.Dispose()
            }
        }
        elseif ($digit -eq '8') {
            Write-Host "Installing Security Check.." -ForegroundColor Green
            try {
                $wc = New-Object System.Net.WebClient
                $wc.DownloadFile($securitychecklink, "$downloads\SecurityCheck.exe")
                Write-Host "Security Check downloaded successfully." -ForegroundColor Cyan
            }
            catch {
                Write-Host "Failed to download Security Check." -ForegroundColor Red
            }
            finally {
                $wc.Dispose()
            }
        }
        elseif ($digit -eq '9') {
            Write-Host "Installing Emsisoft.." -ForegroundColor Green
            try {
                $wc = New-Object System.Net.WebClient
                $wc.DownloadFile($emsisoftlink, "$downloads\EmsisoftEmergencyKit.exe")
                Write-Host "Emsisoft downloaded successfully." -ForegroundColor Cyan
            }
            catch {
                Write-Host "Failed to download Emsisoft." -ForegroundColor Red
            }
            finally {
                $wc.Dispose()
            }
        }
        elseif ($digit -eq '10') {
            Write-Host "Installing Revo Uninstaller.." -ForegroundColor Green
            try {
                $wc = New-Object System.Net.WebClient
                $wc.DownloadFile($revolink, "$downloads\RevoUninstaller_Portable.zip")
                Write-Host "Revo Uninstaller downloaded successfully." -ForegroundColor Cyan
            }
            catch {
                Write-Host "Failed to download Revo Uninstaller." -ForegroundColor Red
            }
            finally {
                $wc.Dispose()
            }
        }
        elseif ($digit -eq '11') {
            Write-Host "Removing tools.." -ForegroundColor Green

            $itemstoremove = @(
                "$downloads\RevoUninstaller_Portable",
                "$downloads\RevoUninstaller_Portable.zip",
                "$downloads\EmsisoftEmergencyKit.exe",
                "$downloads\FRSTEnglish.exe",
                "$downloads\HitmanPro_x64.exe",
                "$downloads\FRST-OlderVersion",
                "$downloads\TrojanKiller.exe",
                "$downloads\msert.exe",
                "$downloads\esetonlinescanner.exe",
                "$downloads\adwcleaner",
                "$downloads\adwcleaner.exe",
                "$downloads\NPE.exe",
                "$downloads\rkill.exe",
                "$downloads\SecurityCheck.exe",
                "$downloads\Addition.txt",
                "$downloads\Fixlog.txt",
                "$downloads\FRST.txt",
                "$downloads\Search.txt",
                "C:\AdwCleaner",
                "C:\EEK",
                "$downloads"

                # will add more when i feel like finding the rest

            )
            
            Remove-Item -Path $itemstoremove -Recurse -Force > $null 2>&1
            
        }
    }
    
    Write-Host ""
    Write-Host "Done! The tools are located in $downloads" -ForegroundColor Yellow
    Write-Host "Press any key to exit the script.." -ForegroundColor Yellow
    $null = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}

scriptstart
