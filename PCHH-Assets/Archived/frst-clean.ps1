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

$Host.UI.RawUI.WindowTitle = "PCHH FRST Clean Script"

Clear-Host 
Write-Host ""
Write-Host "============================================" -ForegroundColor DarkGreen
Write-Host "--      Script is running correctly      --" -ForegroundColor Green
Write-Host "--         Made by ShinTheBean           --" -ForegroundColor Green
Write-Host "============================================" -ForegroundColor DarkGreen
Write-Host ""

$filePath = Read-Host "File path for FRST Log`nOnly one log at a time"

$searchStrings = @("14EC5FE4-5B1E-42B9-9EDA-F281C1506E7A", "89B4C1CD-B018-4511-B0A1-5476DBF70820", "8203C095-FB62-4005-807D-7C9A3775D1EA", "Edge DefaultProfile: Default", "Edge Extension: (uBlock Origin)", "Edge Extension: (HTTPS Everywhere)", "Edge Extension: (Outlook)", "Edge Extension: (Word)", "Edge Extension: (Excel)", "Edge Extension: (PowerPoint)", "Edge Extension: (IDM Integration Module)", "Edge Extension: (Bitdefender Anti-tracker)", "FF Extension: (Avast Online Security)", "FF Extension: (Avast SafePrice | Comparison, deals, coupons)", "FF Extension: (Adblock Plus - free ad blocker)", "FF Extension: (uBlock Origin)", "FF Extension: (Adobe Acrobat)", "FF Extension: (Bitdefender Wallet)", "FF Extension: (Bitdefender Anti-tracker)", "FF Extension: (Bitdefender Antispam Toolbar)", "FF Extension: (IDM integration)", "FF Extension: (IDM CC)", "BRA Extension: (Malwarebytes Browser Guard)", "BRA Extension: (IDM Integration Module)", "BRA Extension: (Brave Local Data Files Updater)", "BRA Extension: (Brave Ad Block Updater (Default))", "BRA Extension: (Brave NTP sponsored images)", "BRA Extension: (Brave SpeedReader Updater)", "BRA Extension: (Brave HTTPS Everywhere Updater)", "OPR Extension: (Rich Hints Agent)", "OPR Extension: (Amazon Assistant Promotion)", "CHR Extension: (Google Drive)", "CHR Extension: (YouTube)", "CHR Extension: (uBlock Origin)", "CHR Extension: (HTTPS Everywhere)", "CHR Extension: (Chrome Web Store Payments)", "CHR Extension: (Gmail)", "CHR Extension: (Chrome Media Router)", "CHR Extension: (Slides)", "CHR Extension: (Docs)", "CHR Extension: (Sheets)", "CHR Extension: (Google Docs Offline)", "CHR Extension: (Kaspersky Protection)", "CHR Extension: (Grammarly for Chrome)", "CHR Extension: (Duolingo on the Web)", "CHR Extension: (Avast Online Security)", "CHR Extension: (Avast SafePrice | Comparison, deals, coupons)", "CHR Extension: (Adobe Acrobat)", "CHR Extension: (Malwarebytes Browser Guard)", "CHR Extension: (Emsisoft Browser Security)", "CHR Extension: (Decentraleyes)", "CHR Extension: (LocalCDN)", "CHR Extension: (User-Agent Switcher for Chrome)", "CHR Extension: (Quick source viewer)", "CHR Extension: (Decentraleyes)", "CHR Extension: (Tampermonkey)", "CHR Extension: (Dark Reader)", "CHR Extension: (IDM Integration Module)", "CHR Extension: (EditThisCookie)", "CHR Extension: (Cookie-Editor)", "CHR Extension: (BetterTTV)", "CHR Extension: (ColorPick Eyedropper)", "CHR Extension: (Proxy SwitchyOmega)", "CHR Extension: (Sci-Hub X Now!)", "CHR Extension: (Bypass Paywalls Clean)", "CHR Extension: (Untrusted Types for DevTools)", "CHR Extension: (Adblock Plus - free ad blocker)", "CHR Extension: (Privacy Badger)", "CHR Extension: (Google Translate)", "CHR Extension: (Adobe Acrobat: PDF edit, convert, sign tools)", "CHR Extension: (McAfee(R) WebAdvisor)", "OPR Extension: (opera-intro)", "BRA Extension: (Wallet Data Files Updater)", "aeblfdkhhhdcdjpifhhbdiojplfjncoa", "ihcjicgdanjaechkgeegckofjjedodee", "bojobppfploabceghnmlahpoonbcbacn", "jmjflgjpcpepeafmmgdpfkogkghcpiha", "ghbmnnjooekpmoecnnnilnnbdlolhkhi", "bmnlcjabgnpnenekpadlanbbkooimhnj", "gighmmpiobklfepjocnamgkkbiglidom", "mmioliijnhnoblpgimnlajmefafdfilb", "ponfpcnoihfmfllpaingbgckeeldkhle", "aoojcmojmmcbpfgoecoadbdpnagfchel", "gkboaolpopklhgplhaaiboijnklogmbc", "heplpbhjcbmiibdlchlanmdenffpiibo", "iodkpdagapdfkphljnddpjlldadblomo", "mfddibmblmbccpadfndgakiopmmhebop", "pjbgfifennfhnbkhoidkdchbflppjncb", "nkbihfbeogaeaoehlefnkodbefgpgknn", "amaaokahonnfjjemodnpmeenfpnnbkco", "bcjindcccaagfpapjjmafapmmgkkhgoa", "fbgcedjacmlbgleddnoacbnijgmiolem", "gngocbkfmikdgphklgmmehbjjlfgdemm", "pocpnlppkickgojjlmhdmidojbmbodfm", "nopfnnpnopgmcnkjchnlpomggcdjfepo", "R2 NVDisplay.ContainerLocalSystem;", "(2BrightSparks Pte Ltd )", "(AVAST Software)", "(Adobe Systems)", "(Audyssey Labs)", "(BitDefender S.R.L. Bucharest, ROMANIA)", "(Bitdefender)", "(Bleeping Computer, LLC)", "(Broadcom)", "(Conexant Systems Inc.)", "(DTS)", "(DTS, Inc.)", "(Digimarc)", "(Discord Inc.)", "(Dolby Laboratories)", "(Dolby Laboratories, Inc.)", "(ESET)", "(EldoS Corporation)", "(Farbar)", "(General Workings, Inc.)", "(GridinSoft LLC)", "(Harman)", "(ICEpower a/s)", "(Igor Pavlov)", "(Initex)", "(Intel)", "(Kaspersky)", "(Khronos Group)", "(Malwarebytes)", "(Mente Binária)", "(MicroWorld Technologies Inc.)", "(Mozilla Foundation)", "(Mozilla)", "(Oracle Corporation)", "(Other World Computing, Inc.)", "(Pango Inc)", "(Razer Inc)", "(Real Sound Lab SIA)", "(Realtek semiconductor)", "(SRS Labs, Inc.)", "(Seiko Epson Corporation)", "(Skype)", "(Sony Corporation)", "(Sound Research, Corp.)", "(Synopsys, Inc.)", "(Sysinternals - www.sysinternals.com)", "(TOSHIBA CORPORATION.)", "(TOSHIBA Corporation)", "(The ICU Project)", "(The OpenVPN Project)", "(Tonec Inc.)", "(Toshiba Client Solutions Co., Ltd.)", "(VSO Software)", "(Virage Logic Corporation / Sonic Focus)", "(VoodooSoft, LLC)", "(Windows (R) Win 7 DDK provider)", "(Yamaha Corporation)", "(curl, hxxps://curl.se/)", "(Electronic Arts)", "(On2.com)", "(Logitech)", "(Tonec Inc.)", "2BrightSparks Pte. Ltd.", "A-Volute SAS", "A-Volute", "AO Kaspersky Lab", "ARCAI", "ASROCK Incorporation", "ASUSTEK COMPUTER INC.", "ASUSTeK Computer Inc.", "AVB Disc Soft, SIA", "Acer Incorporated", "Acro Software Inc.", "Adobe Inc.", "Adobe Systems Incorporated", "Adobe Systems, Incorporated", "Advanced Micro Devices Inc.", "Advanced Micro Devices, Inc", "Advanced Micro Devices, Inc.", "Amazon.com Services LLC", "AnchorFree Inc", "Apple Inc.", "Autodesk, Inc.", "Avast Software s.r.o.", "Avid Technology, Inc.", "BattlEye Innovations e.K.", "Beijing NormalSoft technology Co.,Ltd.", "Bitdefender SRL", "Blizzard Entertainment, Inc.", "Bluestack Systems, Inc", "Brave Software, Inc.", "CPUID S.A.R.L.U.", "Canon Inc.", "Citrix Systems, Inc.", "Code Sector", "Conexant Systems, Inc.", "Corel Corporation", "Corsair Memory, Inc.", "Dell Inc", "Digiarty Software, Inc.", "Disc Soft Ltd", "Discord Inc.", "Dolby Laboratories, Inc.", "Dropbox, Inc", "ELAN Microelectronics Corp.", "ESET, spol. s r.o.", "EVGA Co., Ltd.", "EVGA Corp.", "EasyAntiCheat Oy", "EldoS Corporation", "Electronic Arts, Inc.", "Emsisoft (Emsisoft Limited)", "Emsisoft Ltd", "Epic Games Inc.", "Even Balance, Inc.", "Figma, Inc.", "Flexera Software LLC", "Fortemedia Inc", "GIGA-BYTE TECHNOLOGY CO., LTD.", "Gaijin Network LTD", "Gemalto, Inc.", "Glarysoft LTD", "Global Media (Thailand) Co., Ltd", "GoTrustID Inc.", "Google Inc.", "Google LLC", "GridinSoft, LLC", "Guillaume Ryder (hxxp://utilfr42.free.fr)", "HP Inc.", "Hewlett Packard", "Hewlett-Packard Co.", "Hewlett-Packard Company", "Huawei Technologies Co., Ltd.", "INTEL CORP", "Initeks, OOO", "Initex", "Insecure.Com LLC", "Intel Corporation", "Intel(R) Corporation", "Intel(R) pGFX", "Ivaylo Beltchev", "Kaspersky Lab ZAO", "Kilonova LLC", "Kristjan Skutta", "Lenovo (Beijing) Limited", "Lenovo", "Lenovo.", "LogMeIn, Inc.", "Logitech, Inc.", "MICRO-STAR INTERNATIONAL CO., LTD", "MICRO-STAR INTERNATIONAL CO., LTD.", "MICSYS Technology Co., Ltd.", "Malwarebytes Inc", "Mediafour Corporation", "Micro-Star International CO., LTD.", "Microsemi Corporation.", "Microsemi Storage Solutions Inc.", "Microsoft Corp.", "Microsoft Corporation", "Microsoft Windows", "MiniTool Solution Ltd", "Mozilla Corporation", "NVIDIA Corporation", "Node.js Foundation", "NortonLifeLock Inc", "Notepad++", "Nuance Communications, Inc.", "OOO Lightshot", "Open Source Developer, Dominik Reichl", "OpenJS Foundation", "OpenVPN Technologies, Inc.", "Opera Software AS", "Oracle America, Inc.", "Other World Computing, Inc", "Overwolf Ltd", "PACE Anti-Piracy, Inc.", "PC Micro Systems Inc.", "Pango Inc.", "Parsec Cloud, Inc.", "Piriform Software Ltd", "Primera Technology, Inc.", "ProtonVPN AG", "QFX Software Corporation", "Qualcomm Atheros", "RealNetworks, Inc.", "Realtek Semiconductor Corp", "Realtek Semiconductor Corp.", "Red Giant Software LLC", "Riot Games, Inc.", "Riverbed Technology, Inc.", "Rivet Networks LLC", "Rockstar Games, Inc.", "S.C. BITDEFENDER S.R.L.", "SCREENOVATE TECHNOLOGIES LTD.", "SEIKO EPSON CORPORATION", "SEIKO EPSON Corporation", "Samsung Electronics CO., LTD.", "Samsung Electronics Co., Ltd.", "SanDisk Corporation", "Shaul Eizikovich", "Skype Software Sarl", "Smart Sound Technology", "SonicWall Inc.", "Sony Imaging Products & Solutions Inc.", "Sophos Ltd", "Sound Research Corporation", "Spotify AB", "SteelSeries ApS", "Sublime HQ Pty Ltd", "SurfRight B.V.", "Swift Media Entertainment, Inc.", "Symantec Corporation", "Synaptics Incorporated", "TEFINCOM S.A.", "TeamViewer Germany GmbH", "Threatstar B.V.", "Tonalio GmbH", "Tonec Inc.", "Travis Lee Robinson", "Valve Corp.", "Valve Corporation", "VideoLAN", "Wacom Co., Ltd.", "Wacom Technology Corp.", "Wacom Technology, Corp.", "Waves Inc", "Webroot Software, Inc.", "Western Digital Technologies, Inc.", "Wondershare Technology Co.,Ltd", "X-Rite Incorporated", "magicJack, L.P.", "voidtools", "Mega Limited", "Shenzhen Evision Semiconductor Technology Co., Ltd", "Shenzhen Evision Semiconductor Technology Co.,Ltd.", "Shanghai Yitu Information Technology Co.,Ltd.", "e2eSoft", "PUBG CORPORATION", "Int3 Software AB", "Giga-Byte Technology", "Windows (R) Server 2003 DDK provider", "VMware, Inc.", "Firebit OU", "Rainmeter", "McAfee, LLC", "kernel-panik", "Razer USA Ltd.", "The CefSharp Authors", "Razer Inc.", "ASUSTeK COMPUTER INC.", "ASUSTek Computer Inc.", "Plex, Inc.", "Windscribe Limited", "DTS, Inc.", "Logitech Inc", "Logitech Inc.", "Opera Norway AS", "Gaijin Network Ltd", "Nefarius Software Solutions e.U.", "Riot Games, Inc", "Roblox Corporation", "Rockstar Games", "ROBLOX Corporation", "win.rar GmbH", "Microsoft Studios", "WHIRLWIND VIRTUAL REALITIES INC.", "Noriyuki MIYAZAKI", "Blizzard Entertainment", "BeamMP", "Bitdefender", "VoodooSoft, LLC", "Comodo Security Solutions, Inc.", "Comodo Security Solutions, Inc", "COMODO Security Solutions Inc.", "Opera Software", "(NVIDIA Corp.)", "Reincubate Ltd", "(Team Cherry)", "LunarG, Inc.", "Python Software Foundation", "Parsec Cloud Inc.", "Microsoft Corporation", "Oracle Corporation", "Epic Games, Inc.", "AutoHotkey Foundation LLC", "Igor Pavlov", "FOXIT SOFTWARE INC.", "philandro Software GmbH", "AnyDesk Software GmbH", "Foxit Software Inc.", "The Git Development Community", "Skutta, Kristjan", "Proton Technologies AG", "Jagex Limited", "Activision Publishing Inc", "Activision Blizzard, Inc.", "Micro-Star Int'l Co. Ltd.", "VS Revo Group Ltd.", "VS Revo Group", "Jagex Ltd", "Mozilla", "Nicholas H.Tollervey", "Newgrounds", "OBS Project", "Proton AG", "TeamViewer", "RuneLite", "Realtek", "PROXIMA BETA PTE. LIMITED", "KRAFTON, Inc.", "Advanced Micro Devices INC.", "Advanced Micro Devices", "LG Electronics Inc.", "Snap Inc.", "GOG  sp. z o.o", "GOG.com", "FACE IT LIMITED", "tinyBuild Games", "Wellbia.com Co., Ltd.", "Audacity Team", "CPUID, Inc.", "Bethesda Softworks", "BANDAI NAMCO Entertainment Inc.", "WhatsApp Inc.", "TechPowerUp LLC", "Ubisoft Entertainment Sweden AB", "EXPRSVPN LLC", "ExpressVPN", "ExprsVPN LLC", "The OpenVPN Project", "Ring.com", "NZXT, Inc.", "Wondershare Technology Group Co.,Ltd", "Wondershare", "Voyetra Turtle Beach, Inc.", "ROCCAT", "Ferox Games B.V.", "Spotify Ltd", "Medal B.V.", "Logitech", "Lexikos", "Voicemod Sociedad Limitada", "Voicemod", "GoPro Inc.", "Twitch Interactive, Inc.", "Facebook, Inc.", "Chris Andriessen", "Moonsworth, LLC", "Now.gg, INC", "Vincent Burel", "Windows (R) Win 7 DDK provider", "(AMD)", "Disney", "Charles Milette", "Bandicam Company", "Conexant Systems LLC.", "The Qt Company Ltd.", "F.lux Software LLC", "f.lux Software LLC", ": %windir%\system32\compattelrunner.exe", "Synaptics Hong Kong Limited, Taiwan Branch (H.K.)", "TRACKER SOFTWARE PRODUCTS (CANADA) LIMITED", "Tracker Software Products (Canada) Ltd.", "Electronic Arts", "TranslucentTB Open Source Developers", "MSI Co., LTD", "Axiw Software", "Signify Netherlands B.V.", "rocksdanister", "Oculus VR, LLC", "Facebook Technologies, LLC", "Zoom Video Communications, Inc.", "Unity Technologies ApS", "Unity Technologies Inc.", "Ubisoft", "ManyCam (VISICOM MÉDIA INC.)", "Visicom Media Inc.", "WindowsLiveWallpaper", "Chan Software Solutions", "Instagram", "Amazon Development Centre (London) Ltd", "Rémi Mercier", "Whirlwind FX (Whirlwind Virtual Realities Inc.)", "(Microsoft)", "ppy Pty Ltd", "Crystal Dew World", "(Meta)", "TranslucentTB", "CyberLink Corp.", "CyberLink", "GoPro Media, Inc.", "Hewlett-Packard Development Company, L.P.", "Virtual Desktop, Inc.", "BUREL VINCENT", "VB-AUDIO Software", "Silicon Motion, Inc.", "(Facebook Inc.)", "VB-Audio Software", "Red Giant   LLC", "Red Giant LLC", "Focusrite Audio Engineering Ltd.", "Focusrite Audio Engineering Ltd", "Focusrite Audio Engineering, Ltd.", "SentinelOne Inc.", "Sentinel Labs, Inc.", "Psyonix, LLC", "(BetterDiscord)", "Bytedance Pte. Ltd.", "Mojang AB", "Mojang", "DISPLAYLINK (UK) LIMITED", "DisplayLink Corp.", "ASUSTek COMPUTER INC.", "(AMD Inc.)", "Docker Inc", "(ELAN Microelectronic Corp.)", "LIAN LI INDUSTRIAL CO., LTD.", "Lian-Li", "MUSIC Tribe Brands DE GmbH", "TC-Helicon Vocal Technologies Inc.", "Alexey Nicolaychuk", "nordvpn s.a.", "nordvpn S.A.", "Florian Höch", "Duet, Inc.", "Hugh Bailey", "Mullvad VPN AB", "Shenzhen Huion Animation Technology Co.,LTD", "ICEpower a/s", "ICEpower A/S", "COGNOSPHERE PTE. LTD.", "HoYoverse", "Corsair Components, Inc.", "Dell Technologies", "Monect (Suzhou) Co., Ltd.", "Monect, Inc.", "KRAFTON, Inc", "Stardock Corporation", "Stardock Software, Inc", "STARDOCK SYSTEMS, INC.", "Micro-Star INT'L CO., LTD.", "Sony Corporation", "ASUS", "ASUSTeK Computer Inc.", "ASUSTeK COMPUTER INC.", "KINGSTON COMPONENTS INC.", "Adobe Inc.", "Adobe Systems", "Voicemod Sociedad Limitada", "Voicemod", "win.rar GmbH", "Alexander Roshal")

$importantStrings = @("<==== ATTENTION", "No File", "File not signed", "[not found]", "[X]", "Hidden", "no ImagePath", "detected!", "powershell")

$fileContent = Get-Content -Path $filePath

$newContent = @()

foreach ($line in $fileContent) {
    $containsSearchString = $false

    foreach ($searchString in $searchStrings) {
        $escapedSearchString = [regex]::Escape($searchString)
        if ($line -match $escapedSearchString) {
            $containsSearchString = $true
            break
        }
    }

    if ($containsSearchString) {
        $isImportant = $false

        foreach ($importantString in $importantStrings) {
            $escapedImportantString = [regex]::Escape($importantString)
            if ($line -match $escapedImportantString) {
                $isImportant = $true
                break
            }
        }

        if ($isImportant) {
            $newContent += $line
        }
    }
    else {
        $newContent += $line
    }
}

if (Test-Path -Path $filePath) {
    $directoryPath = Split-Path -Path $filePath

    if ($filePath -like "*Addition*") {
        $outputFileName = "Addition_Filtered.txt"
    }
    elseif ($filePath -like "*FRST*") {
        $outputFileName = "FRST_Filtered.txt"
    }
    else {
        $outputFileName = "Filtered-FRST.txt"
    }

    $outputFilePath = Join-Path -Path $directoryPath -ChildPath $outputFileName
}
else {
    $outputFilePath = "Filtered-FRST.txt"
}

$newContent | Set-Content -Path $outputFilePath

Write-Host ""

Write-Host "Successfully filtered the log, file is located at $outputFilePath" -ForegroundColor Green
Write-Host ""
Pause