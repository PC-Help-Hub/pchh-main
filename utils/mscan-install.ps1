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

$Host.UI.RawUI.WindowTitle = "PCHH Crashlog Script"

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

$frstlink = "https://www.dropbox.com/scl/fi/n3zkk0q4i6zq8hi6oq5d6/FRSTEnglish.exe?rlkey=dkf9cmnqnccfsmg6ylr3npstk&st=waxgi45n&dl=1"
$hitmanlink = "https://www.dropbox.com/scl/fi/exuwti6tfx6g9891rep3i/HitmanPro_x64.exe?rlkey=32cjnefe3s2ee6cchk3fcdums&st=m5wl0q8t&dl=1"
$adwcleanerlink = "https://downloads.malwarebytes.com/file/adwcleaner"
$npelink = "https://www.norton.com/npe_latest"
$esetlink = "https://download.eset.com/com/eset/tools/online_scanner/latest/esetonlinescanner.exe"
$emsisoftlink = "https://dl.emsisoft.com/EmsisoftEmergencyKit.exe"
$msertlink = "https://go.microsoft.com/fwlink/?LinkId=212732"
$trojankillerlink = "https://www.dropbox.com/scl/fi/iry33ywlg9tpfi7m2qmkp/GTKSetup-en.exe?rlkey=jjcpat9hzmn07s9cniw29gbjy&st=9t7cuvm3&dl=1"
$revolink = "https://download.revouninstaller.com/download/RevoUninstaller_Portable.zip"
$securitychecklink = "https://tools.safezone.cc/glax24/SecurityCheck/SecurityCheck.exe"
$rkilllink = "https://download.bleepingcomputer.com/dl/b9f1f87f75b31e2b2a3e57746beaa752/66f64487/windows/security/security-utilities/r/rkill/rkill.exe"

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

    $downloads = [Environment]::GetFolderPath('MyDocuments').Replace("Documents", "Downloads")

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
    
        if ($digit -contains '0') {
            Write-Host "Installing Rkill.." -ForegroundColor Green
            $wc = New-Object net.webclient
            $wc.Downloadfile($rkilllink, "$downloads\rkill.exe")
        }

        if ($digit -contains '1') {
            Write-Host "Installing FRST.." -ForegroundColor Green
            $wc = New-Object net.webclient
            $wc.Downloadfile($frstlink, "$downloads\FRSTEnglish.exe")
        }
        elseif ($digit -contains '2') {
            Write-Host "Installing Hitman Pro.." -ForegroundColor Green
            $wc = New-Object net.webclient
            $wc.Downloadfile($hitmanlink, "$downloads_HitmanPro_x64.exe")
        }
        elseif ($digit -contains '3') {
            Write-Host "Installing adware cleaner.." -ForegroundColor Green
            $wc = New-Object net.webclient
            $wc.Downloadfile($adwcleanerlink, "$downloads\adwcleaner.exe")

        }
        elseif ($digit -eq '4') {
            Write-Host "Installing NPE.." -ForegroundColor Green
            $wc = New-Object net.webclient
            $wc.Downloadfile($npelink, "$downloads\NPE.exe")
        }
        elseif ($digit -eq '5') {
            Write-Host "Installing ESET.." -ForegroundColor Green
            $wc = New-Object net.webclient
            $wc.Downloadfile($esetlink, "$downloads\esetonlinescanner.exe")
        }
        elseif ($digit -eq '6') {
            Write-Host "Installing MSERT.." -ForegroundColor Green
            $wc = New-Object net.webclient
            $wc.Downloadfile($msertlink, "$downloads\msert.exe")
        }
        elseif ($digit -eq '7') {
            Write-Host "Installing Trojan Killer.." -ForegroundColor Green

            $wc = New-Object net.webclient
            $wc.Downloadfile($trojankillerlink, "$downloads\TrojanKiller.exe")
        }
        elseif ($digit -eq '8') {
            Write-Host "Installing Security Checker.." -ForegroundColor Green

            $wc = New-Object net.webclient
            $wc.Downloadfile($securitychecklink, "$downloads\SecurityCheck.exe")

        }
        elseif ($digit -eq '9') {
            Write-Host "Installing Emsisoft.." -ForegroundColor Green

            $wc = New-Object net.webclient
            $wc.Downloadfile($emsisoftlink, "$downloads\EmsisoftEmergencyKit.exe")

        }
        elseif ($digit -eq '10') {
            Write-Host "Installing Revo Uninstaller.." -ForegroundColor Green

            $wc = New-Object net.webclient
            $wc.Downloadfile($revolink, "$downloads\RevoUninstaller_Portable.zip")

            Expand-Archive -Path "$downloads\RevoUninstaller_Portable.zip" -DestinationPath "$downloads\RevoUninstaller_Portable" -Force > $null 2>&1
            Remove-Item -Path "$downloads\RevoUninstaller_Portable.zip" -Force > $null 2>&1

        }
        elseif ($digit -eq '11') {
            Write-Host "Removing tools.." -ForegroundColor Green

            $itemstoremove = @(
                "$downloads\RevoUninstaller_Portable",
                "$downloads\EmsisoftEmergencyKit.exe",
                "$downloads\FRSTEnglish.exe",
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
                "C:\EEK"

                # will add more when i feel like finding the rest

            )
            
            Remove-Item -Path $itemstoremove -Recurse -Force > $null 2>&1
        }

        Write-Host "Completed installation.." -ForegroundColor Blue
        Write-Host ""
    }

    Write-Host "Everything that was downloaded is located in '$downloads'" -ForegroundColor Yellow
    endmessage
}

function endmessage {
    Write-Host ""
    Write-Host "Press any key to exit.."
        
    $null = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    exit
}

scriptstart