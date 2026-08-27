Set-ExecutionPolicy -ExecutionPolicy Unrestricted -Scope Process -Force

# change window size to fit textt
# change window color

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

$Host.UI.RawUI.WindowTitle = "PCHH Triage"

# checks if script is running as admin
if (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Host "============================================" -ForegroundColor Red
    Write-Host "-- Script must be run as an Administrator --" -ForegroundColor Red
    Write-Host "-- Right-Click Start -> Terminal(Admin)   --" -ForegroundColor Red
    Write-Host "============================================" -ForegroundColor Red
    Write-Host ""
    Write-Host "Press any key to exit the script.." -ForegroundColor Yellow
    $null = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    Stop-Process -Id $PID -Force
}

Write-Host ""

# Variable setup
$random = Get-Random -Minimum 1 -Maximum 5000
$minidump = "$env:SystemRoot\minidump"
$source = "$env:SystemRoot\minidump\*.dmp"

$desktop = [Environment]::GetFolderPath("Desktop")

$File = "$desktop\PCHH-Triage"
$infofile = "$File\specs-programs.txt"

$ziptar = "$File\PCHH-Triage_$random.zip"

$scriptVersion = "2.1 26-08-2026"
$lookbackDays = 365   # match reliability history's ~1 year span; System log is size-capped anyway
$reliability_csv_path = "$File\reliability.csv"
$reliability_html_path = "$File\triage-report.html"

# Embedded HTML viewer (reliability + specs + system events, data injected at runtime)
$viewerTemplate = @'
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>PCHH Triage - System Report</title>
<link rel="preconnect" href="https://fonts.googleapis.com">
<link href="https://fonts.googleapis.com/css2?family=Albert+Sans:wght@400;500;600;700&family=IBM+Plex+Mono:wght@400;500&display=swap" rel="stylesheet">
<style>
:root{
  --bg:#0b0c0f; --panel:#151720; --panel2:#1e212b; --line:#2c313d;
  --text:#f5f7fa; --dim:#aab0bd; --faint:#767e8c;
  --err:#ff6b6b; --warn:#ffc069; --ok:#3ddc97; --info:#6aa7ff;
}
*{box-sizing:border-box;margin:0;padding:0}
@media (prefers-reduced-motion: reduce){*{animation-duration:.001ms!important;animation-iteration-count:1!important}}
body{background:var(--bg);color:var(--text);font-family:'Albert Sans',sans-serif;font-size:16px;min-height:100vh}
#appShell{display:flex;background:var(--bg);padding:40px 16px 40px 40px;gap:16px;min-height:100vh;width:100%}
.mono{font-family:'IBM Plex Mono',monospace}
#sidebar{width:230px;flex:0 0 230px;background:var(--panel2);border:1px solid var(--line);border-radius:16px;display:flex;flex-direction:column;padding:36px 16px 22px}
#brand{font-size:19px;font-weight:600;letter-spacing:.01em;padding:0 10px 18px}
#content{flex:1;min-width:0}
@media (max-width:900px){
  #appShell{flex-direction:column;padding:16px}
  #sidebar{width:auto;flex:0 0 auto;flex-direction:row;flex-wrap:wrap;align-items:center;padding:14px}
  #brand{padding:0 14px 0 0}
  #tabs{flex-direction:row;flex-wrap:wrap;gap:6px 14px;flex:1}
  .nav-group{display:contents}
  .nav-group-title{display:none}
  #sideFoot{width:100%;order:99;flex-direction:row;justify-content:space-between;padding-top:10px}
}
#tabs{display:flex;flex-direction:column;gap:2px;flex:1;overflow-y:auto}
.nav-group{margin-bottom:14px}
.nav-group-title{display:flex;align-items:center;justify-content:space-between;color:var(--text);font-size:18px;text-transform:none;letter-spacing:0;font-weight:600;padding:8px 10px;cursor:pointer;border-radius:6px;user-select:none}
.nav-group-title:hover{color:var(--text)}
.nav-group-title.static{cursor:default}
.nav-group-title.static:hover{color:var(--dim)}
.nav-group-title .chev{font-size:10px;transition:transform .15s;color:var(--faint)}
.nav-group.collapsed .nav-group-title .chev{transform:rotate(-90deg)}
.nav-group.collapsed .nav-group-items{display:none}
.nav-group-items{display:flex;flex-direction:column;gap:2px}
#sideFoot{margin-top:auto;padding-top:14px;border-top:1px solid var(--line);display:flex;flex-direction:column;gap:4px}
#sideFoot span{color:var(--faint);font-size:12px}
.tab{display:flex;align-items:center;gap:10px;width:100%;text-align:left;background:none;border:none;color:var(--dim);font-family:inherit;font-size:16px;font-weight:500;padding:9px 10px 9px 20px;cursor:pointer;border-radius:9px}
.tab svg{width:16px;height:16px;flex-shrink:0;opacity:.65;stroke:currentColor;fill:none;stroke-width:1.7;stroke-linecap:round;stroke-linejoin:round}
.tab.on svg,.tab:hover svg{opacity:1}
.tab:hover{color:var(--text);background:color-mix(in srgb,var(--panel2) 60%,transparent)}
.tab.on{color:var(--text);background:var(--panel2)}
#summary{padding:0;display:flex;flex-direction:column;gap:6px;font-size:15.5px;line-height:1.55}


#summary .slabel{color:var(--dim)}
.summary-kv{grid-template-columns:165px 1fr;margin-bottom:4px}
.summary-kv dt{color:var(--dim)}
.summary-kv dd b{font-weight:500}
.notes-head{color:var(--faint);font-size:12.5px;text-transform:uppercase;letter-spacing:.08em;font-weight:600}
.notes-group{margin-bottom:18px}
.notes-group:last-child{margin-bottom:0}
.notes{margin:6px 0 0 2px;padding-left:18px}
.notes li{margin:3px 0;color:var(--text)}
.g{color:var(--ok)}
.r{color:var(--err)}
.y{color:var(--warn)}
.view{display:none}
@keyframes viewFadeIn{from{opacity:0;transform:translateY(6px)}to{opacity:1;transform:translateY(0)}}
body.tab-summary #summaryView,body.tab-rel #relView,body.tab-sys #sysView,body.tab-shutdowns #shutdownsView,body.tab-mobo #moboView,body.tab-cpu #cpuView,body.tab-drives #drivesView,body.tab-gpu #gpuView,body.tab-memory #memoryView,body.tab-battery #batteryView,body.tab-net #netView,body.tab-devices #devicesView,body.tab-security #securityView,body.tab-processes #processesView,body.tab-apps #appsView,body.tab-updates #updatesView,body.tab-extensions #extensionsView,body.tab-faq #faqView,body.tab-tools #toolsView,body.tab-dumps #dumpsView{display:block;animation:viewFadeIn .28s cubic-bezier(.16,1,.3,1)}
#pageTitle{padding:36px 36px 0;font-size:40px;font-weight:700;letter-spacing:-.01em;color:var(--text);max-width:1160px}
#pageTitleSub{color:var(--info);font-weight:600}
#summaryView,#sysView,#shutdownsView,#moboView,#cpuView,#drivesView,#netView,#securityView,#appsView,#dumpsView,#memoryView,#gpuView,#processesView,#extensionsView,#updatesView,#toolsView,#faqView{padding:20px 36px 64px;max-width:1160px}
.sys-ok{color:var(--ok);padding:24px 0;font-size:16px}
.sys-note{color:var(--faint);font-size:13px;margin-bottom:14px}
.spec-section{margin-bottom:40px}

/* System Summary hero: identity strip + at-a-glance spec tiles */
#summaryHero{margin-bottom:36px}
.identity{display:flex;align-items:center;justify-content:space-between;gap:24px;background:var(--panel);border:1px solid var(--line);border-radius:14px;padding:22px 26px;margin-bottom:16px}
.identity-left{display:flex;align-items:center;gap:16px;min-width:0}
.identity-icon{width:46px;height:46px;flex-shrink:0;border-radius:10px;background:var(--panel2);display:flex;align-items:center;justify-content:center}
.identity-icon svg{width:24px;height:24px;stroke:var(--info);fill:none;stroke-width:1.7;stroke-linecap:round;stroke-linejoin:round}
.identity-text{min-width:0}
.identity-title{font-size:21px;font-weight:700;letter-spacing:-.01em;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}
.identity-sub{color:var(--dim);font-size:14px;margin-top:3px}
.status-pill{display:flex;align-items:center;gap:8px;background:var(--panel2);border:1px solid var(--line);border-radius:20px;padding:8px 16px;font-size:14px;white-space:nowrap;flex-shrink:0}
.status-dot{width:8px;height:8px;border-radius:50%;flex-shrink:0}
.status-pill.warn{color:var(--warn)}.status-pill.warn .status-dot{background:var(--warn)}
.status-pill.err{color:var(--err)}.status-pill.err .status-dot{background:var(--err)}
.status-pill.ok{color:var(--ok)}.status-pill.ok .status-dot{background:var(--ok)}
.tile-grid{display:grid;grid-template-columns:repeat(3,1fr);gap:14px}
@media (max-width:820px){.tile-grid{grid-template-columns:repeat(2,1fr)}}
@media (max-width:520px){.tile-grid{grid-template-columns:1fr}.identity{flex-wrap:wrap}}
.tile{background:var(--panel);border:1px solid var(--line);border-radius:12px;padding:20px 22px 22px;transition:border-color .15s ease;cursor:pointer}
.tile:hover{border-color:var(--dim)}
.tile-head{display:flex;align-items:center;gap:10px;margin-bottom:14px}
.tile-icon{width:32px;height:32px;border-radius:8px;display:flex;align-items:center;justify-content:center;flex-shrink:0}
.tile-icon svg{width:17px;height:17px;fill:none;stroke-width:1.8;stroke-linecap:round;stroke-linejoin:round}
.tile-label{color:var(--faint);font-size:12px;text-transform:uppercase;letter-spacing:.07em;font-weight:600}
.tile-value{font-size:17px;font-weight:600;line-height:1.35;margin-bottom:6px}
.tile-line{color:var(--dim);font-size:13.5px;line-height:1.6}
.c-cpu .tile-icon{background:color-mix(in srgb,var(--info) 16%,transparent)}.c-cpu .tile-icon svg{stroke:var(--info)}
.c-gpu .tile-icon{background:color-mix(in srgb,var(--ok) 16%,transparent)}.c-gpu .tile-icon svg{stroke:var(--ok)}
.c-ram .tile-icon{background:color-mix(in srgb,var(--warn) 16%,transparent)}.c-ram .tile-icon svg{stroke:var(--warn)}
.c-storage .tile-icon{background:color-mix(in srgb,#c398ff 16%,transparent)}.c-storage .tile-icon svg{stroke:#c398ff}
.c-mobo .tile-icon{background:color-mix(in srgb,var(--dim) 16%,transparent)}.c-mobo .tile-icon svg{stroke:var(--dim)}
.c-os .tile-icon{background:color-mix(in srgb,var(--info) 16%,transparent)}.c-os .tile-icon svg{stroke:none;fill:var(--info)}

.modal-overlay{display:none;position:fixed;inset:0;background:rgba(0,0,0,.6);z-index:100;align-items:center;justify-content:center;padding:24px}
.modal-overlay.open{display:flex}
.modal-box{background:var(--panel);border:1px solid var(--line);border-radius:14px;padding:28px 30px;max-width:480px;width:100%;max-height:82vh;overflow-y:auto;position:relative}
.modal-close{position:absolute;top:16px;right:16px;background:none;border:none;color:var(--dim);font-size:22px;line-height:1;cursor:pointer;padding:4px}
.modal-close:hover{color:var(--text)}
.spec-section h2{font-size:14px;font-weight:600;color:var(--faint);text-transform:uppercase;letter-spacing:.08em;padding:4px 0 14px;border-bottom:1px solid var(--line);margin-bottom:20px}
.kv{display:grid;grid-template-columns:210px 1fr;gap:7px 16px;font-size:15px}
#wuHistList,#hfList{grid-template-columns:145px 1fr}
.kv dt{color:var(--dim)}
.kv dd{word-break:break-word}
.kv dd.flag-off{color:var(--warn)}
.drive-grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(340px,1fr));gap:18px}
.gfx-node{transition:filter .12s}
.gfx-node:hover{filter:brightness(1.15)}
.gfx-callout{margin-top:16px;padding:12px 14px;border-radius:8px;background:color-mix(in srgb,var(--warn) 12%,transparent);border:1px solid color-mix(in srgb,var(--warn) 35%,transparent);color:var(--warn);font-size:14px;display:flex;gap:10px;align-items:flex-start}
.gfx-callout svg{flex-shrink:0;margin-top:2px}
.gfx-legend{display:flex;gap:20px;margin-top:14px;font-size:13px;color:var(--faint);flex-wrap:wrap}
.gfx-legend span{display:inline-flex;align-items:center;gap:7px}
.gfx-legend i{width:16px;height:0;border-top:2px solid}
.gfx-legend i.dash{border-top-style:dashed}
.drive{background:var(--panel);border:1px solid var(--line);border-radius:12px;padding:22px}
.tool-card{display:block;text-decoration:none;color:inherit;cursor:pointer;transition:border-color .12s,background .12s}
.tool-card:hover{border-color:var(--info);background:var(--panel2)}
.tool-card h3{display:flex;align-items:center;justify-content:space-between;gap:8px}
.tool-card h3::after{content:'\2197';color:var(--faint);font-size:15px}
.tool-card:hover h3::after{color:var(--info)}
.tool-card-group{padding:22px}
.tool-card-link{display:block;text-decoration:none;color:inherit;cursor:pointer}
.tool-card-link h3{display:flex;align-items:center;justify-content:space-between;gap:8px}
.tool-card-link h3::after{content:'\2197';color:var(--faint);font-size:15px}
.tool-card-link:hover h3::after{color:var(--info)}
.tool-video-link{display:inline-block;margin-top:14px;padding-top:12px;border-top:1px solid var(--line);font-size:13.5px;color:var(--info);text-decoration:none;cursor:pointer}
.tool-video-link:hover{text-decoration:underline}
.drive h3{font-size:17px;font-weight:600;margin-bottom:4px}
.drive .sub{color:var(--dim);font-size:14.5px;margin-bottom:16px}
.drive .meter{height:6px;background:var(--panel2);border-radius:3px;overflow:hidden;margin-bottom:6px}
.drive .meter div{height:100%;background:var(--info)}
.drive .meter.low div{background:var(--warn)}
.drive .use{color:var(--dim);font-size:14px}
.drive.smart-bad{border-color:var(--err)}
.smart-kv{grid-template-columns:1fr auto;font-size:14.5px;gap:7px 12px}
.smart-kv dt{color:var(--dim)}
.smart-kv dd{text-align:right;font-family:'IBM Plex Mono',monospace}
.proc-head{display:grid;grid-template-columns:1fr 110px 110px;color:var(--faint);font-size:13px;text-transform:uppercase;letter-spacing:.06em;padding:6px 4px;border-bottom:1px solid var(--line);margin-top:8px}
.proc-row{display:grid;grid-template-columns:1fr 110px 110px;padding:5px 4px;border-bottom:1px solid color-mix(in srgb,var(--line) 40%,transparent);font-size:14.5px;font-family:'Albert Sans',sans-serif;color:var(--text)}
.proc-row span:nth-child(2),.proc-row span:nth-child(3),.proc-head span:nth-child(2),.proc-head span:nth-child(3){text-align:right}
.pager{display:flex;gap:12px;align-items:center;margin-top:12px}
.pg-btn{background:var(--panel);border:1px solid var(--line);border-radius:6px;color:var(--dim);font-family:inherit;font-size:14px;padding:6px 14px;cursor:pointer}
.pg-btn:hover:not(:disabled){color:var(--text);border-color:var(--dim)}
.pg-btn:disabled{opacity:.35;cursor:default}
.pg-info{color:var(--faint);font-size:13.5px}
.sorth{cursor:pointer;user-select:none}
.sorth:hover{color:var(--text)}
#procSearch{background:var(--panel);border:1px solid var(--line);border-radius:6px;color:var(--text);padding:8px 12px;font-size:14px;font-family:inherit;width:260px;margin-bottom:6px}
#procSearch:focus{outline:none;border-color:var(--dim)}
#progSearch{background:var(--panel);border:1px solid var(--line);border-radius:6px;color:var(--text);padding:8px 12px;font-size:14px;font-family:inherit;width:260px;margin-bottom:10px}
#hfSearch{background:var(--panel);border:1px solid var(--line);border-radius:6px;color:var(--text);padding:8px 12px;font-size:14px;font-family:inherit;width:260px;margin-bottom:10px}
#hfSearch:focus{outline:none;border-color:var(--dim)}
#progSearch:focus{outline:none;border-color:var(--dim)}
.prog-row{padding:5px 4px;border-bottom:1px solid color-mix(in srgb,var(--line) 40%,transparent);font-size:14.5px;font-family:'Albert Sans',sans-serif;color:var(--text)}
@media (max-width:600px){.kv{grid-template-columns:1fr;gap:0}.kv dt{margin-top:8px}}
h1{font-size:24px;font-weight:600;letter-spacing:.01em}
#range{color:var(--dim);font-size:14px}
#drop{display:block;margin:0 0 16px;font-size:12px;color:var(--faint);border:1px dashed var(--line);border-radius:8px;padding:8px 10px;cursor:pointer;text-align:center}
#drop:hover{color:var(--dim);border-color:var(--dim)}
body.dragging #drop{color:var(--info);border-color:var(--info)}

/* timeline */
#timeline{padding:18px 0 6px}
#tlHead{display:flex;justify-content:space-between;align-items:baseline;margin-bottom:8px}
#tlRange{color:var(--text);font-size:15px;font-weight:500}
#tlHint{color:var(--faint);font-size:13.5px}
#tl-inner{display:flex;align-items:stretch;gap:10px}
#tl-main{flex:1;min-width:0}
.tl-nav{background:var(--panel);border:1px solid var(--line);border-radius:8px;color:var(--dim);font-size:20px;width:34px;cursor:pointer;font-family:inherit;align-self:stretch}
.tl-nav:hover:not(:disabled){color:var(--text);border-color:var(--dim)}
.tl-nav:disabled{opacity:.3;cursor:default}
#bars{display:flex;align-items:flex-end;gap:6px;height:72px;border-bottom:1px solid var(--line);padding-bottom:1px}
.bar{flex:1;display:flex;flex-direction:column;justify-content:flex-end;gap:2px;cursor:pointer;min-width:4px;border-radius:3px 3px 0 0;position:relative}
.bar div{width:100%}
.bar .seg-err{background:var(--err)}
.bar .seg-warn{background:var(--warn)}
.bar .seg-ok{background:#2f3542}
.bar.clean .seg-ok{background:color-mix(in srgb,var(--ok) 45%,#2f3542)}
.bar:hover .seg-ok,.bar.active .seg-ok{background:#3d4554}
.bar.clean:hover .seg-ok,.bar.clean.active .seg-ok{background:color-mix(in srgb,var(--ok) 60%,#2f3542)}
.bar.active{outline:1px solid var(--dim);outline-offset:1px}
#axis{display:flex;gap:6px;margin-top:6px}
.axis-lab{flex:1;text-align:center;color:var(--faint);font-size:13px;white-space:nowrap;overflow:hidden}
.axis-lab.active{color:var(--text)}

/* controls */
#controls{padding:12px 0;display:flex;gap:8px;flex-wrap:wrap;align-items:center;border-bottom:1px solid var(--line)}
.chip{background:var(--panel);border:1px solid var(--line);border-radius:20px;padding:8px 16px;font-size:14px;color:var(--dim);cursor:pointer;font-family:inherit}
.chip .n{color:var(--faint);margin-left:4px}
.chip.on{color:var(--text);border-color:var(--dim)}
.chip.on.c-err{color:var(--err);border-color:var(--err)}
.chip.on.c-warn{color:var(--warn);border-color:var(--warn)}
.chip.on.c-info{color:var(--info);border-color:var(--info)}
#search{background:var(--panel);border:1px solid var(--line);border-radius:6px;color:var(--text);padding:9px 13px;font-size:14px;font-family:inherit;width:220px;margin-left:auto}
#search:focus{outline:none;border-color:var(--dim)}
#clearDay{display:none;font-size:12px;color:var(--info);cursor:pointer;background:none;border:none;font-family:inherit}

/* rows */
#list{padding:8px 0 48px}
.day-head{color:var(--text);font-size:16px;font-weight:500;padding:22px 0 8px;border-bottom:1px solid var(--line);margin-bottom:4px}
.sev-head{font-size:15px;font-weight:500;padding:12px 0 5px 4px}
.sev-err{color:var(--err)}.sev-warn{color:var(--warn)}.sev-info{color:var(--info)}
.row{display:grid;grid-template-columns:58px 12px 1fr;gap:10px;padding:9px 8px;border-radius:6px;cursor:pointer;align-items:baseline}
.row:hover{background:var(--panel)}
.row.open{background:var(--panel2)}
.time{color:var(--faint);font-size:14px}
.dot{width:8px;height:8px;border-radius:50%;align-self:center}
.d-err{background:var(--err)}.d-warn{background:var(--warn)}.d-info{background:var(--info)}
.title{overflow:hidden;text-overflow:ellipsis;white-space:nowrap}
.row.open .title{white-space:normal}
.src{color:var(--dim);font-size:14px;margin-left:10px}
.msg{grid-column:3;color:var(--dim);font-size:14px;line-height:1.5;padding:6px 0 2px;white-space:pre-wrap;display:none;word-break:break-word;cursor:text;user-select:text}
.row.open .msg{display:block}
.faq-row{grid-template-columns:12px 1fr}
.faq-row .msg{grid-column:2}
#empty{color:var(--faint);padding:40px 0;text-align:center;display:none}
@media (max-width:600px){
  #timeline,#controls,#list{padding-left:14px;padding-right:14px}
  #search{width:100%;margin-left:0}
  .row{grid-template-columns:44px 10px 1fr}
  #summaryView,#sysView,#shutdownsView,#moboView,#cpuView,#drivesView,#netView,#securityView,#appsView,#dumpsView,#memoryView,#gpuView,#processesView,#extensionsView,#updatesView,#toolsView,#faqView{padding:24px 16px 48px}
  #pageTitle{font-size:28px;padding:24px 16px 0}
}
</style>
</head>
<body class="tab-summary">
<div id="appShell">
<aside id="sidebar">
  <div id="brand">PCHH Triage</div>
  <label id="drop">Open another CSV<input type="file" accept=".csv" hidden></label>
  <nav id="tabs">
    <div class="nav-group">
      <div class="nav-group-title static"><span>Overview</span></div>
      <div class="nav-group-items">
        <button class="tab on" data-tab="summary"><svg viewBox="0 0 24 24"><polyline points="22 12 18 12 15 21 9 3 6 12 2 12"/></svg>Summary</button>
      </div>
    </div>
    <div class="nav-group">
      <div class="nav-group-title"><span>Diagnostics</span><span class="chev">&#9660;</span></div>
      <div class="nav-group-items">
        <button class="tab" data-tab="rel"><svg viewBox="0 0 24 24"><circle cx="12" cy="12" r="10"/><polyline points="12 6 12 12 16 14"/></svg>Reliability History</button>
        <button class="tab" data-tab="sys"><svg viewBox="0 0 24 24"><line x1="8" y1="6" x2="21" y2="6"/><line x1="8" y1="12" x2="21" y2="12"/><line x1="8" y1="18" x2="21" y2="18"/><line x1="3" y1="6" x2="3.01" y2="6"/><line x1="3" y1="12" x2="3.01" y2="12"/><line x1="3" y1="18" x2="3.01" y2="18"/></svg>Event Viewer</button>
        <button class="tab" data-tab="shutdowns"><svg viewBox="0 0 24 24"><path d="M18.36 6.64a9 9 0 1 1-12.73 0"/><line x1="12" y1="2" x2="12" y2="12"/></svg>Unexpected Shutdowns</button>
        <button class="tab" data-tab="dumps" id="dumpsTab" style="display:none"><svg viewBox="0 0 24 24"><path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z"/><polyline points="14 2 14 8 20 8"/><line x1="16" y1="13" x2="8" y2="13"/><line x1="16" y1="17" x2="8" y2="17"/></svg>Memory Dumps</button>
      </div>
    </div>
    <div class="nav-group">
      <div class="nav-group-title"><span>Hardware</span><span class="chev">&#9660;</span></div>
      <div class="nav-group-items">
        <button class="tab" data-tab="cpu"><svg viewBox="0 0 24 24"><rect x="4" y="4" width="16" height="16" rx="2" ry="2"/><rect x="9" y="9" width="6" height="6"/><line x1="9" y1="1" x2="9" y2="4"/><line x1="15" y1="1" x2="15" y2="4"/><line x1="9" y1="20" x2="9" y2="23"/><line x1="15" y1="20" x2="15" y2="23"/><line x1="20" y1="9" x2="23" y2="9"/><line x1="20" y1="14" x2="23" y2="14"/><line x1="1" y1="9" x2="4" y2="9"/><line x1="1" y1="14" x2="4" y2="14"/></svg>Processor</button>
        <button class="tab" data-tab="gpu"><svg viewBox="0 0 24 24"><rect x="2" y="3" width="20" height="14" rx="2" ry="2"/><line x1="8" y1="21" x2="16" y2="21"/><line x1="12" y1="17" x2="12" y2="21"/></svg>Graphics</button>
        <button class="tab" data-tab="memory"><svg viewBox="0 0 24 24"><rect x="2" y="2" width="20" height="8" rx="2" ry="2"/><rect x="2" y="14" width="20" height="8" rx="2" ry="2"/><line x1="6" y1="6" x2="6.01" y2="6"/><line x1="6" y1="18" x2="6.01" y2="18"/></svg>Memory</button>
        <button class="tab" data-tab="drives"><svg viewBox="0 0 24 24"><line x1="22" y1="12" x2="2" y2="12"/><path d="M5.45 5.11 2 12v6a2 2 0 0 0 2 2h16a2 2 0 0 0 2-2v-6l-3.45-6.89A2 2 0 0 0 16.76 4H7.24a2 2 0 0 0-1.79 1.11z"/><line x1="6" y1="16" x2="6.01" y2="16"/><line x1="10" y1="16" x2="10.01" y2="16"/></svg>Storage</button>
        <button class="tab" data-tab="mobo"><svg viewBox="0 0 24 24"><rect x="3" y="3" width="18" height="18" rx="2" ry="2"/><line x1="3" y1="9" x2="21" y2="9"/><line x1="9" y1="21" x2="9" y2="9"/></svg>Motherboard</button>
        <button class="tab" data-tab="battery" id="batteryTab" style="display:none"><svg viewBox="0 0 24 24"><rect x="1" y="6" width="18" height="12" rx="2" ry="2"/><line x1="23" y1="13" x2="23" y2="11"/></svg>Battery</button>
        <button class="tab" data-tab="net"><svg viewBox="0 0 24 24"><path d="M5 12.55a11 11 0 0 1 14.08 0"/><path d="M1.42 9a16 16 0 0 1 21.16 0"/><path d="M8.53 16.11a6 6 0 0 1 6.95 0"/><line x1="12" y1="20" x2="12.01" y2="20"/></svg>Network</button>
        <button class="tab" data-tab="devices"><svg viewBox="0 0 24 24"><path d="M15 7h3a5 5 0 0 1 5 5 5 5 0 0 1-5 5h-3m-6 0H6a5 5 0 0 1-5-5 5 5 0 0 1 5-5h3"/><line x1="8" y1="12" x2="16" y2="12"/></svg>Connected Devices</button>
      </div>
    </div>
    <div class="nav-group">
      <div class="nav-group-title"><span>System</span><span class="chev">&#9660;</span></div>
      <div class="nav-group-items">
        <button class="tab" data-tab="security"><svg viewBox="0 0 24 24"><path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z"/></svg>Security</button>
        <button class="tab" data-tab="processes"><svg viewBox="0 0 24 24"><line x1="18" y1="20" x2="18" y2="10"/><line x1="12" y1="20" x2="12" y2="4"/><line x1="6" y1="20" x2="6" y2="14"/></svg>Processes</button>
        <button class="tab" data-tab="apps"><svg viewBox="0 0 24 24"><rect x="3" y="3" width="7" height="7"/><rect x="14" y="3" width="7" height="7"/><rect x="14" y="14" width="7" height="7"/><rect x="3" y="14" width="7" height="7"/></svg>Apps</button>
        <button class="tab" data-tab="updates"><svg viewBox="0 0 24 24"><polyline points="8 17 12 21 16 17"/><line x1="12" y1="12" x2="12" y2="21"/><path d="M20.88 18.09A5 5 0 0 0 18 9h-1.26A8 8 0 1 0 3 16.29"/></svg>Updates</button>
        <button class="tab" data-tab="extensions"><svg viewBox="0 0 24 24"><path d="M21 16V8a2 2 0 0 0-1-1.73l-7-4a2 2 0 0 0-2 0l-7 4A2 2 0 0 0 3 8v8a2 2 0 0 0 1 1.73l7 4a2 2 0 0 0 2 0l7-4A2 2 0 0 0 21 16z"/><polyline points="3.27 6.96 12 12.01 20.73 6.96"/><line x1="12" y1="22.08" x2="12" y2="12"/></svg>Extensions</button>
      </div>
    </div>
    <div class="nav-group">
      <div class="nav-group-title"><span>Help</span><span class="chev">&#9660;</span></div>
      <div class="nav-group-items">
        <button class="tab" data-tab="faq"><svg viewBox="0 0 24 24"><circle cx="12" cy="12" r="10"/><path d="M9.09 9a3 3 0 0 1 5.83 1c0 2-3 3-3 3"/><line x1="12" y1="17" x2="12.01" y2="17"/></svg>FAQ</button>
        <button class="tab" data-tab="tools"><svg viewBox="0 0 24 24"><path d="M14.7 6.3a1 1 0 0 0 0 1.4l1.6 1.6a1 1 0 0 0 1.4 0l3.77-3.77a6 6 0 0 1-7.94 7.94l-6.91 6.91a2.12 2.12 0 0 1-3-3l6.91-6.91a6 6 0 0 1 7.94-7.94z"/></svg>Tools &amp; Utilities</button>
      </div>
    </div>
  </nav>
  <div id="sideFoot"><span id="pageFoot"></span></div>
</aside>
<main id="content">

<h1 id="pageTitle">PCHH Triage <span id="pageTitleSub">- Summary</span></h1>

<div id="summaryView" class="view">
  <div id="summaryHero"></div>
  <div class="spec-section"><h2>General Notes</h2><div id="notesBody"></div></div>
</div>

<div id="relView" class="view">
<div id="timeline">
  <div id="tlHead"><span id="tlRange" class="mono"></span><span id="tlHint">Click a bar to see that day's events. Use the arrows to move back two weeks.</span></div>
  <div id="tl-inner">
    <button id="tlPrev" class="tl-nav" title="Earlier">&#8249;</button>
    <div id="tl-main"><div id="bars"></div><div id="axis"></div></div>
    <button id="tlNext" class="tl-nav" title="Later">&#8250;</button>
  </div>
</div>

<div id="controls">
  <button class="chip c-err" data-cat="err">&#10060;&#65038; Critical events<span class="n"></span></button>
  <button class="chip c-warn" data-cat="warn">&#9888;&#65038; Warnings<span class="n"></span></button>
  <button class="chip c-info" data-cat="info">&#8505;&#65038; Informational events<span class="n"></span></button>
  <button id="clearDay"></button>
  <input id="search" type="text" placeholder="Search product or message…">
</div>

<div id="list"></div>
<div id="empty">No events match.</div>
</div>

<div id="sysView" class="view"></div>
<div id="shutdownsView" class="view"></div>
<div id="moboView" class="view"></div>
<div id="cpuView" class="view"></div>
<div id="drivesView" class="view"></div>
<div id="gpuView" class="view"></div>
<div id="memoryView" class="view"></div>
<div id="batteryView" class="view"></div>
<div id="netView" class="view"></div>
<div id="devicesView" class="view"></div>
<div id="securityView" class="view"></div>
<div id="processesView" class="view"></div>
<div id="appsView" class="view"></div>
<div id="updatesView" class="view"></div>
<div id="extensionsView" class="view"></div>
<div id="faqView" class="view"></div>
<div id="toolsView" class="view"><div class="spec-section"><h2>Diagnostics &amp; Monitoring</h2><div class="drive-grid"><a class="drive tool-card" id="tool-hwinfo" data-tool="HWiNFO" href="https://www.hwinfo.com/download/" target="_blank" rel="noopener"><h3>HWiNFO</h3><div class="sub" style="line-height:1.5">Real-time hardware sensor monitoring &mdash; temperatures, voltages, clock speeds, fan speeds.</div></a><a class="drive tool-card" id="tool-cpu-z" data-tool="CPU-Z" href="https://www.cpuid.com/softwares/cpu-z.html" target="_blank" rel="noopener"><h3>CPU-Z</h3><div class="sub" style="line-height:1.5">Quick reference for CPU, motherboard, and RAM specifications.</div></a><a class="drive tool-card" id="tool-gpu-z" data-tool="GPU-Z" href="https://www.techpowerup.com/gpuz/" target="_blank" rel="noopener"><h3>GPU-Z</h3><div class="sub" style="line-height:1.5">CPU-Z's GPU-focused equivalent &mdash; driver version, VRAM, clocks, sensors.</div></a><a class="drive tool-card" id="tool-crystaldiskinfo" data-tool="CrystalDiskInfo" href="https://crystalmark.info/en/software/crystaldiskinfo/" target="_blank" rel="noopener"><h3>CrystalDiskInfo</h3><div class="sub" style="line-height:1.5">Drive health and SMART status at a glance.</div></a><a class="drive tool-card" id="tool-hdsentinel" data-tool="HDSentinel" href="https://www.hdsentinel.com/" target="_blank" rel="noopener"><h3>HDSentinel</h3><div class="sub" style="line-height:1.5">Alternative drive health monitor with predictive failure estimates and more detailed SMART reporting.</div></a><a class="drive tool-card" id="tool-latencymon" data-tool="LatencyMon" href="https://www.resplendence.com/latencymon" target="_blank" rel="noopener"><h3>LatencyMon</h3><div class="sub" style="line-height:1.5">Measures system latency and DPC issues &mdash; the standard tool for diagnosing audio crackling and stuttering.</div></a></div></div><div class="spec-section"><h2>Stability &amp; Stress Testing</h2><div class="drive-grid"><a class="drive tool-card" id="tool-memtest86" data-tool="MemTest86" href="https://www.memtest86.com/" target="_blank" rel="noopener"><h3>MemTest86</h3><div class="sub" style="line-height:1.5">Bootable RAM stability test, run outside Windows &mdash; the standard way to confirm or rule out bad memory.</div></a><a class="drive tool-card" id="tool-occt" data-tool="OCCT" href="https://www.ocbase.com/" target="_blank" rel="noopener"><h3>OCCT</h3><div class="sub" style="line-height:1.5">Combined CPU/GPU/RAM stress test with built-in stability and error detection.</div></a><a class="drive tool-card" id="tool-furmark" data-tool="FurMark" href="https://geeks3d.com/furmark/" target="_blank" rel="noopener"><h3>FurMark</h3><div class="sub" style="line-height:1.5">GPU stress test &mdash; useful for spotting thermal throttling or instability under sustained load.</div></a></div></div><div class="spec-section"><h2>Crash Analysis</h2><div class="drive-grid"><a class="drive tool-card" id="tool-whocrashed" data-tool="WhoCrashed" href="https://www.resplendence.com/whocrashed" target="_blank" rel="noopener"><h3>WhoCrashed</h3><div class="sub" style="line-height:1.5">Plain-English analysis of minidump files &mdash; pairs directly with the .dmp files this tool collects.</div></a><a class="drive tool-card" id="tool-windbg" data-tool="WinDbg" href="https://learn.microsoft.com/en-us/windows-hardware/drivers/debugger/debugger-download-tools" target="_blank" rel="noopener"><h3>WinDbg</h3><div class="sub" style="line-height:1.5">Microsoft's own debugger &mdash; a more advanced tool for reading minidumps in full detail, down to the exact stack trace.</div></a></div></div><div class="spec-section"><h2>Advanced System Tools</h2><div class="drive-grid"><a class="drive tool-card" id="tool-process-explorer" data-tool="Process Explorer" href="https://learn.microsoft.com/en-us/sysinternals/downloads/process-explorer" target="_blank" rel="noopener"><h3>Process Explorer</h3><div class="sub" style="line-height:1.5">A far deeper Task Manager replacement from Microsoft's Sysinternals suite &mdash; inspect loaded DLLs, handles, and process trees.</div></a><a class="drive tool-card" id="tool-autoruns" data-tool="Autoruns" href="https://learn.microsoft.com/en-us/sysinternals/downloads/autoruns" target="_blank" rel="noopener"><h3>Autoruns</h3><div class="sub" style="line-height:1.5">The definitive startup-entry inspector from Sysinternals &mdash; see and control everything set to launch with Windows, in far more depth than this report's own startup check.</div></a></div></div><div class="spec-section"><h2>Cleanup &amp; Disk Space</h2><div class="drive-grid"><a class="drive tool-card" id="tool-bleachbit" data-tool="BleachBit" href="https://www.bleachbit.org/" target="_blank" rel="noopener"><h3>BleachBit</h3><div class="sub" style="line-height:1.5">Clears temporary files and caches to free up disk space.</div></a><a class="drive tool-card" id="tool-wiztree" data-tool="WizTree" href="https://diskanalyzer.com/" target="_blank" rel="noopener"><h3>WizTree</h3><div class="sub" style="line-height:1.5">Visualises what's actually taking up space on a drive.</div></a></div></div><div class="spec-section"><h2>Driver Management</h2><div class="drive-grid"><div class="drive tool-card-group" id="tool-display-driver-uninstaller-ddu" data-tool="Display Driver Uninstaller (DDU)"><a class="tool-card-link" href="https://www.wagnardsoft.com/" target="_blank" rel="noopener"><h3>Display Driver Uninstaller (DDU)</h3><div class="sub" style="line-height:1.5">Fully removes GPU drivers before a clean reinstall &mdash; the standard fix for driver-related instability.</div></a><a class="tool-video-link" href="https://youtu.be/ULgWBAlgpfk" target="_blank" rel="noopener">&#9654; Watch tutorial</a></div><a class="drive tool-card" id="tool-amd-drivers-amp-support" data-tool="AMD Drivers &amp; Support" href="https://www.amd.com/en/support" target="_blank" rel="noopener"><h3>AMD Drivers &amp; Support</h3><div class="sub" style="line-height:1.5">Official AMD driver downloads.</div></a><a class="drive tool-card" id="tool-nvidia-drivers-amp-support" data-tool="NVIDIA Drivers &amp; Support" href="https://www.nvidia.com/Download/index.aspx" target="_blank" rel="noopener"><h3>NVIDIA Drivers &amp; Support</h3><div class="sub" style="line-height:1.5">Official NVIDIA driver downloads.</div></a><a class="drive tool-card" id="tool-intel-drivers-amp-support" data-tool="Intel Drivers &amp; Support" href="https://www.intel.com/content/www/us/en/support/detect.html" target="_blank" rel="noopener"><h3>Intel Drivers &amp; Support</h3><div class="sub" style="line-height:1.5">Official Intel driver downloads.</div></a></div></div><div class="spec-section"><h2>Installation Media</h2><div class="drive-grid"><div class="drive tool-card-group" id="tool-windows-11-download" data-tool="Windows 11 Download"><a class="tool-card-link" href="https://www.microsoft.com/software-download/windows11" target="_blank" rel="noopener"><h3>Windows 11 Download</h3><div class="sub" style="line-height:1.5">Official Microsoft page for Windows 11 installation media.</div></a><a class="tool-video-link" href="https://youtu.be/TiqcfvO_8Tc" target="_blank" rel="noopener">&#9654; Watch tutorial</a></div><a class="drive tool-card" id="tool-rufus" data-tool="Rufus" href="https://rufus.ie/" target="_blank" rel="noopener"><h3>Rufus</h3><div class="sub" style="line-height:1.5">Creates bootable USB installers from a Windows ISO &mdash; the alternative to the official Windows 11 media creation tool.</div></a></div></div><div class="spec-section"><h2>Motherboard / BIOS Vendor Support</h2><div class="drive-grid"><a class="drive tool-card" id="tool-asus-support" data-tool="ASUS Support" href="https://www.asus.com/support/" target="_blank" rel="noopener"><h3>ASUS Support</h3><div class="sub" style="line-height:1.5">Official ASUS driver and BIOS downloads.</div></a><a class="drive tool-card" id="tool-msi-support" data-tool="MSI Support" href="https://www.msi.com/support/" target="_blank" rel="noopener"><h3>MSI Support</h3><div class="sub" style="line-height:1.5">Official MSI driver and BIOS downloads.</div></a><a class="drive tool-card" id="tool-gigabyte-support" data-tool="Gigabyte Support" href="https://www.gigabyte.com/Support" target="_blank" rel="noopener"><h3>Gigabyte Support</h3><div class="sub" style="line-height:1.5">Official Gigabyte driver and BIOS downloads.</div></a><a class="drive tool-card" id="tool-asrock-support" data-tool="ASRock Support" href="https://www.asrock.com/support/index.asp" target="_blank" rel="noopener"><h3>ASRock Support</h3><div class="sub" style="line-height:1.5">Official ASRock driver and BIOS downloads.</div></a><a class="drive tool-card" id="tool-dell-support" data-tool="Dell Support" href="https://www.dell.com/support/home/" target="_blank" rel="noopener"><h3>Dell Support</h3><div class="sub" style="line-height:1.5">Official Dell driver and BIOS downloads (by service tag).</div></a><a class="drive tool-card" id="tool-hp-support" data-tool="HP Support" href="https://support.hp.com/" target="_blank" rel="noopener"><h3>HP Support</h3><div class="sub" style="line-height:1.5">Official HP driver and BIOS downloads.</div></a><a class="drive tool-card" id="tool-lenovo-support" data-tool="Lenovo Support" href="https://support.lenovo.com/" target="_blank" rel="noopener"><h3>Lenovo Support</h3><div class="sub" style="line-height:1.5">Official Lenovo driver and BIOS downloads.</div></a></div></div></div>
<div id="dumpsView" class="view"></div>

</main>
<div id="smartModal" class="modal-overlay"><div class="modal-box"><button class="modal-close" id="smartModalClose">&times;</button><div id="smartModalBody"></div></div></div>
</div>

<script>
const RAW = /*__DATA__*/[];
let SPECS_PROGRAMS=[];
const SPECS = /*__SPECS__*/"";
const DUMPS = /*__DUMPS__*/[];
const SYSEVT = /*__SYSEVT__*/[];
const SMART = /*__SMART__*/[];
const DIRTY = /*__DIRTY__*/[];
const DISKLAYOUT = /*__DISKLAYOUT__*/[];
const RAM = /*__RAM__*/[];
const GPUS = /*__GPUS__*/[];
const HAGS = /*__HAGS__*/null;
const ISLAPTOP = /*__ISLAPTOP__*/false;
const BATTERY = /*__BATTERY__*/[];
const RAMSLOTS = /*__RAMSLOTS__*/null;
const WUHISTORY = /*__WUHISTORY__*/[];
const WINUPDATE = /*__WINUPDATE__*/null;
const MONS = /*__MONS__*/[];
const DISPLAYS = /*__DISPLAYS__*/[];
const PROCS = /*__PROCS__*/[];
const MEMUSE = /*__MEMUSE__*/null;
const NET = /*__NET__*/null;
const SECURITY = /*__SECURITY__*/null;
const HOTFIXES = /*__HOTFIXES__*/[];
const WINDOWSOLD = /*__WINDOWSOLD__*/null;
const POWERPLAN = /*__POWERPLAN__*/null;
const GENFLAGS = /*__GENFLAGS__*/null;
const CBS = /*__CBS__*/null;
const DEVERR = /*__DEVERR__*/[];
const AUDIO = /*__AUDIO__*/null;
const USBDEVS = /*__USB__*/[];
const CAMERAS = /*__CAMERAS__*/[];
const VER = /*__VER__*/"";
const GEN = /*__GEN__*/"";

// --- parsing / classification ---
function parseDate(s){
  // DD/MM/YYYY HH:MM:SS or MM/DD/YYYY, detect: first field >12 means DD first
  const m = s.match(/(\d{1,2})\/(\d{1,2})\/(\d{4})[ ,]+(\d{1,2}):(\d{2}):(\d{2})\s*(AM|PM)?/i);
  if(!m) return null;
  let [,a,b,y,h,mi,se,ap] = m;
  a=+a;b=+b;h=+h;
  let day=a, mon=b;
  if(a<=12 && b>12){ day=b; mon=a; }
  if(ap){ if(/pm/i.test(ap)&&h<12)h+=12; if(/am/i.test(ap)&&h===12)h=0; }
  return new Date(+y, mon-1, day, h, +mi, +se);
}
function classify(r){
  const src=r.s, msg=(r.m||'').trim();
  if(src==='Application Error'||src==='Windows Error Reporting'||/bugcheck/i.test(src)) return 'err';
  // SourceName 'EventLog' within reliability history is specifically Windows' own unexpected-
  // shutdown marker - no need to also match the English word "unexpected" in the message,
  // which is localized and would misclassify this as a lower severity on non-English systems.
  if(src==='EventLog') return 'err';
  // MsiInstaller (1033 install / 1034 uninstall / 1035 reconfigure) and WindowsUpdateClient
  // (19 success / 20 failure) always carry a numeric status/result code. SourceName and
  // EventIdentifier are fixed internal identifiers - never localized - so gating on those and
  // reading the trailing number in the message means this still works when the message text
  // itself is in a language other than English, unlike matching English words like "fail" or
  // "success or error status".
  if(src==='MsiInstaller' && ['1033','1034','1035'].includes(r.e)){
    const m=msg.match(/(\d+)\.?\s*$/);
    if(m) return m[1]==='0' ? 'info' : 'warn';
  }
  if(src==='Microsoft-Windows-WindowsUpdateClient'){
    if(r.e==='20') return 'warn';
    if(r.e==='19') return 'info';
  }
  // Fallback for everything else: English keyword match on the message. Only reliable on
  // English-language systems, but there's no locale-independent field to fall back to for the
  // long tail of other SourceNames.
  if(/fail|error status: 1|not.*success/i.test(msg.toLowerCase()) && !/status: 0/.test(msg)) return 'warn';
  return 'info';
}
const CATNAMES={err:'Critical events',warn:'Warnings',info:'Informational events'};

let events=[], state={cats:new Set(['err','warn']), q:'', day:null, tlEnd:null};
const TL_WIN=14;

function load(raw){
  events = raw.map(r=>{
    const d=parseDate(r.t);
    return {...r, d, cat:classify(r), dayKey:d?d.toISOString().slice(0,10):'?'};
  }).filter(e=>e.d).sort((a,b)=>b.d-a.d);
  state.day=null;
  state.tlEnd=null;
  render();
}

function fmtDay(k){const d=new Date(k);const dd=String(d.getDate()).padStart(2,'0');const mm=String(d.getMonth()+1).padStart(2,'0');return dd+'/'+mm+'/'+d.getFullYear();}
function fmtDayShort(k){const d=new Date(k);return d.getDate()+'/'+(d.getMonth()+1);}
function fmtTime(d){return d.toLocaleTimeString('en-GB',{hour:'2-digit',minute:'2-digit'});}

function render(){
  // counts per category (unfiltered by cat, filtered by search+day)
  const base = events.filter(e=>
    (!state.day||e.dayKey===state.day) &&
    (!state.q || (e.p+' '+e.m+' '+e.s).toLowerCase().includes(state.q)));
  document.querySelectorAll('.chip[data-cat]').forEach(c=>{
    const cat=c.dataset.cat;
    c.querySelector('.n').textContent=base.filter(e=>e.cat===cat).length;
    c.classList.toggle('on',state.cats.has(cat));
  });

  const shown = base.filter(e=>state.cats.has(e.cat));


  // timeline: continuous calendar days, windowed to 7 with scroll
  const allDays=[];
  if(events.length){
    const lo=new Date(events[events.length-1].dayKey), hi=new Date(events[0].dayKey);
    for(let d=new Date(lo); d<=hi; d.setDate(d.getDate()+1)) allDays.push(d.toISOString().slice(0,10));
  }
  if(state.tlEnd===null||state.tlEnd>allDays.length-1) state.tlEnd=allDays.length-1;
  if(state.tlEnd<Math.min(TL_WIN,allDays.length)-1) state.tlEnd=Math.min(TL_WIN,allDays.length)-1;
  const winStart=Math.max(0,state.tlEnd-TL_WIN+1);
  const days=allDays.slice(winStart,state.tlEnd+1);
  const byDay={};
  allDays.forEach(k=>byDay[k]={err:0,warn:0,rest:0});
  events.forEach(e=>{
    if(state.q && !(e.p+' '+e.m+' '+e.s).toLowerCase().includes(state.q)) return;
    const b=byDay[e.dayKey]; if(!b) return;
    if(e.cat==='err')b.err++; else if(e.cat==='warn')b.warn++; else b.rest++;
  });
  const max=Math.max(1,...days.map(k=>byDay[k].err+byDay[k].warn+byDay[k].rest));
  document.getElementById('tlPrev').disabled = winStart===0;
  document.getElementById('tlNext').disabled = state.tlEnd>=allDays.length-1;
  const bars=document.getElementById('bars');
  bars.innerHTML='';
  days.forEach(k=>{
    const b=byDay[k], tot=b.err+b.warn+b.rest;
    const bar=document.createElement('div');
    bar.className='bar'+(state.day===k?' active':'')+((b.err+b.warn)===0?' clean':'');
    bar.title=fmtDay(k)+' \u00b7 '+tot+' event'+(tot===1?'':'s')+(b.err?' ('+b.err+' critical)':'');
    if(!tot){const s=document.createElement('div');s.className='seg-ok';s.style.height='3px';s.style.opacity='.45';bar.appendChild(s);}
    const h=x=>Math.round(x/max*64);
    if(b.rest){const s=document.createElement('div');s.className='seg-ok';s.style.height=Math.max(tot?3:0,h(b.rest))+'px';bar.appendChild(s);}
    if(b.warn){const s=document.createElement('div');s.className='seg-warn';s.style.height=Math.max(8,h(b.warn))+'px';bar.appendChild(s);}
    if(b.err){const s=document.createElement('div');s.className='seg-err';s.style.height=Math.max(8,h(b.err))+'px';bar.appendChild(s);}
    bar.onclick=()=>{state.day=state.day===k?null:k;render();};
    bars.appendChild(bar);
  });
  const axis=document.getElementById('axis');
  axis.innerHTML=days.map(k=>{
    return '<span class="axis-lab'+(state.day===k?' active':'')+'">'+fmtDayShort(k)+'</span>';
  }).join('');
  const rEl=document.getElementById('tlRange');
  if(days.length){
    rEl.textContent=fmtDay(days[0])+' \u2013 '+fmtDay(days[days.length-1]);
  }

  const cd=document.getElementById('clearDay');
  cd.style.display=state.day?'inline':'none';
  cd.textContent=state.day?('✕ '+fmtDay(state.day)):'';

  // list grouped by day
  const list=document.getElementById('list');
  list.innerHTML='';
  const dayGroups=new Map();
  shown.forEach(e=>{
    if(!dayGroups.has(e.dayKey))dayGroups.set(e.dayKey,{err:[],warn:[],info:[]});
    dayGroups.get(e.dayKey)[e.cat].push(e);
  });
  const ICONS={err:'\u274C\uFE0E',warn:'\u26A0\uFE0E',info:'\u2139\uFE0E'};
  dayGroups.forEach((groups,dayKey)=>{
    const h=document.createElement('div');h.className='day-head';
    h.textContent=fmtDay(dayKey);
    list.appendChild(h);
    ['err','warn','info'].forEach(cat=>{
      const evs=groups[cat];
      if(!evs.length)return;
      const sh=document.createElement('div');sh.className='sev-head sev-'+cat;
      sh.textContent=ICONS[cat]+' '+CATNAMES[cat]+(evs.length>1?' ('+evs.length+')':'');
      list.appendChild(sh);
      evs.forEach(e=>{
        const row=document.createElement('div');row.className='row';
        row.innerHTML='<span class="time mono">'+fmtTime(e.d)+'</span>'+
          '<span class="dot d-'+e.cat+'"></span>'+
          '<span class="title">'+esc(e.p||'(unnamed)')+'<span class="src">'+summary(e)+'</span></span>'+
          '<div class="msg mono">'+esc(e.m)+'</div>';
        row.onclick=(e)=>{ if(e.target.closest('.msg')||hasTextSelection())return; row.classList.toggle('open'); };
        row.querySelector('.msg').onclick=e=>e.stopPropagation();
        list.appendChild(row);
      });
    });
  });
  document.getElementById('empty').style.display=shown.length?'none':'block';
}
function summary(e){
  if(e.cat==='err'){
    if(e.s==='Application Error')return 'Stopped working';
    if(e.s==='EventLog')return 'Windows was not properly shut down';
    return 'Critical event';
  }
  // EventIdentifier (like SourceName) is a fixed internal code, never localized, so branching on
  // it instead of matching English words in the message keeps these labels correct regardless of
  // the system's display language.
  if(e.s==='Microsoft-Windows-WindowsUpdateClient')
    return e.e==='19'?'Successful Windows Update':'Windows Update';
  if(e.s==='MsiInstaller'){
    if(e.e==='1033')return 'Successful application installation';
    if(e.e==='1034')return 'Successful application removal';
    if(e.e==='1035')return 'Successful application reconfiguration';
    return 'Application event';
  }
  return esc(e.s);
}
function esc(s){return String(s??'').replace(/[&<>"]/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;'}[c]));}
// Hero tile icons - reused verbatim from the matching sidebar tab icon wherever one exists
// (GPU, Storage, Memory), so a tile visually promises "click me to see more" honestly. CPU,
// Motherboard and System have no dedicated tab of their own, so they get their own icon.
const ICON_CPU='<svg viewBox="0 0 24 24"><rect x="4" y="4" width="16" height="16" rx="2" ry="2"/><rect x="9" y="9" width="6" height="6"/><line x1="9" y1="1" x2="9" y2="4"/><line x1="15" y1="1" x2="15" y2="4"/><line x1="9" y1="20" x2="9" y2="23"/><line x1="15" y1="20" x2="15" y2="23"/><line x1="20" y1="9" x2="23" y2="9"/><line x1="20" y1="14" x2="23" y2="14"/><line x1="1" y1="9" x2="4" y2="9"/><line x1="1" y1="14" x2="4" y2="14"/></svg>';
const ICON_GPU='<svg viewBox="0 0 24 24"><rect x="2" y="3" width="20" height="14" rx="2" ry="2"/><line x1="8" y1="21" x2="16" y2="21"/><line x1="12" y1="17" x2="12" y2="21"/></svg>';
const ICON_RAM='<svg viewBox="0 0 24 24"><rect x="2" y="2" width="20" height="8" rx="2" ry="2"/><rect x="2" y="14" width="20" height="8" rx="2" ry="2"/><line x1="6" y1="6" x2="6.01" y2="6"/><line x1="6" y1="18" x2="6.01" y2="18"/></svg>';
const ICON_STORAGE='<svg viewBox="0 0 24 24"><line x1="22" y1="12" x2="2" y2="12"/><path d="M5.45 5.11 2 12v6a2 2 0 0 0 2 2h16a2 2 0 0 0 2-2v-6l-3.45-6.89A2 2 0 0 0 16.76 4H7.24a2 2 0 0 0-1.79 1.11z"/><line x1="6" y1="16" x2="6.01" y2="16"/><line x1="10" y1="16" x2="10.01" y2="16"/></svg>';
const ICON_MOBO='<svg viewBox="0 0 24 24"><rect x="3" y="3" width="18" height="18" rx="2" ry="2"/><line x1="3" y1="9" x2="21" y2="9"/><line x1="9" y1="21" x2="9" y2="9"/></svg>';
const ICON_OS='<svg viewBox="0 0 24 24"><rect x="3" y="3" width="8" height="8" rx="1"/><rect x="13" y="3" width="8" height="8" rx="1"/><rect x="3" y="13" width="8" height="8" rx="1"/><rect x="13" y="13" width="8" height="8" rx="1"/></svg>';
const ICON_PC='<svg viewBox="0 0 24 24"><rect x="5" y="2" width="14" height="20" rx="2" ry="2"/><line x1="5" y1="7" x2="19" y2="7"/><line x1="9" y1="15" x2="9.01" y2="15"/><line x1="13" y1="15" x2="17" y2="15"/></svg>';
const ICON_INFO='<svg viewBox="0 0 24 24"><circle cx="12" cy="12" r="10"/><line x1="12" y1="16" x2="12" y2="12"/><line x1="12" y1="8" x2="12.01" y2="8"/></svg>';
// Guards accordion-row toggles against text selection. Checking only whether the click
// *landed* inside .msg isn't enough - drag-selecting a long/wrapped message often ends with
// the mouse released just outside its box, which used to collapse the row mid-selection and
// made it hard to copy anything. Checking for a live selection catches that regardless of
// where the mouseup happened.
function hasTextSelection(){ const s=window.getSelection(); return !!(s && s.toString().length>0); }

document.querySelectorAll('.chip[data-cat]').forEach(c=>c.onclick=()=>{
  const cat=c.dataset.cat;
  state.cats.has(cat)?state.cats.delete(cat):state.cats.add(cat);
  render();
});
document.getElementById('clearDay').onclick=()=>{state.day=null;render();};
document.getElementById('tlPrev').onclick=()=>{state.tlEnd=Math.max(TL_WIN-1,state.tlEnd-TL_WIN);render();};
document.getElementById('tlNext').onclick=()=>{state.tlEnd=state.tlEnd+TL_WIN;render();};
document.getElementById('search').oninput=e=>{state.q=e.target.value.toLowerCase();render();};

// CSV loading (drop or picker) for future exports
function parseCSV(text){
  const rows=[];let cur=[''],inQ=false,i=0;
  for(;i<text.length;i++){
    const c=text[i];
    if(inQ){
      if(c==='"'){ if(text[i+1]==='"'){cur[cur.length-1]+='"';i++;} else inQ=false; }
      else cur[cur.length-1]+=c;
    } else {
      if(c==='"')inQ=true;
      else if(c===',')cur.push('');
      else if(c==='\n'||c==='\r'){ if(cur.length>1||cur[0]!==''){rows.push(cur);cur=[''];} }
      else cur[cur.length-1]+=c;
    }
  }
  if(cur.length>1||cur[0]!=='')rows.push(cur);
  const head=rows.shift().map(h=>h.replace(/^\ufeff/,''));
  const ix=n=>head.findIndex(h=>h.toLowerCase()===n);
  const [t,s,e,p,m]=['timegenerated','sourcename','eventidentifier','productname','message'].map(ix);
  return rows.map(r=>({t:r[t],s:r[s],e:r[e],p:r[p],m:r[m]}));
}
function handleFile(f){
  const rd=new FileReader();
  rd.onload=()=>{try{load(parseCSV(rd.result));}catch(err){alert('Could not parse that CSV: '+err.message);}};
  rd.readAsText(f);
}
document.querySelector('#drop input').onchange=e=>e.target.files[0]&&handleFile(e.target.files[0]);
['dragover','dragenter'].forEach(ev=>document.addEventListener(ev,e=>{e.preventDefault();document.body.classList.add('dragging');}));
['dragleave','drop'].forEach(ev=>document.addEventListener(ev,e=>{e.preventDefault();document.body.classList.remove('dragging');}));
document.addEventListener('drop',e=>{const f=e.dataTransfer.files[0];if(f)handleFile(f);});

// --- specs parsing & rendering ---
function parseSpecs(text){
  const out={info:[],drives:[],programs:[]};
  if(!text||!text.trim())return out;
  const norm=text.replace(/\r/g,'');
  const [head, rest] = splitOnce(norm, /^Drive Information:\s*$/m);
  const [driveTxt, progTxt] = splitOnce(rest||'', /^Programs Installed:\s*$/m);
  head.split('\n').forEach(l=>{
    const m=l.match(/^([^:]+):\s?(.*)$/);
    if(m&&m[2]!=='')out.info.push([m[1].trim(),m[2].trim()]);
  });
  let cur=null;
  (driveTxt||'').split('\n').forEach(l=>{
    const m=l.match(/^([^:]+):\s?(.*)$/);
    if(!m)return;
    const k=m[1].trim(),v=m[2].trim();
    if(k==='Drive Label'){cur={};out.drives.push(cur);}
    if(cur)cur[k]=v;
  });
  (progTxt||'').split('\n').forEach(l=>{
    const t=l.trim();
    if(!t||t==='DisplayName'||/^-+$/.test(t))return;
    out.programs.push(t);
  });
  // The registry scan reads both the 32-bit and 64-bit Uninstall keys, so the same shared
  // redistributable (e.g. a .NET or Visual C++ runtime) commonly appears in both and shows up
  // twice with an identical name - dedupe before sorting so the count reflects reality.
  out.programs=[...new Set(out.programs)];
  out.programs.sort((a,b)=>a.localeCompare(b,undefined,{sensitivity:'base'}));
  return out;
}
function splitOnce(text,re){
  const m=text.match(re);
  if(!m)return[text,''];
  return[text.slice(0,m.index),text.slice(m.index+m[0].length)];
}
function renderSpecs(){
  const sp=parseSpecs(SPECS);
  let dh='';
  if(DISKLAYOUT.length){
    const smartByDisk={};
    SMART.forEach(d=>{smartByDisk[String(d.disk)]=d;});
    const disksSorted=[...DISKLAYOUT].sort((a,b)=>(+a.disk)-(+b.disk));
    dh+='<div class="spec-section"><h2>Disk layout</h2>';
    const TYPE_COLOR={'EFI System Partition':'var(--info)','Recovery':'var(--warn)','Recovery (MBR)':'var(--warn)','Microsoft Reserved':'var(--faint)','Data':'var(--ok)','System':'var(--dim)'};
    disksSorted.forEach(dk=>{
      const total=dk.partitions.reduce((a,p)=>a+p.sizeGB,0)||dk.sizeGB||1;
      const sm=smartByDisk[String(dk.disk)];
      const probs=sm?smartProbs(sm):[];
      const bad=probs.length>0;
      const healthLabel=(sm&&sm.health&&!(bad&&/^healthy$/i.test(sm.health)))?sm.health+(sm.op&&sm.op!=='OK'&&sm.op!==sm.health?' ('+sm.op+')':''):'';
      dh+='<div class="drive'+(bad?' smart-bad':'')+'" style="margin-bottom:14px'+(bad?';cursor:pointer':'')+'"'+(bad?' onclick="openSmartModal(\''+esc(dk.disk)+'\')"':'')+'>';
      dh+='<h3>Disk '+esc(dk.disk)+(sm&&sm.name?' <span style="color:var(--dim);font-weight:400">'+esc(sm.name)+'</span>':'')+'</h3>';
      dh+='<div class="sub">'+esc(dk.style||'Unknown')+' \u00b7 '+dk.sizeGB+' GB'+(sm&&sm.bus?' \u00b7 '+esc(sm.bus):'')+
        (healthLabel?' \u00b7 <span style="color:'+(bad?'var(--err)':'var(--ok)')+'">'+esc(healthLabel)+'</span>':'')+'</div>'+
        (bad?'<div style="color:var(--err);font-size:13.5px;margin-bottom:6px">\u26a0 SMART warning &mdash; click for details</div>':'');
      dh+='<div style="display:flex;height:22px;border-radius:6px;overflow:hidden;margin:10px 0;background:var(--panel2)">';
      dk.partitions.forEach(p=>{
        const pct=Math.max(1.5,(p.sizeGB/total*100));
        const col=TYPE_COLOR[p.type]||'var(--dim)';
        dh+='<div title="'+esc(p.type)+(p.letter?' ('+esc(p.letter)+')':'')+' \u00b7 '+p.sizeGB+' GB" style="width:'+pct+'%;background:'+col+';border-right:1px solid var(--panel)"></div>';
      });
      dh+='</div><dl class="kv smart-kv">';
      dk.partitions.forEach(p=>{
        dh+='<dt><span style="display:inline-block;width:9px;height:9px;border-radius:2px;background:'+(TYPE_COLOR[p.type]||'var(--dim)')+';margin-right:6px"></span>'+esc(p.type)+(p.letter?' ('+esc(p.letter)+')':'')+'</dt><dd>'+p.sizeGB+' GB</dd>';
      });
      dh+='</dl></div>';
    });
    dh+='</div>';
    const alerts=[];
    SMART.forEach(d=>{
      const probs=smartProbs(d);
      if(probs.length)alerts.push('<li><span class="r" style="color:var(--err)">Disk '+esc(d.disk)+' ('+esc(d.name)+'): '+esc(probs.join(', '))+'</span></li>');
    });
    DIRTY.forEach(v=>alerts.push('<li><span style="color:var(--warn)">Volume '+esc(v)+' has its dirty bit set</span></li>'));
    dh+='<div class="spec-section" style="margin-top:26px"><h2>SMART alerts</h2>'+
      (alerts.length?'<ul class="notes">'+alerts.join('')+'</ul>'
       :'<div style="color:var(--ok)">\u2713 No SMART alerts. All disks report Healthy with no uncorrected errors.</div>')+'</div>';
  }
  document.getElementById('drivesView').innerHTML=dh||'<div class="spec-section"><h2>Storage</h2><div style="color:var(--faint)">No storage data embedded.</div></div>';
  return sp.programs;
}
const PS_={q:'',page:1,key:'mem',dir:-1}, PG_={q:'',page:1};
let PROGS_ALL=[];
function renderProcesses(){
  const v=document.getElementById('processesView');
  if(!PROCS.length){
    v.innerHTML='<div class="spec-section"><h2>Running Processes</h2><div style="color:var(--faint)">No process data embedded.</div></div>';
    return;
  }
  v.innerHTML='<div class="spec-section"><h2>Running processes ('+PROCS.length+')</h2>'+
    '<input id="procSearch" type="text" placeholder="Filter processes\u2026">'+
    '<div class="proc-head">'+
    '<span class="sorth" data-key="name">Process<span class="arrow"></span></span>'+
    '<span class="sorth" data-key="cnt">Instances<span class="arrow"></span></span>'+
    '<span class="sorth" data-key="mem">Memory<span class="arrow"></span></span></div>'+
    '<div id="procList"></div><div class="pager" id="procPager"></div></div>';
  const pf=document.getElementById('procSearch');
  if(pf)pf.oninput=e=>{PS_.q=e.target.value.toLowerCase();PS_.page=1;renderProcList();};
  document.querySelectorAll('.sorth').forEach(hd=>hd.onclick=()=>{
    const k=hd.dataset.key;
    if(PS_.key===k)PS_.dir=-PS_.dir; else {PS_.key=k;PS_.dir=k==='name'?1:-1;}
    PS_.page=1;renderProcList();
  });
  renderProcList();
}
function renderAppsList(programs){
  PROGS_ALL=programs||[];
  const v=document.getElementById('appsView');
  v.innerHTML=PROGS_ALL.length?
    '<div class="spec-section"><h2>Installed programs ('+PROGS_ALL.length+')</h2>'+
    '<input id="progSearch" type="text" placeholder="Filter programs\u2026">'+
    '<div class="proc-head"><span>Program<span class="arrow"></span></span></div>'+
    '<div id="progList"></div><div class="pager" id="progPager"></div></div>'
    :'<div class="spec-section"><h2>Installed Apps</h2><div style="color:var(--faint)">No data embedded.</div></div>';
  const ps=document.getElementById('progSearch');
  if(ps)ps.oninput=e=>{PG_.q=e.target.value.toLowerCase();PG_.page=1;renderProgList();};
  renderProgList();
}
const WH_={page:1};
function renderUpdates(){
  const v=document.getElementById('updatesView');
  let h='';
  const w=WINUPDATE;
  if(w){
    h+='<div class="spec-section"><h2>Windows Update status</h2><dl class="kv">';
    h+='<dt>Pending Reboot?</dt><dd style="color:'+(w.pendingReboot?'var(--warn)':'var(--ok)')+'">'+(w.pendingReboot?'Yes':'No')+'</dd>';
    if(w.serviceStatus)h+='<dt>Windows Update service</dt><dd style="color:'+(w.serviceStartType==='Disabled'?'var(--warn)':'var(--ok)')+'">'+esc(w.serviceStatus)+(w.serviceStartType?' <span style="color:var(--faint)">('+esc(w.serviceStartType)+')</span>':'')+'</dd>';
    h+='</dl></div>';
  }
  if(WUHISTORY.length){
    const failCount=WUHISTORY.filter(u=>u.result==='Failed'||u.result==='Cancelled').length;
    h+='<div class="spec-section"><h2>Recent update history ('+WUHISTORY.length+')</h2>';
    if(failCount)h+='<div style="color:var(--warn);font-size:14px;margin-bottom:12px">'+failCount+' update'+(failCount>1?'s':'')+' did not complete successfully</div>';
    h+='<dl class="kv" id="wuHistList"></dl><div class="pager" id="wuHistPager"></div></div>';
  }
  if(HOTFIXES.length){
    h+='<div class="spec-section"><h2>Installed updates ('+HOTFIXES.length+')</h2>'+
      '<input id="hfSearch" type="text" placeholder="Filter updates\u2026">'+
      '<dl class="kv" id="hfList"></dl><div class="pager" id="hfPager"></div></div>';
  }
  v.innerHTML=h||'<div class="spec-section"><h2>Windows Updates</h2><div style="color:var(--faint)">No update data embedded.</div></div>';
  const hf=document.getElementById('hfSearch');
  if(hf)hf.oninput=e=>{HF_.q=e.target.value.toLowerCase();HF_.page=1;renderHfList();};
  renderHfList();
  renderWuHistList();
}
function renderWuHistList(){
  const el=document.getElementById('wuHistList');if(!el)return;
  const SZ=15,pages=Math.max(1,Math.ceil(WUHISTORY.length/SZ));
  if(WH_.page>pages)WH_.page=pages;
  const slice=WUHISTORY.slice((WH_.page-1)*SZ,WH_.page*SZ);
  el.innerHTML=slice.map(u=>{
    const col=u.result==='Succeeded'?'var(--ok)':(u.result==='Failed'||u.result==='Cancelled')?'var(--err)':'var(--warn)';
    return '<dt>'+esc(u.date)+'</dt><dd>'+esc(u.title)+' <span style="color:'+col+'">('+esc(u.result)+')</span></dd>';
  }).join('')||'<dd style="color:var(--faint)">No update history.</dd>';
  pager(document.getElementById('wuHistPager'),WH_.page,pages,WUHISTORY.length,slice.length,g=>{WH_.page+=g;renderWuHistList();});
}
const FAQ_DATA=[
{id:'app-crashes',q:"Application Crashes",a:"This counts how many times a program on your PC has crashed and forced Windows to close it, based on the "+tabLink('rel','Windows Reliability History')+".<br><br>Occasional crashes are normal, especially in games or browsers. A rising number, especially if they're all the same program or all mention the same driver file, usually points to that specific program, a graphics driver, or a plugin/mod rather than Windows itself.",tools:["WhoCrashed","Display Driver Uninstaller (DDU)"]},
{id:'unexpected-shutdown',q:"Unexpected Shutdowns",a:"Windows didn't shut down properly last time, meaning it never received the normal 'the user is turning off the PC' signal. This can be caused by:<ul style='margin:8px 0 8px 20px;padding:0'><li>a full system crash (a 'blue screen')</li><li>a power cut</li><li>overheating (thermal shutdown)</li><li>someone holding the power button</li><li>the PC freezing and being force-restarted</li></ul>If a specific bugcheck code is shown, that's the technical reason Windows gave. It can point toward whether this is a hardware, driver, or Windows problem. Most bugcheck codes are Google-able and have common fixes.<br><br>When Windows detects the power button was physically held down for 4+ seconds, it records that moment separately from the shutdown itself - that's shown as 'Power button held down' with the exact time, which usually means the PC was unresponsive and had to be force-closed rather than crashing cleanly with a bugcheck.",tools:["WhoCrashed","OCCT","MemTest86","Display Driver Uninstaller (DDU)"]},
{id:'memory-dump',q:"Memory Dump",a:"When Windows crashes badly, a 'blue screen' happens. Windows tries to save a snapshot of exactly what the computer was doing at that moment to a file called a memory dump.<br><br>Memory dump(s) are included in the zip this tool creates. If you have them, you can share the zip file with us and we'll try to debug for you. Memory dumps are one of the most useful pieces of evidence for figuring out precisely what caused a crash.<br><br>If there are no memory dumps in the zip file but you've been experiencing crashes, shutdowns, or freezing, that means Windows wasn't able to create one. This can (but not always) indicate a hardware problem over a software one. Windows will usually try to generate a memory dump when the system crashes.",tools:["WhoCrashed"]},
{id:'whea',q:"Fatal Hardware Error (WHEA)",a:"WHEA is Windows' hardware error reporting system. A fatal WHEA error means a core piece of hardware, usually the CPU, memory controller, or a PCIe device, reported a serious problem Windows couldn't recover from, and the machine likely crashed or rebooted as a result.<br><br>This is a strong indication that something is physically wrong or unstable, often an overclock, degraded hardware, or insufficient voltage, rather than a software issue.",tools:["OCCT","MemTest86","HWiNFO"]},
{id:'disk-smart',q:"Storage / SMART Warnings",a:"Your drives (SSD, NVMe, hard drive) constantly track their own health statistics using something called SMART data. This data lists specific problems the drive itself has self-reported, such as:<ul style='margin:8px 0 8px 20px;padding:0'><li>reallocated sectors (damaged areas it's had to work around)</li><li>pending or uncorrectable sectors (data that couldn't be read reliably)</li><li>a high UltraDMA CRC error count (usually a loose or failing cable)</li></ul>If a drive predicts its own failure, it's important that you back up anything important from it immediately. Drive failures are often random and unpredictable.",tools:["CrystalDiskInfo"]},
{id:'dirty-bit',q:"Dirty Bit",a:"This means Windows flagged a drive as not having been cleanly unmounted, usually caused by the same unexpected shutdown or crash reported elsewhere in this report. It's a marker for Windows to check that drive's filesystem for errors next time it gets the chance.<br><br>On its own it isn't necessarily a sign of a failing drive, and is used as an indication that something might be wrong.",tools:[]},
{id:'device-manager-errors',q:"Device Manager Errors",a:"Windows found a piece of hardware but couldn't properly load a driver for it, or the device itself reported a problem. This usually means a missing, outdated, or corrupted driver. Occasionally it's a genuine hardware fault.",tools:["AMD Drivers & Support","NVIDIA Drivers & Support","Intel Drivers & Support"]},
{id:'mbr-secureboot',q:"MBR Partitioning",a:"Windows drives use one of two partitioning styles: MBR or the newer GPT. Secure Boot, a feature that helps stop malware loading before Windows starts, requires GPT.<br><br>If the main drive (the one with Windows installed on it) is MBR, Secure Boot can't be turned on without converting the drive or doing a clean reinstall of Windows, which is a bigger job and best not attempted without guidance.",tools:[]},
{id:'pending-reboot',q:"Pending Reboot",a:"Windows or an update has made changes that only take full effect after a restart, and it's currently waiting on one. Until then the system can behave oddly and further updates may queue up behind it.<br><br>A normal restart resolves this.",tools:[]},
{id:'wu-service',q:"Windows Update Service",a:"The background service that lets Windows check for and install updates is disabled. Normally it's set to start on demand (so it's often shown as 'Stopped' when idle - that's expected and not a problem), but 'Disabled' means it can't start at all, so Windows won't be able to update until it's turned back on.",tools:[]},
{id:'wu-failed',q:"Failed Windows Updates",a:"One or more recent update attempts failed partway through rather than installing cleanly. This can happen for lots of reasons: a bad download, low disk space, corrupted update files, or a conflict with other software.<br><br>It can sometimes leave a PC feeling unstable or repeatedly nagging about the same update.",tools:["Windows 11 Download"]},
{id:'ram-speed',q:"RAM Speed (XMP/EXPO)",a:"Your memory (RAM) is capable of running faster than it currently is. This almost always means that a feature called XMP (Intel) or EXPO (AMD) isn't enabled.<br><br>XMP/EXPO is a one-click profile in the BIOS that allows your RAM to run at its advertised speed. When it's disabled, your RAM will default to a lower speed. Enabling it isn't overclocking, and isn't dangerous. We'd recommend enabling it, which can be done through your BIOS. If you're unsure how to do that, you can ask one of our advisors for more help.<br><br><i>Note: some systems can struggle to run RAM at its full advertised speed for various reasons, which is why it isn't enabled by default. When this happens, it can sometimes help to disable it, to prevent system instability or crashes.</i><br><br>This isn't dangerous either way, but running below the rated speed does mean the RAM isn't performing the way it was bought to.",tools:["CPU-Z"]},
{id:'antivirus-conflict',q:"Multiple Antivirus Programs",a:"More than one antivirus program is trying to actively scan the system at the same time. This is a common, often-overlooked cause of slowdowns, false-positive quarantines, and general instability, since the two programs can end up fighting over the same files.",tools:[]},
{id:'defender-rtp',q:"Defender Real-Time Protection",a:"Windows' built-in antivirus isn't actively scanning for threats. This can be intentional if another antivirus is installed, or it can be accidental. Malware sometimes disables it deliberately to avoid detection.",tools:[]},
{id:'bitlocker-on',q:"BitLocker Enabled",a:"The system drive is encrypted with BitLocker. This is worth knowing before any wipe, reset, reinstall, or drive removal &mdash; without the recovery key, an encrypted drive that gets locked out (for example, after a motherboard or TPM change) cannot be read or recovered.<br><br>If a wipe or reset is planned, confirm the recovery key is backed up somewhere accessible (Microsoft account, Active Directory, or a printed/saved copy) before proceeding.",tools:[]},
{id:'firewall-disabled',q:"Firewall Disabled",a:"Windows Firewall isn't active on one or more network profiles (Domain, Private, or Public), leaving the system more exposed to unwanted network connections.",tools:[]},
{id:'defender-threats',q:"Defender Threat Detections",a:"Windows Defender has previously found and acted on something it identified as malware, a virus, or another threat on this PC. This is historical. It doesn't necessarily mean anything is currently infected, but repeated or recent detections are worth taking seriously.",tools:[]},
{id:'defender-exclusions',q:"Risky Defender Exclusions",a:"An exclusion tells Windows Defender to skip scanning a specific file, folder, or file type. Excluding a game folder is common and usually fine.<br><br>Excluding an entire drive, a broad system folder, or all .exe files is far more dangerous, since it means malware placed there would never be scanned at all. Check the Security tab for exactly what's excluded.",tools:[]},
{id:'rdp-enabled',q:"Remote Desktop (RDP) Enabled",a:"Remote Desktop lets someone log into this PC over the network as if sitting at it. It's useful for legitimate remote access, but it's also a common target for attackers, especially if the PC is reachable from the internet or has a weak password.<br><br>The signed-in account type matters here too: a local account only needs its own password, while a Microsoft or Entra ID account can be backed by MFA. If this wasn't set up intentionally, it's worth disabling. If it's needed, make sure Network Level Authentication is required and the account used has a strong password.",tools:[]},
{id:'hosts-redirect',q:"Hosts File Redirects",a:"The hosts file is a small system text file that can override where certain web addresses point. This flag means an update- or security-related address, like Windows Update or an antivirus vendor, has been redirected elsewhere. Sometimes this is done deliberately to block updates, but it's also a technique malware uses to stop antivirus software updating itself.<br><br>It's also common to find the hosts file modified when the user (or someone else) has installed cracked software, since some software relies on connecting to license server websites to 'check' that they're licensed.",tools:[]},
{id:'startup-flagged',q:"Flagged Startup Entries",a:"These are programs set to launch automatically with Windows that either run from a Temp folder or don't have a valid digital signature. Neither is automatically a problem. Plenty of legitimate small or hobbyist tools are unsigned, but it's exactly the pattern malware persistence uses, so anything unfamiliar here is worth a closer look.",tools:[]},
{id:'gpu-tdr',q:"Display Driver Timeout (TDR)",a:"The graphics driver stopped responding briefly and Windows had to recover it (often called a TDR event). This usually shows up as a brief flicker or freeze rather than a full crash, though it can escalate to one.<br><br>Common causes are an unstable GPU overclock, an outdated or corrupted graphics driver, or the GPU overheating under load.",tools:["Display Driver Uninstaller (DDU)","FurMark","HWiNFO"]},
{id:'high-uptime',q:"Long System Uptime",a:"The PC hasn't been restarted in over a week. This is common and not inherently a problem, but pending Windows/driver updates won't take effect until a reboot, and memory leaks or resource creep in long-running processes become more likely to cause slowdowns the longer a session goes on.<br><br>If something on this PC is running slow or behaving oddly, a restart is a cheap first thing to try before digging further.",tools:[]},
{id:'cbs-corruption',q:"Unresolved Component Corruption (CBS.log)",a:"CBS.log records Windows' component servicing activity, including any system file repairs. A 'Cannot repair member' entry means a corrupted system file was found during a check (from Windows Update, an in-place upgrade, or a manual sfc/DISM run) that couldn't be automatically fixed.<br><br>This can cause update failures, missing features, or general instability depending on what's affected. Running <span class=\"mono\">sfc /scannow</span> followed by <span class=\"mono\">DISM /Online /Cleanup-Image /RestoreHealth</span> is the standard next step; if DISM can't find a good copy of the file locally it will need a network connection or Windows installation media to pull one from.",tools:["sfc /scannow","DISM"]},
{id:'livekernelevent',q:"LiveKernelEvent",a:"Windows' record of a serious problem severe enough to be crash-like, but that the system managed to recover from without a full restart, most often tied to a graphics driver failing and recovering.<br><br>Frequent LiveKernelEvents point to the same kinds of causes as display driver timeouts.",tools:["Display Driver Uninstaller (DDU)","FurMark","HWiNFO"]},
{id:'wifi-signal',q:"Weak Wi-Fi Signal",a:"The wireless connection's signal strength was weak at the moment this report was generated. A weak signal can cause slow speeds, dropped connections, and higher ping in games, and is usually down to distance from the router, walls/obstructions, or interference from other devices.",tools:[]},
{id:'gigabit-slow',q:"Gigabit Adapter Running Below Rated Speed",a:"This network adapter supports Gigabit Ethernet (1000 Mbps) but is currently connected at a much lower speed, most often 100 Mbps.<br><br>This is a very common symptom of a damaged or low-quality cable, a loose connection, or a faulty port on either end - Gigabit needs all 4 wire pairs in the cable to be good, while 100 Mbps only needs 2, so a cable can work perfectly well at the lower speed while silently capping the connection. Try a known-good cable (ideally Cat5e or better) and a different port on the router/switch first.",tools:[]},
{id:'commit-charge',q:"Commit Charge",a:"This measures how much memory (RAM plus the page file combined) the system had committed to running programs at the moment this report was generated.<br><br>Running close to the limit can cause slowdowns, stuttering, or 'out of memory' errors, and often points to either too little RAM for the workload or a page file set too small.",tools:["HWiNFO"]},
{id:'software-anticheat',q:"Anti-Cheat / Kernel Drivers",a:"Anti-cheat systems like Vanguard, Easy Anti-Cheat, and BattlEye run at a very deep level in Windows (a 'kernel driver') to detect cheating in games. That deep access makes them a common (though not the only) suspect when troubleshooting crashes tied to a specific game.<br><br>This is a factual note that it's installed, not a claim that it's causing a problem.",tools:[]},
{id:'software-overclock',q:"Overclocking / Monitoring Tools",a:"Tools like MSI Afterburner, RTSS, Intel XTU, and Ryzen Master can adjust CPU/GPU clock speeds, voltages, and power limits beyond default settings. If a system is unstable, an aggressive overclock applied through one of these is a common and easy-to-test cause.",tools:["OCCT"]},
{id:'software-rgb',q:"RGB / Peripheral Software",a:"Software like Corsair iCUE, Razer Synapse, Logitech G HUB, and similar RGB/peripheral control suites has a real history of causing background crashes, high idle CPU/RAM usage, and driver conflicts, even though each individual program is legitimate.",tools:[]},
{id:'software-audio',q:"Audio / Overlay Software",a:"Tools like Nahimic, GeForce Experience, Xbox Game Bar, and Streamlabs OBS can conflict with each other or with games, particularly when more than one is trying to add an overlay at the same time.",tools:[]},
{id:'software-network',q:"Flagged Network Software",a:"Software like Killer Network Manager or Hola VPN has a known history of causing latency spikes, packet loss, or other connectivity problems on some systems.",tools:[]},
{id:'software-shell',q:"Shell/Taskbar Tweak Tools",a:"Tools like TranslucentTB, ExplorerPatcher, StartAllBack, Start11, Open-Shell, or Windhawk modify Windows Explorer or the taskbar/Start menu's appearance and behaviour, often by hooking into or patching explorer.exe itself.<br><br>They're generally safe day-to-day, but because they hook into core shell processes, they're a common cause of taskbar/Start menu glitches, explorer.exe crashes, or freezes after a Windows feature update changes something they relied on. Worth ruling out first if that's the symptom.",tools:[]},
{id:'software-cheat',q:"Game Exploit / Cheat Tool",a:"Tools like JJSploit, Synapse X, Krnl, Fluxus, and similar Roblox/game script executors, along with general memory-editors like Cheat Engine, are flagged here because they carry real risk beyond just breaking the rules of a game:<ul style='margin:8px 0 8px 20px;padding:0'><li>they're a very common way to end up with genuine malware, since many are distributed through cracked/pirated download sites with a trojan bundled in</li><li>most inject code into a running game process, which is exactly the pattern antivirus and anti-cheat software is built to catch - a wave of false-positive detections or a sudden anti-cheat ban often traces straight back to one of these</li><li>some game accounts can be permanently banned the moment one of these is detected running, even once</li></ul>This is a factual note that it's installed, not an accusation - but if unexplained AV detections, game bans, or crashes tied to a specific game are the symptom, this is worth checking first.",tools:[]},
{id:'software-fancontrol',q:"Multiple Fan-Control Programs",a:"Programs like Lian Li L-Connect, FanControl, SpeedFan, Fan Xpert, and RGB/fan hubs such as Corsair iCUE, NZXT CAM, MSI Dragon Center, or ASUS Armoury Crate can all set fan curves directly through the motherboard or a fan controller.<br><br>Running more than one of these at the same time means they can end up fighting over the same fans - each one periodically re-applying its own curve over the other's - which shows up as fans that surge, stall, or cycle speed for no clear reason. The fix is usually to pick one and fully close (not just minimize) the others, since some keep running in the background even without a visible window.",tools:[]},
{id:'windows-old',q:"Windows.old Folder",a:"Windows.old is a backup of the previous Windows installation, automatically created when Windows is upgraded in place or reset while keeping personal files. It lets Windows roll back to the previous version for about 10 days before it's automatically deleted to free up space, though it can stick around longer if that cleanup didn't run.<br><br>Its presence is a useful sign that this installation is newer than the hardware, which is handy context if a problem only started recently. It doesn't cover every case, though: a full wipe-and-reinstall or a reset that removes everything doesn't leave a Windows.old folder behind at all, so its absence doesn't rule out a recent reset.",tools:[]},
{id:'secure-boot',q:"Secure Boot",a:"Secure Boot is a security feature that checks the software involved in starting Windows hasn't been tampered with, before the operating system even loads. It helps stop a specific but nasty category of malware (called bootkits or rootkits) that tries to run before Windows, and before any antivirus, gets a chance to load.<br><br>Microsoft requires it for Windows 11, and leaving it disabled removes a real layer of protection for no real-world upside on most PCs. It requires the system disk to use GPT partitioning. See the note about MBR partitioning in this report if that's relevant.",tools:[]},
{id:'tpm',q:"TPM",a:"A TPM (Trusted Platform Module) is a small, dedicated security chip, or a feature built into the CPU (fTPM) on newer systems, that securely stores encryption keys and other sensitive data separately from the rest of the PC. It's what Windows 11 relies on for BitLocker drive encryption and for meeting its own minimum security requirements.<br><br>If it's disabled, Windows Hello, BitLocker, and some newer Windows security features either can't be used or fall back to a weaker mode. It can usually be turned on in the BIOS/UEFI settings (often listed as 'TPM', 'fTPM', 'PTT', or 'Security Device').",tools:[]},
{id:'wrong-gpu-slot',q:"Display on the Wrong GPU",a:"This PC has a dedicated graphics card, but the monitor cable is plugged into the motherboard's video output instead of the graphics card's. That routes everything through the slower integrated graphics built into the CPU, so the dedicated GPU sits there unused."
  +"<br><br>This is a very common cable mistake, especially after a fresh build or a cable getting knocked loose. The desktop will still work and look normal, but games and demanding programs will run far below the performance the GPU should be giving."
  +"<br><br>The fix is simple: move the monitor cable to one of the ports on the graphics card itself, usually found at the bottom of the case where the card's bracket is, rather than the ports built into the motherboard I/O panel at the top.",tools:["GPU-Z"]},
{id:'software-bloatware',q:"Bloatware / PUPs",a:"This flags software with a track record of being unwanted, low-value, or actively harmful to performance: things like registry 'cleaners', aggressive PC 'optimizer' tools, or trial antivirus suites that came pre-installed. None of these are viruses, but removing them is often one of the most effective ways to speed up a slow PC.",tools:[]},
];
function renderFAQ(){
  const v=document.getElementById('faqView');
  let h='<div class="spec-section"><h2>Frequently Asked Questions</h2>'+
    '<div style="color:var(--dim);font-size:14px;margin-bottom:16px">Click any question to expand it. Flagged items in General Notes link straight here.</div>';
  FAQ_DATA.forEach(f=>{
    h+='<div class="row faq-row" id="faq-'+f.id+'"><span class="dot d-info"></span>'+
      '<span class="title">'+esc(f.q)+'</span>'+
      '<div class="msg">'+f.a+
      (f.tools.length?'<div style="margin-top:10px;color:var(--dim)">Helpful tools: '+f.tools.map(toolLink).join(', ')+'</div>':'')+
      '</div></div>';
  });
  h+='</div>';
  v.innerHTML=h;
  v.querySelectorAll('.faq-row').forEach(r=>r.onclick=(e)=>{ if(e.target.closest('.msg')||hasTextSelection())return; r.classList.toggle('open'); });
  v.querySelectorAll('.faq-row .msg').forEach(m=>m.onclick=e=>e.stopPropagation());
}
function goFaq(id){
  document.querySelectorAll('.tab').forEach(x=>x.classList.toggle('on',x.dataset.tab==='faq'));
  document.body.className='tab-faq';
  setTimeout(()=>{
    const el=document.getElementById('faq-'+id);
    if(!el)return;
    el.classList.add('open');
    el.scrollIntoView({behavior:'smooth',block:'center'});
    el.style.outline='2px solid var(--info)';
    setTimeout(()=>{el.style.outline='';},1600);
  },30);
  return false;
}
function goTab(tabId){
  const btn=[...document.querySelectorAll(".tab")].find(t=>t.dataset.tab===tabId);
  if(btn)btn.click();
  return false;
}
function goTool(name){
  goTab('tools');
  setTimeout(()=>{
    const el=[...document.querySelectorAll('[data-tool]')].find(e=>e.dataset.tool===name);
    if(!el)return;
    el.scrollIntoView({behavior:'smooth',block:'center'});
    el.style.outline='2px solid var(--info)';
    setTimeout(()=>{el.style.outline='';},1600);
  },30);
  return false;
}
function toolLink(name){
  return '<a href="#" onclick="return goTool(\''+name+'\')" style="color:var(--info);text-decoration:underline;text-decoration-style:dotted;text-underline-offset:3px;cursor:pointer">'+esc(name)+'</a>';
}
function tabLink(tabId,label){
  return '<a href="#" onclick="return goTab(\'' + tabId + '\')" style="color:var(--info);text-decoration:underline;text-decoration-style:dotted;text-underline-offset:3px;cursor:pointer">'+label+'</a>';
}
function goAnchor(tabId,anchorId){
  goTab(tabId);
  setTimeout(()=>{
    const el=document.getElementById(anchorId);
    if(!el)return;
    el.scrollIntoView({behavior:'smooth',block:'center'});
    el.style.outline='2px solid var(--info)';
    setTimeout(()=>{el.style.outline='';},1600);
  },30);
  return false;
}
function anchorLink(tabId,anchorId,faqId,html){
  const main='<a href="#" onclick="return goAnchor(\''+tabId+'\',\''+anchorId+'\')" style="color:inherit;text-decoration:underline;text-decoration-style:dotted;text-underline-offset:3px;cursor:pointer">'+html+'</a>';
  const info=faqId?' <a href="#" onclick="return goFaq(\''+faqId+'\')" title="What does this mean?" style="color:var(--faint);text-decoration:none;cursor:pointer;font-size:12px">(?)</a>':'';
  return main+info;
}
function flagLink(faqId,html){
  return '<a href="#" class="faq-link" onclick="return goFaq(\''+faqId+'\')" style="color:inherit;text-decoration:underline;text-decoration-style:dotted;text-underline-offset:3px;cursor:pointer">'+html+'</a>';
}
function dataLink(tabId,faqId,html){
  const main='<a href="#" onclick="return goTab(\''+tabId+'\')" style="color:inherit;text-decoration:underline;text-decoration-style:dotted;text-underline-offset:3px;cursor:pointer">'+html+'</a>';
  const info=faqId?' <a href="#" onclick="return goFaq(\''+faqId+'\')" title="What does this mean?" style="color:var(--faint);text-decoration:none;cursor:pointer;font-size:12px">(?)</a>':'';
  return main+info;
}

function renderExtensions(){
  const v=document.getElementById('extensionsView');
  if(!SECURITY||!SECURITY.extensions||!SECURITY.extensions.length){
    v.innerHTML='<div class="spec-section"><h2>Browser Extensions</h2><div style="color:var(--faint)">No browser extension data embedded.</div></div>';
    return;
  }
  const byBrowser={};
  SECURITY.extensions.forEach(e=>{(byBrowser[e.browser]=byBrowser[e.browser]||[]).push(e.name);});
  let h='<div class="spec-section"><h2>Browser extensions ('+SECURITY.extensions.length+')</h2><div class="drive-grid">';
  Object.keys(byBrowser).sort().forEach(b=>{
    const names=[...new Set(byBrowser[b])].sort((a,c)=>a.localeCompare(c,undefined,{sensitivity:'base'}));
    h+='<div class="drive"><h3>'+esc(b)+'</h3>'+
      '<div class="sub">'+names.length+' extension'+(names.length>1?'s':'')+'</div>'+
      '<div style="color:var(--dim);font-size:14px;line-height:1.8">'+names.map(esc).join('<br>')+'</div></div>';
  });
  h+='</div></div>';
  v.innerHTML=h;
}
function pager(el,page,pages,total,shown,onGo){
  if(!el)return;
  if(pages<=1){el.innerHTML=total?'<span class="pg-info">'+shown+' of '+total+'</span>':'';return;}
  el.innerHTML='<button class="pg-btn" '+(page<=1?'disabled':'')+' data-go="-1">\u2039 Prev</button>'+
    '<span class="pg-info">Page '+page+' of '+pages+' \u00b7 '+total+' items</span>'+
    '<button class="pg-btn" '+(page>=pages?'disabled':'')+' data-go="1">Next \u203a</button>';
  el.querySelectorAll('.pg-btn').forEach(b=>b.onclick=()=>onGo(+b.dataset.go));
}
function renderProcList(){
  const el=document.getElementById('procList');if(!el)return;
  let rows=PROCS.filter(p=>!PS_.q||p.name.toLowerCase().includes(PS_.q));
  const k=PS_.key,d=PS_.dir;
  rows=rows.slice().sort((a,b)=>k==='name'?d*a.name.localeCompare(b.name,undefined,{sensitivity:'base'}):d*((+a[k]||0)-(+b[k]||0)));
  const SZ=50,pages=Math.max(1,Math.ceil(rows.length/SZ));
  if(PS_.page>pages)PS_.page=pages;
  const slice=rows.slice((PS_.page-1)*SZ,PS_.page*SZ);
  el.innerHTML=slice.map(p=>'<div class="proc-row"><span>'+esc(p.name)+'</span><span>'+esc(String(p.cnt))+'</span><span class="mono">'+esc(String(p.mem))+' MB</span></div>').join('')||'<div style="color:var(--faint);padding:10px 4px">No matches.</div>';
  document.querySelectorAll('.sorth').forEach(hd=>{
    hd.querySelector('.arrow').textContent=hd.dataset.key===PS_.key?(PS_.dir>0?' \u25b2':' \u25bc'):'';
  });
  pager(document.getElementById('procPager'),PS_.page,pages,rows.length,slice.length,g=>{PS_.page+=g;renderProcList();});
}
function renderProgList(){
  const el=document.getElementById('progList');if(!el)return;
  const rows=PROGS_ALL.filter(p=>!PG_.q||p.toLowerCase().includes(PG_.q));
  const SZ=60,pages=Math.max(1,Math.ceil(rows.length/SZ));
  if(PG_.page>pages)PG_.page=pages;
  const slice=rows.slice((PG_.page-1)*SZ,PG_.page*SZ);
  el.innerHTML=slice.map(p=>'<div class="prog-row">'+esc(p)+'</div>').join('')||'<div style="color:var(--faint)">No matches.</div>';
  pager(document.getElementById('progPager'),PG_.page,pages,rows.length,slice.length,g=>{PG_.page+=g;renderProgList();});
}
const HF_={q:'',page:1};
function renderHfList(){
  const el=document.getElementById('hfList');if(!el)return;
  const rows=HOTFIXES.filter(h=>!HF_.q||(h.id+' '+h.desc).toLowerCase().includes(HF_.q));
  const SZ=15,pages=Math.max(1,Math.ceil(rows.length/SZ));
  if(HF_.page>pages)HF_.page=pages;
  const slice=rows.slice((HF_.page-1)*SZ,HF_.page*SZ);
  el.innerHTML=slice.map(h=>'<dt>'+esc(h.date||'')+'</dt><dd>'+esc(h.id)+(h.desc?' <span style="color:var(--faint)">'+esc(h.desc)+'</span>':'')+'</dd>').join('')||'<dd style="color:var(--faint)">No matches.</dd>';
  pager(document.getElementById('hfPager'),HF_.page,pages,rows.length,slice.length,g=>{HF_.page+=g;renderHfList();});
}
function smartProbs(d){
  const probs=[];
  if(d.pf==='1')probs.push('drive predicts its own failure');
  if(d.health&&d.health!=='Healthy')probs.push('health: '+d.health);
  if(+d.rl>0)probs.push(d.rl+' reallocated sectors');
  if(+d.pend>0)probs.push(d.pend+' pending sectors');
  if(+d.unc>0)probs.push(d.unc+' uncorrectable sectors');
  if(+d.crc>0)probs.push(d.crc+' UltraDMA CRC errors');
  if(+d.reu>0)probs.push(d.reu+' uncorrected read errors');
  if(+d.weu>0)probs.push(d.weu+' uncorrected write errors');
  return probs;
}
function openSmartModal(diskNum){
  const d=SMART.find(x=>String(x.disk)===String(diskNum));
  if(!d)return;
  let rows='';
  const add=(l,val)=>{if(val!=='')rows+='<dt>'+l+'</dt><dd>'+esc(val)+'</dd>';};
  add('Health',d.health+(d.op&&d.op!=='OK'?' ('+d.op+')':''));
  add('Temperature',d.temp?d.temp+'\u00b0C'+(d.tmax?' (max '+d.tmax+'\u00b0C)':''):'');
  add('Power-on hours',d.hours);
  add('Wear',d.wear?d.wear+'%':'');
  add('Read errors (uncorrected)',d.reu);
  add('Read errors (corrected)',d.rec);
  add('Write errors (uncorrected)',d.weu);
  add('Write errors (corrected)',d.wec);
  add('Reallocated sectors',d.rl);
  add('Pending sectors',d.pend);
  add('Uncorrectable sectors',d.unc);
  add('UltraDMA CRC errors',d.crc);
  add('Command timeouts',d.cto);
  if(d.pf==='1')rows+='<dt style="color:var(--err)">Failure predicted</dt><dd style="color:var(--err)">Yes (drive self-report)</dd>';
  document.getElementById('smartModalBody').innerHTML=
    '<h2 style="margin:0 0 4px">Disk '+esc(d.disk)+'</h2>'+
    '<div class="sub" style="margin-bottom:16px">'+esc(d.name)+(d.media?' \u00b7 '+esc(d.media):'')+(d.bus?' \u00b7 '+esc(d.bus):'')+'</div>'+
    '<dl class="kv smart-kv">'+rows+'</dl>';
  document.getElementById('smartModal').classList.add('open');
}
function closeSmartModal(){ document.getElementById('smartModal').classList.remove('open'); }
document.getElementById('smartModalClose').onclick=closeSmartModal;
document.getElementById('smartModal').onclick=e=>{ if(e.target.id==='smartModal')closeSmartModal(); };
document.addEventListener('keydown',e=>{ if(e.key==='Escape')closeSmartModal(); });
function friendlyMedia(m){
  const map={ '802.3':'Ethernet (802.3)', 'Native 802.11':'Wi-Fi (802.11)', '802.11':'Wi-Fi (802.11)', 'Bluetooth':'Bluetooth', 'WiMax':'WiMAX', 'Unspecified':'' };
  return map.hasOwnProperty(m)?map[m]:m;
}
function friendlyDriver(gpuName,ver,radeon){
  if(!ver)return '';
  const n=(gpuName||'').toLowerCase();
  if(/nvidia|geforce|quadro|rtx|gtx/.test(n)){
    const digits=ver.replace(/\./g,'');
    if(digits.length>=5){
      const five=digits.slice(-5);
      return five.slice(0,3)+'.'+five.slice(3)+' <span style="color:var(--faint)">('+ver+')</span>';
    }
  }
  if(/\bintel\b|\barc\b|iris|uhd/.test(n)){
    const parts=ver.split('.');
    if(parts.length>=4)return parts[2]+'.'+parts[3]+' <span style="color:var(--faint)">('+ver+')</span>';
  }
  if(/amd|radeon/.test(n)&&radeon){
    return radeon+' <span style="color:var(--faint)">('+ver+')</span>';
  }
  return ver;
}
function specVal(info,key){const f=info.find(([k])=>k===key);return f?f[1]:null;}
function driverAgeLabel(dateStr){
  if(!dateStr)return '';
  const then=new Date(dateStr),now=new Date();
  const months=(now.getFullYear()-then.getFullYear())*12+(now.getMonth()-then.getMonth());
  if(months<12)return '';
  const years=Math.floor(months/12);
  return years>=1?' ('+years+'y old)':'';
}
// Rough average glyph width for Albert Sans / IBM Plex Mono at a given size, used to keep
// GPU/monitor node text inside its box instead of overflowing.
function fitText(text,maxWidth,fontSize,opts){
  opts=opts||{};
  const perChar=fontSize*(opts.mono?0.6:(opts.bold?0.62:0.56));
  if(text.length*perChar<=maxWidth)return esc(text);
  const maxChars=Math.max(1,Math.floor(maxWidth/perChar)-1);
  return esc(text.slice(0,maxChars).trimEnd())+'\u2026';
}
// Wraps onto up to maxLines lines by word, truncating the final line with an ellipsis if
// it still doesn't fit. Used for GPU names, which can run long.
function wrapText(text,maxWidth,fontSize,opts,maxLines){
  opts=opts||{};
  const perChar=fontSize*(opts.mono?0.6:(opts.bold?0.62:0.56));
  const maxChars=Math.max(1,Math.floor(maxWidth/perChar));
  const words=text.split(' ');
  const lines=[];
  let cur='';
  for(const w of words){
    const test=cur?cur+' '+w:w;
    if(test.length<=maxChars||!cur){
      cur=test.length<=maxChars?test:w;
      if(test.length>maxChars&&cur===w){lines.push(cur);cur='';}
    }else{
      lines.push(cur);
      cur=w;
    }
    if(lines.length>=maxLines)break;
  }
  if(cur&&lines.length<maxLines)lines.push(cur);
  if(lines.length>maxLines)lines.length=maxLines;
  const last=lines[lines.length-1]||'';
  if(last.length>maxChars)lines[lines.length-1]=last.slice(0,maxChars-1).trimEnd()+'\u2026';
  return lines.map(l=>esc(l));
}
function realSpec(v){
  if(!v)return '';
  if(/^(system manufacturer|system product name|to be filled by o\.e\.m\.?|default string|not applicable|unknown|n\/a)$/i.test(v.trim()))return '';
  return v;
}
function renderSummary(){
  const sp=parseSpecs(SPECS);
  // pairs/el are now unused - everything that used to populate this curated list moved into the
  // hero tiles above; #specsContent (via renderSpecs, further down) is the remaining "everything
  // else" detail (TPM, Secure Boot, Page File, etc.) that never belonged in the hero.
  // Most of what used to live here (name, manufacturer/model, OS, uptime, CPU, GPU, motherboard,
  // BIOS date, memory) now lives in the hero tiles above instead - kept as plain variables here
  // since the hero-building code further down still needs them, just without a second pairs.push
  // duplicating what the tiles already show.
  const sysMfr=realSpec(specVal(sp.info,'Manufacturer')), sysModel=realSpec(specVal(sp.info,'Model'));
  // On DIY/homebuilt PCs, Win32_ComputerSystemProduct's "Model" is often just the motherboard's
  // own part number restated (e.g. "MS-7C96") - already shown in full on the Motherboard tile.
  // Only treat it as adding something when it doesn't just repeat that.
  const mbForDedupe=specVal(sp.info,'Motherboard')||'';
  const sysModelIsDupe=sysModel && mbForDedupe.toLowerCase().includes(sysModel.toLowerCase());
  const os=specVal(sp.info,'OS'), build=specVal(sp.info,'Build'), up=specVal(sp.info,'System Uptime');
  const WINVER={ '26200':'25H2','26100':'24H2','22631':'23H2','22621':'22H2','22000':'21H2','19045':'22H2','19044':'21H2' };
  const cpu=specVal(sp.info,'CPU Name');
  const mb=specVal(sp.info,'Motherboard'), mbMfr=specVal(sp.info,'Motherboard Manufacturer');
  const bdate=specVal(sp.info,'BIOS Date');
  const bver=specVal(sp.info,'BIOS Version');
  // SourceName is a fixed internal identifier and stays in English regardless of the system's
  // display language - unlike the message text, which is fully localized. Counting by source
  // alone (rather than also requiring the English phrase "faulting application" in the message)
  // means this stays accurate on non-English Windows installs instead of silently reading 0.
  const crashes=events.filter(e=>e.cat==='err'&&e.s==='Application Error').length;
  const shutdowns=events.filter(e=>e.s==='EventLog').length;
  const notes=[];
  notes.push(crashes?dataLink('rel','app-crashes','<span class="r"><b>'+crashes+'</b> Application crash'+(crashes>1?'es':'')+'</span>'):'<span class="g">No application crashes</span>');
  // Unexpected shutdowns: reliability history (6008-derived) and Kernel-Power 41 record the
  // same incident. Report one merged line, using the larger count if they disagree.
  const kp41ev=SYSEVT.filter(r=>String(r.id)==='41');
  const shutdownCount=Math.max(shutdowns,kp41ev.length);
  if(shutdownCount){
    notes.push(dataLink('shutdowns','unexpected-shutdown','<span class="r"><b>'+shutdownCount+'</b> Unexpected shutdown'+(shutdownCount>1?'s':'')+'</span>'));
  }else{
    notes.push('<span class="g">No unexpected shutdowns</span>');
  }
  if(DUMPS.length)notes.push(dataLink('dumps','memory-dump','<span class="y"><b>'+DUMPS.length+'</b> Memory dump'+(DUMPS.length>1?'s':'')+' collected</span> <span style="color:var(--faint)">(in zip)</span>'));
  const wheaFatal=SYSEVT.filter(r=>/WHEA/i.test(r.prov)&&['18','46'].includes(String(r.id))).length;
  if(wheaFatal)notes.push(dataLink('sys','whea','<span class="r"><b>'+wheaFatal+'</b> Fatal hardware error'+(wheaFatal>1?'s':'')+' (WHEA)</span>'));
  SMART.forEach(d=>{
    const probs=smartProbs(d);
    if(probs.length)notes.push(dataLink('drives','disk-smart','<span class="r">Disk '+esc(d.disk)+' ('+esc(d.name)+'): '+esc(probs.join(', '))+'</span>'));
  });
  DIRTY.forEach(v=>notes.push(dataLink('drives','dirty-bit','<span class="y">Volume '+esc(v)+' has its dirty bit set</span>')));
  if(DEVERR.length){
    const devNames=DEVERR.map(e=>e.name);
    const shown=devNames.slice(0,3).join(', ')+(devNames.length>3?' +'+(devNames.length-3)+' more':'');
    notes.push(anchorLink('summary','devErrSection','device-manager-errors','<span class="y"><b>'+DEVERR.length+'</b> device'+(DEVERR.length>1?'s':'')+' showing errors in Device Manager</span> <span style="color:var(--faint)">('+esc(shown)+')</span>'));
  }
  const sysDisk=DISKLAYOUT.find(dk=>dk.partitions.some(p=>p.letter==='C:'));
  if(sysDisk&&sysDisk.style&&sysDisk.style.toUpperCase()==='MBR')notes.push(dataLink('drives','mbr-secureboot','<span class="y">System disk uses MBR partitioning (Secure Boot requires GPT)</span>'));
  if(WINUPDATE&&WINUPDATE.pendingReboot)notes.push(dataLink('updates','pending-reboot','<span class="y">System has a pending reboot (Windows Update or servicing)</span>'));
  if(WINUPDATE&&WINUPDATE.serviceStartType==='Disabled')notes.push(dataLink('updates','wu-service','<span class="y">Windows Update service is disabled</span>'));
  const wuFails=WUHISTORY.filter(u=>u.result==='Failed'||u.result==='Cancelled').length;
  if(wuFails)notes.push(dataLink('updates','wu-failed','<span class="y"><b>'+wuFails+'</b> Windows Update'+(wuFails>1?'s':'')+' did not complete successfully</span>'));
  if(RAM.length){
    // Prefer the speed embedded in the part number over Win32_PhysicalMemory.Speed when it's
    // higher - Speed often just reflects the JEDEC default the stick is currently running at,
    // not what it's actually rated for, which silently hides an XMP/EXPO-off situation.
    const effRated=m=>Math.max(+m.rated||0,+m.pnSpeed||0)||'';
    const slow=RAM.filter(m=>effRated(m)&&m.conf&&+m.conf<+effRated(m));
    if(slow.length)notes.push(dataLink('memory','ram-speed','<span class="y">RAM configured at '+esc(slow[0].conf)+' MT/s, rated '+esc(effRated(slow[0]))+' MT/s</span>'));
  }
  // Known software flags: anti-cheat/kernel drivers, OC & monitoring tools, RGB/peripheral suites, bloatware/PUPs
  const SOFT_FLAGS=[
    {re:/riot vanguard/i,        label:'Riot Vanguard',              grp:'ac'},
    {re:/easy anti-?cheat/i,     label:'Easy Anti-Cheat',            grp:'ac'},
    {re:/battleye/i,             label:'BattlEye',                   grp:'ac'},
    {re:/faceit anti-?cheat|faceit ac/i, label:'FACEIT AC',          grp:'ac'},
    {re:/msi afterburner/i,      label:'MSI Afterburner',            grp:'oc'},
    {re:/rtss|rivatuner/i,       label:'RTSS (RivaTuner Statistics)',grp:'oc'},
    {re:/intel.*extreme tuning|intel\(r\) xtu/i, label:'Intel XTU', grp:'oc'},
    {re:/ryzen master/i,         label:'AMD Ryzen Master',           grp:'oc'},
    {re:/evga precision/i,       label:'EVGA Precision X1/XOC',      grp:'oc'},
    {re:/gpu tweak/i,            label:'ASUS GPU Tweak',             grp:'oc'},
    {re:/firestorm/i,            label:'Zotac Firestorm',            grp:'oc'},
    {re:/sapphire trixx/i,       label:'Sapphire TriXX',             grp:'oc'},
    {re:/aorus engine/i,         label:'Gigabyte AORUS Engine',      grp:'oc'},
    {re:/throttlestop/i,         label:'ThrottleStop',               grp:'oc'},
    {re:/corsair icue/i,         label:'Corsair iCUE',               grp:'periph'},
    {re:/razer synapse/i,        label:'Razer Synapse',              grp:'periph'},
    {re:/(logitech|logi) g ?hub/i, label:'Logitech G HUB',           grp:'periph'},
    {re:/armoury crate/i,        label:'ASUS Armoury Crate',         grp:'periph'},
    {re:/mystic light/i,         label:'MSI Mystic Light',           grp:'periph'},
    {re:/aura sync/i,            label:'ASUS Aura Sync',             grp:'periph'},
    {re:/mcafee/i,               label:'McAfee',                     grp:'bloat'},
    {re:/norton (360|security)/i,label:'Norton 360',                 grp:'bloat'},
    {re:/wildtangent/i,          label:'WildTangent Games',          grp:'bloat'},
    {re:/advanced systemcare|driver booster|iobit/i, label:'IObit utilities', grp:'bloat'},
    {re:/reimage|restoro/i,      label:'Restoro/Reimage',            grp:'bloat'},
    {re:/pc cleaner pro|mycleanpc|pc healthboost|systweak/i, label:'PC "cleaner" utility', grp:'bloat'},
    {re:/driverfix|smart driver care|driver updater/i, label:'Third-party driver updater', grp:'bloat'},
    {re:/driverpack solution/i,  label:'DriverPack Solution',        grp:'bloat'},
    {re:/snappy driver installer/i, label:'Snappy Driver Installer', grp:'bloat'},
    {re:/driver ?easy/i,         label:'Driver Easy',                grp:'bloat'},
    {re:/drivermax/i,            label:'DriverMax',                  grp:'bloat'},
    {re:/avast driver updater|avg driver updater/i, label:'Avast/AVG Driver Updater', grp:'bloat'},
    {re:/auslogics driver updater/i, label:'Auslogics Driver Updater', grp:'bloat'},
    {re:/tweakbit/i,             label:'TweakBit Driver Updater',    grp:'bloat'},
    {re:/nzxt cam/i,             label:'NZXT CAM',                   grp:'periph'},
    {re:/msi dragon center|dragon center/i, label:'MSI Dragon Center', grp:'periph'},
    {re:/nahimic/i,              label:'Nahimic Audio',              grp:'audio'},
    {re:/nvidia geforce experience/i, label:'GeForce Experience',    grp:'audio'},
    {re:/xbox game bar|gaming services/i, label:'Xbox Game Bar',     grp:'audio'},
    {re:/streamlabs/i,           label:'Streamlabs OBS',             grp:'audio'},
    {re:/hola vpn/i,             label:'Hola VPN',                   grp:'net'},
    {re:/killer network|killer control center/i, label:'Killer Network Manager', grp:'net'},
    {re:/translucenttb/i,        label:'TranslucentTB',              grp:'shell'},
    {re:/explorerpatcher/i,      label:'ExplorerPatcher',            grp:'shell'},
    {re:/startallback/i,         label:'StartAllBack',               grp:'shell'},
    {re:/^start11$|stardock start11/i, label:'Start11',              grp:'shell'},
    {re:/open-?shell|classic shell/i, label:'Open-Shell/Classic Shell', grp:'shell'},
    {re:/windhawk/i,             label:'Windhawk',                   grp:'shell'},
    {re:/teamviewer/i,           label:'TeamViewer',                 grp:'remote'},
    {re:/anydesk/i,              label:'AnyDesk',                    grp:'remote'},
    {re:/screenconnect|connectwise control|connectwise screenconnect/i, label:'ScreenConnect', grp:'remote'},
    {re:/splashtop/i,            label:'Splashtop',                  grp:'remote'},
    {re:/logmein/i,              label:'LogMeIn',                    grp:'remote'},
    {re:/rustdesk/i,             label:'RustDesk',                   grp:'remote'},
    {re:/dameware/i,             label:'DameWare',                   grp:'remote'},
    {re:/(tight|ultra|real)?vnc (server|viewer|connect)|^vnc\b/i, label:'VNC', grp:'remote'},
    {re:/nomachine/i,            label:'NoMachine',                  grp:'remote'},
    {re:/gotomypc|gotoassist/i,  label:'GoTo Assist/MyPC',           grp:'remote'},
    {re:/ammyy admin/i,          label:'Ammyy Admin',                grp:'remote'},
    {re:/supremo/i,              label:'Supremo',                    grp:'remote'},
    {re:/zoho assist/i,          label:'Zoho Assist',                grp:'remote'},
    {re:/chrome remote desktop/i,label:'Chrome Remote Desktop',      grp:'remote'},
    // Roblox/game exploit executors - frequently bundled with malware, routinely
    // quarantined or flagged by antivirus/anti-cheat, and a common cause of game bans.
    // Worth calling out even factually, since it explains a lot of "random" AV
    // detections, crashes, or account bans people bring to tech support.
    {re:/jjsploit/i,              label:'JJSploit',                   grp:'cheat'},
    {re:/synapse ?x/i,            label:'Synapse X',                  grp:'cheat'},
    {re:/\bkrnl\b/i,              label:'Krnl',                       grp:'cheat'},
    {re:/fluxus/i,                label:'Fluxus',                     grp:'cheat'},
    {re:/\belectron\b.*executor|electron executor/i, label:'Electron', grp:'cheat'},
    {re:/sentinel executor|sentinel roblox/i, label:'Sentinel',       grp:'cheat'},
    {re:/wave executor/i,         label:'Wave',                       grp:'cheat'},
    {re:/\bcodex\b.*executor|codex executor/i, label:'Codex',         grp:'cheat'},
    {re:/\bevon\b/i,              label:'Evon',                       grp:'cheat'},
    {re:/solara/i,                label:'Solara',                     grp:'cheat'},
    {re:/seliware/i,              label:'Seliware',                   grp:'cheat'},
    {re:/arceus ?x/i,             label:'Arceus X',                   grp:'cheat'},
    {re:/hydrogen executor/i,     label:'Hydrogen',                   grp:'cheat'},
    {re:/cheat engine/i,          label:'Cheat Engine',               grp:'cheat'},
    {re:/wemod/i,                 label:'WeMod',                      grp:'cheat'},
    // Dedicated fan-curve controllers - see the multi-app conflict check below, which
    // also folds in the multi-purpose RGB hubs (iCUE, CAM, etc.) that control fans too.
    {re:/l-?connect/i,            label:'Lian Li L-Connect',          grp:'fan'},
    {re:/^fan ?control$/i,        label:'FanControl',                 grp:'fan'},
    {re:/speedfan/i,              label:'SpeedFan',                   grp:'fan'},
    {re:/argus monitor/i,         label:'Argus Monitor',              grp:'fan'},
    {re:/fan ?xpert/i,            label:'ASUS Fan Xpert',             grp:'fan'},
    {re:/silverstone/i,           label:'SilverStone Fan Control',    grp:'fan'},
    {re:/tt rgb plus/i,           label:'Thermaltake TT RGB Plus',    grp:'fan'},
    {re:/ek loop connect/i,       label:'EK Loop Connect',            grp:'fan'},
    {re:/gigabyte.*(smart ?fan|\bsiv\b)/i, label:'Gigabyte SIV/Smart Fan', grp:'fan'},
  ];
  const foundSoft={};
  (sp.programs||[]).forEach(p=>{
    SOFT_FLAGS.forEach(f=>{ if(f.re.test(p)){ (foundSoft[f.grp]=foundSoft[f.grp]||new Set()).add(f.label); } });
  });
  const softNotes=[];
  if(SECURITY&&SECURITY.avProducts&&SECURITY.avProducts.length){
    const avList=SECURITY.avProducts.filter(a=>a.enabled).map(a=>a.name);
    if(avList.length>1)softNotes.push(dataLink('security','antivirus-conflict','<span class="y">Multiple real-time antivirus products active: '+esc(avList.join(', '))+'</span>'));
  }
  // Fan-curve conflicts: dedicated fan-control tools (grp 'fan') plus the multi-purpose RGB
  // hubs that also drive fan curves (iCUE, CAM, Dragon Center, Armoury Crate) - two or more
  // of these fighting over the same header/fans is a real, common cause of erratic or noisy
  // fan behaviour, so this gets its own elevated check rather than just a plain listing.
  const fanCapablePeriph=['Corsair iCUE','NZXT CAM','MSI Dragon Center','ASUS Armoury Crate'];
  const fanApps=new Set([...(foundSoft.fan||[]), ...[...(foundSoft.periph||[])].filter(n=>fanCapablePeriph.includes(n))]);
  if(fanApps.size>1){
    notes.push(dataLink('apps','software-fancontrol','<span class="y">Multiple fan-control programs active: '+esc([...fanApps].sort().join(', '))+' &mdash; these can fight over the same fan curves and cause erratic or noisy fan behaviour</span>'));
  }
  Object.keys(foundSoft).forEach(grp=>{
    const items=[...foundSoft[grp]].sort().join(', ');
    const SOFT_FAQ={ac:'software-anticheat',oc:'software-overclock',periph:'software-rgb',audio:'software-audio',net:'software-network',bloat:'software-bloatware',shell:'software-shell',cheat:'software-cheat',fan:'software-fancontrol'};
    const GRP_COLOR={cheat:'r'};
    softNotes.push(dataLink('apps',SOFT_FAQ[grp]||'','<span class="'+(GRP_COLOR[grp]||'')+'">'+esc(items)+'</span>'));
  });

  if(SECURITY){
    if(SECURITY.defender&&SECURITY.defender.rtp!=='True')notes.push(dataLink('security','defender-rtp','<span class="r">Windows Defender real-time protection is disabled</span>'));
    if(SECURITY.firewall&&SECURITY.firewall.some(f=>f.enabled!=='True')){
      const off=SECURITY.firewall.filter(f=>f.enabled!=='True').map(f=>f.profile);
      notes.push(dataLink('security','firewall-disabled','<span class="r">Firewall disabled on: '+esc(off.join(', '))+'</span>'));
    }
    if(SECURITY.threats&&SECURITY.threats.length)notes.push(dataLink('security','defender-threats','<span class="r"><b>'+SECURITY.threats.length+'</b> threat detection'+(SECURITY.threats.length>1?'s':'')+' recorded by Windows Defender</span>'));
    if(SECURITY.exclFlags&&SECURITY.exclFlags.length)notes.push(dataLink('security','defender-exclusions','<span class="y"><b>'+SECURITY.exclFlags.length+'</b> risky Defender exclusion'+(SECURITY.exclFlags.length>1?'s':'')+'</span>'));
    if(SECURITY.hostsFlags&&SECURITY.hostsFlags.length)notes.push(dataLink('security','hosts-redirect','<span class="y">Hosts file redirects a known update/security domain</span>'));
    if(SECURITY.startupFlags&&SECURITY.startupFlags.length)notes.push(dataLink('security','startup-flagged','<span class="y"><b>'+SECURITY.startupFlags.length+'</b> flagged startup entr'+(SECURITY.startupFlags.length>1?'ies':'y')+'</span>'));
    if(SECURITY.rdp&&SECURITY.rdp.enabled){
      let extra=[];
      if(SECURITY.rdp.nlaRequired===false)extra.push('Network Level Authentication is <b>off</b>');
      if(SECURITY.acctType)extra.push(esc(SECURITY.acctType));
      notes.push(dataLink('security','rdp-enabled','<span class="y">Remote Desktop (RDP) is enabled'+(extra.length?' &mdash; '+extra.join(', '):'')+'</span>'));
    }
    if(SECURITY.bitlocker&&SECURITY.bitlocker.length){
      const osVol=SECURITY.bitlocker.find(b=>b.type==='OperatingSystem')||SECURITY.bitlocker.find(b=>b.drive==='C:');
      if(osVol&&osVol.status==='On')notes.push(dataLink('security','bitlocker-on','<span class="y">BitLocker is enabled on the system drive &mdash; back up the recovery key before wiping or resetting</span>'));
    }
  }
  const gpuDrvRe=/nvlddmkm|amdwddmg|amdkmdag|atikmdag/i;
  const tdrEvents=SYSEVT.filter(r=>String(r.id)==='4101'||gpuDrvRe.test(r.prov)||gpuDrvRe.test(r.msg||''));
  if(tdrEvents.length){
    const drv=[...new Set(tdrEvents.map(r=>{const m2=(r.prov+' '+(r.msg||'')).match(gpuDrvRe);return m2?m2[0].toLowerCase():null;}).filter(Boolean))];
    notes.push(dataLink('sys','gpu-tdr','<span class="r"><b>'+tdrEvents.length+'</b> display driver timeout/reset event'+(tdrEvents.length>1?'s':'')+(drv.length?' ('+esc(drv.join(', '))+')':'')+'</span>'));
  }
  // SourceName is 'LiveKernelEvent' for these reliability records - a fixed internal identifier,
  // never localized - so matching it directly is safer than matching the word "LiveKernelEvent"
  // inside the (potentially translated) message text.
  const lke=RAW.filter(r=>r.s==='LiveKernelEvent').length;
  if(lke)notes.push(dataLink('rel','livekernelevent','<span class="r"><b>'+lke+'</b> LiveKernelEvent record'+(lke>1?'s':'')+' in reliability history</span>'));
  if(NET&&NET.wifi&&NET.wifi.signal){
    const sig=parseInt(NET.wifi.signal)||0;
    if(sig&&sig<50)notes.push(dataLink('net','wifi-signal','<span class="y">Wi-Fi signal at '+sig+'%'+(NET.wifi.band?' on '+esc(NET.wifi.band):'')+'</span>'));
  }
  if(NET&&NET.adapters){
    NET.adapters.filter(a=>a.gigabitBelowRated).forEach(a=>{
      notes.push(dataLink('net','gigabit-slow','<span class="y">'+esc(a.name)+' is Gigabit-capable but connected at only '+esc(a.speed)+'</span>'));
    });
  }
  if(MEMUSE&&MEMUSE.ct&&MEMUSE.cu/MEMUSE.ct>0.9)notes.push(dataLink('memory','commit-charge','<span class="y">Commit charge at '+Math.round(MEMUSE.cu/MEMUSE.ct*100)+'% of limit at time of capture</span>'));
  // Display connected to the integrated GPU while a dedicated GPU sits unused - the classic
  // "wrong slot" cable mistake. Desktops only: laptops normally route the built-in panel
  // through the iGPU by design, which is correct there, not a mistake.
  if(!ISLAPTOP&&GPUS.length>1){
    const isIGPU=g=>/Intel\(R\)?\s*(UHD|HD|Iris)/i.test(g.name)||/^AMD Radeon(\(TM\))?\s*Graphics$/i.test(g.name.trim());
    const isDGPU=g=>/NVIDIA|GeForce|RTX|GTX|Quadro|Radeon\s*(RX|VII|Pro\s*W)/i.test(g.name);
    const igpu=GPUS.find(isIGPU), dgpu=GPUS.find(isDGPU);
    if(igpu&&dgpu){
      const igpuActive=DISPLAYS.some(d=>d.gpu===igpu.name)||igpu.hres>0;
      const dgpuActive=DISPLAYS.some(d=>d.gpu===dgpu.name)||dgpu.hres>0;
      if(igpuActive&&!dgpuActive)notes.push(dataLink('gpu','wrong-gpu-slot','<span class="y">Display is connected to the integrated GPU ('+esc(igpu.name)+'), not the dedicated GPU ('+esc(dgpu.name)+')</span>'));
    }
  }
  if(WINDOWSOLD&&WINDOWSOLD.present)notes.push(flagLink('windows-old','<span style="color:var(--dim)">Windows.old folder present. Windows was upgraded or reset around '+esc(WINDOWSOLD.date)+'</span>'));
  if(POWERPLAN&&!POWERPLAN.isDefault)notes.push('<span style="color:var(--dim)">Non-default power plan active: '+esc(POWERPLAN.name)+'</span>');
  if(GENFLAGS&&GENFLAGS.tpmDisabled)notes.push(flagLink('tpm','<span style="color:var(--dim)">TPM is present but disabled</span>'));
  if(GENFLAGS&&GENFLAGS.secureBootDisabled)notes.push(dataLink('security','secure-boot','<span style="color:var(--dim)">Secure Boot disabled</span>'));
  if(CBS&&CBS.unresolvedCount>0)notes.push(dataLink('sys','cbs-corruption','<span class="r"><b>'+CBS.unresolvedCount+'</b> unresolved component corruption entr'+(CBS.unresolvedCount>1?'ies':'y')+' in CBS.log</span>'));
  if(up){
    const upDays=parseInt((up.match(/^(\d+)\s*days?/i)||[])[1]||'0',10);
    if(upDays>=7)notes.push(dataLink('sys','high-uptime','<span class="y">System has been running for <b>'+upDays+'</b> days without a restart</span>'));
  }
  const nEl=document.getElementById('notesBody');

  // --- At-a-glance hero: identity strip + spec tiles ---
  // Everything here is a plain fact, nothing flagged or colour-coded - anything worth calling
  // out (RAM under its rated speed, a disk's SMART health, etc.) belongs in General Notes below,
  // not buried in a tile. The status pill is the one exception, and it only ever reflects a
  // count already computed for General Notes, never a new check of its own.
  (function(){
    const heroEl=document.getElementById('summaryHero');
    const tiles=[];
    const cpuCT=specVal(sp.info,'CPU Cores/Threads'), cpuGHz=specVal(sp.info,'CPU Speed'), cpuSocket=specVal(sp.info,'CPU Socket');
    if(cpu){
      const ctm=(cpuCT||'').match(/(\d+)C\s*\/\s*(\d+)T/i);
      tiles.push({cls:'cpu',icon:ICON_CPU,label:'Processor',tab:'cpu',value:cpu.trim(),lines:[
        ctm?ctm[1]+' cores / '+ctm[2]+' threads':'',
        cpuGHz?'Base speed: '+cpuGHz:'',
        cpuSocket?'Socket: '+cpuSocket:''
      ].filter(Boolean)});
    }
    if(GPUS.length||DISPLAYS.length){
      const gNames=[...new Set(GPUS.length?GPUS.map(g=>g.name):DISPLAYS.map(d=>d.gpu))];
      const g0=GPUS[0];
      // friendlyDriver() wraps the friendly number with a parenthetical HTML span showing the raw
      // driver string, meant for the full GPU tab - the hero tile just wants the plain friendly
      // number on its own, since that's the "at a glance" version.
      const driverFriendly=g0&&g0.drv?friendlyDriver(g0.name,g0.drv,g0.radeon).replace(/\s*<span[^>]*>.*<\/span>/,''):'';
      tiles.push({cls:'gpu',icon:ICON_GPU,label:gNames.length>1?'Graphics ('+gNames.length+')':'Graphics',tab:'gpu',value:gNames[0]||'',lines:[
        g0&&g0.vram?g0.vram+' GB VRAM':'',
        driverFriendly?'Driver: '+driverFriendly:''
      ].filter(Boolean)});
    }
    if(RAM.length){
      const heroRamGB=RAM.reduce((a,x)=>a+(+x.cap||0),0);
      const heroRamConf=[...new Set(RAM.map(m=>m.conf).filter(Boolean))].join('/');
      const heroRamRated=[...new Set(RAM.map(m=>Math.max(+m.rated||0,+m.pnSpeed||0)||'').filter(Boolean))].join('/');
      // Only show a brand in the headline value when every stick agrees on one - a mixed-brand
      // kit (or one with no resolved brand) just falls back to plain capacity.
      const ramMfrs=[...new Set(RAM.map(m=>m.mfr).filter(Boolean))];
      const ramMfrLabel=ramMfrs.length===1?ramMfrs[0]:'';
      tiles.push({cls:'ram',icon:ICON_RAM,label:'Memory',tab:'memory',value:heroRamGB+' GB'+(ramMfrLabel?' '+ramMfrLabel:''),lines:[
        heroRamRated?'Rated speed: '+heroRamRated+' MT/s':'',
        heroRamConf?'Configured speed: '+heroRamConf+' MT/s':'',
        'Modules: '+RAM.length
      ].filter(Boolean)});
    }
    if(sp.drives&&sp.drives.length){
      const totalGB=DISKLAYOUT.length?DISKLAYOUT.reduce((a,d)=>a+(+d.sizeGB||0),0):sp.drives.reduce((a,d)=>a+(+d['Total Size (GB)']||0),0);
      const freeGB=sp.drives.reduce((a,d)=>a+(+d['Free Space (GB)']||0),0);
      const fmtSize=gb=>gb>=1000?(gb/1000).toFixed(1)+' TB':Math.round(gb)+' GB';
      const freePct=totalGB?Math.round(freeGB/totalGB*100):null;
      const diskCount=DISKLAYOUT.length||sp.drives.length;
      const winDir=specVal(sp.info,'Windows Directory');
      tiles.push({cls:'storage',icon:ICON_STORAGE,label:diskCount>1?'Storage ('+diskCount+' disks)':'Storage',tab:'drives',value:fmtSize(totalGB)+' total',lines:[
        'Free space: '+fmtSize(freeGB)+(freePct!=null?' ('+freePct+'%)':''),
        winDir?'Windows directory: '+winDir:''
      ].filter(Boolean)});
    }
    if(mb){
      const mbClean=((mbMfr||'').replace(/ASUSTeK COMPUTER INC\./i,'ASUS').replace(/Micro-Star International.*/i,'MSI').replace(/Gigabyte Technology.*/i,'Gigabyte')+' '+mb).trim();
      tiles.push({cls:'mobo',icon:ICON_MOBO,label:'Motherboard',tab:'mobo',value:mbClean,lines:[
        bver?'BIOS: '+bver:'',
        bdate?'Date: '+bdate.replace(/\s+\d{1,2}:\d{2}(:\d{2})?(\s*[AP]M)?$/i,''):''
      ].filter(Boolean)});
    }
    if(os){
      const bMajor=build?build.split('.')[0]:'';
      const fv=WINVER[bMajor];
      const installDate=specVal(sp.info,'Windows Install Date');
      tiles.push({cls:'os',icon:ICON_OS,label:'Windows',tab:'summary',value:os.replace('Microsoft ',''),lines:[
        fv?'Version: '+fv:'',
        build?'Build: '+build:'',
        up?'System uptime: '+up.replace(/ days?/,'d').replace(/ hours?/,'h').replace(/ minutes?/,'m').replace(/,/g,''):'',
        installDate?'Installed on: '+installDate:''
      ].filter(Boolean)});
    }
    if(!tiles.length){heroEl.innerHTML='';return;}

    const critCount=notes.filter(n=>/class="r"/.test(n)).length;
    const warnCount=notes.filter(n=>/class="y"/.test(n)).length;
    const totalFlags=critCount+warnCount;
    const pillCls=totalFlags===0?'ok':(critCount>0?'err':'warn');
    const pillParts=[];
    if(critCount)pillParts.push(critCount+' Critical');
    if(warnCount)pillParts.push(warnCount+' Warning'+(warnCount>1?'s':''));
    const pillText=totalFlags===0?'All clear':pillParts.join(', ');

    // Never fall back to the hostname (System Name) here - people commonly name their PC after
    // themselves (e.g. a literal "Rory-PC"), so showing it risks leaking a real name into a
    // report meant to be safely shareable. When manufacturer/model are the generic BIOS
    // placeholder strings (common on DIY boards), fall back to a plainly generic label instead.
    const titleParts=[sysMfr,(sysModel&&!sysModelIsDupe)?sysModel:''].filter(Boolean);
    const title=titleParts.length?titleParts.join(' '):'System Manufacturer, System Product Name';

    let h='<div class="identity"><div class="identity-left">'+
      '<div class="identity-icon">'+ICON_INFO+'</div>'+
      '<div class="identity-text"><div class="identity-title">'+esc(title)+'</div>'+
      '</div></div>'+
      '<div class="status-pill '+pillCls+'"><span class="status-dot"></span>'+esc(pillText)+'</div></div>';

    h+='<div class="tile-grid">';
    tiles.forEach(t=>{
      h+='<div class="tile c-'+t.cls+'" onclick="return goTab(\''+t.tab+'\')"><div class="tile-head"><div class="tile-icon">'+t.icon+'</div><div class="tile-label">'+esc(t.label)+'</div></div>'+
        '<div class="tile-value">'+esc(t.value)+'</div>'+
        t.lines.map(l=>'<div class="tile-line">'+esc(l)+'</div>').join('')+
        (t.link?'<div class="tile-line"><a href="'+t.link.url+'" target="_blank" rel="noopener" onclick="event.stopPropagation()" style="color:var(--info)">'+esc(t.link.text)+'</a></div>':'')+
        '</div>';
    });
    h+='</div>';
    heroEl.innerHTML=h;
  })();

  const NOTE_GROUPS=[
    {label:'Critical',   items:notes.filter(n=>/class="r"/.test(n))},
    {label:'Warnings',   items:notes.filter(n=>/class="y"/.test(n))},
    {label:'Notable software', items:softNotes},
    {label:'Informational', items:notes.filter(n=>!/class="[ry]"/.test(n)&&!/class="g"/.test(n))},
    {label:'All good',   items:notes.filter(n=>/class="g"/.test(n))},
  ];
  let notesHtml='';
  NOTE_GROUPS.forEach(g=>{
    if(!g.items.length)return;
    notesHtml+='<div class="notes-group"><div class="notes-head">'+g.label+'</div><ul class="notes">'+g.items.map(n=>'<li>'+n+'</li>').join('')+'</ul></div>';
  });
  nEl.innerHTML=notesHtml;
}
function sysCat(lvl){return lvl<=2?'err':lvl===3?'warn':'info';}
function renderSys(){
  const v=document.getElementById('sysView');
  let h='';
  if(!SYSEVT.length){
    h+='<div class="sys-ok">\u2713 No notable system events found in the collection window.</div>';
    v.innerHTML=h;return;
  }
  const evs=SYSEVT.map(r=>({...r,dt:parseDate(r.t)})).filter(r=>r.dt).sort((a,b)=>b.dt-a.dt);
  let lastDay=null;
  evs.forEach(e=>{
    const dk=e.dt.toISOString().slice(0,10);
    if(dk!==lastDay){lastDay=dk;h+='<div class="day-head">'+fmtDay(dk)+'</div>';}
    const cat=sysCat(e.lvl);
    let title=esc(e.prov)+' '+esc(e.id);
    if(e.bc&&e.bc!=='0')title+=' <span class="r" style="color:var(--err)">\u00b7 Bugcheck 0x'+esc(parseInt(e.bc).toString(16).toUpperCase())+'</span>';
    if(e.cnt)title+=' \u00d7'+e.cnt;
    const overheatNote=String(e.id)==='41'?' <span style="color:var(--faint)">(this can also include overheating)</span>':'';
    h+='<div class="row"><span class="time mono">'+fmtTime(e.dt)+'</span>'+
      '<span class="dot d-'+cat+'"></span>'+
      '<span class="title">'+title+'</span>'+
      '<div class="msg mono">'+esc(e.msg||'')+overheatNote+'</div></div>';
  });
  v.innerHTML=h;
  v.querySelectorAll('.row').forEach(r=>r.onclick=(e)=>{ if(e.target.closest('.msg')||hasTextSelection())return; r.classList.toggle('open'); });
  v.querySelectorAll('.row .msg').forEach(m=>m.onclick=e=>e.stopPropagation());
}
function renderShutdowns(){
  const v=document.getElementById('shutdownsView');
  const BC_NAMES={ '278':'VIDEO_TDR_FAILURE','279':'VIDEO_TDR_TIMEOUT_DETECTED','281':'VIDEO_SCHEDULER_INTERNAL_ERROR','321':'VIDEO_ENGINE_TIMEOUT_DETECTED','322':'VIDEO_TDR_APPLICATION_BLOCKED' };
  // Kernel-Power (event 41) carries a bugcheck code when one was recorded; reliability history's
  // 'EventLog' source marks the same kind of incident but never carries a bugcheck, and can reach
  // further back than the System log (which is size-capped). Merge both, preferring the bugcheck
  // when the same incident appears in both.
  const kp41=SYSEVT.filter(r=>String(r.id)==='41').map(r=>{
    const dt=parseDate(r.t);
    const bc=(r.bc&&String(r.bc)!=='0')?String(r.bc):'';
    const pbt=r.pbt?parseDate(r.pbt):null;
    return {d:dt,bc,pbt,src:'Kernel-Power (41)'};
  }).filter(x=>x.d);
  const relOnly=events.filter(e=>e.s==='EventLog').map(e=>({d:e.d,bc:'',pbt:null,src:'Reliability history'}));
  const all=[...kp41,...relOnly].sort((a,b)=>b.d-a.d);
  const merged=[];
  all.forEach(item=>{
    const dup=merged.find(m=>Math.abs(m.d-item.d)<2*60*1000);
    if(dup){
      if(!dup.bc&&item.bc)dup.bc=item.bc;
      if(!dup.pbt&&item.pbt)dup.pbt=item.pbt;
      if(!dup.src.includes(item.src))dup.src+=' + '+item.src;
    }else merged.push({...item});
  });
  if(!merged.length){
    v.innerHTML='<div class="spec-section"><h2>Unexpected Shutdowns</h2><div class="sys-ok">\u2713 No unexpected shutdowns found.</div></div>';
    return;
  }
  let h='<div class="spec-section"><h2>Unexpected Shutdowns ('+merged.length+')</h2>'+
    '<div class="sys-note">A shutdown Windows never got a clean "powering off" signal for &mdash; caused by a crash, power loss, overheating, a hard reset, or a freeze that needed a force restart.</div>'+
    '<dl class="kv">';
  merged.forEach(x=>{
    const bcLabel=x.bc?('0x'+parseInt(x.bc).toString(16).toUpperCase()+(BC_NAMES[x.bc]?' '+BC_NAMES[x.bc]:'')):'';
    let cause;
    if(bcLabel)cause='<span class="r">Bugcheck '+esc(bcLabel)+'</span>';
    else if(x.pbt)cause='<span class="y">Power button held down</span>';
    else cause='<span style="color:var(--faint)">No crash code recorded &mdash; likely a power loss, hard reset, or hang</span>';
    const pbtNote=x.pbt?' <span style="color:var(--faint)">\u00b7 button held at '+esc(fmtTime(x.pbt))+(x.pbt.toISOString().slice(0,10)!==x.d.toISOString().slice(0,10)?' on '+esc(fmtDay(x.pbt.toISOString().slice(0,10))):'')+'</span>':'';
    h+='<dt class="mono" title="Source: '+esc(x.src)+'">'+esc(fmtDay(x.d.toISOString().slice(0,10)))+', '+esc(fmtTime(x.d))+'</dt>'+
      '<dd>'+cause+pbtNote+'</dd>';
  });
  h+='</dl></div>';
  v.innerHTML=h;
}
function renderSecurity(){
  const v=document.getElementById('securityView');
  const sp=parseSpecs(SPECS);
  const tpmStatus=specVal(sp.info,'TPM Status'), tpmVersion=specVal(sp.info,'TPM Version');
  const secureBoot=specVal(sp.info,'Secure Boot State'), uac=specVal(sp.info,'UAC');
  let h='';
  if(tpmStatus||secureBoot||uac){
    h+='<div class="spec-section"><h2>Firmware &amp; account security</h2><dl class="kv">';
    if(tpmStatus)h+='<dt>'+flagLink('tpm','TPM')+'</dt><dd style="color:'+(tpmStatus==='Enabled'?'var(--ok)':'var(--err)')+'">'+esc(tpmStatus)+(tpmVersion?' <span style="color:var(--dim)">('+esc(tpmVersion)+')</span>':'')+'</dd>';
    if(secureBoot)h+='<dt>'+flagLink('secure-boot','Secure Boot')+'</dt><dd style="color:'+(secureBoot==='Enabled'?'var(--ok)':'var(--warn)')+'">'+esc(secureBoot)+'</dd>';
    if(uac)h+='<dt>User Account Control (UAC)</dt><dd style="color:'+(uac==='Enabled'?'var(--ok)':'var(--err)')+'">'+esc(uac)+'</dd>';
    h+='</dl></div>';
  }
  if(!SECURITY){
    if(!h)v.innerHTML='<div class="spec-section"><h2>Security</h2><div style="color:var(--faint)">No security data embedded.</div></div>';
    else v.innerHTML=h;
    return;
  }
  if(SECURITY.avProducts&&SECURITY.avProducts.length){
    h+='<div class="spec-section"><h2>Antivirus</h2><dl class="kv">';
    SECURITY.avProducts.forEach(a=>{
      h+='<dt>'+esc(a.name)+'</dt><dd style="color:'+(a.enabled?'var(--ok)':'var(--dim)')+'">'+(a.enabled?'Active':'Inactive')+'</dd>';
    });
    h+='</dl></div>';
  }
  if(SECURITY.firewallProducts&&SECURITY.firewallProducts.length){
    h+='<div class="spec-section"><h2>Third-party firewall software</h2><dl class="kv">';
    SECURITY.firewallProducts.forEach(a=>{
      h+='<dt>'+esc(a.name)+'</dt><dd style="color:'+(a.enabled?'var(--ok)':'var(--dim)')+'">'+(a.enabled?'Active':'Inactive')+'</dd>';
    });
    h+='</dl></div>';
  }
  const d=SECURITY.defender;
  if(d){
    h+='<div class="spec-section"><h2>Windows Defender</h2><dl class="kv">';
    h+='<dt>Real-time protection</dt><dd style="color:'+(d.rtp==='True'?'var(--ok)':'var(--err)')+'">'+(d.rtp==='True'?'Enabled':'Disabled')+'</dd>';
    if(d.lastQuick)h+='<dt>Last quick scan</dt><dd>'+esc(d.lastQuick)+'</dd>';
    if(d.lastFull)h+='<dt>Last full scan</dt><dd>'+esc(d.lastFull)+'</dd>';
    if(d.sigAge)h+='<dt>Signature age</dt><dd>'+esc(d.sigAge)+' day'+(d.sigAge==='1'?'':'s')+'</dd>';
    if(d.sigVersion)h+='<dt>Security intelligence version</dt><dd class="mono">'+esc(d.sigVersion)+'</dd>';
    h+='</dl></div>';
  }
  if(SECURITY.firewall&&SECURITY.firewall.length){
    h+='<div class="spec-section"><h2>Firewall</h2><dl class="kv">';
    SECURITY.firewall.forEach(f=>{h+='<dt>'+esc(f.profile)+'</dt><dd style="color:'+(f.enabled==='True'?'var(--ok)':'var(--err)')+'">'+(f.enabled==='True'?'Enabled':'Disabled')+'</dd>';});
    h+='</dl></div>';
  }
  if(SECURITY.rdp||SECURITY.acctType){
    h+='<div class="spec-section"><h2>Remote Desktop (RDP)</h2><dl class="kv">';
    if(SECURITY.acctType)h+='<dt>Signed-in account</dt><dd>'+esc(SECURITY.acctType)+'</dd>';
    if(SECURITY.rdp){
      const r=SECURITY.rdp;
      h+='<dt>Status</dt><dd style="color:'+(r.enabled?'var(--warn)':'var(--ok)')+'">'+(r.enabled?'Enabled':'Disabled')+'</dd>';
      if(r.enabled){
        h+='<dt>Service</dt><dd>'+esc(r.serviceStatus)+'</dd>';
        if(r.nlaRequired!==null)h+='<dt>Network Level Authentication</dt><dd style="color:'+(r.nlaRequired?'var(--ok)':'var(--err)')+'">'+(r.nlaRequired?'Required':'Not required')+'</dd>';
      }
    }
    h+='</dl></div>';
  }
  if(SECURITY.bitlocker&&SECURITY.bitlocker.length){
    h+='<div class="spec-section"><h2>BitLocker</h2><dl class="kv">';
    SECURITY.bitlocker.forEach(b=>{
      const on=b.status==='On';
      h+='<dt>'+esc(b.drive||'?')+(b.type?' <span style="color:var(--dim);font-weight:400">('+esc(b.type)+')</span>':'')+'</dt>'+
        '<dd style="color:'+(on?'var(--ok)':'var(--err)')+'">'+(on?'Enabled':'Disabled')+'</dd>';
    });
    h+='</dl></div>';
  }
  if(SECURITY.threats&&SECURITY.threats.length){
    h+='<div class="spec-section"><h2>Threat detections ('+SECURITY.threats.length+')</h2><dl class="kv">';
    SECURITY.threats.forEach(t=>{h+='<dt>'+esc(t.time)+'</dt><dd>'+esc(t.name)+(t.act==='True'?' <span style="color:var(--ok)">(action successful)</span>':' <span style="color:var(--err)">(action failed)</span>')+'</dd>';});
    h+='</dl></div>';
  } else if(d) {
    h+='<div class="spec-section"><h2>Threat detections</h2><div style="color:var(--ok)">\u2713 No threats recorded by Windows Defender.</div></div>';
  }
  if(SECURITY.exclFlags&&SECURITY.exclFlags.length){
    h+='<div class="spec-section"><h2>Defender exclusion alerts</h2><ul class="notes">'+SECURITY.exclFlags.map(f=>'<li><span class="y">'+esc(f)+'</span></li>').join('')+'</ul></div>';
  }
  if(SECURITY.exclusions&&SECURITY.exclusions.length){
    h+='<div class="spec-section"><h2>Defender Exclusions ('+SECURITY.exclusions.length+')</h2><div style="color:var(--dim);font-size:14px;line-height:1.8">'+SECURITY.exclusions.map(esc).join('<br>')+'</div></div>';
  }
  if(SECURITY.hostsFlags&&SECURITY.hostsFlags.length){
    h+='<div class="spec-section"><h2>Hosts file</h2><div style="color:var(--dim);font-size:14px;margin-bottom:8px">'+SECURITY.hostsCustom+' custom entr'+(SECURITY.hostsCustom===1?'y':'ies')+' found.</div><ul class="notes">'+SECURITY.hostsFlags.map(f=>'<li><span class="y">'+esc(f)+'</span></li>').join('')+'</ul></div>';
  } else if(typeof SECURITY.hostsCustom==='number'){
    h+='<div class="spec-section"><h2>Hosts file</h2><div style="color:var(--dim);font-size:14px">'+SECURITY.hostsCustom+' custom entr'+(SECURITY.hostsCustom===1?'y':'ies')+' found, none flagged.</div></div>';
  }
  if(SECURITY.startupFlags&&SECURITY.startupFlags.length){
    h+='<div class="spec-section"><h2>Startup entries flagged</h2><ul class="notes">'+SECURITY.startupFlags.map(f=>'<li><span class="y">'+esc(f)+'</span></li>').join('')+'</ul></div>';
  }
  v.innerHTML=h||'<div class="spec-section"><h2>Security</h2><div style="color:var(--faint)">No security data embedded.</div></div>';
}
function renderGPU(){
  const v=document.getElementById('gpuView');
  if(!GPUS.length && !DISPLAYS.length){
    v.innerHTML='<div class="spec-section"><h2>Graphics</h2><div style="color:var(--faint)">No GPU data embedded.</div></div>';
    return;
  }

  // Official vendor driver pages are stable, well-known download hubs (unlike motherboard vendor
  // support pages, which get restructured often) - no need for the site-scoped search fallback
  // used for BIOS updates.
  const gpuDriverUrl=name=>{
    const n=(name||'').toLowerCase();
    if(/nvidia|geforce|quadro|rtx|gtx/.test(n))return 'https://www.nvidia.com/Download/index.aspx';
    if(/\bamd\b|radeon/.test(n))return 'https://www.amd.com/en/support';
    if(/\bintel\b|\barc\b|iris|uhd/.test(n))return 'https://www.intel.com/content/www/us/en/support/detect.html';
    return null;
  };
  // dxdiag's MonitorName is the generic driver's friendly name, not the panel's actual model -
  // Windows shows "Generic PnP Monitor" here even when it has perfectly good EDID data (which
  // is exactly how Settings > Display gets the real model name to show). Swap in the real
  // name from MONS (read via WmiMonitorID/EDID) wherever dxdiag's name is one of these generic
  // placeholders, consuming MONS entries in order for multi-monitor setups.
  const genericMonRe=/^(generic\s+(pnp|non-pnp|plug\s*and\s*play)\s+monitor|default\s+monitor|pnp\s+monitor)\s*$/i;
  const monsPool=MONS.slice();
  const displays=DISPLAYS.filter(d=>d.gpu&&(d.mon||d.res));
  displays.forEach(d=>{ if(!d.mon||genericMonRe.test(d.mon.trim())){ const real=monsPool.shift(); if(real)d.mon=real; } });
  // Only treat leftover MONS entries as "unidentified displays" when dxdiag gave us nothing
  // to map them against - otherwise they've already been consumed above.
  const unmatchedMons=(!displays.length&&monsPool.length)?monsPool.splice(0):[];

  const byGpu={};
  displays.forEach(d=>{(byGpu[d.gpu]=byGpu[d.gpu]||[]).push(d);});

  // Same wrong-GPU-slot detection used for the Summary tab note: a dedicated GPU sitting
  // unused while the display is actually being driven by the integrated one.
  const isIGPU=g=>/Intel\(R\)?\s*(UHD|HD|Iris)/i.test(g.name)||/^AMD Radeon(\(TM\))?\s*Graphics$/i.test(g.name.trim());
  const isDGPU=g=>/NVIDIA|GeForce|RTX|GTX|Quadro|Radeon\s*(RX|VII|Pro\s*W)/i.test(g.name);
  const igpu=GPUS.find(isIGPU),dgpu=GPUS.find(isDGPU);
  let mismatchActive=null;
  if(igpu&&dgpu){
    const igpuActive=!!byGpu[igpu.name],dgpuActive=!!byGpu[dgpu.name];
    if(igpuActive&&!dgpuActive)mismatchActive='igpu';
  }

  const svgW=680,margin=20,boxGap=20,rowGap=56;
  const idealW=240,minW=160;
  const vramMax=Math.max(1,...GPUS.map(g=>g.vram||0));

  // Lays out n boxes of a shared width in a single centered horizontal row, shrinking
  // below idealW only if they wouldn't otherwise fit within the diagram's width.
  function rowLayout(n){
    if(!n)return {boxW:idealW,x:[]};
    const boxW=Math.min(idealW,Math.max(minW,Math.floor((svgW-2*margin-(n-1)*boxGap)/n)));
    const totalW=n*boxW+(n-1)*boxGap;
    const startX=margin+(svgW-2*margin-totalW)/2;
    const x=Array.from({length:n},(_,i)=>startX+i*(boxW+boxGap));
    return {boxW,x};
  }

  const gpuLayout=rowLayout(GPUS.length);
  const gpuBoxW=gpuLayout.boxW;
  const titleMaxW=gpuBoxW-44-14;
  const gpuInfo=GPUS.map(g=>{
    const titleLines=wrapText(g.name,titleMaxW,14,{bold:true},2);
    const titleBlockEnd=22+(titleLines.length-1)*16;
    const statusY=titleBlockEnd+16;
    const driverY=statusY+20;
    const barY=driverY+10;
    const height=barY+18;
    return {titleLines,statusY,driverY,barY,height};
  });
  const gpuRowY=24;
  const gpuRowH=gpuInfo.length?Math.max(...gpuInfo.map(i=>i.height)):0;

  const monCount=displays.length+unmatchedMons.length;
  const monLayout=rowLayout(monCount);
  const monBoxW=monLayout.boxW;
  const monTitleMaxW=monBoxW-42-14;
  const MON_H=76;
  const monRowY=gpuRowY+gpuRowH+rowGap;
  // Unmatched (EDID-only) monitors share the same row/x-positions as normal ones, just
  // appended after them, since there's no GPU to group them under.
  const monX=monLayout.x.slice(0,displays.length);
  const unmatchedX=monLayout.x.slice(displays.length);

  const svgH=monRowY+MON_H+24;

  let defs='<defs><marker id="gfxDot" viewBox="0 0 10 10" refX="5" refY="5" markerWidth="5" markerHeight="5"><circle cx="5" cy="5" r="4" fill="context-stroke"/></marker></defs>';
  let svg='<svg width="100%" viewBox="0 0 '+svgW+' '+svgH+'" role="img"><title>GPU to display connections</title>'+defs;

  displays.forEach((d,di)=>{
    const gi=GPUS.findIndex(g=>g.name===d.gpu);
    if(gi===-1)return;
    const x1=gpuLayout.x[gi]+gpuBoxW/2,y1=gpuRowY+gpuInfo[gi].height;
    const x2=monX[di]+monBoxW/2,y2=monRowY;
    const isWarn=mismatchActive==='igpu'&&d.gpu===igpu.name;
    const stroke=isWarn?'var(--warn)':'var(--ok)';
    svg+='<line x1="'+x1+'" y1="'+y1+'" x2="'+x2+'" y2="'+y2+'" stroke="'+stroke+'" stroke-width="2" marker-end="url(#gfxDot)"/>';
  });
  if(mismatchActive==='igpu'){
    const gi=GPUS.findIndex(g=>g.name===dgpu.name);
    const x1=gpuLayout.x[gi]+gpuBoxW/2,y1=gpuRowY+gpuInfo[gi].height;
    const x2=monX[0]+monBoxW/2,y2=monRowY;
    svg+='<line x1="'+x1+'" y1="'+y1+'" x2="'+x2+'" y2="'+y2+'" stroke="var(--faint)" stroke-width="1.5" stroke-dasharray="4 5" opacity="0.5"/>';
  }

  GPUS.forEach((g,i)=>{
    const x=gpuLayout.x[i],y=gpuRowY,info=gpuInfo[i];
    const active=!!byGpu[g.name];
    const isWarnNode=mismatchActive==='igpu'&&g.name===igpu.name;
    const stroke=isWarnNode?'var(--warn)':(active?'var(--ok)':'var(--line)');
    const iconColor=isWarnNode?'var(--warn)':(active?'var(--ok)':'var(--faint)');
    const vramPct=g.vram?Math.min(100,Math.round((g.vram/vramMax)*100)):0;
    const statusLabel=isWarnNode?'Wrong port':(active?'Active':'Idle');
    const statusColor=isWarnNode?'var(--warn)':(active?'var(--ok)':'var(--faint)');
    const friendly=g.drv?friendlyDriver(g.name,g.drv,g.radeon||'').replace(/\s*<span[^>]*>.*<\/span>/,''):'';
    const driverStr=(friendly||g.drv||'Driver unknown')+driverAgeLabel(g.driverDate);
    const barW=gpuBoxW-44-60;
    const titleTspans=info.titleLines.map((line,li)=>'<tspan x="'+(x+44)+'" dy="'+(li===0?0:16)+'">'+line+'</tspan>').join('');

    svg+='<g class="gfx-node">'+
      '<rect x="'+x+'" y="'+y+'" width="'+gpuBoxW+'" height="'+info.height+'" rx="12" fill="var(--panel2)" stroke="'+stroke+'" stroke-width="1.25"/>'+
      '<svg x="'+(x+14)+'" y="'+(y+14)+'" width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="'+iconColor+'" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round"><rect x="2" y="7" width="20" height="11" rx="2"/><circle cx="8" cy="12.5" r="2"/><circle cx="15" cy="12.5" r="2"/><line x1="2" y1="10.5" x2="4" y2="10.5"/></svg>'+
      '<text font-size="14" font-weight="600" fill="var(--text)" y="'+(y+22)+'">'+titleTspans+'</text>'+
      '<text x="'+(x+44)+'" y="'+(y+info.statusY)+'" font-size="11.5" font-weight="600" fill="'+statusColor+'">'+statusLabel+'</text>'+
      '<text class="mono" x="'+(x+44)+'" y="'+(y+info.driverY)+'" font-size="11.5" fill="var(--dim)">'+fitText(driverStr,titleMaxW,11.5,{mono:true})+'</text>'+
      '<rect x="'+(x+44)+'" y="'+(y+info.barY)+'" width="'+barW+'" height="6" rx="3" fill="var(--panel)"/>'+
      '<rect x="'+(x+44)+'" y="'+(y+info.barY)+'" width="'+(barW*vramPct/100).toFixed(1)+'" height="6" rx="3" fill="'+iconColor+'" opacity="0.85"/>'+
      '<text class="mono" x="'+(x+gpuBoxW-14)+'" y="'+(y+info.barY+6)+'" font-size="10.5" fill="var(--faint)" text-anchor="end">'+(g.vram?g.vram+'GB':'?')+'</text>'+
      '</g>';
  });

  displays.forEach((d,i)=>{
    const x=monX[i],y=monRowY;
    svg+='<g class="gfx-node">'+
      '<rect x="'+x+'" y="'+y+'" width="'+monBoxW+'" height="'+MON_H+'" rx="12" fill="var(--panel2)" stroke="var(--line)" stroke-width="1.25"/>'+
      '<svg x="'+(x+14)+'" y="'+(y+12)+'" width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="var(--info)" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round"><rect x="2" y="3" width="20" height="14" rx="2" ry="2"/><line x1="8" y1="21" x2="16" y2="21"/><line x1="12" y1="17" x2="12" y2="21"/></svg>'+
      '<text x="'+(x+42)+'" y="'+(y+22)+'" font-size="13.5" font-weight="600" fill="var(--text)">'+fitText(d.mon||'Display',monTitleMaxW,13.5,{bold:true})+'</text>'+
      '<text class="mono" x="'+(x+42)+'" y="'+(y+42)+'" font-size="11" fill="var(--dim)">'+fitText(d.res||'',monTitleMaxW,11,{mono:true})+'</text>'+
      '<text class="mono" x="'+(x+42)+'" y="'+(y+58)+'" font-size="11" fill="var(--dim)">'+fitText(d.hz||'',monTitleMaxW,11,{mono:true})+'</text>'+
      '</g>';
  });

  unmatchedMons.forEach((name,ui)=>{
    const x=unmatchedX[ui],y=monRowY;
    svg+='<g class="gfx-node">'+
      '<rect x="'+x+'" y="'+y+'" width="'+monBoxW+'" height="'+MON_H+'" rx="12" fill="var(--panel2)" stroke="var(--line)" stroke-width="1" stroke-dasharray="4 4" opacity="0.75"/>'+
      '<svg x="'+(x+14)+'" y="'+(y+12)+'" width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="var(--faint)" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round"><rect x="2" y="3" width="20" height="14" rx="2" ry="2"/><line x1="8" y1="21" x2="16" y2="21"/><line x1="12" y1="17" x2="12" y2="21"/></svg>'+
      '<text x="'+(x+42)+'" y="'+(y+22)+'" font-size="13" font-weight="600" fill="var(--dim)">'+fitText(name,monTitleMaxW,13,{bold:true})+'</text>'+
      '<text class="mono" x="'+(x+42)+'" y="'+(y+42)+'" font-size="11" fill="var(--faint)">Detected via EDID, GPU unknown</text>'+
      '</g>';
  });

  svg+='</svg>';

  let h='<div class="spec-section">'+
    '<h2 style="margin:0 0 18px">Graphics</h2>'+svg+
    '<div class="gfx-legend">'+
    '<span><i style="border-color:var(--ok)"></i>active connection</span>'+
    '<span><i class="dash" style="border-color:var(--faint)"></i>idle GPU, no display</span>'+
    '<span><i style="border-color:var(--warn)"></i>active but likely wrong port</span>'+
    '</div>';

  if(mismatchActive==='igpu'){
    h+='<div class="gfx-callout"><svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="var(--warn)" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round"><path d="M12 9v4"/><path d="M12 17h.01"/><path d="M10.3 3.9L2.4 18a1 1 0 0 0 .9 1.5h17.4a1 1 0 0 0 .9-1.5L13.7 3.9a1 1 0 0 0-1.7 0z"/></svg>'+
      '<div>Display is connected to the integrated GPU ('+esc(igpu.name)+'), not the dedicated GPU ('+esc(dgpu.name)+'). Move the monitor cable to the graphics card\'s own ports.</div></div>';
  }

  const driverUrls=GPUS.map(g=>({name:g.name,url:gpuDriverUrl(g.name)})).filter(x=>x.url);
  if(driverUrls.length){
    h+='<div style="margin-top:14px;display:flex;gap:16px;flex-wrap:wrap">'+
      driverUrls.map(x=>'<a href="'+x.url+'" target="_blank" rel="noopener" style="color:var(--info);font-size:13.5px">Check '+esc(x.name)+' drivers</a>').join('')+
      '</div>';
  }

  h+='</div>';
  v.innerHTML=h;
}
function renderMotherboard(){
  const v=document.getElementById('moboView');
  const sp=parseSpecs(SPECS);
  const mb=specVal(sp.info,'Motherboard'), mbMfr=specVal(sp.info,'Motherboard Manufacturer');
  if(!mb){v.innerHTML='<div class="spec-section"><h2>Motherboard</h2><div style="color:var(--faint)">No motherboard data embedded.</div></div>';return;}
  const mbClean=((mbMfr||'').replace(/ASUSTeK COMPUTER INC\./i,'ASUS').replace(/Micro-Star International.*/i,'MSI').replace(/Gigabyte Technology.*/i,'Gigabyte')+' '+mb).trim();
  const bver=specVal(sp.info,'BIOS Version');
  const bdate=specVal(sp.info,'BIOS Date');
  const fastBoot=specVal(sp.info,'Fast Boot State');
  const powerPlan=specVal(sp.info,'Active Power Plan');
  // Vendor support sites are single-page apps that get restructured often (MSI's own
  // "/Search?searchKeyword=" link 404s as of 2026, and ASUS's has since moved behind a region
  // prefix) - hard-coding another guessed URL just sets up the next 404. A site-scoped Google
  // search always lands on the current support page regardless of how the vendor's frontend
  // changes, so every vendor uses that instead of a direct link.
  const vendorSite={asus:'asus.com',msi:'msi.com','micro-star':'msi.com',gigabyte:'gigabyte.com',asrock:'asrock.com'};
  const mfrL=(mbMfr||'').toLowerCase();
  let biosUrl='https://www.google.com/search?q='+encodeURIComponent(mbClean+' bios update download');
  const vendorKey=Object.keys(vendorSite).find(k=>mfrL.includes(k));
  if(vendorKey)biosUrl='https://www.google.com/search?q='+encodeURIComponent('site:'+vendorSite[vendorKey]+' '+mb);
  let h='<div class="spec-section"><h2>Motherboard</h2><div class="drive-grid"><div class="drive"><h3>'+esc(mbClean)+'</h3><dl class="kv smart-kv">'+
    (bver?'<dt>BIOS version</dt><dd>'+esc(bver)+'</dd>':'')+
    (bdate?'<dt>BIOS date</dt><dd>'+esc(bdate.replace(/\s+\d{1,2}:\d{2}(:\d{2})?(\s*[AP]M)?$/i,''))+'</dd>':'')+
    (fastBoot?'<dt>Fast Boot</dt><dd>'+esc(fastBoot)+'</dd>':'')+
    (powerPlan?'<dt>Active power plan</dt><dd>'+esc(powerPlan)+'</dd>':'')+
    '</dl><div style="margin-top:14px"><a href="'+biosUrl+'" target="_blank" rel="noopener" style="color:var(--info)">Check for BIOS updates</a></div></div></div></div>';
  v.innerHTML=h;
}
function renderCPU(){
  const v=document.getElementById('cpuView');
  const sp=parseSpecs(SPECS);
  const cpuName=specVal(sp.info,'CPU Name');
  if(!cpuName){v.innerHTML='<div class="spec-section"><h2>Processor</h2><div style="color:var(--faint)">No processor data embedded.</div></div>';return;}
  const ct=specVal(sp.info,'CPU Cores/Threads'), ctm=(ct||'').match(/(\d+)C\s*\/\s*(\d+)T/i);
  const ghz=specVal(sp.info,'CPU Speed');
  const l2=specVal(sp.info,'CPU L2 Cache'), l3=specVal(sp.info,'CPU L3 Cache');
  const socket=specVal(sp.info,'CPU Socket'), arch=specVal(sp.info,'CPU Architecture');
  const virt=specVal(sp.info,'CPU Virtualization');
  let h='<div class="spec-section"><h2>Processor</h2><div class="drive-grid"><div class="drive"><h3>'+esc(cpuName.trim())+'</h3><dl class="kv smart-kv">'+
    (ctm?'<dt>Cores / Threads</dt><dd>'+ctm[1]+' / '+ctm[2]+'</dd>':'')+
    (ghz?'<dt>Speed</dt><dd>'+esc(ghz)+'</dd>':'')+
    (socket?'<dt>Socket</dt><dd>'+esc(socket)+'</dd>':'')+
    (arch?'<dt>Architecture</dt><dd>'+esc(arch)+'</dd>':'')+
    (l2?'<dt>L2 Cache</dt><dd>'+esc(l2)+'</dd>':'')+
    (l3?'<dt>L3 Cache</dt><dd>'+esc(l3)+'</dd>':'')+
    (virt?'<dt>Virtualization (VT-x/AMD-V)</dt><dd style="color:'+(virt==='Enabled'?'var(--ok)':'var(--warn)')+'">'+esc(virt)+'</dd>':'')+
    '</dl></div></div>';
  if(virt==='Disabled'){
    h+='<div style="color:var(--faint);font-size:13.5px;margin-top:14px">Hardware virtualization is present but disabled in firmware - this is the most common reason Hyper-V, WSL2, or an Android/emulator app fails to start. It\'s enabled in the BIOS/UEFI setup, usually under a CPU or Advanced settings page, often labelled Intel VT-x, AMD-V, or SVM Mode.</div>';
  }
  h+='</div>';
  v.innerHTML=h;
}
function renderMemory(){
  const v=document.getElementById('memoryView');
  const sp=parseSpecs(SPECS);
  const pageFile=specVal(sp.info,'Page File Size');
  let h='';
  if(RAM.length){
    h+='<div class="spec-section"><h2>Memory modules ('+RAM.length+')</h2>';
    if(RAMSLOTS)h+='<div style="color:var(--dim);font-size:14px;margin-bottom:16px">'+RAM.length+' of '+RAMSLOTS+' slots populated'+(RAM.length<RAMSLOTS?' <span style="color:var(--faint)">('+(RAMSLOTS-RAM.length)+' free)</span>':'')+'</div>';
    h+='<div class="drive-grid">';
    RAM.forEach(m=>{
      h+='<div class="drive"><h3>'+esc(m.slot)+'</h3>'+
        '<div class="sub">'+esc(m.mfr||'')+'</div>'+
        '<dl class="kv smart-kv">'+
        '<dt>Part number</dt><dd>'+esc(m.pn||'?')+'</dd>'+
        '<dt>Capacity</dt><dd>'+esc(m.cap)+' GB</dd>'+
        (m.rated?'<dt>Rated speed</dt><dd>'+esc(m.rated)+' MT/s</dd>':'')+
        (m.pnSpeed?'<dt>Speed (from part number)</dt><dd>'+esc(m.pnSpeed)+' MT/s'+(m.rated&&+m.pnSpeed>+m.rated?' <span style="color:var(--faint)">(higher than reported rated speed)</span>':'')+'</dd>':'')+
        (m.conf?'<dt>Configured speed</dt><dd>'+esc(m.conf)+' MT/s</dd>':'')+
        '</dl></div>';
    });
    h+='</div></div>';
  }
  const hasOtherBox=(MEMUSE&&(MEMUSE.avail!=null||MEMUSE.cache!=null||MEMUSE.pagedPool!=null||MEMUSE.nonPagedPool!=null))||pageFile;
  if((MEMUSE&&MEMUSE.pt)||hasOtherBox){
    h+='<div class="spec-section"><h2>Memory usage at capture</h2><div class="drive-grid">';
    if(MEMUSE&&MEMUSE.pt){
      const physPct=Math.round(MEMUSE.pu/MEMUSE.pt*100);
      h+='<div class="drive"><h3>In use (compressed)</h3>'+
        '<div class="meter'+(physPct>85?' low':'')+'"><div style="width:'+Math.min(physPct,100)+'%"></div></div>'+
        '<div class="use mono">'+MEMUSE.pu.toFixed(1)+' GB used of '+MEMUSE.pt.toFixed(1)+' GB ('+physPct+'%)</div></div>';
      if(MEMUSE.ct){
        const commitPct=Math.round(MEMUSE.cu/MEMUSE.ct*100);
        h+='<div class="drive"><h3>Committed</h3>'+
          '<div class="meter'+(commitPct>90?' low':'')+'"><div style="width:'+Math.min(commitPct,100)+'%"></div></div>'+
          '<div class="use mono">'+MEMUSE.cu.toFixed(1)+' GB used of '+MEMUSE.ct.toFixed(1)+' GB ('+commitPct+'%)</div></div>';
      }
    }
    if(hasOtherBox){
      h+='<div class="drive"><h3>Other</h3><dl class="kv smart-kv">'+
        (MEMUSE&&MEMUSE.avail!=null?'<dt>Available</dt><dd>'+MEMUSE.avail.toFixed(1)+' GB</dd>':'')+
        (MEMUSE&&MEMUSE.cache!=null?'<dt>Cached</dt><dd>'+MEMUSE.cache.toFixed(2)+' GB</dd>':'')+
        (MEMUSE&&MEMUSE.pagedPool!=null?'<dt>Paged pool</dt><dd>'+Math.round(MEMUSE.pagedPool)+' MB</dd>':'')+
        (MEMUSE&&MEMUSE.nonPagedPool!=null?'<dt>Non-paged pool</dt><dd>'+Math.round(MEMUSE.nonPagedPool)+' MB</dd>':'')+
        (pageFile?'<dt>Page file size</dt><dd>'+esc(pageFile)+'</dd>':'')+
        '</dl></div>';
    }
    h+='</div></div>';
  }
  v.innerHTML=h||'<div class="spec-section"><h2>Memory</h2><div style="color:var(--faint)">No memory data embedded.</div></div>';
}
function renderBattery(){
  if(!BATTERY.length)return;
  document.getElementById('batteryTab').style.display='';
  const v=document.getElementById('batteryView');
  let h='<div class="spec-section"><h2>Battery health ('+BATTERY.length+')</h2><div class="drive-grid">';
  BATTERY.forEach(b=>{
    h+='<div class="drive"><h3>'+esc(b.name)+'</h3>'+
      (b.chemistry?'<div class="sub">'+esc(b.chemistry)+'</div>':'');
    if(b.healthPct!=null){
      h+='<div class="meter'+(b.healthPct<70?' low':'')+'"><div style="width:'+Math.min(b.healthPct,100)+'%"></div></div>'+
        '<div class="use mono">'+esc(b.healthPct)+'% of original capacity'+(b.healthPct<70?' <span class="y">(significant wear)</span>':'')+'</div>';
    }
    h+='<dl class="kv smart-kv">'+
      (b.designCap?'<dt>Design capacity</dt><dd>'+esc(b.designCap)+' mWh</dd>':'')+
      (b.fullCap?'<dt>Full charge capacity</dt><dd>'+esc(b.fullCap)+' mWh</dd>':'')+
      (b.cycleCount?'<dt>Cycle count</dt><dd>'+esc(b.cycleCount)+'</dd>':'')+
      (b.chargePct!=null?'<dt>Charge at capture</dt><dd>'+esc(b.chargePct)+'%</dd>':'')+
      (b.status?'<dt>Status at capture</dt><dd>'+esc(b.status)+'</dd>':'')+
      '</dl>'+
      (b.healthPct==null?'<div style="color:var(--faint);font-size:13px;margin-top:8px">This hardware doesn\'t report a full-charge capacity, so wear % can\'t be calculated - only the raw status below is available.</div>':'')+
      '</div>';
  });
  h+='</div></div>';
  v.innerHTML=h;
}
function renderNet(){
  const v=document.getElementById('netView');
  if(!NET||(!NET.adapters||!NET.adapters.length)&&!NET.wifi){
    v.innerHTML='<div class="spec-section"><h2>Network adapters</h2><div style="color:var(--faint)">No network data embedded.</div></div>';
    return;
  }
  let h='';
  if(NET.adapters&&NET.adapters.length){
    h+='<div class="spec-section"><h2>Network adapters ('+NET.adapters.length+')</h2><div class="drive-grid">';
    NET.adapters.forEach(a=>{
      const up=/^up$/i.test(a.status);
      const stCol=up?'var(--ok)':/disconnect/i.test(a.status)?'var(--warn)':'var(--faint)';
      h+='<div class="drive"><h3>'+esc(a.name)+'</h3>'+
        '<div class="sub">'+esc(a.desc||'')+'</div>'+
        '<dl class="kv smart-kv">'+
        '<dt>Status</dt><dd style="color:'+stCol+'">'+esc(a.status)+'</dd>'+
        (up&&a.speed?'<dt>Link speed</dt><dd'+(a.gigabitBelowRated?' style="color:var(--warn)"':'')+'>'+esc(a.speed)+(a.gigabitBelowRated?' <span style="color:var(--faint)">(Gigabit-capable)</span>':'')+'</dd>':'')+
        (a.media?'<dt>Media</dt><dd>'+esc(friendlyMedia(a.media))+'</dd>':'')+
        (a.driverVersion?'<dt>Driver version</dt><dd class="mono">'+esc(a.driverVersion)+'</dd>':'')+
        (a.driverDate?'<dt>Driver date</dt><dd>'+esc(a.driverDate)+'</dd>':'')+
        '</dl></div>';
    });
    h+='</div></div>';
  }
  if(NET.vpns&&NET.vpns.length){
    h+='<div class="spec-section"><h2>VPN / virtual adapters ('+NET.vpns.length+')</h2><div class="drive-grid">';
    NET.vpns.forEach(a=>{
      const up=/^up$/i.test(a.status);
      h+='<div class="drive"><h3>'+esc(a.name)+'</h3>'+
        '<div class="sub">'+esc(a.desc||'')+'</div>'+
        '<dl class="kv smart-kv"><dt>Status</dt><dd style="color:'+(up?'var(--ok)':'var(--faint)')+'">'+esc(a.status)+'</dd></dl></div>';
    });
    h+='</div></div>';
  }
  if(NET.wifi&&NET.wifi.signal){
    const w=NET.wifi;
    const sig=parseInt(w.signal)||0;
    h+='<div class="spec-section"><h2>Wi-Fi connection</h2>'+
      '<div class="drive" style="max-width:420px">'+
      '<div class="meter'+(sig<50?' low':'')+'" style="margin-bottom:8px"><div style="width:'+sig+'%"></div></div>'+
      '<dl class="kv smart-kv">'+
      '<dt>Signal</dt><dd>'+esc(w.signal)+'</dd>'+
      (w.band?'<dt>Band</dt><dd>'+esc(w.band)+'</dd>':'')+
      (w.channel?'<dt>Channel</dt><dd>'+esc(w.channel)+(w.width?' ('+esc(w.width)+')':'')+'</dd>':'')+
      (w.radio?'<dt>Radio type</dt><dd>'+esc(w.radio)+'</dd>':'')+
      (w.rx?'<dt>Receive rate</dt><dd>'+esc(w.rx)+' Mbps</dd>':'')+
      (w.tx?'<dt>Transmit rate</dt><dd>'+esc(w.tx)+' Mbps</dd>':'')+
      (w.auth?'<dt>Authentication</dt><dd>'+esc(w.auth)+'</dd>':'')+
      '</dl></div>'+
      '<div style="color:var(--faint);font-size:13.5px;margin-top:10px">SSID, BSSID and IP address are intentionally not collected.</div></div>';
  }
  if(NET.dns&&NET.dns.length){
    h+='<div class="spec-section"><h2>DNS servers</h2><dl class="kv"><dt style="grid-column:1/-1">'+esc(NET.dns.join(', '))+'</dt></dl></div>';
  }
  v.innerHTML=h;
}
function renderDevices(){
  const v=document.getElementById('devicesView');
  let h='';
  if(AUDIO&&(AUDIO.playbackDevices&&AUDIO.playbackDevices.length||AUDIO.recordingDevices&&AUDIO.recordingDevices.length)){
    const isVirtual=n=>/vb-audio|voicemeeter|cable (input|output)|virtual audio/i.test(n);
    const devRow=d=>'<dt style="grid-column:1/-1">'+esc(d.name)+(isVirtual(d.name)?' <span style="color:var(--info)">(virtual)</span>':'')+'</dt>';
    h+='<div class="spec-section"><h2>Audio</h2>';
    if(AUDIO.playbackDevices&&AUDIO.playbackDevices.length){
      h+='<div style="color:var(--faint);font-size:13px;text-transform:uppercase;letter-spacing:.06em;margin:8px 0 4px">Playback (output)</div><dl class="kv">';
      AUDIO.playbackDevices.forEach(d=>{h+=devRow(d);});
      h+='</dl>';
    }
    if(AUDIO.recordingDevices&&AUDIO.recordingDevices.length){
      h+='<div style="color:var(--faint);font-size:13px;text-transform:uppercase;letter-spacing:.06em;margin:12px 0 4px">Recording (input)</div><dl class="kv">';
      AUDIO.recordingDevices.forEach(d=>{h+=devRow(d);});
      h+='</dl>';
    }
    h+='</div>';
  }
  if(CAMERAS&&CAMERAS.length){
    h+='<div class="spec-section"><h2>Webcams &amp; Capture Devices ('+CAMERAS.length+')</h2><dl class="kv">';
    CAMERAS.forEach(c=>{
      const ok=/^ok$/i.test(c.status);
      h+='<dt>'+esc(c.name)+'</dt><dd style="color:'+(ok?'var(--ok)':'var(--warn)')+'">'+esc(c.status||'Unknown')+'</dd>';
    });
    h+='</dl></div>';
  }
  if(USBDEVS&&USBDEVS.length){
    h+='<div class="spec-section"><h2>Peripherals ('+USBDEVS.length+')</h2><dl class="kv">';
    USBDEVS.forEach(u=>{
      h+='<dt style="grid-column:1/-1">'+esc(u.name)+'</dt>';
    });
    h+='</dl></div>';
  }
  if(DEVERR.length){
    h+='<div class="spec-section" id="devErrSection"><h2>Device Manager errors ('+DEVERR.length+')</h2><dl class="kv">';
    const DEVERR_CODES={
      '1':'Device not configured correctly',
      '3':'Driver may be corrupted, or system is low on resources',
      '10':'Device cannot start',
      '12':'Not enough free resources',
      '14':'Device needs a restart to work',
      '18':'Drivers need reinstalling',
      '19':'Registry entries for the device are corrupted',
      '21':'Windows is in the process of removing the device',
      '22':'Device is disabled',
      '24':'Device not present, not working, or missing drivers',
      '28':'Drivers are not installed',
      '29':'Disabled by firmware \u2014 didn\u2019t give the device resources',
      '31':'Windows cannot load the drivers',
      '32':'Driver service is disabled',
      '37':'Driver returned a failure',
      '39':'Driver is missing or corrupted',
      '41':'Driver loaded but can\u2019t find the device',
      '42':'Duplicate device found',
      '43':'Device reported a problem',
      '44':'An application or driver stopped the device',
      '45':'Device not currently connected',
      '48':'A previous driver for this device is blocked from loading',
      '52':'Drivers aren\u2019t digitally signed',
    };
    DEVERR.forEach(e=>{
      const desc=DEVERR_CODES[String(e.code)];
      h+='<dt>'+esc(e.name)+'</dt><dd style="color:var(--err)">Error code '+esc(e.code)+(desc?' <span style="color:var(--faint)">\u2014 '+desc+'</span>':'')+'</dd>';
    });
    h+='</dl></div>';
  }
  if(!h)h='<div class="spec-section"><h2>Connected Devices</h2><div style="color:var(--faint)">No audio, webcam, or USB peripheral data was collected.</div></div>';
  v.innerHTML=h;
}
function renderDumps(){
  if(!DUMPS.length)return;
  document.getElementById('dumpsTab').style.display='';
  let h='<div class="spec-section"><h2>Memory dumps ('+DUMPS.length+')</h2><dl class="kv">';
  DUMPS.forEach(d=>{h+='<dt class="mono">'+esc(d.n)+'</dt><dd>'+esc(d.d)+' \u00b7 '+esc(d.z)+'</dd>';});
  h+='</dl><div style="color:var(--faint);font-size:13px;margin-top:12px">The .dmp files are included in the zip.</div></div>';
  document.getElementById('dumpsView').innerHTML=h;
}
document.querySelectorAll('.tab').forEach(t=>t.onclick=()=>{
  document.querySelectorAll('.tab').forEach(x=>x.classList.toggle('on',x===t));
  document.body.className='tab-'+t.dataset.tab;
  document.getElementById('pageTitleSub').textContent='- '+t.textContent;
});
document.querySelectorAll('.nav-group-title:not(.static)').forEach(g=>g.onclick=()=>{
  g.closest('.nav-group').classList.toggle('collapsed');
});
SPECS_PROGRAMS=SPECS_PROGRAMS=renderSpecs();
load(RAW);
renderSummary();
renderSys();
renderShutdowns();
renderDumps();
renderNet();
renderDevices();
renderGPU();
renderMotherboard();
renderCPU();
renderMemory();
renderBattery();
renderSecurity();
renderAppsList(SPECS_PROGRAMS);
renderProcesses();
renderExtensions();
renderUpdates();
renderFAQ();
document.getElementById('pageFoot').textContent=(GEN?'Generated '+GEN+' · ':'')+'PCHH Triage'+(VER?' v'+VER:'')+' · Author: Rory (ctrl.alt.repeat)';
</script>
</body>
</html>
'@


$dmpfound = $false

$errors = @{
    fileCreate  = $false
    Compress    = $false
    reliability = $false
}

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

function cmark {
    return [char]0x2705
}

function xmark {
    return [char]0x274C
}

function dmpcheck {
    Clear-Host 
    Write-Host ""
    Write-Host "==================================================" -ForegroundColor DarkGreen
    Write-Host "         PCHH Triage v$scriptVersion            " -ForegroundColor Green
    Write-Host "       Developed by Rory (ctrl.alt.repeat)		  " -ForegroundColor DarkGray
    Write-Host "==================================================" -ForegroundColor DarkGreen
    Write-Host ""
    Write-Host "This collects crash logs, specs and diagnostics into" -ForegroundColor Gray
    Write-Host "a single zip on your Desktop. This can take time, please be patient." -ForegroundColor Gray
    Write-Host ""
    Write-Host "[1/3] Collecting system specs.." -ForegroundColor Blue

    # Detect minidumps only - files on the user's PC are never deleted by this script.
    if (Test-Path $minidump) {
        if (Test-Path $source) {
            $script:dmpfound = $true
        }
    }
    
    filecreation
}

function filecreation {
    Remove-Item -Path "$File\*" -Force -Recurse -ErrorAction SilentlyContinue > $null 2>&1

    try {
        New-Item -Path $File -ItemType Directory -Force | Out-Null
        New-Item -Path $infofile -ItemType File -Force | Out-Null
    }
    catch {
        $errors.fileCreate = $true
    }

    fileadd
}

# Grabbing specs & info
function fileadd {

    $secCompat = $false
    $cpu = Get-WmiObject Win32_Processor
    $cpuName = $cpu | Select-Object -ExpandProperty Name
    $gpu = Get-WmiObject Win32_VideoController | Select-Object -ExpandProperty Name
    $compSys = Get-WmiObject Win32_ComputerSystem
    $sysName = $env:COMPUTERNAME
    $sysMfr = $compSys | Select-Object -ExpandProperty Manufacturer
    $sysModel = $compSys | Select-Object -ExpandProperty Model

    if ((Get-Tpm).TpmEnabled -eq "True") {
        $tpmEnabled = "Enabled"
    }
    else {
        $tpmEnabled = "Disabled"
    }

    $tpmSpecParts = "$((Get-CimInstance -Namespace "root\CIMV2\Security\MicrosoftTPM" -ClassName Win32_TPM).SpecVersion)" -split ',' | ForEach-Object { $_.Trim() }
    $tpmVersion = "$($tpmSpecParts[0])"
    if ($tpmVersion -and $tpmVersion -notmatch '\.') { $tpmVersion = "$tpmVersion.0" }
    if ($tpmSpecParts.Count -ge 3 -and $tpmSpecParts[2]) { $tpmVersion = "$tpmVersion (rev $($tpmSpecParts[2]))" }

    $motherboardModel = Get-WmiObject Win32_BaseBoard | Select-Object -ExpandProperty Product
    $motherboardMfr = Get-WmiObject Win32_BaseBoard | Select-Object -ExpandProperty Manufacturer
    $bios = Get-WmiObject Win32_BIOS
    $biosVersion = $bios | Select-Object -ExpandProperty SMBIOSBIOSVersion
    $biosDate = $bios | Select-Object -ExpandProperty ReleaseDate
    $os = Get-WmiObject Win32_OperatingSystem
    $osName = $os | Select-Object -ExpandProperty Caption
    $osVersion = $os | Select-Object -ExpandProperty Version
    $secureBoot = try { Confirm-SecureBootUEFI } catch { $secCompat = $true }
    $fastboot = (Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power" -Name HiberbootEnabled).HiberbootEnabled

    $buildNumber = (Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion").CurrentBuild
    $ubr = (Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion").UBR
    $build = "$buildNumber.$ubr"


    $osInstallDate = try { ([System.Management.ManagementDateTimeConverter]::ToDateTime($os.InstallDate)).ToString("dd'/'MM'/'yyyy") } catch { "" }
    $cpuCores = ($cpu | Select-Object -ExpandProperty NumberOfCores) -join "+"
    $cpuThreads = ($cpu | Select-Object -ExpandProperty ThreadCount) -join "+"
    # WMI's MaxClockSpeed is usually the CPU's rated/base speed, but on some systems it reports
    # the max boost instead - labelled generically as "CPU Speed" rather than "Base Clock" so we
    # aren't overclaiming precision we can't actually guarantee across every chip.
    $cpuSpeedGHz = try { [math]::Round((($cpu | Select-Object -ExpandProperty MaxClockSpeed | Select-Object -First 1) / 1000), 2) } catch { $null }
    # Cache sizes, socket, address width, and firmware virtualization state - all sitting
    # unused on the same Win32_Processor object already queried above. Virtualization support
    # is the one with real diagnostic value: it reflects whether VT-x/AMD-V is actually enabled
    # in firmware right now, not just whether the CPU supports it - the classic reason Hyper-V,
    # WSL2, or an Android emulator refuses to start even on hardware that fully supports it.
    $cpuL2KB = try { $cpu | Select-Object -ExpandProperty L2CacheSize | Select-Object -First 1 } catch { $null }
    $cpuL3KB = try { $cpu | Select-Object -ExpandProperty L3CacheSize | Select-Object -First 1 } catch { $null }
    $cpuSocket = try { $cpu | Select-Object -ExpandProperty SocketDesignation | Select-Object -First 1 } catch { $null }
    $cpuAddressWidth = try { $cpu | Select-Object -ExpandProperty AddressWidth | Select-Object -First 1 } catch { $null }
    $cpuVirtEnabled = try { $cpu | Select-Object -ExpandProperty VirtualizationFirmwareEnabled | Select-Object -First 1 } catch { $null }
    $uacEnabled = try { if ((Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" -ErrorAction Stop).EnableLUA -eq 1) { "Enabled" } else { "Disabled" } } catch { "" }
    $powerPlan = try { if ((powercfg /getactivescheme) -match '\((.+)\)\s*$') { $Matches[1] } else { "" } } catch { "" }

    $lboottime = (Get-CimInstance -ClassName Win32_OperatingSystem).LastBootUpTime
    $uptime = (Get-Date) - $lboottime

    $pgfile = Get-WmiObject -Query "SELECT * FROM Win32_PageFileUsage"
    $pgfilesize = $pgfile.AllocatedBaseSize

    $installedMemory = Get-WmiObject Win32_ComputerSystem | Select-Object -ExpandProperty TotalPhysicalMemory
    $ramSpeed = ((Get-WmiObject Win32_PhysicalMemory | Select-Object -ExpandProperty Speed | Sort-Object -Unique) -join '/')

    $secureBootState = if ($secureBoot -match "True") { "Enabled" } elseif ($secureBoot -match "False") { "Disabled" } elseif ($secCompat -eq "$true") { "Not Supported" }
    $fastbootState = if ($fastboot -eq "1") { "Enabled" } else { "Disabled" }

    # Hostname is deliberately not embedded in the report - people commonly name a PC after
    # themselves (e.g. a literal "Rory-PC"), so it's a real (if easy to overlook) way for a
    # personal name to end up in a report meant to be safely shareable with strangers for
    # tech support.
    specs "Manufacturer: $sysMfr"
    specs "Model: $sysModel"
    specs "`nCPU Name: $cpuName"
    specs "GPU: $gpu"
    specs "`nMotherboard Manufacturer: $motherboardMfr"
    specs "Motherboard: $motherboardModel"
    specs "BIOS Version: $biosVersion"
    specs "BIOS Date: $([System.Management.ManagementDateTimeConverter]::ToDateTime($biosDate))"
    specs "`nOS: $osName"
    specs "OS Version: $osVersion"
    specs "Windows Directory: $env:SystemRoot"
    specs "System Uptime: $($uptime.Days) days, $($uptime.Hours) hours, $($uptime.Minutes) minutes"
    specs "Build: $build"
    specs "`nTPM Status: $tpmEnabled"
    if ($tpmEnabled -eq "Enabled") {
        specs "TPM Version: $tpmVersion"
    }
    specs "Secure Boot State: $secureBootState"
    specs "Fast Boot State: $fastbootState"
    specs "Page File Size: $pgfilesize MB"
    specs "CPU Cores/Threads: ${cpuCores}C / ${cpuThreads}T"
    if ($cpuSpeedGHz) { specs "CPU Speed: ${cpuSpeedGHz} GHz" }
    if ($cpuSocket) { specs "CPU Socket: $cpuSocket" }
    if ($cpuAddressWidth) { specs "CPU Architecture: ${cpuAddressWidth}-bit" }
    if ($cpuL2KB -and $cpuL2KB -gt 0) { specs "CPU L2 Cache: $([math]::Round($cpuL2KB / 1024, 1)) MB" }
    if ($cpuL3KB -and $cpuL3KB -gt 0) { specs "CPU L3 Cache: $([math]::Round($cpuL3KB / 1024, 1)) MB" }
    if ($null -ne $cpuVirtEnabled) { specs "CPU Virtualization: $(if ($cpuVirtEnabled) { 'Enabled' } else { 'Disabled' })" }
    if ($osInstallDate) { specs "Windows Install Date: $osInstallDate" }
    if ($uacEnabled) { specs "UAC: $uacEnabled" }
    if ($powerPlan) { specs "Active Power Plan: $powerPlan" }
    specs "`nRam Capacity: $([math]::Round($installedMemory/1GB)) GB"
    specs "RAM Speed: $ramSpeed MT/s"

    # DriveType=3 is 'Local Fixed Disk' - this excludes network/cloud-sync virtual mounts (like
    # Google Drive's virtual drive letter), removable media, and optical drives, all of which can
    # otherwise show up with misleading or borrowed capacity figures that aren't real storage.
    $drives = Get-WmiObject Win32_LogicalDisk -Filter "DriveType=3" | ForEach-Object {
        $logicalDisk = $_
        $windowsDrive = $logicalDisk.DeviceID.TrimEnd(':')

        $partition = Get-Partition | Where-Object { $_.DriveLetter -eq $windowsDrive }

        $diskNumber = if ($partition) {
            $partition.DiskNumber
        }
        else {
            $null
        }

        $disk = if ($null -ne $diskNumber) {
            Get-Disk -Number $diskNumber
        }

        $physicalDisk = if ($disk) {
            Get-PhysicalDisk | Where-Object { $_.DeviceId -eq $diskNumber }
        }

        $driveType = if ($physicalDisk) { $physicalDisk.MediaType } else { 'Unknown' }
        $operationalStatus = if ($physicalDisk) { $physicalDisk.OperationalStatus } else { 'Unknown' }
        $healthStatus = if ($physicalDisk) { $physicalDisk.HealthStatus } else { 'Unknown' }

        $totalSizeGB = if ($logicalDisk.Size) { [math]::Round($logicalDisk.Size / 1GB, 2) } else { 0 }
        $freeSpaceGB = if ($logicalDisk.FreeSpace) { [math]::Round($logicalDisk.FreeSpace / 1GB, 2) } else { 0 }
        $percentageFree = if ($totalSizeGB -ne 0) {
            [math]::Round(($freeSpaceGB / $totalSizeGB) * 100, 2)
        }
        else {
            'N/A'
        }

        [PSCustomObject]@{
            'Drive Label'         = $logicalDisk.DeviceID
            'Drive Name'          = if (-not [string]::IsNullOrEmpty($logicalDisk.VolumeName)) { $logicalDisk.VolumeName } else { 'No Name Found' }
            'Drive Status'        = "$operationalStatus, $healthStatus"
            'Windows Drive'       = ($logicalDisk.DeviceID -eq "$env:SystemDrive")
            'Drive ID'            = if ($null -ne $diskNumber) { $diskNumber } else { 'Unknown' }
            'Drive Type'          = $driveType
            'Total Size (GB)'     = $totalSizeGB
            'Free Space (GB)'     = $freeSpaceGB
            'Percentage Free (%)' = $percentageFree
        }
    }

    # Win32_LogicalDisk enumerates by drive letter (C, D, E...), which doesn't necessarily match
    # physical disk order - a drive letter on Disk 1 can easily sort before one on Disk 0. Sort by
    # the actual disk number so the Storage tab always reads Disk 0, Disk 1, Disk 2... in order.
    $drives = @($drives | Sort-Object { if ($_.'Drive ID' -is [int]) { $_.'Drive ID' } else { [int]::MaxValue } })

    specs "`n`nDrive Information:`n`n"

    foreach ($drive in $drives) {
        specs "Drive Label: $($drive.'Drive Label')"
        specs "Drive Name: $($drive.'Drive Name')"
        specs "Drive Status: $($drive.'Drive Status')"
        specs "Windows Drive: $($drive.'Windows Drive')"
        specs "Drive ID: $($drive.'Drive ID')"
        specs "Drive Type: $($drive.'Drive Type')"
        specs "Total Size (GB): $($drive.'Total Size (GB)')"
        specs "Free Space (GB): $($drive.'Free Space (GB)')"
        specs "Percentage Free (%): $($drive.'Percentage Free (%)')`n"
    }



    $installedPrograms = Get-ItemProperty HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*,
    HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\* |
    Select-Object DisplayName |
    Where-Object { $null -ne $_.DisplayName }

    $programs = $installedPrograms | Out-String

    specs "`n`nPrograms Installed:`n $programs"
    
    Write-Host -NoNewline -ForegroundColor Green "$(cmark)"
    Write-Host " System specs collected"

    reliabilityexport
}


function specs {
    param (
        [string]$value
    )
    Add-Content -Path $infofile -Value "$value"
}

# Curated System event log entries (crash / hardware / storage / GPU / service failures)
function Get-CuratedSystemEvents {
    $allow = @(
        @{ P = '*Kernel-Power';               I = 41, 137, 142 },
        @{ P = '*WHEA-Logger';                I = 17, 18, 19, 46, 47 },
        @{ P = 'disk';                        I = 7, 51, 153, 154, 157 },
        @{ P = '*stor*';                      I = 129 },
        @{ P = '*Ntfs*';                      I = 55 },
        @{ P = 'volmgr';                      I = 161 },
        @{ P = 'Display';                     I = 4101 },
        @{ P = 'nvlddmkm';                    I = 13, 14 },
        @{ P = 'Service Control Manager';     I = 7034 },
        @{ P = '*MemoryDiagnostics-Results';  I = 1102 },
        @{ P = 'EventLog';                    I = 6008 },
        @{ P = '*WER-SystemErrorReporting';   I = 1001 }
    )
    $ids = @($allow | ForEach-Object { $_.I } | Select-Object -Unique)
    $since = (Get-Date).AddDays(-$lookbackDays)

    # Windows limits FilterHashtable to 23 event IDs per query - chunk the list
    $raw = @()
    for ($i = 0; $i -lt $ids.Count; $i += 20) {
        $chunk = $ids[$i..([Math]::Min($i + 19, $ids.Count - 1))]
        $raw += @(Get-WinEvent -FilterHashtable @{ LogName = 'System'; StartTime = $since; Id = $chunk } -ErrorAction SilentlyContinue)
    }

    $matched = @($raw | Where-Object {
        $ev = $_
        $allow | Where-Object { $ev.ProviderName -like $_.P -and $_.I -contains $ev.Id } | Select-Object -First 1
    })

    # WHEA 17 (corrected PCIe) can flood - summarise to a single record
    $whea17 = @($matched | Where-Object { $_.ProviderName -like '*WHEA-Logger' -and $_.Id -eq 17 })
    $keep   = @($matched | Where-Object { -not ($_.ProviderName -like '*WHEA-Logger' -and $_.Id -eq 17) })

    $out = @($keep | Select-Object -First 400 | ForEach-Object {
        $bc = ''
        $pbt = ''
        if ($_.ProviderName -like '*Kernel-Power' -and $_.Id -eq 41) {
            try {
                $x = [xml]$_.ToXml()
                $bc = "$(($x.Event.EventData.Data | Where-Object { $_.Name -eq 'BugcheckCode' }).'#text')"
                # PowerButtonTimestamp is a FILETIME (100ns intervals since 1601), non-zero only when
                # the power button was physically held for 4+ seconds to force the shutdown - see
                # https://learn.microsoft.com/en-us/archive/technet-wiki/14246.kernel-power-event-id-41
                $pbtRaw = ($x.Event.EventData.Data | Where-Object { $_.Name -eq 'PowerButtonTimestamp' }).'#text'
                if ($pbtRaw -and [long]$pbtRaw -gt 0) {
                    $pbt = ([DateTime]::FromFileTime([long]$pbtRaw)).ToString("dd'/'MM'/'yyyy HH:mm:ss")
                }
            } catch { }
        }
        [PSCustomObject]@{
            t    = $_.TimeCreated.ToString("dd'/'MM'/'yyyy HH:mm:ss")
            prov = ($_.ProviderName -replace '^Microsoft-Windows-', '')
            id   = "$($_.Id)"
            lvl  = [int]$_.Level
            bc   = $bc
            pbt  = $pbt
            msg  = "$($_.Message)"
        }
    })

    if ($whea17.Count -gt 0) {
        $latest = $whea17 | Sort-Object TimeCreated -Descending | Select-Object -First 1
        $out += [PSCustomObject]@{
            t    = $latest.TimeCreated.ToString("dd'/'MM'/'yyyy HH:mm:ss")
            prov = 'WHEA-Logger'
            id   = '17'
            lvl  = 3
            bc   = ''
            cnt  = $whea17.Count
            msg  = "$($whea17.Count) corrected PCIe hardware error(s) recorded in the last $lookbackDays days (summarised)."
        }
    }

    return $out
}

# Exports reliability history + system specs and builds an interactive HTML viewer
function reliabilityexport {
    Write-Host ""
    Write-Host "[2/3] Collecting diagnostics.." -ForegroundColor Blue

        Write-Host "      - Reliability history" -ForegroundColor DarkGray
        $recs = @()
        try {
            $recs = @(Get-CimInstance Win32_ReliabilityRecords -ErrorAction Stop | ForEach-Object {
                [PSCustomObject]@{
                    t = $_.TimeGenerated.ToString("dd'/'MM'/'yyyy HH:mm:ss")
                    s = $_.SourceName
                    e = "$($_.EventIdentifier)"
                    p = $_.ProductName
                    m = $_.Message
                }
            })
            # CSV copy for sharing
            $recs | Export-Csv $reliability_csv_path -NoTypeInformation -Encoding UTF8
        } catch {
            Write-Host "      Could not read reliability history - continuing with the rest of the report." -ForegroundColor Yellow
        }

        # Curated system events for the viewer
        Write-Host "      - Notable system events" -ForegroundColor DarkGray
        $sysEvents = @(Get-CuratedSystemEvents)

        Write-Host "      - Drive S.M.A.R.T data" -ForegroundColor DarkGray
        # Raw ATA SMART attributes (SATA drives; NVMe reports via reliability counters instead)
        $rawSmart = @{}
        $predictFail = @{}
        try {
            $ddMap = @{}
            Get-CimInstance Win32_DiskDrive -ErrorAction Stop | ForEach-Object { $ddMap["$($_.PNPDeviceID)".ToUpper()] = "$($_.Index)" }
            $fpd = @(Get-CimInstance -Namespace root\wmi -ClassName MSStorageDriver_FailurePredictData -ErrorAction Stop)
            foreach ($f in $fpd) {
                $pnp = ("$($f.InstanceName)" -replace '_\d+$', '').ToUpper()
                if (-not $ddMap.ContainsKey($pnp)) { continue }
                $attrs = @{}
                $bytes = $f.VendorSpecific
                for ($i = 0; $i -lt 30; $i++) {
                    $o = 2 + ($i * 12)
                    if ($o + 11 -ge $bytes.Count) { break }
                    $id = [int]$bytes[$o]
                    if ($id -eq 0) { continue }
                    $rawv = [uint64]0
                    for ($j = 0; $j -lt 6; $j++) { $rawv += ([uint64]$bytes[$o + 5 + $j]) -shl (8 * $j) }
                    $attrs[$id] = $rawv
                }
                $rawSmart[$ddMap[$pnp]] = $attrs
            }
            $fps = @(Get-CimInstance -Namespace root\wmi -ClassName MSStorageDriver_FailurePredictStatus -ErrorAction SilentlyContinue)
            foreach ($f in $fps) {
                $pnp = ("$($f.InstanceName)" -replace '_\d+$', '').ToUpper()
                if ($ddMap.ContainsKey($pnp) -and $f.PredictFailure) { $predictFail[$ddMap[$pnp]] = $true }
            }
        } catch { }

        # SMART / drive reliability data (admin required; some drives report partial data)
        $smart = @()
        try {
            $smart = @(Get-PhysicalDisk -ErrorAction Stop | ForEach-Object {
                $pd = $_
                $rc = $null
                try { $rc = $pd | Get-StorageReliabilityCounter -ErrorAction Stop } catch { }
                $ra = $rawSmart["$($pd.DeviceId)"]
                [PSCustomObject]@{
                    name   = "$($pd.FriendlyName)"
                    disk   = "$($pd.DeviceId)"
                    media  = "$($pd.MediaType)"
                    bus    = "$($pd.BusType)"
                    health = "$($pd.HealthStatus)"
                    op     = "$($pd.OperationalStatus)"
                    temp   = if ($null -ne $rc.Temperature -and $rc.Temperature -gt 0) { "$($rc.Temperature)" } else { "" }
                    tmax   = if ($null -ne $rc.TemperatureMax -and $rc.TemperatureMax -gt 0) { "$($rc.TemperatureMax)" } else { "" }
                    hours  = if ($null -ne $rc.PowerOnHours) { "$($rc.PowerOnHours)" } else { "" }
                    wear   = if ($null -ne $rc.Wear) { "$($rc.Wear)" } else { "" }
                    reu    = if ($null -ne $rc.ReadErrorsUncorrected) { "$($rc.ReadErrorsUncorrected)" } else { "" }
                    rec    = if ($null -ne $rc.ReadErrorsCorrected) { "$($rc.ReadErrorsCorrected)" } else { "" }
                    weu    = if ($null -ne $rc.WriteErrorsUncorrected) { "$($rc.WriteErrorsUncorrected)" } else { "" }
                    wec    = if ($null -ne $rc.WriteErrorsCorrected) { "$($rc.WriteErrorsCorrected)" } else { "" }
                    rl     = if ($ra -and $ra.ContainsKey(5))   { "$($ra[5])" }   else { "" }
                    cto    = if ($ra -and $ra.ContainsKey(188)) { "$($ra[188])" } else { "" }
                    pend   = if ($ra -and $ra.ContainsKey(197)) { "$($ra[197])" } else { "" }
                    unc    = if ($ra -and $ra.ContainsKey(198)) { "$($ra[198])" } else { "" }
                    crc    = if ($ra -and $ra.ContainsKey(199)) { "$($ra[199])" } else { "" }
                    pf     = if ($predictFail["$($pd.DeviceId)"]) { "1" } else { "" }
                }
            })
        } catch { }

        # Dirty bit per fixed volume
        $dirtyVols = @()
        try {
            Get-CimInstance Win32_LogicalDisk -Filter "DriveType=3" -ErrorAction Stop | ForEach-Object {
                $dl = $_.DeviceID
                $q = fsutil dirty query $dl 2>$null
                if ("$q" -match 'is Dirty') { $dirtyVols += "$dl" }
            }
        } catch { }

        # Disk layout: partition style (GPT/MBR) and partition -> drive-letter chain per physical disk.
        # Useful for Secure Boot troubleshooting (requires GPT) and spotting a missing/damaged ESP.
        $diskLayout = @()
        try {
            Get-Disk -ErrorAction Stop | ForEach-Object {
                $disk = $_
                $parts = @(Get-Partition -DiskNumber $disk.Number -ErrorAction SilentlyContinue | Sort-Object PartitionNumber | ForEach-Object {
                    $p = $_
                    # MBR type 7 (0x07) just means "NTFS/exFAT/HPFS partition" - it's used by every
                    # NTFS partition on an MBR disk (C:, D:, a hidden recovery partition, all of them),
                    # so it is NOT a reliable recovery indicator on its own and must not be labelled as
                    # such. The real signal for a hidden MBR partition is type+0x10 (23/0x17 for hidden
                    # NTFS), which combined with no drive letter and a small size is what Windows itself
                    # uses for its own WinRE partitions.
                    $sizeGBraw = $p.Size / 1GB
                    $typeLabel = switch -Regex ("$($p.GptType)$($p.MbrType)") {
                        'c12a7328-f81f-11d2-ba4b-00a0c93ec93b' { "EFI System Partition"; break }
                        'e3c9e316-0b5c-4db8-817d-f92df00215ae' { "Microsoft Reserved"; break }
                        'de94bba4-06d1-4d40-a16a-bfd50179d6ac' { "Recovery"; break }
                        '^23$' {
                            if (-not $p.DriveLetter -and $sizeGBraw -lt 10) { "Recovery (MBR)" }
                            elseif ($p.DriveLetter) { "Data" } else { "System" }
                            break
                        }
                        default { if ($p.DriveLetter) { "Data" } else { "System" } }
                    }
                    [PSCustomObject]@{
                        num    = $p.PartitionNumber
                        type   = $typeLabel
                        sizeGB = [math]::Round($p.Size / 1GB, 2)
                        letter = if ($p.DriveLetter) { "$($p.DriveLetter):" } else { "" }
                    }
                })
                $diskLayout += [PSCustomObject]@{
                    disk       = $disk.Number
                    style      = "$($disk.PartitionStyle)"
                    sizeGB     = [math]::Round($disk.Size / 1GB, 1)
                    partitions = $parts
                }
            }
        } catch { }

        # Per-stick RAM info (slots, part numbers, rated vs configured speed)
        # Win32_PhysicalMemory.Manufacturer is unreliable - it identifies the silicon fab (or just
        # says "Unknown"), not the kit brand printed on the box, since brands like G.Skill/Corsair/
        # Kingston/Crucial buy chips and program their own part number into SPD but don't always set
        # the manufacturer string. The part number prefix is usually a much better brand signal.
        $ramBrandByPrefix = @(
            @{ p = 'F[1-5]-';        b = 'G.Skill' },
            @{ p = 'CM[KWTRJUZ]';    b = 'Corsair' },
            @{ p = '(KHX|KF4|KF3|KVR)'; b = 'Kingston / HyperX' },
            @{ p = '(BLS|BLM|CT\d)'; b = 'Crucial' },
            @{ p = '(TLZ|TED4|TF\d|TPD4)'; b = 'Team Group' },
            # Samsung's own module numbering is M3xx (UDIMM/RDIMM) or M4xx (SODIMM), e.g.
            # M378, M391, M393, M471, M472 - the previous pattern (M[3478][45AB]) required a
            # 4/5/A/B as the third character and so never matched any real Samsung part number.
            @{ p = '^M[34]\d{2}';    b = 'Samsung' },
            @{ p = 'HMA|HMT';       b = 'SK Hynix' },
            @{ p = 'MTA|MT\d{2}';  b = 'Micron' },
            @{ p = '^MD\d';          b = 'PNY' },
            @{ p = '^AD4U|^AX4U|^AD5U'; b = 'ADATA' },
            @{ p = '^PSD|^PVS|^PVB'; b = 'Patriot' },
            @{ p = '^99[UA]|^MR[AB]'; b = 'Mushkin' }
        )
        function Resolve-RamBrand($mfr, $pn) {
            if ($mfr -and $mfr -notmatch '^(Unknown|Undefined|To Be Filled|0*)$') { return $mfr }
            foreach ($entry in $ramBrandByPrefix) {
                if ($pn -match $entry.p) { return $entry.b }
            }
            return $mfr
        }
        # Most consumer DDR4/DDR5 part numbers embed the kit's rated speed as a bare 4-digit
        # number (e.g. "MD16GSD43200-SI" -> 3200 MT/s). Win32_PhysicalMemory.Speed is often just
        # the JEDEC default the module happens to be running at, not what it's actually rated
        # for, so this catches XMP/EXPO-off cases that comparing Speed to ConfiguredClockSpeed
        # alone would miss. Matches only against known real DDR speeds (with no leading/trailing
        # digit) to avoid picking up capacity or revision numbers.
        $knownDdrSpeeds = '1600|1866|2133|2400|2666|2800|2933|3000|3200|3466|3600|3733|4000|4133|4266|4400|4600|4800|5200|5333|5600|5800|6000|6400|6800|7200|7600|8000|8400|8800'
        function Resolve-RamSpeedFromPartNumber($pn) {
            if ($pn -match "(?<!\d)($knownDdrSpeeds)(?!\d)") { return $Matches[1] }
            return ""
        }
        $ram = @()
        try {
            $rawRam = @(Get-CimInstance Win32_PhysicalMemory -ErrorAction Stop | ForEach-Object {
                [PSCustomObject]@{
                    slot  = "$($_.DeviceLocator)"
                    mfr   = "$($_.Manufacturer)".Trim()
                    pn    = "$($_.PartNumber)".Trim()
                    cap   = "$([math]::Round($_.Capacity / 1GB))"
                    rated = if ($_.Speed) { "$($_.Speed)" } else { "" }
                    conf  = if ($_.ConfiguredClockSpeed) { "$($_.ConfiguredClockSpeed)" } else { "" }
                }
            })
            # Some boards report an identical, non-unique DeviceLocator for every slot - append a
            # position number in that case so sticks are still visually distinguishable in the report.
            $slotSeen = @{}
            $rawRam | ForEach-Object { $slotSeen[$_.slot] = ($slotSeen[$_.slot] + 1) }
            $slotIndex = @{}
            $ram = @($rawRam | ForEach-Object {
                $mfrResolved = Resolve-RamBrand $_.mfr $_.pn
                $pnSpeed = Resolve-RamSpeedFromPartNumber $_.pn
                $displaySlot = $_.slot
                if ($slotSeen[$_.slot] -gt 1) {
                    $slotIndex[$_.slot] = ($slotIndex[$_.slot] + 1)
                    $displaySlot = "$($_.slot) (position $($slotIndex[$_.slot]))"
                }
                [PSCustomObject]@{
                    slot     = $displaySlot
                    mfr      = $mfrResolved
                    pn       = $_.pn
                    cap      = $_.cap
                    rated    = $_.rated
                    conf     = $_.conf
                    pnSpeed  = $pnSpeed
                }
            })
        } catch { }

        # Total physical RAM slots on the board (populated + empty), via the memory array rather
        # than the modules themselves - tells someone whether they have room to add more RAM
        # without opening the case to count empty slots by eye.
        $ramSlotsTotal = $null
        try {
            $ramSlotsTotal = Get-CimInstance Win32_PhysicalMemoryArray -ErrorAction Stop | Select-Object -First 1 -ExpandProperty MemoryDevices
        } catch { }

        # GPU adapters (name, driver, current mode) and monitor models
        $radeonVer = ""
        try {
            $radeonVer = "$((Get-ItemProperty 'HKLM:\SOFTWARE\AMD\CN' -ErrorAction Stop).RadeonSoftwareVersion)"
        } catch { }
        # Accurate VRAM per adapter - Win32_VideoController's AdapterRAM is a 32-bit field that
        # overflows/wraps on cards with >4GB VRAM (a known, widely-reported Windows bug). The real
        # value lives in the driver's registry key as a 64-bit QWORD.
        $vramByKey = @{}
        try {
            $classRoot = 'HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}'
            Get-ChildItem $classRoot -ErrorAction Stop | Where-Object { $_.PSChildName -match '^\d{4}$' } | ForEach-Object {
                $qw = (Get-ItemProperty -Path $_.PSPath -Name 'HardwareInformation.qwMemorySize' -ErrorAction SilentlyContinue).'HardwareInformation.qwMemorySize'
                $drvDesc = (Get-ItemProperty -Path $_.PSPath -Name 'DriverDesc' -ErrorAction SilentlyContinue).DriverDesc
                if ($qw -and $drvDesc) { $vramByKey[$drvDesc] = $qw }
            }
        } catch { }

        # Custom power plan: compare the active scheme's GUID against Microsoft's small, fixed set
        # of built-in plans, rather than matching the (renameable, localized) friendly name - some
        # tweaking tools clone "Balanced" and keep the name identical, and some legitimate OEM/AMD
        # plans have odd names too, so the GUID is the only reliable signal either way.
        $powerPlanInfo = $null
        try {
            $builtInSchemes = @(
                '381b4222-f694-41f0-9685-ff5bb260df2e', # Balanced
                '8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c', # High performance
                'a1841308-3541-4fab-bc81-f71556f20b4a', # Power saver
                'e9a42b02-d5df-448d-aa00-03f14749eb61'  # Ultimate Performance
            )
            $activeSchemeOut = powercfg /getactivescheme
            if ($activeSchemeOut -match '([0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12})') {
                $activeGuid = $Matches[1].ToLower()
                $planName = if ($activeSchemeOut -match '\((.+)\)\s*$') { $Matches[1] } else { $activeGuid }
                $powerPlanInfo = [PSCustomObject]@{
                    name      = $planName
                    isDefault = [bool]($builtInSchemes -contains $activeGuid)
                }
            }
        } catch { }

        # A small, extensible set of general "worth mentioning" flags - not inherently a problem
        # (unlike the red/yellow findings above), just useful context for a conversation, e.g.
        # Windows 11 eligibility or general security posture.
        $generalFlags = [PSCustomObject]@{
            tpmDisabled         = $false
            secureBootDisabled  = $false
        }
        try {
            $tpmCheck = Get-Tpm -ErrorAction Stop
            if ($tpmCheck.TpmPresent -and -not $tpmCheck.TpmEnabled) { $generalFlags.tpmDisabled = $true }
        } catch { }
        try {
            # Confirm-SecureBootUEFI throws on legacy BIOS/unsupported hardware rather than
            # returning $false - only a hard $false (UEFI present, Secure Boot turned off) counts
            # here, since "not supported" isn't something the user can just switch on.
            if ((Confirm-SecureBootUEFI -ErrorAction Stop) -eq $false) { $generalFlags.secureBootDisabled = $true }
        } catch { }

        # Windows.old: left behind after an in-place upgrade or a "Reset this PC" that kept files.
        # Presence + date is a useful proxy for "this OS install is newer than the hardware", but it's
        # not a reliable way to detect every reset path (a full wipe-and-reinstall leaves no trace here).
        $windowsOld = $null
        try {
            $woPath = "$env:SystemDrive\Windows.old"
            if (Test-Path $woPath -PathType Container) {
                $woDate = (Get-Item $woPath -ErrorAction Stop).LastWriteTime.ToString("dd'/'MM'/'yyyy")
                $windowsOld = [PSCustomObject]@{ present = $true; date = $woDate }
            }
        } catch { }

        # CBS.log: read-only check for unresolved component corruption ("Cannot repair member" is the
        # marker SFC leaves when it found damage it couldn't fix). We don't run a fresh sfc/DISM scan
        # here - that takes minutes - we just read whatever CBS.log already has on disk.
        $cbs = $null
        try {
            $cbsPath = "$env:SystemRoot\Logs\CBS\CBS.log"
            if (Test-Path $cbsPath) {
                $cbsLines = Get-Content -Path $cbsPath -ErrorAction Stop
                $unresolved = @($cbsLines | Select-String -Pattern 'Cannot repair member')
                $lastLine = $cbsLines | Select-Object -Last 1
                $lastDate = $null
                if ($lastLine -match '^(\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2})') {
                    try { $lastDate = [datetime]::ParseExact($matches[1], 'yyyy-MM-dd HH:mm:ss', $null).ToString("dd'/'MM'/'yyyy HH:mm") } catch { }
                }
                $cbs = [PSCustomObject]@{
                    unresolvedCount = $unresolved.Count
                    lastActivity    = $lastDate
                }
            }
        } catch { }

        $hotfixes = @()
        try {
            $hotfixes = @(Get-HotFix -ErrorAction Stop | Where-Object { $_.Description -notmatch 'Security Intelligence Update' -and $_.HotFixID -ne 'KB2267602' } | Sort-Object InstalledOn -Descending | ForEach-Object {
                [PSCustomObject]@{
                    id   = "$($_.HotFixID)"
                    desc = "$($_.Description)"
                    date = if ($_.InstalledOn) { $_.InstalledOn.ToString("dd'/'MM'/'yyyy") } else { "" }
                }
            })
        } catch { }

        Write-Host "      - Windows Update history and pending reboot status (can take a few seconds)" -ForegroundColor DarkGray
        # Pending reboot: several independent flags across Windows can indicate this; any one being set means yes
        $pendingReboot = $false
        try {
            $rebootChecks = @(
                'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending',
                'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired'
            )
            foreach ($rc in $rebootChecks) { if (Test-Path $rc) { $pendingReboot = $true } }
            if (-not $pendingReboot) {
                $pfro = (Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager' -Name 'PendingFileRenameOperations' -ErrorAction SilentlyContinue).PendingFileRenameOperations
                if ($pfro) { $pendingReboot = $true }
            }
        } catch { }

        # Windows Update service status. wuauserv is a Manual/Trigger-Start service by default from
        # Windows 10 onward - it's normal for it to sit "Stopped" when idle and only start when
        # Windows Update actually runs, so a live Status of anything but "Running" is not itself a
        # problem. StartType is the useful signal: "Disabled" means Windows genuinely can't update.
        $wuServiceStatus = ""
        $wuServiceStartType = ""
        try {
            $wuSvc = Get-Service -Name wuauserv -ErrorAction Stop
            $wuServiceStatus = "$($wuSvc.Status)"
            $wuServiceStartType = "$($wuSvc.StartType)"
        } catch { }

        # Recent Windows Update history, including FAILED/pending attempts that Get-HotFix cannot show.
        # Defender's daily "Security Intelligence Update" entries can dominate the most recent history,
        # so pull a wider raw window before filtering them out and capping the final list.
        $wuHistory = @()
        try {
            $session = New-Object -ComObject Microsoft.Update.Session
            $searcher = $session.CreateUpdateSearcher()
            $historyCount = $searcher.GetTotalHistoryCount()
            if ($historyCount -gt 0) {
                $resultMap = @{ 1 = "In progress"; 2 = "Succeeded"; 3 = "Succeeded with errors"; 4 = "Failed"; 5 = "Cancelled" }
                $wuHistory = @($searcher.QueryHistory(0, [Math]::Min($historyCount, 200)) | Where-Object { $_.Title -notmatch 'Security Intelligence Update' } | Select-Object -First 40 | ForEach-Object {
                    [PSCustomObject]@{
                        title  = "$($_.Title)"
                        date   = if ($_.Date) { $_.Date.ToString("dd'/'MM'/'yyyy HH:mm") } else { "" }
                        result = if ($resultMap.ContainsKey([int]$_.ResultCode)) { $resultMap[[int]$_.ResultCode] } else { "Unknown" }
                    }
                } | Sort-Object date -Descending)
            }
        } catch { }

        $devErrors = @()
        try {
            $devErrors = @(Get-CimInstance Win32_PNPEntity -ErrorAction Stop | Where-Object { $_.ConfigManagerErrorCode -ne 0 } | ForEach-Object {
                [PSCustomObject]@{ name = "$($_.Name)"; code = "$($_.ConfigManagerErrorCode)" }
            })
        } catch { }

        # Full audio device list: Windows stores every render (output) and capture (input) endpoint,
        # active or not, under these two documented registry trees. DeviceState is a standard MMDevice
        # API value (1=Active, 2=Disabled, 4=Not present, 8=Unplugged). We don't attempt to mark which
        # one is the "default" - that's set via an undocumented COM interface with no reliable registry
        # read, so mislabelling it would be worse than leaving it out.
        function Get-AudioEndpoints($direction) {
            $out = @()
            try {
                $base = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\MMDevices\Audio\$direction"
                Get-ChildItem -Path $base -ErrorAction Stop | ForEach-Object {
                    $name = $null
                    try {
                        $name = (Get-ItemProperty -Path "$($_.PSPath)\Properties" -Name '{a45c254e-df1c-4efd-8020-67d146a850e0},2' -ErrorAction Stop).'{a45c254e-df1c-4efd-8020-67d146a850e0},2'
                    } catch { }
                    if ($name) {
                        $stateVal = (Get-ItemProperty -Path $_.PSPath -Name 'DeviceState' -ErrorAction SilentlyContinue).DeviceState
                        $state = switch ($stateVal) { 1 {"Active"} 2 {"Disabled"} 4 {"Not present"} 8 {"Unplugged"} default {"Unknown"} }
                        $out += [PSCustomObject]@{ name = "$name"; state = $state }
                    }
                }
            } catch { }
            return $out
        }
        $audio = $null
        try {
            $playbackDevs  = @(Get-AudioEndpoints 'Render'  | Where-Object { $_.state -eq 'Active' })
            $recordingDevs = @(Get-AudioEndpoints 'Capture' | Where-Object { $_.state -eq 'Active' })
            if ($playbackDevs.Count -or $recordingDevs.Count) {
                $audio = [PSCustomObject]@{ playbackDevices = $playbackDevs; recordingDevices = $recordingDevs }
            }
        } catch { }

        # Webcams / capture devices: PNPClass Camera covers modern USB Video Class webcams,
        # Image covers older webcams and scanners/imaging devices. -PresentOnly is the important
        # part here: Win32_PnPEntity has no reliable "still actually plugged in" flag and happily
        # lists devices that were unplugged or removed long ago ("ghost" devices). Get-PnpDevice's
        # -PresentOnly switch is the documented, correct way to filter those out.
        $cameras = @()
        try {
            $camRaw = @(Get-PnpDevice -PresentOnly -Class Camera,Image -ErrorAction Stop)
            $cameras = @($camRaw | Group-Object FriendlyName,Status | ForEach-Object {
                $g = $_.Group[0]
                [PSCustomObject]@{ name = "$($g.FriendlyName)$(if($_.Count -gt 1){" (x$($_.Count))"})"; status = "$($g.Status)" }
            })
        } catch { }

        # Other connected USB peripherals: filtered to actual endpoint devices (mice, keyboards,
        # controllers, capture cards, storage, audio interfaces, etc), excluding hub/composite-parent
        # entries that don't mean anything to a person reading the report, and excluding cameras
        # (shown separately above). Identical repeats (e.g. several HID collections belonging to
        # the same wireless dongle) are collapsed into one line with a count instead of one line each.
        $usbDevices = @()
        try {
            $camNames = @($cameras | ForEach-Object { $_.name -replace ' \(x\d+\)$','' })
            $usbRaw = @(Get-PnpDevice -PresentOnly -ErrorAction Stop | Where-Object {
                $_.InstanceId -like 'USB*' -and
                $_.Class -ne 'USB' -and
                $_.Status -eq 'OK' -and
                $_.Service -notin @('usbhub','USBHUB3','usbccgp','UMB','USBSTOR') -and
                $_.FriendlyName -notin $camNames
            })
            $usbDevices = @($usbRaw | Group-Object FriendlyName | ForEach-Object {
                $g = $_.Group[0]
                [PSCustomObject]@{ name = "$($g.FriendlyName)$(if($_.Count -gt 1){" (x$($_.Count))"})"; status = "$($g.Status)" }
            })
        } catch { }

        # Hardware-accelerated GPU Scheduling (system-wide setting, not per-adapter)
        # Desktop vs laptop: a battery is the simplest reliable signal. This gates the
        # "display on wrong GPU" check below, since laptops normally route the built-in
        # panel through the integrated GPU by design, which isn't a mistake there.
        $isLaptop = $false
        try {
            $batt = Get-CimInstance Win32_Battery -ErrorAction Stop
            if ($batt) { $isLaptop = $true }
        } catch { }

        # Battery health: Win32_Battery only gives current charge % and a coarse status, not
        # the wear that actually matters. The real numbers - design capacity vs. what it can
        # currently hold when full - live in root\wmi, the same data powercfg /batteryreport
        # pulls from, just without needing to parse a report file.
        $batteryInfo = @()
        if ($isLaptop) {
            try {
                $bStatic = @(Get-CimInstance -Namespace root\wmi -ClassName BatteryStaticData -ErrorAction SilentlyContinue)
                $bFull = @(Get-CimInstance -Namespace root\wmi -ClassName BatteryFullChargedCapacity -ErrorAction SilentlyContinue)
                $bCycle = @(Get-CimInstance -Namespace root\wmi -ClassName BatteryCycleCount -ErrorAction SilentlyContinue)
                $chemNames = @{1='Other';2='Unknown';3='Lead Acid';4='Nickel Cadmium';5='Nickel Metal Hydride';6='Lithium-ion';7='Zinc Air';8='Lithium Polymer'}
                $battArr = @($batt)
                for ($i = 0; $i -lt $battArr.Count; $i++) {
                    $w32 = $battArr[$i]
                    $static = $bStatic | Where-Object { $_.InstanceName -eq $w32.DeviceID -or $bStatic.Count -eq $battArr.Count } | Select-Object -Index ([Math]::Min($i, [Math]::Max(0,$bStatic.Count-1)))
                    $full = $bFull | Select-Object -Index ([Math]::Min($i, [Math]::Max(0,$bFull.Count-1)))
                    $cycle = $bCycle | Select-Object -Index ([Math]::Min($i, [Math]::Max(0,$bCycle.Count-1)))
                    $designCap = if ($static -and $static.DesignedCapacity -gt 0) { $static.DesignedCapacity } else { $null }
                    $fullCap = if ($full -and $full.FullChargedCapacity -gt 0) { $full.FullChargedCapacity } else { $null }
                    $healthPct = if ($designCap -and $fullCap) { [Math]::Round(($fullCap / $designCap) * 100, 1) } else { $null }
                    $cycleCount = if ($cycle -and $cycle.CycleCount -gt 0) { $cycle.CycleCount } else { $null }
                    $batteryInfo += [PSCustomObject]@{
                        name       = if ($w32.Name) { $w32.Name } else { "Battery $($i+1)" }
                        chemistry  = if ($chemNames.ContainsKey([int]$w32.Chemistry)) { $chemNames[[int]$w32.Chemistry] } else { $null }
                        chargePct  = $w32.EstimatedChargeRemaining
                        designCap  = $designCap
                        fullCap    = $fullCap
                        healthPct  = $healthPct
                        cycleCount = $cycleCount
                        status     = switch ($w32.BatteryStatus) { 1 {'Discharging'} 2 {'On AC, fully charged'} 3 {'Fully charged'} 4 {'Low'} 5 {'Critical'} 6 {'Charging'} 7 {'Charging, high'} 8 {'Charging, low'} 9 {'Charging, critical'} 10 {'Undefined'} 11 {'Partially charged'} default {$null} }
                    }
                }
            } catch { }
        }

        $hagsEnabled = $null
        try {
            $hw = (Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers' -Name 'HwSchMode' -ErrorAction Stop).HwSchMode
            $hagsEnabled = if ($hw -eq 2) { "Enabled" } else { "Disabled" }
        } catch { }

        $gpus = @()
        try {
            $gpus = @(Get-CimInstance Win32_VideoController -ErrorAction Stop | ForEach-Object {
                $vram = if ($vramByKey.ContainsKey($_.Name)) { $vramByKey[$_.Name] } elseif ($_.AdapterRAM) { $_.AdapterRAM } else { 0 }
                # DriverDate comes back as a CIM_DATETIME string (e.g. "20250815000000.000000+000");
                # convert to a plain ISO date the report's JS can parse with `new Date(...)`.
                $driverDate = ""
                if ($_.DriverDate) {
                    try { $driverDate = ([System.Management.ManagementDateTimeConverter]::ToDateTime($_.DriverDate)).ToString('yyyy-MM-dd') } catch { }
                }
                [PSCustomObject]@{
                    name       = "$($_.Name)"
                    drv        = "$($_.DriverVersion)"
                    driverDate = $driverDate
                    radeon     = if ($_.Name -match 'AMD|Radeon') { $radeonVer } else { "" }
                    hres       = if ($_.CurrentHorizontalResolution) { [int]$_.CurrentHorizontalResolution } else { 0 }
                    vres       = if ($_.CurrentVerticalResolution) { [int]$_.CurrentVerticalResolution } else { 0 }
                    hz         = if ($_.CurrentRefreshRate) { [int]$_.CurrentRefreshRate } else { 0 }
                    vram       = if ($vram) { [math]::Round($vram / 1GB, 1) } else { 0 }
                }
            })
        } catch { }
        $mons = @()
        try {
            $mons = @(Get-CimInstance -Namespace root\wmi -ClassName WmiMonitorID -ErrorAction Stop | ForEach-Object {
                if ($_.UserFriendlyName) {
                    ([System.Text.Encoding]::ASCII.GetString(($_.UserFriendlyName | Where-Object { $_ -ne 0 }))).Trim()
                }
            } | Where-Object { $_ })
        } catch { }

        Write-Host "      - GPU and display info via DXDIAG (this can take up to 30 seconds)" -ForegroundColor DarkGray
        # Per-output display -> GPU mapping via dxdiag (waits up to 30s; falls back to WMI data above)
        $displays = @()
        try {
            $dxPath = "$env:TEMP\pchh_dxdiag.xml"
            Remove-Item $dxPath -Force -ErrorAction SilentlyContinue
            Start-Process dxdiag -ArgumentList "/whql:off", "/x", "`"$dxPath`"" -WindowStyle Hidden
            for ($i = 0; $i -lt 30 -and -not (Test-Path $dxPath); $i++) { Start-Sleep -Seconds 1 }
            Start-Sleep -Seconds 1
            if (Test-Path $dxPath) {
                [xml]$dx = Get-Content $dxPath -Raw
                $displays = @($dx.DxDiag.DisplayDevices.DisplayDevice | ForEach-Object {
                    $mon = "$($_.MonitorName)"
                    if (-not $mon) { $mon = "$($_.MonitorModel)" }
                    # dxdiag's CurrentMode is one string like "2560 x 1440 (32 bit) (144Hz)" -
                    # split into resolution/refresh/bit depth so the report can lay each out
                    # on its own line instead of parsing one long string client-side.
                    $raw = "$($_.CurrentMode)".Trim()
                    $res = $raw; $hz = ""; $bits = ""
                    if ($raw -match '^(.*?)\s*\((\d+) bit\)\s*\((\d+)Hz\)\s*$') {
                        $res = $Matches[1].Trim(); $bits = $Matches[2]; $hz = "$($Matches[3])Hz"
                    }
                    [PSCustomObject]@{
                        gpu  = "$($_.CardName)"
                        mon  = $mon.Trim()
                        res  = $res
                        hz   = $hz
                        bits = $bits
                    }
                } | Where-Object { $_.gpu })
                Remove-Item $dxPath -Force -ErrorAction SilentlyContinue
            }
        } catch { }

        # Running processes grouped by name (top 150 by memory)
        $procs = @()
        try {
            $procs = @(Get-Process -ErrorAction Stop | Group-Object ProcessName | ForEach-Object {
                [PSCustomObject]@{
                    name = $_.Name
                    cnt  = $_.Count
                    mem  = [math]::Round((($_.Group | Measure-Object WorkingSet64 -Sum).Sum) / 1MB)
                }
            } | Sort-Object mem -Descending)
        } catch { }

        Write-Host "      - Security (Defender status, exclusions, hosts file, startup, browser extensions)" -ForegroundColor DarkGray
        $security = $null
        try {
            # Defender status + scan history
            $mpStatus = $null
            try { $mpStatus = Get-MpComputerStatus -ErrorAction Stop } catch { }
            $defender = if ($mpStatus) {
                [PSCustomObject]@{
                    rtp        = "$($mpStatus.RealTimeProtectionEnabled)"
                    lastQuick  = if ($mpStatus.QuickScanEndTime) { $mpStatus.QuickScanEndTime.ToString("dd'/'MM'/'yyyy HH:mm") } else { "" }
                    lastFull   = if ($mpStatus.FullScanEndTime) { $mpStatus.FullScanEndTime.ToString("dd'/'MM'/'yyyy HH:mm") } else { "" }
                    sigAge     = "$($mpStatus.AntivirusSignatureAge)"
                    sigVersion = "$($mpStatus.AntivirusSignatureVersion)"
                }
            } else { $null }

            # Registered antivirus products (Windows Security Center) - name + real-time enabled state
            $avProducts = @()
            try {
                $avProducts = @(Get-CimInstance -Namespace root/SecurityCenter2 -ClassName AntiVirusProduct -ErrorAction Stop | ForEach-Object {
                    # productState is a bitmask; the middle byte's low nibble indicates enabled/disabled
                    $stateHex = "{0:X6}" -f [int]$_.productState
                    $enabled = $stateHex.Substring(2,2) -in @('10','11')
                    [PSCustomObject]@{ name = "$($_.displayName)"; enabled = $enabled }
                })
            } catch { }

            # Third-party firewall products, same Security Center namespace as the AV check above -
            # mainly useful for spotting a leftover firewall product (uninstalled security suites
            # sometimes leave their firewall driver registered and blocking traffic behind).
            $firewallProducts = @()
            try {
                $firewallProducts = @(Get-CimInstance -Namespace root/SecurityCenter2 -ClassName FirewallProduct -ErrorAction Stop | ForEach-Object {
                    $stateHex = "{0:X6}" -f [int]$_.productState
                    $enabled = $stateHex.Substring(2,2) -in @('10','11')
                    [PSCustomObject]@{ name = "$($_.displayName)"; enabled = $enabled }
                })
            } catch { }

            $threats = @()
            try {
                $threats = @(Get-MpThreatDetection -ErrorAction Stop | Select-Object -First 25 | ForEach-Object {
                    [PSCustomObject]@{
                        name = "$($_.ThreatName)"
                        time = $_.InitialDetectionTime.ToString("dd'/'MM'/'yyyy HH:mm")
                        act  = "$($_.ActionSuccess)"
                    }
                })
            } catch { }

            # Exclusions with dangerous-pattern flagging (paths genericized to strip username)
            $genericize = { param($p) if ("$p") { "$p" -replace [regex]::Escape("$env:USERPROFILE"), "%USERPROFILE%" -replace 'C:\\Users\\[^\\]+', "C:\Users\<user>" } else { "$p" } }
            $exclusions = @()
            $exclFlags = @()
            try {
                $mpPref = Get-MpPreference -ErrorAction Stop
                foreach ($p in $mpPref.ExclusionPath) {
                    $g = & $genericize $p
                    $exclusions += "Path: $g"
                    if ($p -match '^[A-Za-z]:\\?$') { $exclFlags += "Entire drive excluded: $g" }
                    elseif ($p -match '\\(Temp|AppData\\Roaming)\\?$') { $exclFlags += "Broad system folder excluded: $g" }
                }
                foreach ($e in $mpPref.ExclusionExtension) {
                    $exclusions += "Extension: .$e"
                    if ($e -match '^(exe|dll|scr|bat|ps1)$') { $exclFlags += "Executable file type excluded: .$e" }
                }
                foreach ($pr in $mpPref.ExclusionProcess) { $exclusions += "Process: $(& $genericize $pr)" }
            } catch { }

            # Hosts file: count custom entries, flag known-domain redirects
            $hostsCustom = 0
            $hostsFlags = @()
            try {
                $hostsPath = "$env:SystemRoot\System32\drivers\etc\hosts"
                $watchDomains = 'windowsupdate\.microsoft\.com|update\.microsoft\.com|\.microsoft\.com$|malwarebytes\.com|windowsdefender|virustotal\.com|avast\.com|kaspersky\.com|mcafee\.com|norton\.com'
                Get-Content $hostsPath -ErrorAction Stop | ForEach-Object {
                    $line = $_.Trim()
                    if ($line -and -not $line.StartsWith('#')) {
                        $hostsCustom++
                        if ($line -match $watchDomains -and $line -notmatch '^\s*(0\.0\.0\.0|127\.0\.0\.1)\s') {
                            $hostsFlags += $line
                        } elseif ($line -match $watchDomains) {
                            $hostsFlags += "$line (redirected to loopback/null - likely intentional block)"
                        }
                    }
                }
            } catch { }

            # Suspicious startup entries: no publisher/signature, or launching from Temp/AppData with odd naming
            $startupFlags = @()
            function Test-SuspiciousStartupExe($exePath) {
                if ($exePath -match '\\(Temp|AppData\\Local\\Temp)\\') { return @{ Suspicious = $true; Reason = "runs from Temp folder" } }
                if (Test-Path $exePath -ErrorAction SilentlyContinue) {
                    try {
                        $sig = Get-AuthenticodeSignature -FilePath $exePath -ErrorAction Stop
                        if ($sig.Status -ne 'Valid') { return @{ Suspicious = $true; Reason = "unsigned or invalid signature" } }
                    } catch { }
                }
                return @{ Suspicious = $false; Reason = "" }
            }
            try {
                $runKeys = @(
                    'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run',
                    'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run'
                )
                foreach ($rk in $runKeys) {
                    if (Test-Path $rk) {
                        $props = Get-ItemProperty -Path $rk -ErrorAction SilentlyContinue
                        $props.PSObject.Properties | Where-Object { $_.Name -notmatch '^PS' } | ForEach-Object {
                            $val = "$($_.Value)"
                            $exePath = ($val -replace '^"?([^"]+\.exe)"?.*$', '$1')
                            $check = Test-SuspiciousStartupExe $exePath
                            if ($check.Suspicious) { $startupFlags += "$($_.Name): $($check.Reason)" }
                        }
                    }
                }
            } catch { }

            # Firewall status per profile
            $firewall = @()
            try {
                $firewall = @(Get-NetFirewallProfile -ErrorAction Stop | ForEach-Object {
                    [PSCustomObject]@{ profile = "$($_.Name)"; enabled = "$($_.Enabled)" }
                })
            } catch { }

            # RDP (Remote Desktop) status: registry setting + listening service
            $rdp = $null
            try {
                $deny = (Get-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server' -Name fDenyTSConnections -ErrorAction Stop).fDenyTSConnections
                $enabled = ($deny -eq 0)
                $svc = Get-Service -Name TermService -ErrorAction SilentlyContinue
                $nla = $null
                try {
                    $nla = (Get-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp' -Name UserAuthentication -ErrorAction Stop).UserAuthentication
                } catch { }
                $rdp = [PSCustomObject]@{
                    enabled       = $enabled
                    serviceStatus = if ($svc) { "$($svc.Status)" } else { "Unknown" }
                    nlaRequired   = if ($null -ne $nla) { ($nla -eq 1) } else { $null }
                }
            } catch { }

            # Signed-in account type: Microsoft account, Domain-joined, or Local
            $acctType = $null
            try {
                $curSid = ([System.Security.Principal.WindowsIdentity]::GetCurrent()).User.Value
                if ($curSid -match '^S-1-12-1-') {
                    $acctType = "Microsoft / Entra ID account"
                } else {
                    $cs = Get-CimInstance Win32_ComputerSystem -ErrorAction Stop
                    $acctType = if ($cs.PartOfDomain) { "Domain account" } else { "Local account" }
                }
            } catch { }

            # Scheduled Tasks: user-created, non-Microsoft, enabled - flag unsigned/Temp-run actions
            try {
                $tasks = Get-ScheduledTask -ErrorAction Stop | Where-Object {
                    $_.State -ne 'Disabled' -and $_.TaskPath -notmatch '\\Microsoft\\' -and $_.TaskPath -notmatch '\\Windows\\'
                }
                foreach ($t in $tasks) {
                    $act = ($t.Actions | Where-Object { $_.Execute } | Select-Object -First 1).Execute
                    if (-not $act) { continue }
                    $exePath = $act -replace '^"?([^"]+)"?.*$', '$1'
                    $check = Test-SuspiciousStartupExe $exePath
                    if ($check.Suspicious) { $startupFlags += "Scheduled task '$($t.TaskName)': $($check.Reason)" }
                }
            } catch { }

            # Startup folder shortcuts (both all-users and current user)
            try {
                $startupDirs = @("$env:ProgramData\Microsoft\Windows\Start Menu\Programs\StartUp", "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\StartUp")
                foreach ($sd in $startupDirs) {
                    if (-not (Test-Path $sd)) { continue }
                    Get-ChildItem -Path $sd -Filter "*.lnk" -ErrorAction SilentlyContinue | ForEach-Object {
                        try {
                            $sh = New-Object -ComObject WScript.Shell
                            $target = $sh.CreateShortcut($_.FullName).TargetPath
                            if ($target -match '\\(Temp|AppData\\Local\\Temp)\\') {
                                $startupFlags += "Startup shortcut '$($_.BaseName)': runs from Temp folder"
                            }
                        } catch { }
                    }
                }
            } catch { }

            # Services set to Automatic that are not Running
            $stalledServices = @()
            try {
                $stalledServices = @(Get-CimInstance Win32_Service -Filter "StartMode='Auto' AND State!='Running'" -ErrorAction Stop | ForEach-Object {
                    [PSCustomObject]@{ name = "$($_.DisplayName)"; state = "$($_.State)" }
                } | Select-Object -First 20)
            } catch { }

            # Browser extensions: Chrome + Edge, all profiles, name only (no IDs, no sync data)
            $extensions = @()
            try {
                $browserRoots = @(
                    @{ browser = "Chrome";    root = "$env:LOCALAPPDATA\Google\Chrome\User Data" },
                    @{ browser = "Edge";      root = "$env:LOCALAPPDATA\Microsoft\Edge\User Data" },
                    @{ browser = "Brave";     root = "$env:LOCALAPPDATA\BraveSoftware\Brave-Browser\User Data" },
                    @{ browser = "Opera";     root = "$env:APPDATA\Opera Software\Opera Stable" },
                    @{ browser = "Opera GX";  root = "$env:APPDATA\Opera Software\Opera GX Stable" },
                    @{ browser = "Vivaldi";   root = "$env:LOCALAPPDATA\Vivaldi\User Data" }
                )
                foreach ($b in $browserRoots) {
                    if (-not (Test-Path $b.root)) { continue }
                    $profiles = @(Get-ChildItem -Path $b.root -Directory -ErrorAction SilentlyContinue | Where-Object { $_.Name -eq 'Default' -or $_.Name -match '^Profile \d+$' })
                    if ($profiles.Count -eq 0 -and (Test-Path (Join-Path $b.root "Extensions"))) {
                        # Opera / Opera GX keep the Extensions folder directly under the root (no Default subfolder)
                        $profiles = @([PSCustomObject]@{ FullName = $b.root; Name = "Default" })
                    }
                    foreach ($prof in $profiles) {
                        $extDir = Join-Path $prof.FullName "Extensions"
                        if (-not (Test-Path $extDir)) { continue }

                        # Cross-reference against the browser's own extension state, not just what's
                        # on disk - Chromium doesn't always clean up an extension's folder immediately
                        # after uninstall/disable, which can make a removed extension look "installed".
                        # state: 0 = disabled, 1 = enabled. Only IDs present here with state=1 count.
                        $enabledIds = $null
                        foreach ($prefFile in @('Secure Preferences', 'Preferences')) {
                            $prefPath = Join-Path $prof.FullName $prefFile
                            if (-not (Test-Path $prefPath)) { continue }
                            try {
                                $prefs = Get-Content $prefPath -Raw -ErrorAction Stop | ConvertFrom-Json
                                if ($prefs.extensions -and $prefs.extensions.settings) {
                                    $enabledIds = @($prefs.extensions.settings.PSObject.Properties | Where-Object { $_.Value.state -eq 1 } | ForEach-Object { $_.Name })
                                    break
                                }
                            } catch { }
                        }

                        Get-ChildItem -Path $extDir -Directory -ErrorAction SilentlyContinue | ForEach-Object {
                            $extId = $_.Name
                            if ($enabledIds -and $enabledIds -notcontains $extId) { return }
                            $verDir = Get-ChildItem -Path $_.FullName -Directory -ErrorAction SilentlyContinue | Sort-Object Name -Descending | Select-Object -First 1
                            if (-not $verDir) { return }
                            $manifestPath = Join-Path $verDir.FullName "manifest.json"
                            if (-not (Test-Path $manifestPath)) { return }
                            try {
                                $manifest = Get-Content $manifestPath -Raw -ErrorAction Stop | ConvertFrom-Json
                                $name = "$($manifest.name)"
                                if ($name -match '^__MSG_(.+)__$') {
                                    $key = $Matches[1]
                                    $locale = if ($manifest.default_locale) { $manifest.default_locale } else { "en" }
                                    $msgPath = Join-Path $verDir.FullName "_locales\$locale\messages.json"
                                    if (Test-Path $msgPath) {
                                        try {
                                            $msgs = Get-Content $msgPath -Raw -ErrorAction Stop | ConvertFrom-Json
                                            if ($msgs.$key.message) { $name = "$($msgs.$key.message)" }
                                        } catch { }
                                    }
                                }
                                if ($name -and $name -notmatch '^__MSG_') {
                                    $extensions += [PSCustomObject]@{ browser = $b.browser; profile = $prof.Name; name = $name }
                                }
                            } catch { }
                        }
                    }
                }
            } catch { }

            # Firefox: extensions.json per profile (different storage format to Chromium)
            try {
                $ffRoot = "$env:APPDATA\Mozilla\Firefox\Profiles"
                if (Test-Path $ffRoot) {
                    Get-ChildItem -Path $ffRoot -Directory -ErrorAction SilentlyContinue | Where-Object { $_.Name -match '\.default' } | ForEach-Object {
                        $extJsonPath = Join-Path $_.FullName "extensions.json"
                        if (-not (Test-Path $extJsonPath)) { return }
                        try {
                            $extData = Get-Content $extJsonPath -Raw -ErrorAction Stop | ConvertFrom-Json
                            foreach ($addon in $extData.addons) {
                                if ($addon.type -ne 'extension' -or $addon.active -ne $true) { continue }
                                $name = if ($addon.defaultLocale -and $addon.defaultLocale.name) { "$($addon.defaultLocale.name)" } else { "$($addon.id)" }
                                if ($name) { $extensions += [PSCustomObject]@{ browser = "Firefox"; profile = $_.Name; name = $name } }
                            }
                        } catch { }
                    }
                }
            } catch { }

            # BitLocker status per volume (drive letter, protection status)
            $bitlocker = @()
            try {
                $bitlocker = @(Get-BitLockerVolume -ErrorAction Stop | ForEach-Object {
                    [PSCustomObject]@{
                        drive  = "$($_.MountPoint)"
                        status = "$($_.ProtectionStatus)"
                        type   = "$($_.VolumeType)"
                    }
                })
            } catch { }

            $security = [PSCustomObject]@{
                defender         = $defender
                threats          = $threats
                exclusions       = $exclusions
                exclFlags        = $exclFlags
                hostsCustom      = $hostsCustom
                hostsFlags       = $hostsFlags
                startupFlags     = $startupFlags
                extensions       = $extensions
                firewall         = $firewall
                stalledServices  = $stalledServices
                bitlocker        = $bitlocker
                rdp              = $rdp
                acctType         = $acctType
                avProducts       = $avProducts
                firewallProducts = $firewallProducts
            }
        } catch { }

        Write-Host "      - Network adapters, Memory and Running processes" -ForegroundColor DarkGray
        # Network adapters (no IPs, MACs or SSIDs collected - DNS server addresses are the one
        # exception, since a stale/leftover DNS override, often left behind by a VPN client that's
        # since been closed, is a common and otherwise invisible cause of "the internet is broken"
        # reports; this is a static config read, not a live query out to anything)
        $net = $null
        # Each piece below gets its own try/catch with a safe empty default. Previously the whole
        # block shared one try, so a single failure anywhere - e.g. Get-NetAdapter throwing on a
        # machine with an unusual adapter setup - silently discarded everything else that had
        # already been collected successfully, including data with nothing to do with the failure
        # (this is almost certainly what caused "No network data embedded" on a real report).
        $dnsServers = @()
        try {
            $dnsServers = @(Get-DnsClientServerAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue |
                Where-Object { $_.ServerAddresses.Count -gt 0 -and $_.InterfaceAlias -notmatch 'Loopback' } |
                Select-Object -ExpandProperty ServerAddresses | Sort-Object -Unique)
        } catch { }
        $adapters = @()
        try {
            $adapters = @(Get-NetAdapter -Physical -ErrorAction Stop | ForEach-Object {
                # Flag an Ethernet link that's connected well below what the hardware can do - a
                # classic sign of a bad/damaged cable, a bad port, or a cheap Cat5 run. We check the
                # driver's own advertised speed options (ValidDisplayValues) rather than guessing
                # gigabit capability from the adapter's name, since plenty of genuine gigabit NICs
                # (e.g. most Intel ones) don't say "Gigabit" anywhere in their description.
                $gigabitBelowRated = $false
                try {
                    if ($_.Status -eq 'Up' -and $_.PhysicalMediaType -eq '802.3') {
                        $speedProp = Get-NetAdapterAdvancedProperty -Name $_.Name -RegistryKeyword '*SpeedDuplex' -ErrorAction Stop
                        if ($speedProp.ValidDisplayValues -match '1\.?0?\s*Gbps|1000') {
                            if ("$($_.LinkSpeed)" -match '^([\d.,]+)\s*(Gbps|Mbps|Kbps)') {
                                $val = [double]($Matches[1] -replace ',', '.')
                                $mbps = switch -Regex ($Matches[2]) { 'Gbps' { $val * 1000 }; 'Mbps' { $val }; 'Kbps' { $val / 1000 } }
                                if ($mbps -lt 1000) { $gigabitBelowRated = $true }
                            }
                        }
                    }
                } catch { }
                [PSCustomObject]@{
                    name   = "$($_.Name)"
                    desc   = "$($_.InterfaceDescription)"
                    status = "$($_.Status)"
                    speed  = "$($_.LinkSpeed)"
                    media  = "$($_.PhysicalMediaType)"
                    gigabitBelowRated = $gigabitBelowRated
                    driverVersion = "$($_.DriverVersion)"
                    driverDate    = if ($_.DriverDate) { $_.DriverDate.ToString("dd'/'MM'/'yyyy") } else { "" }
                }
            })
        } catch { }
        $vpns = @()
        try {
            $vpns = @(Get-NetAdapter -ErrorAction SilentlyContinue | Where-Object {
                -not $_.Physical -and (
                    $_.Status -eq 'Up' -or
                    "$($_.InterfaceDescription) $($_.Name)" -match 'TAP|Wintun|WireGuard|OpenVPN|Tailscale|Nord|ExpressVPN|Proton|Surfshark|Mullvad|ZeroTier|Hamachi|Radmin|Bright|VPN|AnyConnect|GlobalProtect|Forti|Cloudflare|WARP|Pulse|SonicWall|NetExtender|CheckPoint|SoftEther|PacketiX|Windscribe|IVPN|Psiphon|Betternet|Shadowsocks|Hotspot Shield'
                ) -and "$($_.InterfaceDescription)" -notmatch 'WAN Miniport|Bluetooth|Loopback|Kernel Debug'
            } | ForEach-Object {
                [PSCustomObject]@{
                    name   = "$($_.Name)"
                    desc   = "$($_.InterfaceDescription)"
                    status = "$($_.Status)"
                }
            })
        } catch { }
        $wifi = $null
        try {
            # Signal strength via WMI rather than parsing 'netsh wlan show interfaces' text output -
            # netsh's field labels (Signal/Band/Channel/etc) are localized by Windows' own display
            # language, so text-matching them only works on English-language systems. This WMI class
            # returns the raw numeric value regardless of system language.
            $wifiSignalPct = $null
            try {
                $sig = Get-CimInstance -Namespace root\wmi -ClassName MSNdis_80211_ReceivedSignalStrength -ErrorAction Stop | Select-Object -First 1
                if ($sig) { $wifiSignalPct = [int]$sig.Ndis80211ReceivedSignalStrength }
            } catch { }

            # Radio type / auth / rx-tx rate via the native WLAN API (wlanapi.dll) instead of text-
            # matching netsh's localized field labels - this returns raw enum/numeric values from the
            # OS regardless of display language, so it no longer silently comes back empty on a
            # non-English system the way the old netsh parsing did.
            $radioType = $null; $authDisplay = $null; $rxMbps = $null; $txMbps = $null
            try {
                if (-not ("PCHH.Wlan" -as [type])) {
                    Add-Type -Namespace PCHH -Name Wlan -MemberDefinition @'
[DllImport("wlanapi.dll")] public static extern int WlanOpenHandle(uint clientVersion, IntPtr reserved, out uint negotiatedVersion, out IntPtr clientHandle);
[DllImport("wlanapi.dll")] public static extern int WlanCloseHandle(IntPtr clientHandle, IntPtr reserved);
[DllImport("wlanapi.dll")] public static extern int WlanEnumInterfaces(IntPtr clientHandle, IntPtr reserved, out IntPtr interfaceList);
[DllImport("wlanapi.dll")] public static extern int WlanQueryInterface(IntPtr clientHandle, ref Guid interfaceGuid, int opCode, IntPtr reserved, out uint dataSize, out IntPtr data, IntPtr valueType);
[DllImport("wlanapi.dll")] public static extern void WlanFreeMemory(IntPtr memory);
'@ -ErrorAction Stop

                    Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
namespace PCHH {
    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
    public struct WLAN_INTERFACE_INFO {
        public Guid InterfaceGuid;
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 256)] public string strInterfaceDescription;
        public int isState;
    }
    [StructLayout(LayoutKind.Sequential)]
    public struct DOT11_SSID {
        public uint uSSIDLength;
        [MarshalAs(UnmanagedType.ByValArray, SizeConst = 32)] public byte[] ucSSID;
    }
    [StructLayout(LayoutKind.Sequential)]
    public struct WLAN_ASSOCIATION_ATTRIBUTES {
        public DOT11_SSID dot11Ssid;
        public int dot11BssType;
        [MarshalAs(UnmanagedType.ByValArray, SizeConst = 6)] public byte[] dot11Bssid;
        public uint dot11PhyType;
        public uint uDot11PhyIndex;
        public uint wlanSignalQuality;
        public uint ulRxRate;
        public uint ulTxRate;
    }
    [StructLayout(LayoutKind.Sequential)]
    public struct WLAN_SECURITY_ATTRIBUTES {
        [MarshalAs(UnmanagedType.Bool)] public bool bSecurityEnabled;
        [MarshalAs(UnmanagedType.Bool)] public bool bOneXEnabled;
        public uint dot11AuthAlgorithm;
        public uint dot11CipherAlgorithm;
    }
    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
    public struct WLAN_CONNECTION_ATTRIBUTES {
        public int isState;
        public int wlanConnectionMode;
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 256)] public string strProfileName;
        public WLAN_ASSOCIATION_ATTRIBUTES wlanAssociationAttributes;
        public WLAN_SECURITY_ATTRIBUTES wlanSecurityAttributes;
    }
}
'@ -ErrorAction Stop
                }

                $clientHandle = [IntPtr]::Zero
                $negotiatedVersion = 0
                if ([PCHH.Wlan]::WlanOpenHandle(2, [IntPtr]::Zero, [ref]$negotiatedVersion, [ref]$clientHandle) -eq 0) {
                    try {
                        $ifaceListPtr = [IntPtr]::Zero
                        if ([PCHH.Wlan]::WlanEnumInterfaces($clientHandle, [IntPtr]::Zero, [ref]$ifaceListPtr) -eq 0) {
                            try {
                                $numItems = [Runtime.InteropServices.Marshal]::ReadInt32($ifaceListPtr, 0)
                                $ifaceStructSize = [Runtime.InteropServices.Marshal]::SizeOf([type][PCHH.WLAN_INTERFACE_INFO])
                                for ($i = 0; $i -lt $numItems; $i++) {
                                    # dwNumberOfItems (4 bytes) + dwIndex (4 bytes) precede the interface array
                                    $ifaceInfoPtr = [IntPtr]::Add($ifaceListPtr, 8 + ($i * $ifaceStructSize))
                                    $ifaceInfo = [Runtime.InteropServices.Marshal]::PtrToStructure($ifaceInfoPtr, [type][PCHH.WLAN_INTERFACE_INFO])
                                    if ($ifaceInfo.isState -ne 1) { continue } # 1 = connected

                                    $dataSize = 0; $dataPtr = [IntPtr]::Zero
                                    $guidCopy = $ifaceInfo.InterfaceGuid
                                    $qres = [PCHH.Wlan]::WlanQueryInterface($clientHandle, [ref]$guidCopy, 7, [IntPtr]::Zero, [ref]$dataSize, [ref]$dataPtr, [IntPtr]::Zero)
                                    if ($qres -eq 0) {
                                        try {
                                            $conn = [Runtime.InteropServices.Marshal]::PtrToStructure($dataPtr, [type][PCHH.WLAN_CONNECTION_ATTRIBUTES])
                                            $assoc = $conn.wlanAssociationAttributes
                                            $sec = $conn.wlanSecurityAttributes

                                            $phyMap = @{ 4 = '802.11a'; 5 = '802.11b'; 6 = '802.11g'; 7 = '802.11n'; 8 = '802.11ac'; 9 = '802.11ad'; 10 = '802.11ax'; 11 = '802.11be' }
                                            if ($phyMap.ContainsKey([int]$assoc.dot11PhyType)) { $radioType = $phyMap[[int]$assoc.dot11PhyType] }

                                            $authMap = @{ 1 = 'Open'; 2 = 'Shared key'; 3 = 'WPA-Enterprise'; 4 = 'WPA-Personal'; 5 = 'WPA-None'; 6 = 'WPA2-Enterprise'; 7 = 'WPA2-Personal'; 8 = 'WPA3-Enterprise'; 9 = 'WPA3-Personal'; 10 = 'OWE'; 11 = 'WPA3-Enterprise (192-bit)' }
                                            if ($authMap.ContainsKey([int]$sec.dot11AuthAlgorithm)) { $authDisplay = $authMap[[int]$sec.dot11AuthAlgorithm] }

                                            if ($null -eq $wifiSignalPct) { $wifiSignalPct = [int]$assoc.wlanSignalQuality }
                                            $rxMbps = [math]::Round($assoc.ulRxRate / 1000)
                                            $txMbps = [math]::Round($assoc.ulTxRate / 1000)
                                        } finally { [PCHH.Wlan]::WlanFreeMemory($dataPtr) }
                                    }
                                    break
                                }
                            } finally { [PCHH.Wlan]::WlanFreeMemory($ifaceListPtr) }
                        }
                    } finally { [PCHH.Wlan]::WlanCloseHandle($clientHandle, [IntPtr]::Zero) }
                }
            } catch { }

            # Band/Channel/Channel width have no clean locale-independent source (the WLAN API's
            # connection attributes don't carry frequency info), so these remain best-effort via
            # netsh and may come back empty on a non-English system. Channel width specifically
            # isn't a standard netsh field on every driver/Windows build - some report it, many
            # don't, so treat it as a bonus when present rather than something to rely on.
            $wl = netsh wlan show interfaces 2>$null
            $wf = @{}
            if ($wl) {
                foreach ($line in $wl) {
                    if ($line -match '^\s*(Band|Channel|Channel width)\s*:\s*(.+)$') {
                        $wf[$Matches[1]] = $Matches[2].Trim()
                    }
                }
            }
            if ($null -ne $wifiSignalPct) {
                $wifi = [PSCustomObject]@{
                    signal  = "$wifiSignalPct%"
                    band    = "$($wf['Band'])"
                    channel = "$($wf['Channel'])"
                    width   = "$($wf['Channel width'])"
                    radio   = "$radioType"
                    auth    = "$authDisplay"
                    rx      = "$rxMbps"
                    tx      = "$txMbps"
                }
            }
        } catch { }
        # Assembled unconditionally from whatever succeeded above - each piece already has a safe
        # empty/null default, so this can't itself throw and can't lose data to an unrelated failure.
        $net = [PSCustomObject]@{ adapters = $adapters; vpns = $vpns; wifi = $wifi; dns = $dnsServers }

        # Memory usage at time of capture (physical + commit charge)
        $memuse = $null
        try {
            $osm = Get-CimInstance Win32_OperatingSystem -ErrorAction Stop
            $memuse = [PSCustomObject]@{
                pt = [math]::Round($osm.TotalVisibleMemorySize / 1MB, 1)
                pu = [math]::Round(($osm.TotalVisibleMemorySize - $osm.FreePhysicalMemory) / 1MB, 1)
                ct = [math]::Round($osm.TotalVirtualMemorySize / 1MB, 1)
                cu = [math]::Round(($osm.TotalVirtualMemorySize - $osm.FreeVirtualMemory) / 1MB, 1)
                avail = [math]::Round($osm.FreePhysicalMemory / 1MB, 1)
            }
        } catch { }
        # The Task Manager-style breakdown (Cached, Paged pool, Non-paged pool) - a separate
        # try/catch since it's a different WMI class to the essentials above, so a failure here
        # only loses these extra numbers rather than the whole memory-usage section.
        try {
            $memPerf = Get-CimInstance Win32_PerfFormattedData_PerfOS_Memory -ErrorAction Stop
            if ($memuse -and $memPerf) {
                $memuse | Add-Member -NotePropertyName cache -NotePropertyValue ([math]::Round($memPerf.CacheBytes / 1GB, 2))
                $memuse | Add-Member -NotePropertyName pagedPool -NotePropertyValue ([math]::Round($memPerf.PoolPagedBytes / 1MB, 0))
                $memuse | Add-Member -NotePropertyName nonPagedPool -NotePropertyValue ([math]::Round($memPerf.PoolNonpagedBytes / 1MB, 0))
            }
        } catch { }

        # Minidump info for the viewer
        $dumps = @()
        if ($dmpfound) {
            $dumps = @(Get-ChildItem -Path $source -ErrorAction SilentlyContinue | ForEach-Object {
                [PSCustomObject]@{
                    n = $_.Name
                    d = $_.LastWriteTime.ToString("dd'/'MM'/'yyyy HH:mm")
                    z = "{0:N1} MB" -f ($_.Length / 1MB)
                }
            })
        }

        # JSON payloads ("</" escaped so text cannot close the script tag)
        $json      = (ConvertTo-Json @($recs) -Compress -Depth 3).Replace('</', '<\/')
        $sysJson   = if ($sysEvents.Count -gt 0) { (ConvertTo-Json @($sysEvents) -Compress -Depth 3).Replace('</', '<\/') } else { '[]' }
        $dumpsJson = if ($dumps.Count -gt 0) { (ConvertTo-Json @($dumps) -Compress -Depth 3).Replace('</', '<\/') } else { '[]' }
        $gpusJson = if ($gpus.Count -gt 0) { (ConvertTo-Json @($gpus) -Compress -Depth 3).Replace('</', '<\/') } else { '[]' }
        $hagsJson = if ($hagsEnabled) { "`"$hagsEnabled`"" } else { 'null' }
        $ramSlotsJson = if ($ramSlotsTotal) { "$ramSlotsTotal" } else { 'null' }
        $isLaptopJson = if ($isLaptop) { 'true' } else { 'false' }
        $batteryJson = if ($batteryInfo.Count -gt 0) { $batteryInfo | ConvertTo-Json -Depth 5 -Compress } else { '[]' }
        if ($batteryJson -notmatch '^\[') { $batteryJson = "[$batteryJson]" }
        $monsJson = if ($mons.Count -gt 0) { (ConvertTo-Json @($mons) -Compress -Depth 3).Replace('</', '<\/') } else { '[]' }
        $displaysJson = if ($displays.Count -gt 0) { (ConvertTo-Json @($displays) -Compress -Depth 3).Replace('</', '<\/') } else { '[]' }
        $procsJson = if ($procs.Count -gt 0) { (ConvertTo-Json @($procs) -Compress -Depth 3).Replace('</', '<\/') } else { '[]' }
        $netJson = if ($net) { (ConvertTo-Json $net -Compress -Depth 4).Replace('</', '<\/') } else { 'null' }
        $securityJson = if ($security) { (ConvertTo-Json $security -Compress -Depth 5).Replace('</', '<\/') } else { 'null' }
        $hotfixesJson = if ($hotfixes.Count -gt 0) { (ConvertTo-Json @($hotfixes) -Compress -Depth 3).Replace('</', '<\/') } else { '[]' }
        $windowsOldJson = if ($windowsOld) { (ConvertTo-Json $windowsOld -Compress).Replace('</', '<\/') } else { 'null' }
        $powerPlanJson = if ($powerPlanInfo) { (ConvertTo-Json $powerPlanInfo -Compress).Replace('</', '<\/') } else { 'null' }
        $generalFlagsJson = (ConvertTo-Json $generalFlags -Compress).Replace('</', '<\/')
        $cbsJson = if ($cbs) { (ConvertTo-Json $cbs -Compress).Replace('</', '<\/') } else { 'null' }
        $wuHistoryJson = if ($wuHistory.Count -gt 0) { (ConvertTo-Json @($wuHistory) -Compress -Depth 3).Replace('</', '<\/') } else { '[]' }
        $winUpdateInfo = [PSCustomObject]@{ pendingReboot = $pendingReboot; serviceStatus = $wuServiceStatus; serviceStartType = $wuServiceStartType }
        $winUpdateJson = (ConvertTo-Json $winUpdateInfo -Compress).Replace('</', '<\/')
        $devErrorsJson = if ($devErrors.Count -gt 0) { (ConvertTo-Json @($devErrors) -Compress -Depth 3).Replace('</', '<\/') } else { '[]' }
        $audioJson = if ($audio) { (ConvertTo-Json $audio -Compress).Replace('</', '<\/') } else { 'null' }
        $usbJson = (ConvertTo-Json @($usbDevices) -Compress).Replace('</', '<\/')
        $camerasJson = (ConvertTo-Json @($cameras) -Compress).Replace('</', '<\/')
        $memuseJson = if ($memuse) { (ConvertTo-Json $memuse -Compress).Replace('</', '<\/') } else { 'null' }
        $ramJson = if ($ram.Count -gt 0) { (ConvertTo-Json @($ram) -Compress -Depth 3).Replace('</', '<\/') } else { '[]' }
        $smartJson = if ($smart.Count -gt 0) { (ConvertTo-Json @($smart) -Compress -Depth 3).Replace('</', '<\/') } else { '[]' }
        $dirtyJson = if ($dirtyVols.Count -gt 0) { (ConvertTo-Json @($dirtyVols) -Compress).Replace('</', '<\/') } else { '[]' }
        $diskLayoutJson = if ($diskLayout.Count -gt 0) { (ConvertTo-Json @($diskLayout) -Compress -Depth 4).Replace('</', '<\/') } else { '[]' }
        $specsRaw = Get-Content -Path $infofile -Raw -ErrorAction SilentlyContinue
        if ($null -eq $specsRaw) { $specsRaw = "" }
        $specsJson = (ConvertTo-Json "$specsRaw" -Compress).Replace('</', '<\/')

        $genStamp = (Get-Date).ToString("dd'/'MM'/'yyyy HH:mm")
        $viewerHtml = $viewerTemplate.Replace('/*__VER__*/""', "`"$scriptVersion`"").Replace('/*__GEN__*/""', "`"$genStamp`"").Replace('/*__DATA__*/[]', $json).Replace('/*__SPECS__*/""', $specsJson).Replace('/*__DUMPS__*/[]', $dumpsJson).Replace('/*__SYSEVT__*/[]', $sysJson).Replace('/*__SMART__*/[]', $smartJson).Replace('/*__DIRTY__*/[]', $dirtyJson).Replace('/*__DISKLAYOUT__*/[]', $diskLayoutJson).Replace('/*__RAM__*/[]', $ramJson).Replace('/*__GPUS__*/[]', $gpusJson).Replace('/*__HAGS__*/null', $hagsJson).Replace('/*__ISLAPTOP__*/false', $isLaptopJson).Replace('/*__MONS__*/[]', $monsJson).Replace('/*__DISPLAYS__*/[]', $displaysJson).Replace('/*__PROCS__*/[]', $procsJson).Replace('/*__MEMUSE__*/null', $memuseJson).Replace('/*__NET__*/null', $netJson).Replace('/*__SECURITY__*/null', $securityJson).Replace('/*__HOTFIXES__*/[]', $hotfixesJson).Replace('/*__WINDOWSOLD__*/null', $windowsOldJson).Replace('/*__POWERPLAN__*/null', $powerPlanJson).Replace('/*__GENFLAGS__*/null', $generalFlagsJson).Replace('/*__CBS__*/null', $cbsJson).Replace('/*__WUHISTORY__*/[]', $wuHistoryJson).Replace('/*__WINUPDATE__*/null', $winUpdateJson).Replace('/*__DEVERR__*/[]', $devErrorsJson).Replace('/*__AUDIO__*/null', $audioJson).Replace('/*__USB__*/[]', $usbJson).Replace('/*__CAMERAS__*/[]', $camerasJson).Replace('/*__BATTERY__*/[]', $batteryJson).Replace('/*__RAMSLOTS__*/null', $ramSlotsJson)
        try {
            Set-Content -Path $reliability_html_path -Value $viewerHtml -Encoding UTF8
        } catch {
            Write-Host "      Could not write the HTML report - the other collected files are still available." -ForegroundColor Yellow
        }

    Write-Host -NoNewline -ForegroundColor Green "$(cmark)"
    Write-Host " Diagnostics collected"

    compression
}



# Compresses files
function compression {
    Write-Host ""
    Write-Host "[3/3] Compressing everything into one zip.." -ForegroundColor Blue

    Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\CrashControl" -Name "DisplayParameters" -Value 1 -Type DWord -Force | Out-Null

    $filesToCompress = @($infofile, $reliability_csv_path, $reliability_html_path)

    if ($dmpfound) {
        # Only include dumps from the last 60 days in the zip - older ones are left alone on disk
        # rather than deleted, in case they're needed for deeper investigation later.
        $dmpLimit = (Get-Date).AddDays(-60)
        $filesToCompress += Get-ChildItem -Path $source -ErrorAction SilentlyContinue | Where-Object { $_.LastWriteTime -ge $dmpLimit }
    }

    try {
        Invoke-WithoutProgress {
            Compress-Archive -Path $filesToCompress -CompressionLevel Optimal -DestinationPath $ziptar -Force | Out-Null
        }
    }
    catch {


        Write-Host ""
        Write-Host "     Unable to compress files..." -ForegroundColor Red
        Write-Host "     Re-run the script to attempt to fix the issue." -ForegroundColor Red
        Write-Host ""

        $errors.Compress = $true
        functionerror
    }

    Remove-Item -Path $infofile, $reliability_csv_path, $reliability_html_path -Force -Recurse -ErrorAction SilentlyContinue > $null 2>&1

    Write-Host -NoNewline -ForegroundColor Green "$(cmark)"
    Write-Host " Zip created"

    eof
}

function eof {
    Write-Host ""
    Write-Host "==================================================" -ForegroundColor DarkGreen
    Write-Host "  DONE - your report is ready to share" -ForegroundColor Green
    Write-Host "==================================================" -ForegroundColor DarkGreen
    Write-Host ""
    Write-Host -NoNewline "  Zip file:   " -ForegroundColor Gray
    Write-Host "$ziptar"
    Write-Host ""
    Write-Host "  The zip is already on your clipboard -" -ForegroundColor Gray
    Write-Host "  just press Ctrl+V in Discord to attach it." -ForegroundColor Gray
    Write-Host ""
    Write-Host "  Want to see the report yourself? Open the zip and" -ForegroundColor Gray
    Write-Host "  double-click triage-report.html - it opens in your browser." -ForegroundColor Gray
    Start-Process explorer.exe -ArgumentList $File
    $script:eofcomplete = $true

    endmessage
}

function functionerror {
    Write-Host -NoNewline -ForegroundColor Red "$(xmark)"

    if ($errors.Compress -eq "true") {
        Write-Host " There was an error during compression.."
    }
    elseif ($errors.fileCreate -eq "true") {
        Write-Host "There was an error while creating files.."
    }

    Write-Host -NoNewline -ForegroundColor White "Error:"
    Write-Host " $_" -ForegroundColor Red

    endmessage
}

function endmessage {
    Write-Host ""
    Write-Host "Press any key to exit.."

    if ($eofcomplete) {
        Add-Type -AssemblyName System.Windows.Forms
        [System.Windows.Forms.Clipboard]::SetFileDropList([System.Collections.Specialized.StringCollection]@($ziptar))
    }
        
    $null = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")

        Stop-Process -Id $PID -Force
}

dmpcheck
