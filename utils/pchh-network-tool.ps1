# ==============================================================================
# PC Help Hub - NETWORK DIAGNOSTICS
# ==============================================================================

# Self-Elevation block
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "Requesting Administrative privileges to run diagnostics..." -ForegroundColor Cyan
    
    # Check if script is run locally or via memory
    if ($MyInvocation.MyCommand.Definition) {
        $arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$($MyInvocation.MyCommand.Definition)`""
    } else {
        $arguments = "-NoProfile -ExecutionPolicy Bypass -Command `"irm $scriptUrl | iex`""
    }
    
    Start-Process powershell -Verb runAs -ArgumentList $arguments
    exit
}

# Force the PowerShell window to maximize for easier screenshotting
$code = '[DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);'
$type = Add-Type -MemberDefinition $code -Name Window -Namespace Win32 -PassThru
$type::ShowWindow((Get-Process -Id $PID).MainWindowHandle, 3) | Out-Null

Clear-Host
Write-Host "===============================================================" -ForegroundColor Cyan
Write-Host "                PC Help Hub - NETWORK DIAGNOSTICS                   " -ForegroundColor Yellow
Write-Host "===============================================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "[ SYSTEM INFORMATION ]" -ForegroundColor Green
$os = Get-CimInstance Win32_OperatingSystem
$uptime = (Get-Date) - $os.LastBootUpTime
Write-Host "  OS Version:   $($os.Caption) ($($os.Version))"
Write-Host "  PC Uptime:    $($uptime.Days) Days, $($uptime.Hours) Hours, $($uptime.Minutes) Minutes"
if ($uptime.Days -ge 7) {
    Write-Host "  WARNING: PC has not been fully restarted in over a week!" -ForegroundColor Yellow
}
Write-Host ""

Write-Host "[ MOTHERBOARD INFO ]" -ForegroundColor Green
$mb = Get-CimInstance Win32_BaseBoard
Write-Host "  Manufacturer: $($mb.Manufacturer)"
Write-Host "  Model:        $($mb.Product)"
Write-Host ""

Write-Host "[ NETWORK ADAPTERS & DRIVERS ]" -ForegroundColor Green
Get-NetAdapter | Select-Object Name, Status, LinkSpeed, InterfaceDescription, DriverVersion, DriverDate | Format-Table -AutoSize

Write-Host "[ IP & DNS CONFIGURATION ]" -ForegroundColor Green
$netConfig = Get-NetIPConfiguration | Where-Object { $_.IPv4DefaultGateway -ne $null } | Select-Object -First 1
if ($netConfig) {
    Write-Host "  Interface: $($netConfig.InterfaceAlias)"
    Write-Host "  IPv4 Addr: $($netConfig.IPv4Address.IPAddress)"
    Write-Host "  Gateway:   $($netConfig.IPv4DefaultGateway.NextHop)"
    $dnsList = $netConfig.DNSServer.ServerAddresses -join ", "
    Write-Host "  DNS Srvs:  $dnsList"
} else {
    Write-Host "  No valid IP configuration with a Default Gateway found." -ForegroundColor Yellow
}
Write-Host ""

Write-Host "[ SECURITY & VPN CHECK ]" -ForegroundColor Green
try {
    $avProducts = Get-CimInstance -Namespace "root/SecurityCenter2" -ClassName "AntiVirusProduct" -ErrorAction SilentlyContinue
    $fwProducts = Get-CimInstance -Namespace "root/SecurityCenter2" -ClassName "FirewallProduct" -ErrorAction SilentlyContinue

    if ($avProducts) {
        foreach ($av in $avProducts) { Write-Host "  Antivirus:    $($av.displayName)" }
    } else {
        Write-Host "  Antivirus:    Windows Defender (or none detected)" -ForegroundColor Gray
    }

    if ($fwProducts) {
        foreach ($fw in $fwProducts) { Write-Host "  Firewall:     $($fw.displayName)" }
    }

    $vpnAdapters = Get-NetAdapter | Where-Object { 
        $_.InterfaceDescription -match "VPN|TAP|TUN|WireGuard|Wintun|Nord|Tailscale|ZeroTier|Cisco|GlobalProtect|Forti|AnyConnect|Cloudflare|WARP|Hamachi|Psiphon|Pulse|SonicWall|NetExtender|F5|CheckPoint|SagerNet|Shadowsocks|Proton|ExpressVPN|Surfshark|Mullvad|Windscribe|IVPN|SoftEther|PacketiX|RethinkDNS|Hotspot|Betternet|V2Ray|Neko|Onion" -or 
        $_.Name -match "VPN"
    }

    if ($vpnAdapters) {
        Write-Host "  VPN/Virtual Adapters Detected:" -ForegroundColor Yellow
        $vpnAdapters | ForEach-Object { Write-Host "    - $($_.Name) ($($_.InterfaceDescription))" }
    } else {
        Write-Host "  VPN Check:    No active third-party VPN adapters found." -ForegroundColor Gray
    }
} catch {
    Write-Host "  Error accessing security information." -ForegroundColor Red
}
Write-Host ""

Write-Host "[ WI-FI DETAILS ]" -ForegroundColor Green
$wifiCheck = netsh wlan show interfaces 2>&1 
if ($wifiCheck -match "no wireless interface|is not running|service is not running") {
    Write-Host "  No active Wi-Fi hardware found. (User is likely on Ethernet only)." -ForegroundColor Gray
} else {
    $wifiCheck | Select-String -Pattern "Name|Description|State|Band|Channel|Radio type|Receive rate|Transmit rate|Signal|Profile" | ForEach-Object {
        Write-Host $_.Line
    }
}
Write-Host ""

Write-Host "[ CONNECTIVITY & DNS CHAIN TEST ]" -ForegroundColor Green

# Define the hop list dynamically
$pingTargets = @()

if ($netConfig.IPv4DefaultGateway.NextHop) {
    $pingTargets += [PSCustomObject]@{ Name = "Local Router ($($netConfig.IPv4DefaultGateway.NextHop))"; IP = $netConfig.IPv4DefaultGateway.NextHop }
}
if ($netConfig.DNSServer.ServerAddresses[0]) {
    $pingTargets += [PSCustomObject]@{ Name = "Your Active DNS ($($netConfig.DNSServer.ServerAddresses[0]))"; IP = $netConfig.DNSServer.ServerAddresses[0] }
}
$pingTargets += [PSCustomObject]@{ Name = "Cloudflare DNS (1.1.1.1)"; IP = "1.1.1.1" }
$pingTargets += [PSCustomObject]@{ Name = "Google DNS (8.8.8.8)"; IP = "8.8.8.8" }

$pingCount = 10

foreach ($target in $pingTargets) {
    Write-Host "  Testing $($target.Name)..." -ForegroundColor Gray -NoNewline
    $ping = Test-Connection -ComputerName $target.IP -Count $pingCount -ErrorAction SilentlyContinue
    
    if ($ping) {
        $received = @($ping | Where-Object { $_.StatusCode -eq 0 }).Count
        $lossPercentage = (($pingCount - $received) / $pingCount) * 100
        
        if ($received -gt 0) {
            $avgPing = ($ping | Where-Object { $_.StatusCode -eq 0 } | Measure-Object -Property ResponseTime -Average).Average
            Write-Host " $([char]0x2714)" -ForegroundColor Green
            Write-Host "  Latency: $([math]::Round($avgPing, 1)) ms | Packet Loss: $($lossPercentage)%"
        } else {
            Write-Host " $([char]0x2718) (100% Packet Loss)" -ForegroundColor Red
        }
    } else {
        Write-Host " $([char]0x2718) (Failed/Timed Out)" -ForegroundColor Red
    }
}

Write-Host "  Testing DNS Resolution (google.com)..." -ForegroundColor Gray -NoNewline
try {
    $dnsTest = Resolve-DnsName -Name "google.com" -Type A -ErrorAction Stop
    Write-Host " $([char]0x2714)" -ForegroundColor Green
} catch {
    Write-Host " $([char]0x2718) (DNS is not resolving names)" -ForegroundColor Red
}

Write-Host "  Testing TCP Port 443 (google.com)..." -ForegroundColor Gray -NoNewline
$tcpTest = Test-NetConnection -ComputerName "google.com" -Port 443 -WarningAction SilentlyContinue
if ($tcpTest.TcpTestSucceeded) {
    Write-Host " $([char]0x2714) (Connection Successful)" -ForegroundColor Green
} else {
    Write-Host " $([char]0x2718) (Port blocked or unreachable)" -ForegroundColor Red
}
Write-Host ""

Write-Host "[ HOSTS FILE CHECK ]" -ForegroundColor Green
$hostsPath = "$env:windir\system32\drivers\etc\hosts"
if (Test-Path $hostsPath) {
    $hostsContent = Get-Content $hostsPath | Where-Object { $_ -notmatch "^\s*#" -and $_ -match "\S" }
    if ($hostsContent) {
        Write-Host "  WARNING: Manual entries detected in HOSTS file:" -ForegroundColor Yellow
        $hostsContent | ForEach-Object { Write-Host "  -> $_" -ForegroundColor White }
    } else {
        Write-Host "  Clean (No active manual entries detected)." -ForegroundColor Gray
    }
} else {
    Write-Host "  ERROR: HOSTS file not found!" -ForegroundColor Red
}
Write-Host ""

Write-Host "===============================================================" -ForegroundColor Cyan
Write-Host "   PLEASE SCREENSHOT THIS ENTIRE WINDOW AND POST IN CHAT       " -ForegroundColor Yellow
Write-Host "===============================================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "Press any key to close this window..." -ForegroundColor Yellow
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")