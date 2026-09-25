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
<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
<link href="https://fonts.googleapis.com/css2?family=Roboto:wght@300;400;500;700&family=Roboto+Mono:wght@400;500&family=Material+Symbols+Outlined:opsz,wght,FILL,GRAD@24,400,0,0&display=swap" rel="stylesheet">
<style>
:root{
  --bg:#111418; --panel:#1D2024; --panel2:#1D2024; --line:#2A2E33; --line2:#43474E;
  --text:#E2E2E9; --dim:#C3C6CF; --faint:#8F9299;
  --err:#FFB4AB; --err-c:#93000A; --err-on-c:#FFDAD6; --err-container:#3B2C2C;
  --warn:#FFDF9B; --warn-c:#5C4600; --warn-on-c:#3F2E00; --warn-container:#332703;
  --ok:#8BD17C; --info:#A0CAFD; --info-c:#004A7D; --info-on-c:#D1E4FF;
}
*{box-sizing:border-box;margin:0;padding:0}
@media (prefers-reduced-motion: reduce){*{animation-duration:.001ms!important;animation-iteration-count:1!important}}
body{background:var(--bg);color:var(--text);font-family:'Roboto',system-ui,sans-serif;font-size:16px;height:100vh;overflow:hidden}
.material-symbols-outlined{font-family:'Material Symbols Outlined';font-weight:normal;font-style:normal;font-size:24px;line-height:1;letter-spacing:normal;text-transform:none;display:inline-block;white-space:nowrap;word-wrap:normal;direction:ltr;vertical-align:middle;-webkit-font-feature-settings:'liga';-webkit-font-smoothing:antialiased;flex-shrink:0}
#appShell{display:flex;background:var(--bg);padding:40px 16px 40px 40px;gap:16px;height:100vh;width:100%}
.mono{font-family:'Roboto Mono',monospace}
#sidebar{width:300px;flex:0 0 300px;background:var(--panel2);border-radius:16px;display:flex;flex-direction:column;padding:12px 12px 8px;overflow:hidden}
#brand{display:flex;align-items:center;gap:12px;padding:16px 16px 20px;font-size:19px;font-weight:600;letter-spacing:.01em}
#brand .material-symbols-outlined{font-size:30px;color:var(--info)}
#brand-sub{font:400 12px/16px Roboto;color:var(--faint);font-weight:400}
#content{flex:1;min-width:0;height:100%;min-height:0;display:flex;flex-direction:column;overflow-y:auto}
@media (max-width:900px){
  #appShell{flex-direction:column;padding:16px}
  #sidebar{width:auto;flex:0 0 auto;flex-direction:row;flex-wrap:wrap;align-items:center;padding:14px}
  #brand{padding:0 14px 0 0}
  #tabs{flex-direction:row;flex-wrap:wrap;gap:6px 14px;flex:1}
  .nav-group{display:contents}
  .nav-group-title{display:none}
  #sideFoot{width:100%;order:99;flex-direction:row;justify-content:space-between;padding-top:10px}
}
#tabs{display:flex;flex-direction:column;gap:2px;flex:1;overflow-y:auto;overflow-x:hidden}
.nav-group{margin-bottom:2px}
.nav-group-title{display:flex;align-items:center;justify-content:space-between;color:var(--dim);font:500 14px/20px Roboto;text-transform:none;letter-spacing:0;padding:0 28px;height:40px;cursor:pointer;border-radius:6px;user-select:none}
.nav-group-title:hover{color:var(--dim)}
.nav-group-title.static{cursor:default;height:40px}
.nav-group-title.static:hover{color:var(--dim)}
.nav-group-title .chev{font-size:18px;transition:transform .15s;color:var(--faint)}
.nav-group.collapsed .nav-group-title .chev{transform:rotate(-90deg)}
.nav-group.collapsed .nav-group-items{display:none}
.nav-group-items{display:flex;flex-direction:column;gap:2px}
#sideFoot{margin-top:auto;padding-top:14px;border-top:1px solid var(--line);display:flex;flex-direction:column;gap:4px}
#sideFoot span{color:var(--faint);font-size:12px}
.tab{display:flex;align-items:center;gap:12px;width:100%;text-align:left;background:none;border:none;color:var(--dim);font-family:'Roboto',inherit;font-size:15px;font-weight:500;height:52px;padding:0 24px;cursor:pointer;border-radius:26px}
.tab .material-symbols-outlined{font-size:24px;color:currentColor}
.tab:hover{color:var(--text);background:#272A2F}
.tab.on{color:var(--info-on-c);background:var(--info-c)}
.tab.on .material-symbols-outlined{font-variation-settings:'FILL' 1}
.tab-badge{margin-left:auto;min-width:20px;height:20px;padding:0 6px;box-sizing:border-box;border-radius:10px;background:var(--err-c);color:var(--err-on-c);font:500 11px/20px Roboto;text-align:center;flex:none}
.tab-badge.warn{background:var(--warn-container);color:var(--warn)}
.flag-sep{width:1px;align-self:stretch;background:var(--line2);margin:0 4px}
.nav-group-title .group-badge{display:none;margin-left:auto;margin-right:10px;min-width:10px;width:10px;height:10px;padding:0}
.nav-group.collapsed .nav-group-title .group-badge.show{display:block}
.nav-group-title .group-badge{background:var(--err)}
.nav-group-title .group-badge.warn{background:var(--warn)}
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
.i{color:var(--info)}
.view{display:none}
@keyframes viewFadeIn{from{opacity:0;transform:translateY(6px)}to{opacity:1;transform:translateY(0)}}
body.tab-battery #batteryView,body.tab-faq #faqView,body.tab-tools #toolsView,body.tab-dumps #dumpsView{display:block;animation:viewFadeIn .28s cubic-bezier(.16,1,.3,1)}
body.tab-summary #summaryView,body.tab-diagsummary #diagsummaryView,body.tab-rel #relView,body.tab-mobo #moboView,body.tab-cpu #cpuView,body.tab-drives #drivesView,body.tab-gpu #gpuView,body.tab-memory #memoryView,body.tab-net #netView,body.tab-devices #devicesView,body.tab-security #securityView,body.tab-apps #appsView,body.tab-processes #processesView,body.tab-updates #updatesView,body.tab-extensions #extensionsView,body.tab-sys #sysView,body.tab-shutdowns #shutdownsView{display:flex;flex-direction:column;min-height:0;flex:1;animation:viewFadeIn .28s cubic-bezier(.16,1,.3,1)}
body.tab-summary #content,body.tab-diagsummary #content,body.tab-rel #content,body.tab-mobo #content,body.tab-cpu #content,body.tab-drives #content,body.tab-gpu #content,body.tab-memory #content,body.tab-net #content,body.tab-devices #content,body.tab-security #content,body.tab-apps #content,body.tab-processes #content,body.tab-updates #content,body.tab-extensions #content,body.tab-sys #content,body.tab-shutdowns #content{overflow:hidden}
#pageTitle{padding:36px 36px 0;font-size:40px;font-weight:700;letter-spacing:-.01em;color:var(--text);max-width:1160px}
body.tab-summary #pageTitle{display:none}
body.tab-diagsummary #pageTitle{display:none}
body.tab-security #pageTitle{display:none}
body.tab-cpu #pageTitle{display:none}
body.tab-drives #pageTitle{display:none}
body.tab-gpu #pageTitle{display:none}
body.tab-mobo #pageTitle{display:none}
body.tab-net #pageTitle{display:none}
body.tab-memory #pageTitle{display:none}
body.tab-devices #pageTitle{display:none}
body.tab-rel #pageTitle{display:none}
body.tab-apps #pageTitle{display:none}
body.tab-processes #pageTitle{display:none}
body.tab-updates #pageTitle{display:none}
body.tab-extensions #pageTitle{display:none}
body.tab-sys #pageTitle{display:none}
#pageTitleSub{color:var(--info);font-weight:600}
#dumpsView,#batteryView,#toolsView,#faqView{padding:20px 36px 64px;max-width:1160px}
.sys-ok{color:var(--ok);padding:24px 0;font-size:16px}
.sys-note{color:var(--faint);font-size:13px;margin-bottom:14px}
.spec-section{margin-bottom:40px}

/* Summary tab: M3 page header (breadcrumb + title + status chip + actions) and spec tile grid */
#summaryView{padding:0}
#summaryHead{padding:24px 40px 28px;display:flex;flex-direction:column;gap:24px;flex:none}
#summaryCrumb{display:flex;align-items:center;gap:8px;min-height:40px}
#summaryCrumb .crumb{font:400 13px/18px Roboto;color:var(--faint);display:flex;align-items:center;gap:6px}
#summaryCrumb .crumb b{color:var(--dim);font-weight:400}
#summaryActions{margin-left:auto;display:flex;gap:8px}
.m3-btn{display:flex;align-items:center;gap:8px;height:36px;padding:0 14px 0 10px;border:1px solid #8D9199;border-radius:18px;font:500 13px/18px Roboto;color:var(--text);cursor:pointer;background:none}
.m3-btn:hover{background:#272A2F}
.m3-btn.filled{border:none;padding:0 20px 0 16px;background:var(--info);color:#00325A}
.m3-btn.filled:hover{background:#B9D8FF}
#summaryTitleRow{display:flex;align-items:flex-end;gap:24px}
#summaryTitle{font:400 32px/40px Roboto;overflow-wrap:anywhere}
#summarySub{font:400 14px/20px Roboto;color:var(--faint);margin-top:6px}
#summaryChip{margin-left:auto;display:flex;align-items:center;gap:8px;height:36px;padding:0 16px 0 12px;border-radius:18px;white-space:nowrap;font:500 13px/18px Roboto;cursor:pointer}
#summaryChip:hover{filter:brightness(1.15)}
#summaryChip .status-dot{width:9px;height:9px;border-radius:50%;flex-shrink:0}
#summaryChip.err{background:var(--err-container);border:1px solid var(--err-c);color:var(--err)}
#summaryChip.err .status-dot{background:var(--err)}
#summaryChip.warn{background:var(--warn-container);border:1px solid var(--warn-c);color:var(--warn)}
#summaryChip.warn .status-dot{background:var(--warn)}
#summaryChip.ok{background:var(--panel);border:1px solid var(--line2);color:var(--ok)}
#summaryChip.ok .status-dot{background:var(--ok)}
#summaryBody{padding:0 40px 40px;flex:1;min-height:0;overflow-y:auto}
.tile-grid{display:grid;grid-template-columns:repeat(3,1fr);grid-auto-rows:1fr;gap:20px;height:100%}
@media (max-width:1100px){.tile-grid{grid-template-columns:repeat(2,1fr)}}
@media (max-width:680px){.tile-grid{grid-template-columns:1fr}#summaryHead{padding:20px 16px 20px}#summaryBody{padding:0 16px 32px}#summaryTitle{font-size:26px;line-height:32px}}
.tile{background:var(--panel);border-radius:16px;padding:25px 25px 29px;display:flex;flex-direction:column;gap:20px;cursor:pointer;transition:background .1s ease;border:1px solid transparent}
.tile:hover{background:#22262B}
.tile-err{border-color:var(--err)}
.tile-warn{border-color:var(--warn)}
.tile-head{display:flex;align-items:center;gap:14px}
.tile-icon{width:48px;height:48px;flex:none;border-radius:14px;background:var(--info-c);color:var(--info-on-c);display:grid;place-items:center}
.tile-icon .material-symbols-outlined{font-size:26px}
.tile-titles{min-width:0}
.tile-label{color:var(--faint);font:500 10px/14px Roboto;letter-spacing:.08em;text-transform:uppercase}
.tile-value{font:400 18px/24px Roboto;overflow-wrap:anywhere}
.tile-chevron{margin-left:auto;color:var(--faint);flex:none}
.tile-warnbadge{margin-left:auto;flex:none;width:28px;height:28px;display:flex;align-items:center;justify-content:center;border-radius:8px}
.tile-warnbadge .material-symbols-outlined{font-size:18px}
.tile-warnbadge-warn{background:var(--warn-container);color:var(--warn)}
.tile-warnbadge-err{background:var(--err-container);color:var(--err)}
.tile-div{height:1px;background:var(--line2)}
.tile-kv{display:grid;grid-template-columns:auto 1fr;gap:10px 16px;font:400 13px/19px Roboto;color:var(--dim)}
.tile-kv dt{color:var(--faint)}
.tile-kv dd{overflow-wrap:anywhere}
.tile-warn-text{color:var(--warn)}
.tile-bars{display:flex;flex-direction:column;gap:14px}
.tile-bar-row{display:flex;flex-direction:column;gap:8px}
.tile-bar-label{display:flex;justify-content:space-between;font:400 13px/18px Roboto;color:var(--dim)}
.tile-bar-label span:first-child{color:var(--faint)}
.tile-bar-track{height:8px;border-radius:4px;background:var(--line2);overflow:hidden}
.tile-bar-fill{height:100%;background:var(--info)}
.tile-bar-fill.low{background:var(--warn)}

/* Shared "detail page" system: header + posture strip + cards, used by Security and other
   redesigned detail pages (Processor, Storage, etc. to follow the same pattern). */
.dp-view{padding:0}
.dp-head{padding:24px 40px 18px;display:flex;flex-direction:column;gap:18px;flex:none}
.dp-crumb{display:flex;align-items:center;gap:8px;min-height:40px}
.dp-crumb .crumb{font:400 14px/20px Roboto;color:var(--faint);display:flex;align-items:center;gap:6px}
.dp-crumb .crumb b{color:var(--dim);font-weight:400}
.dp-actions{margin-left:auto;display:flex;gap:8px}
.dp-title-row{display:flex;align-items:flex-end;gap:24px}
.dp-title{font:400 32px/40px Roboto}
.dp-sub{font:400 14px/20px Roboto;color:var(--faint);margin-top:6px}
.dp-status{margin-left:auto;display:flex;align-items:center;gap:8px;font:500 13px/18px Roboto;white-space:nowrap;flex:none}
.dp-status .status-dot{width:9px;height:9px;border-radius:50%;flex-shrink:0}
.dp-status.err{color:var(--err)}.dp-status.err .status-dot{background:var(--err)}
.dp-status.warn{color:var(--warn)}.dp-status.warn .status-dot{background:var(--warn)}
.dp-status.ok{color:var(--ok)}.dp-status.ok .status-dot{background:var(--ok)}
.dp-posture{padding:0 40px 14px;display:grid;gap:12px;flex:none}
.dp-posture-card{background:var(--panel);border:1px solid var(--line);border-radius:12px;padding:12px 14px;display:flex;align-items:center;gap:12px;cursor:default}
.dp-posture-card.err{background:var(--err-container);border-color:var(--err-c)}
.dp-posture-card.warn{background:var(--warn-container);border-color:var(--warn-c)}
.dp-posture-card .material-symbols-outlined{font-size:22px}
.dp-posture-t{font:500 13px/18px Roboto}
.dp-posture-s{font:400 12px/16px Roboto;color:var(--faint)}
.dp-posture-card.err .dp-posture-t{color:var(--err-on-c)}
.dp-posture-card.warn .dp-posture-t{color:var(--warn)}
.dp-body{flex:1;min-height:0;padding:0 40px 40px;display:grid;grid-template-columns:1fr 1fr;gap:16px;align-content:start}
@media (max-width:900px){.dp-body{grid-template-columns:1fr}}
.dp-card{background:var(--panel);border-radius:16px;padding:20px 22px}
.dp-card-head{display:flex;align-items:center;gap:10px;margin-bottom:12px}
.dp-card-title{font:400 18px/24px Roboto}
.dp-card-count{font:400 13px/18px Roboto;color:var(--faint)}
.dp-card-note{font:400 13px/18px Roboto;color:var(--faint);margin:-6px 0 12px}
.dp-row{display:flex;align-items:center;gap:12px;padding:11px 0;border-bottom:1px solid var(--line)}
.dp-row:last-child{border-bottom:none}
.dp-row-label{flex:1;font:400 14px/20px Roboto;color:var(--dim)}
.dp-row-val{font:500 13px/18px Roboto;white-space:nowrap}
.dp-kv{display:grid;grid-template-columns:auto 1fr;gap:0 20px;font:400 14px/20px Roboto}
.dp-kv dt{color:var(--faint);padding:10px 0;border-bottom:1px solid var(--line)}
.dp-kv dd{padding:10px 0;border-bottom:1px solid var(--line);text-align:right;color:var(--dim)}
.dp-kv dt:last-of-type,.dp-kv dd:last-of-type{border-bottom:none}
.dp-banner{margin-top:12px;display:flex;align-items:center;gap:10px;padding:11px 13px;border-radius:10px;background:var(--warn-container);cursor:pointer}
.dp-banner .material-symbols-outlined{font-size:18px;color:var(--warn);flex:none}
.dp-banner-text{flex:1;font:400 13px/18px Roboto;color:var(--warn)}
.dp-banner-link{font:500 12px/18px Roboto;color:var(--info);white-space:nowrap;flex:none}
.dp-banner.err{background:var(--err-container)}
.dp-banner.info{background:var(--panel)}
.dp-banner.info .material-symbols-outlined,.dp-banner.info .dp-banner-text{color:var(--dim)}
/* dp-cards have no border of their own, so outline them with an inset ring rather than a border - no layout shift */
.dp-card.vol-card-warn{border:none;box-shadow:inset 0 0 0 1px var(--warn)}
.dp-card.vol-card-err{border:none;box-shadow:inset 0 0 0 1px var(--err)}
.dp-banner.err .material-symbols-outlined,.dp-banner.err .dp-banner-text{color:var(--err)}
.dp-flag-row{display:flex;align-items:center;gap:9px;padding:10px 13px;border-radius:9px;background:var(--warn-container);font:400 13px/18px Roboto;color:var(--warn);overflow-wrap:anywhere}
.dp-flag-row .material-symbols-outlined{font-size:16px;flex:none}
.dp-plain-row{padding:10px 13px;border-radius:9px;background:#272A2F;font:400 13px/18px Roboto;color:var(--dim);overflow-wrap:anywhere}
.dp-empty{color:var(--faint);font:400 14px/20px Roboto;padding:8px 0}
.dp-stats{padding:0 40px;display:grid;grid-template-columns:repeat(4,1fr);gap:16px;flex:none;margin-bottom:24px}
.dp-stat{background:var(--panel);border-radius:16px;padding:20px 22px}
.dp-stat-l{font:500 11px/16px Roboto;letter-spacing:.09em;text-transform:uppercase;color:var(--faint)}
.dp-stat-v{font:300 32px/40px Roboto;margin-top:4px}
.dp-stat-sub{font:400 13px/18px Roboto;color:var(--faint);margin-top:2px}
.dp-stat-v .unit{font-size:18px;color:var(--dim)}
.dp-stat-s{font:400 13px/19px Roboto;color:var(--dim)}
.dp-split{padding:20px 40px 40px;flex:1;min-height:0;overflow-y:auto;display:flex;gap:20px;align-items:flex-start}
.dp-split-main{flex:1;min-width:0}
.dp-split-side{width:400px;flex:none;display:flex;flex-direction:column;gap:16px}
@media (max-width:1100px){.dp-split{flex-direction:column}.dp-split-side{width:100%}.dp-stats{grid-template-columns:repeat(2,1fr)}}
.dp-table-note{margin-top:16px;font:400 13px/19px Roboto;color:var(--faint)}
.dp-clickrow{display:flex;align-items:center;gap:12px;padding:13px 15px;border-radius:12px;background:#272A2F;cursor:pointer}
.dp-clickrow:hover{background:#2F3338}
.dp-clickrow .material-symbols-outlined{font-size:20px;flex:none}
.dp-clickrow-t{font:500 14px/20px Roboto}
.dp-clickrow-s{font:400 12px/18px Roboto;color:var(--faint)}
.dp-chip{height:32px;padding:0 12px;border-radius:8px;border:1px solid var(--line2);color:var(--info);font:500 13px/30px Roboto;cursor:pointer}

/* Storage page */
.dp-content{flex:1;min-height:0;overflow-y:auto;padding:0 40px 40px;display:flex;flex-direction:column;gap:20px}
.dp-section-label{font:500 11px/16px Roboto;letter-spacing:.09em;text-transform:uppercase;color:var(--faint);margin-bottom:12px}
.vol-grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(260px,1fr));gap:16px}
.vol-stack{display:flex;flex-direction:column;gap:12px}
.vol-stack .vol-card{flex-direction:row;align-items:center;gap:20px}
.vol-stack .vol-top{flex:0 0 260px}
.vol-stack .vol-bar-track{flex:1;margin:0}
.vol-stack .vol-foot{flex:0 0 220px;flex-direction:column;align-items:flex-end;gap:2px}
.vol-card{background:var(--panel);border-radius:16px;padding:21px 23px;display:flex;flex-direction:column;gap:14px;cursor:pointer;border:1px solid transparent}
.vol-card-err{border:1px solid var(--err)}
.vol-card-warn{border:1px solid var(--warn)}
.vol-card:hover{background:#22262B}
.vol-top{display:flex;align-items:center;gap:12px}
.vol-letter{font:400 20px/26px Roboto}
.vol-sub{font:400 14px/20px Roboto;color:var(--faint)}
/* side-by-side volume cards: name on its own line, disk/bus + chip underneath */
.vol-grid .vol-top{flex-wrap:wrap;row-gap:6px}
.vol-grid .vol-letter{flex:1 1 100%;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}
.vol-grid .vol-top .vol-chip{margin-left:auto}
.vol-chip{margin-left:auto;display:flex;align-items:center;gap:6px;height:26px;padding:0 10px;border-radius:8px;font:500 12px/26px Roboto;white-space:nowrap}
.vol-chip.ok{background:#0F2A16;color:var(--ok)}
.vol-chip.warn{background:var(--warn-container);color:var(--warn)}
.vol-chip.err{background:var(--err-container);color:var(--err)}
.vol-chip.plain{background:#272A2F;color:var(--dim)}
.vol-chip .material-symbols-outlined{font-size:15px}
.vol-bar-track{height:10px;border-radius:5px;background:var(--line2);overflow:hidden}
.vol-bar-fill{height:100%;background:var(--info)}
.vol-bar-fill.warn{background:var(--warn)}
.vol-bar-fill.err{background:var(--err)}
.vol-foot{display:flex;justify-content:space-between;font:400 14px/20px Roboto}
.disk-card{background:var(--panel);border-radius:16px;padding:21px 25px;display:flex;flex-direction:column;gap:14px;margin-bottom:12px;border:1px solid transparent}
.disk-top{display:flex;align-items:center;gap:14px;flex-wrap:wrap}
.disk-name{font:400 20px/26px Roboto}
.disk-model{font:400 15px/22px Roboto;color:var(--dim)}
.disk-size{margin-left:auto;font:400 15px/22px Roboto;color:var(--faint)}
.disk-expand{font-size:20px;color:var(--faint);cursor:pointer}
.disk-bar{display:flex;gap:3px;height:44px;overflow:hidden;border-radius:6px}
.disk-legend{display:flex;flex-wrap:wrap;gap:16px;font:400 13px/18px Roboto;color:var(--faint)}
.disk-legend span.sw{display:inline-flex;align-items:center;gap:6px}
.disk-legend .dot{width:10px;height:10px;border-radius:2px;flex:none}
.disk-mismatch-note{color:var(--faint);font:400 12.5px/18px Roboto}

/* Devices page */
.dev-grid{display:grid;grid-template-columns:repeat(auto-fill,minmax(260px,1fr));gap:12px}
.dev-card{background:var(--panel);border-radius:12px;padding:14px 16px;display:flex;align-items:center;gap:12px}
.dev-card.err{background:var(--err-container)}
.dev-icon{width:36px;height:36px;border-radius:10px;display:flex;align-items:center;justify-content:center;flex:none}
.dev-icon .material-symbols-outlined{font-size:19px}
.dev-icon.ok{background:#0F2A16;color:var(--ok)}
.dev-icon.warn{background:var(--warn-container);color:var(--warn)}
.dev-icon.err{background:var(--err-c);color:var(--err-on-c)}
.dev-icon.plain{background:#272A2F;color:var(--faint)}
.dev-body{min-width:0;flex:1}
.dev-title{font:500 14px/20px Roboto;overflow-wrap:anywhere}
.dev-desc{font:400 12px/17px Roboto;color:var(--faint);margin-top:2px}
.dev-badges{display:flex;gap:6px;margin-top:4px;flex-wrap:wrap}
.dev-badge{display:inline-flex;height:20px;padding:0 8px;border-radius:6px;font:500 11px/20px Roboto;white-space:nowrap}
.dev-badge.ok{background:#0F2A16;color:var(--ok)}
.dev-badge.warn{background:var(--warn-container);color:var(--warn)}
.dev-badge.err{background:var(--err-c);color:var(--err-on-c)}

/* Installed Programs / list-table pages (Software family) */
.list-flagband{padding:0 40px 16px;flex:none}
.list-flagband-inner{background:var(--panel);border-radius:16px;padding:18px 22px;display:flex;align-items:center;gap:22px;flex-wrap:wrap}
.list-flagband-label{flex:none}
.list-flagband-label .l1{font:500 11px/16px Roboto;letter-spacing:.09em;text-transform:uppercase;color:var(--faint)}
.list-flagband-label .l2{font:400 14px/20px Roboto;color:var(--dim);margin-top:2px}
.flagpill{display:inline-flex;align-items:center;gap:6px;height:34px;padding:0 14px;border-radius:8px;border:1px solid var(--line2);color:var(--dim);font:500 13px/32px Roboto;cursor:pointer}
.flagpill:hover{background:#272A2F}
.flagpill .n{font-weight:400;color:var(--faint)}
.flagpill.on{background:var(--warn-container);color:var(--warn);border-color:transparent}
.flagpill.on .n{color:var(--warn);opacity:.8}
.flagpill.zero{border-color:var(--line);color:#5B6068;cursor:default}
.flagpill.zero:hover{background:none}
.list-controls{padding:12px 40px 20px;flex:none;display:flex;align-items:center;gap:12px}
.list-search{flex:1;display:flex;align-items:center;gap:12px;height:48px;padding:0 18px;border-radius:24px;background:var(--panel);color:var(--faint)}
.list-search input{flex:1;align-self:stretch;height:auto;margin:0;padding:0;background:none;border:none;outline:none;color:var(--text);font:400 15px/normal Roboto,sans-serif;min-width:0}
.list-search input::placeholder{color:var(--faint)}
.list-search .material-symbols-outlined{font-size:22px;line-height:1;display:flex;align-items:center}
.dp-card .list-search{background:#272A2F}
.list-sort{display:flex;align-items:center;gap:8px;height:40px;padding:0 14px;border:1px solid var(--line2);border-radius:20px;font:500 14px/20px Roboto;color:var(--dim);cursor:pointer;white-space:nowrap}
.list-sort:hover{background:#272A2F}
.list-wrap{flex:1;min-height:0;display:flex;flex-direction:column;padding:0 40px 20px}
.list-head{background:var(--panel);border-radius:16px 16px 0 0;padding:0 24px;flex:none;display:grid;gap:24px;border-bottom:1px solid var(--line2)}
.list-head-col{display:flex;align-items:center;gap:6px;height:48px;font:500 12px/16px Roboto;letter-spacing:.08em;text-transform:uppercase;color:var(--dim);cursor:pointer}
.list-head-col:not(.sortable){cursor:default}
.list-head-col.active{color:var(--info)}
.list-head-col .material-symbols-outlined{font-size:16px;color:var(--faint)}
.list-head-col.active .material-symbols-outlined{color:var(--info)}
.list-body{flex:1;min-height:0;overflow-y:auto;background:var(--panel);border-radius:0 0 16px 16px;padding:6px 0}
.list-row{padding:0 24px;display:grid;gap:24px;align-items:center;height:52px;cursor:pointer}
.list-row:hover{background:#22262B}
.list-row .c1{font:400 15px/22px Roboto;overflow-wrap:anywhere;overflow:hidden;text-overflow:ellipsis;white-space:nowrap}
.list-row .c2{font:400 14px/20px 'Roboto Mono',monospace;color:var(--dim)}
.list-row .c2.faint{color:var(--faint)}
.list-tag{height:24px;padding:0 10px;border-radius:6px;border:1px solid var(--line2);color:var(--dim);font:500 12px/22px Roboto;white-space:nowrap;display:inline-block}
.list-tag.warn{background:var(--warn-container);color:var(--warn);border:none;line-height:24px}
.list-empty-row{padding:40px 24px;text-align:center;color:var(--faint)}
.list-pager{flex:none;display:flex;align-items:center;gap:16px;padding:14px 4px 0}
.list-pager-count{font:400 14px/20px Roboto;color:var(--faint)}
.list-pager-nums{margin-left:auto;display:flex;align-items:center;gap:4px}
.list-pager-btn{width:40px;height:40px;border-radius:20px;display:grid;place-items:center;color:var(--dim);cursor:pointer;background:none;border:none;font-family:inherit}
.list-pager-btn:hover{background:#272A2F}
.list-pager-btn:disabled{color:var(--line2);cursor:default}
.list-pager-btn:disabled:hover{background:none}
.list-pager-num{min-width:40px;height:40px;padding:0 12px;box-sizing:border-box;border-radius:20px;color:var(--dim);font:500 14px/40px Roboto;text-align:center;cursor:pointer;background:none;border:none;font-family:inherit}
.list-pager-num:hover{background:#272A2F}
.list-pager-num.on{background:var(--info-c);color:var(--info-on-c)}

/* Event Viewer */
.evt-layout{flex:1;min-height:0;display:flex;gap:20px;padding:0 40px 40px}
.evt-facets{width:220px;flex:none;overflow-y:auto;display:flex;flex-direction:column;gap:2px}
.evt-facets-label{font:500 11px/16px Roboto;letter-spacing:.09em;text-transform:uppercase;color:var(--faint);padding:4px 10px 10px}
.evt-facet-item{display:flex;align-items:center;gap:10px;padding:9px 10px;border-radius:8px;cursor:pointer;font:400 14px/20px Roboto;color:var(--dim);overflow:hidden}
.evt-facet-item:hover{background:#272A2F}
.evt-facet-item.on{background:var(--info-c);color:var(--info-on-c)}
.evt-facet-item .t{flex:1;min-width:0;overflow:hidden;text-overflow:ellipsis;white-space:nowrap}
.evt-facet-item .n{flex:none;color:var(--faint);font:400 12px/16px Roboto}
.evt-facet-item.on .n{color:var(--info-on-c);opacity:.75}
.evt-list-col{flex:1;min-width:0;display:flex;flex-direction:column;gap:12px;min-height:0}
.evt-list-col .list-search{flex:none}
.evt-rows{flex:1;min-height:0;overflow-y:auto;display:flex;flex-direction:column;gap:2px;background:var(--panel);border-radius:16px;padding:8px}

/* Unexpected Shutdowns */
.dev-badge.info{background:#272A2F;color:var(--info)}

/* Diagnostic Summary page */
#diagsummaryView{padding:0}
#diagHead{padding:24px 40px 20px;display:flex;flex-direction:column;gap:16px;flex:none}
#diagCrumb{display:flex;align-items:center;gap:8px;min-height:40px}
#diagCrumb .crumb{font:400 13px/18px Roboto;color:var(--faint);display:flex;align-items:center;gap:6px}
#diagCrumb .crumb b{color:var(--dim);font-weight:400}
#diagActions{margin-left:auto;display:flex;gap:8px}
#diagTitle{font:400 32px/40px Roboto}
#diagSub{font:400 14px/20px Roboto;color:var(--faint);margin-top:4px}
#diagStats{padding:0 40px 14px;display:flex;gap:12px;flex-wrap:wrap;flex:none}
.diag-stat{flex:1;min-width:150px;background:var(--panel);border:1px solid var(--line);border-radius:12px;padding:12px 16px;display:flex;align-items:center;gap:12px;cursor:pointer}
.diag-stat:hover{background:#22262B}
.diag-stat.on{border-color:var(--dim)}
.diag-stat.crit{background:var(--err-container);border-color:var(--err-c)}
.diag-stat.warn{background:var(--warn-container);border-color:var(--warn-c)}
.diag-stat .material-symbols-outlined{font-size:22px}
.diag-stat-n{font:400 24px/28px Roboto}
.diag-stat-l{font:500 12px/16px Roboto}
#diagToolbar{padding:0 40px 12px;flex:none}
#diagSearchBox{display:flex;align-items:center;gap:10px;height:42px;padding:0 16px;border-radius:21px;background:var(--panel);color:var(--faint)}
#diagSearchBox .material-symbols-outlined{font-size:20px}
#diagSearch{background:none;border:none;outline:none;color:var(--text);font:400 14px/normal Roboto,sans-serif;flex:1;align-self:stretch;margin:0;padding:0;min-width:0}
#diagSearchBox .material-symbols-outlined{line-height:1;display:flex;align-items:center}
#diagSearch::placeholder{color:var(--faint)}
#diagBody{padding:0 40px 40px;flex:1;min-height:0;overflow-y:auto}
.diag-group-head{display:flex;align-items:center;gap:10px;padding:16px 2px 6px}
.diag-group-label{font:500 11px/16px Roboto;letter-spacing:.08em;text-transform:uppercase}
.diag-group-label.crit{color:var(--err)}
.diag-group-label.warn{color:var(--warn)}
.diag-group-count{font:400 12px/16px Roboto;color:var(--faint)}
.diag-group-line{flex:1;height:1px;background:var(--line)}
.diag-row{display:flex;align-items:center;gap:16px;padding:12px 14px;border-radius:10px}
.diag-row:hover{background:#22262B}
.diag-crit-box{background:var(--err-container);border-left:3px solid var(--err);border-radius:10px;padding:4px 0;overflow:hidden}
.diag-crit-box .diag-row{border-radius:0}
.diag-crit-box .diag-row+.diag-row{border-top:1px solid rgba(255,255,255,.06)}
.diag-crit-box .diag-row:hover{background:rgba(255,255,255,.04)}
.diag-row-main{flex:1;min-width:0;font:400 14px/20px Roboto}
.diag-chip{flex:none;height:24px;padding:0 9px;border-radius:8px;background:#272A2F;color:var(--info);font:500 11px/24px Roboto;white-space:nowrap;cursor:pointer}
.diag-chip:hover{background:var(--info-c);color:var(--info-on-c)}
@media (max-width:680px){#diagHead{padding:20px 16px}#diagStats,#diagToolbar,#diagBody{padding-left:16px;padding-right:16px}#diagTitle{font-size:24px;line-height:30px}}

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
.drive.smart-warn{border-color:var(--warn)}
.disk-card.vol-card-err{border-color:var(--err)}
.disk-card.vol-card-warn{border-color:var(--warn)}
.disk-card.highlight-flash,.dp-card.highlight-flash{animation:diskFlash 1.6s ease-out}
.slot-grid{display:grid;gap:10px}
.slot-chip{margin-left:0;height:36px;font-size:13px;line-height:36px;justify-content:center;cursor:pointer;min-width:0;overflow:hidden;text-overflow:ellipsis}
.slot-chip:hover{background:var(--info-c);color:var(--info-on-c)}
.slot-chip.empty{border:1px dashed var(--line2);background:none;cursor:default}
.slot-chip.empty:hover{background:none;color:inherit}
@keyframes diskFlash{0%{box-shadow:0 0 0 3px var(--info)}100%{box-shadow:0 0 0 0 rgba(0,0,0,0)}}

/* device cards (Devices tab) */
.sub-label{color:var(--faint);font-size:13px;text-transform:uppercase;letter-spacing:.06em;margin:0 0 10px}
.device-grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(240px,1fr));gap:14px;margin-bottom:24px}
.device-grid:last-child{margin-bottom:0}
.device-grid.compact{grid-template-columns:repeat(auto-fit,minmax(200px,1fr));gap:10px}
.dcard{background:var(--panel);border:1px solid var(--line);border-radius:12px;padding:16px;display:flex;gap:12px;align-items:flex-start}
.dcard.err-card{border-color:var(--err)}
.dcard-icon{width:34px;height:34px;border-radius:8px;display:flex;align-items:center;justify-content:center;flex-shrink:0}
.dcard-icon svg{width:17px;height:17px;fill:none;stroke-width:1.8;stroke-linecap:round;stroke-linejoin:round}
.dcard-body{min-width:0;flex:1}
.dcard-title{font-size:14.5px;font-weight:500;overflow-wrap:break-word}
.dcard-badge{display:inline-block;font-size:11.5px;padding:2px 7px;border-radius:20px;margin-top:6px;margin-right:5px}
.badge-info{color:var(--info);background:color-mix(in srgb,var(--info) 14%,transparent)}
.badge-ok{color:var(--ok);background:color-mix(in srgb,var(--ok) 14%,transparent)}
.badge-warn{color:var(--warn);background:color-mix(in srgb,var(--warn) 14%,transparent)}
.badge-err{color:var(--err);background:color-mix(in srgb,var(--err) 14%,transparent)}
.dcard-desc{color:var(--faint);font-size:13px;margin-top:6px;line-height:1.4}
.icon-info{background:color-mix(in srgb,var(--info) 16%,transparent)}.icon-info svg{stroke:var(--info)}
.icon-ok{background:color-mix(in srgb,var(--ok) 16%,transparent)}.icon-ok svg{stroke:var(--ok)}
.icon-warn{background:color-mix(in srgb,var(--warn) 16%,transparent)}.icon-warn svg{stroke:var(--warn)}
.icon-err{background:color-mix(in srgb,var(--err) 16%,transparent)}.icon-err svg{stroke:var(--err)}
.icon-dim{background:color-mix(in srgb,var(--dim) 16%,transparent)}.icon-dim svg{stroke:var(--dim)}
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
.prog-row{display:grid;grid-template-columns:1fr 110px;padding:5px 4px;border-bottom:1px solid color-mix(in srgb,var(--line) 40%,transparent);font-size:14.5px;font-family:'Albert Sans',sans-serif;color:var(--text)}
.prog-row span:nth-child(2){text-align:right;color:var(--dim);font-family:'IBM Plex Mono',monospace;font-size:13px}
.prog-head{display:grid;grid-template-columns:1fr 110px;color:var(--faint);font-size:13px;text-transform:uppercase;letter-spacing:.06em;padding:6px 4px;border-bottom:1px solid var(--line);margin-top:8px}
.prog-head span:nth-child(2){text-align:right}
@media (max-width:600px){.kv{grid-template-columns:1fr;gap:0}.kv dt{margin-top:8px}}
h1{font-size:24px;font-weight:600;letter-spacing:.01em}
#range{color:var(--dim);font-size:14px}
#drop{display:flex;align-items:center;justify-content:center;gap:8px;height:44px;margin:0 16px 24px;border:none;border-radius:22px;background:#3B4858;color:#D7E3F8;font:500 15px/20px Roboto;cursor:pointer;text-align:center}
#drop:hover{background:#465464}
#drop .material-symbols-outlined{font-size:20px}
body.dragging #drop{background:var(--info-c);color:var(--info-on-c)}

/* timeline */
.rel-content{flex:1;min-height:0;padding:0 40px 40px;display:flex;flex-direction:column;gap:14px}
#timeline{background:var(--panel);border-radius:16px;padding:20px 24px 16px;display:flex;flex-direction:column;gap:14px;flex:none}
#controls{flex:none}
#list{flex:1;min-height:0;overflow-y:auto}
#tlHead{display:flex;align-items:center;gap:14px}
#tlLabel{font:500 11px/16px Roboto;letter-spacing:.09em;text-transform:uppercase;color:var(--faint)}
#tlRange{color:var(--dim);font:400 14px/20px Roboto}
#tl-inner{display:flex;align-items:stretch;gap:10px}
#tl-main{flex:1;min-width:0}
.tl-nav{background:none;border:none;border-radius:20px;color:var(--dim);font-size:22px;width:40px;cursor:pointer;font-family:inherit}
.tl-nav:hover:not(:disabled){background:#272A2F;color:var(--text)}
.tl-nav:disabled{opacity:.3;cursor:default}
#bars{display:flex;align-items:flex-end;gap:10px;height:132px}
.bar{flex:1;display:flex;flex-direction:column-reverse;gap:2px;cursor:pointer;min-width:4px}
.bar div{width:100%;border-radius:3px}
.bar .seg-err{background:var(--err)}
.bar .seg-warn{background:var(--warn)}
.bar .seg-ok{background:#3B4858}
.bar.clean .seg-ok{opacity:.45}
.bar.active{outline:2px solid var(--info);outline-offset:3px;border-radius:4px}
#axis{display:flex;gap:10px;margin-top:6px}
.axis-lab{flex:1;text-align:center;color:var(--faint);font:400 12px/16px 'Roboto Mono',monospace;white-space:nowrap;overflow:hidden}
.axis-lab.active{color:var(--info);font-weight:500}

/* controls */
#controls{padding:14px 0;display:flex;gap:10px;flex-wrap:wrap;align-items:center}
.chip{display:flex;align-items:center;gap:8px;height:36px;padding:0 14px;border-radius:8px;background:none;border:1px solid var(--line2);font:500 14px/34px Roboto;color:var(--dim);cursor:pointer;font-family:inherit}
.chip:hover{background:#272A2F}
.chip .material-symbols-outlined{font-size:18px}
.chip .n{font-weight:400;opacity:.75;margin-left:0}
.chip.c-err.on{background:var(--err-c);color:var(--err-on-c);border-color:transparent}
.chip.c-warn.on{background:var(--warn-c);color:var(--warn);border-color:transparent}
.chip.c-info.on{background:var(--info-c);color:var(--info-on-c);border-color:transparent}
.chip.src-chip.on{background:#272A2F;color:var(--text);border-color:var(--dim)}
.chip-sep{width:1px;height:24px;background:var(--line2);margin:0 4px}
.src-tag{flex:none;font:500 11px/22px Roboto;padding:0 8px;border-radius:6px;background:#272A2F;color:var(--dim);white-space:nowrap}
.src-tag.src-both{color:var(--info)}
#search{background:var(--panel);border:none;border-radius:22px;color:var(--text);padding:0 18px;height:44px;font:400 15px/44px Roboto;font-family:inherit;flex:1 1 100%;order:-1;margin:0 0 4px;outline:none}
#search::placeholder{color:var(--faint)}
#search::placeholder{color:var(--faint)}
#search:focus{outline:none}
#clearDay{display:none;align-items:center;gap:6px;height:36px;padding:0 10px 0 14px;border-radius:8px;background:var(--info-c);color:var(--info-on-c);font:500 14px/36px Roboto;cursor:pointer;border:none;font-family:inherit}

/* rows */
#list{padding:8px 0 48px}
.day-head{display:flex;align-items:center;gap:12px;padding:12px 4px 10px;color:var(--text);font:500 16px/22px Roboto}
.day-head .n{font:400 14px/20px Roboto;color:var(--faint)}
.day-head .ln{flex:1;height:1px;background:var(--line)}
.sev-head{display:flex;align-items:center;gap:8px;padding:8px 4px;font:500 12px/16px Roboto;letter-spacing:.08em;text-transform:uppercase}
.sev-head .n{font-weight:400;letter-spacing:0;text-transform:none;color:var(--faint)}
.sev-err{color:var(--err)}.sev-warn{color:var(--warn)}.sev-info{color:var(--dim)}
.row{display:flex;align-items:center;gap:18px;padding:12px 18px;border-radius:12px;cursor:pointer;margin-bottom:2px;flex-wrap:wrap}
.row:hover{background:#22262B}
.row.open{background:#22262B}
.row.cat-err{background:var(--err-container);border-left:4px solid var(--err)}
.time{width:52px;flex:none;color:var(--faint);font:500 14px/20px 'Roboto Mono',monospace}
.row.cat-err .time{color:var(--dim)}
.dot{width:10px;height:10px;border-radius:50%;flex:none}
.d-err{background:var(--err)}.d-warn{background:var(--warn)}.d-info{background:var(--info)}
.title{flex:1;min-width:0;font:500 16px/22px Roboto;overflow:hidden;text-overflow:ellipsis;white-space:nowrap}
.row.open .title{white-space:normal}
.row.cat-err .title{color:var(--err-on-c)}
.src{display:block;color:var(--faint);font:400 14px/20px Roboto;margin-left:0}
.row.cat-err .src{color:var(--dim)}
.evt-meta{flex:none;font:500 13px/26px 'Roboto Mono',monospace;color:var(--dim);background:#111418;border:1px solid var(--line2);border-radius:8px;padding:0 10px}
.evt-chevron{flex:none;color:var(--faint)}
.row.cat-err .evt-chevron{color:var(--err)}
.msg{color:var(--dim);font:400 14px/22px 'Roboto Mono',monospace;padding:12px 0 2px;white-space:pre-wrap;display:none;word-break:break-word;cursor:text;user-select:text;width:100%}
.row.open .msg{display:block;background:#111418;border-radius:10px;padding:14px 16px;margin-top:2px}
.shut-facts{display:none;width:100%;grid-template-columns:130px 1fr;gap:8px 16px;background:#111418;border-radius:10px;padding:14px 16px;font:400 14px/20px Roboto;color:var(--text);cursor:text}
.row.open .shut-facts{display:grid}
.sf-k{color:var(--faint)}
.sf-dim{color:var(--faint)}
.sf-err{color:var(--err)}
.shut-facts a{color:var(--info);cursor:pointer;text-decoration:underline;text-decoration-style:dotted;text-underline-offset:3px}
.faq-row{padding:9px 8px}
#empty{color:var(--faint);padding:40px 0;text-align:center;display:none}
@media (max-width:600px){
  #search{width:100%;margin-left:0}
  #pageTitle{font-size:28px;padding:24px 16px 0}
}@media print{
  body,#appShell,#content{height:auto!important;overflow:visible!important}
  #sidebar{display:none!important}
  .dp-view,#summaryView,#diagsummaryView,#relView{display:block!important}
  .dp-body,.dp-split,.dp-content,.rel-content,#summaryBody,#diagBody,#list,.evt-layout,.evt-facets,.evt-rows{overflow:visible!important;height:auto!important;flex:none!important}
  .dp-actions,#summaryActions,#diagActions{display:none!important}
}
</style>
</head>
<body class="tab-summary">
<div id="appShell">
<aside id="sidebar">
  <div id="brand"><span class="material-symbols-outlined">monitor_heart</span><div>PCHH Triage<div id="brand-sub"></div></div></div>
  <label id="drop"><span class="material-symbols-outlined">upload_file</span>Open another CSV<input type="file" accept=".csv" hidden></label>
  <nav id="tabs">
    <div class="nav-group">
      <div class="nav-group-title static"><span>Overview</span></div>
      <div class="nav-group-items">
        <button class="tab on" data-tab="summary"><span class="material-symbols-outlined">dashboard</span><span class="tab-label">Summary</span></button>
      </div>
    </div>
    <div class="nav-group">
      <div class="nav-group-title"><span>Diagnostics</span><span class="material-symbols-outlined chev">expand_more</span></div>
      <div class="nav-group-items">
        <button class="tab" data-tab="diagsummary"><span class="material-symbols-outlined">fact_check</span><span class="tab-label">Summary</span><span class="tab-badge" id="diagTabBadge" style="display:none"></span></button>
        <button class="tab" data-tab="rel"><span class="material-symbols-outlined">timeline</span><span class="tab-label">Events</span><span class="tab-badge" id="relTabBadge" style="display:none"></span></button>
        <button class="tab" data-tab="dumps" id="dumpsTab" style="display:none"><span class="material-symbols-outlined">description</span><span class="tab-label">Memory Dumps</span></button>
      </div>
    </div>
    <div class="nav-group collapsed">
      <div class="nav-group-title"><span>Hardware</span><span class="material-symbols-outlined chev">expand_more</span></div>
      <div class="nav-group-items">
        <button class="tab" data-tab="cpu"><span class="material-symbols-outlined">memory</span><span class="tab-label">Processor</span><span class="tab-badge warn" id="cpuTabBadge" style="display:none"></span></button>
        <button class="tab" data-tab="gpu"><span class="material-symbols-outlined">videogame_asset</span><span class="tab-label">Graphics</span><span class="tab-badge warn" id="gpuTabBadge" style="display:none"></span></button>
        <button class="tab" data-tab="memory"><span class="material-symbols-outlined">developer_board</span><span class="tab-label">Memory</span><span class="tab-badge warn" id="memoryTabBadge" style="display:none"></span></button>
        <button class="tab" data-tab="drives"><span class="material-symbols-outlined">hard_drive</span><span class="tab-label">Storage</span><span class="tab-badge warn" id="drivesTabBadge" style="display:none"></span></button>
        <button class="tab" data-tab="mobo"><span class="material-symbols-outlined">dashboard_customize</span><span class="tab-label">Motherboard</span><span class="tab-badge warn" id="moboTabBadge" style="display:none"></span></button>
        <button class="tab" data-tab="battery" id="batteryTab" style="display:none"><span class="material-symbols-outlined">battery_full</span><span class="tab-label">Battery</span></button>
        <button class="tab" data-tab="net"><span class="material-symbols-outlined">lan</span><span class="tab-label">Network</span><span class="tab-badge warn" id="netTabBadge" style="display:none"></span></button>
        <button class="tab" data-tab="devices"><span class="material-symbols-outlined">devices_other</span><span class="tab-label">Devices</span><span class="tab-badge warn" id="devicesTabBadge" style="display:none"></span></button>
      </div>
    </div>
    <div class="nav-group collapsed">
      <div class="nav-group-title"><span>Software</span><span class="material-symbols-outlined chev">expand_more</span></div>
      <div class="nav-group-items">
        <button class="tab" data-tab="apps"><span class="material-symbols-outlined">apps</span><span class="tab-label">Installed Programs</span><span class="tab-badge warn" id="appsTabBadge" style="display:none"></span></button>
        <button class="tab" data-tab="processes"><span class="material-symbols-outlined">memory_alt</span><span class="tab-label">Running Processes</span></button>
        <button class="tab" data-tab="updates"><span class="material-symbols-outlined">system_update</span><span class="tab-label">Windows Updates</span><span class="tab-badge warn" id="updatesTabBadge" style="display:none"></span></button>
        <button class="tab" data-tab="extensions"><span class="material-symbols-outlined">extension</span><span class="tab-label">Browser Extensions</span></button>
        <button class="tab" data-tab="security"><span class="material-symbols-outlined">shield</span><span class="tab-label">Security</span><span class="tab-badge" id="securityTabBadge" style="display:none"></span></button>
      </div>
    </div>
    <div class="nav-group collapsed">
      <div class="nav-group-title"><span>Help</span><span class="material-symbols-outlined chev">expand_more</span></div>
      <div class="nav-group-items">
        <button class="tab" data-tab="faq"><span class="material-symbols-outlined">help</span><span class="tab-label">FAQ</span></button>
        <button class="tab" data-tab="tools"><span class="material-symbols-outlined">construction</span><span class="tab-label">Tools &amp; Utilities</span></button>
      </div>
    </div>
  </nav>
  <div id="sideFoot"><span id="pageFoot"></span></div>
</aside>
<main id="content">

<h1 id="pageTitle">PCHH Triage <span id="pageTitleSub">- Summary</span></h1>

<div id="summaryView" class="view">
  <div id="summaryHead">
    <div id="summaryCrumb"><span class="crumb">Overview <span class="material-symbols-outlined" style="font-size:16px">chevron_right</span> <b>Summary</b></span>
      <div id="summaryActions">
        <div class="m3-btn" id="copySpecsBtn"><span class="material-symbols-outlined" style="font-size:18px">content_copy</span>Copy</div>
      </div>
    </div>
    <div id="summaryTitleRow">
      <div style="min-width:0">
        <div id="summaryTitle"></div>
        <div id="summarySub"></div>
      </div>
      <div id="summaryChip" onclick="return goTab('diagsummary')"><span class="status-dot"></span><span id="summaryChipText"></span></div>
    </div>
  </div>
  <div id="summaryBody">
    <div id="summaryHero"></div>
  </div>
</div>

<div id="diagsummaryView" class="view">
  <div id="diagHead">
    <div id="diagCrumb"><span class="crumb">Diagnostics <span class="material-symbols-outlined" style="font-size:16px">chevron_right</span> <b>Diagnostic Summary</b></span>
      <div id="diagActions">
        <div class="m3-btn" id="copyNotesBtn"><span class="material-symbols-outlined" style="font-size:18px">content_copy</span>Copy</div>
      </div>
    </div>
    <div>
      <div id="diagTitle">Diagnostic summary</div>
      <div id="diagSub"></div>
    </div>
  </div>
  <div id="diagStats"></div>
  <div id="diagToolbar">
    <div id="diagSearchBox"><span class="material-symbols-outlined">search</span><input id="diagSearch" placeholder="Search notes, components, event IDs"></div>
  </div>
  <div id="diagBody"></div>
</div>

<div id="relView" class="view dp-view">
<div class="dp-head">
  <div class="dp-crumb"><span class="crumb">Diagnostics <span class="material-symbols-outlined" style="font-size:16px">chevron_right</span> <b>Events</b></span>
    <div class="dp-actions">
      <div class="m3-btn" id="copyRelBtn"><span class="material-symbols-outlined" style="font-size:18px">content_copy</span>Copy</div>
      <div class="m3-btn filled" id="printRelBtn"><span class="material-symbols-outlined" style="font-size:18px">print</span>Print</div>
    </div>
  </div>
  <div><div class="dp-title">Events</div><div class="dp-sub" id="relSub"></div></div>
</div>
<div class="rel-content">
<div id="timeline">
  <div id="tlHead"><span id="tlLabel">Events per day</span><span id="tlRange" class="mono"></span>
    <div style="margin-left:auto;display:flex;gap:4px">
      <button id="tlPrev" class="tl-nav" title="Earlier"><span class="material-symbols-outlined">chevron_left</span></button>
      <button id="tlNext" class="tl-nav" title="Later"><span class="material-symbols-outlined">chevron_right</span></button>
    </div>
  </div>
  <div id="tl-inner">
    <div id="tl-main"><div id="bars"></div><div id="axis"></div></div>
  </div>
</div>

<div id="controls">
  <button class="chip c-err" data-cat="err"><span class="material-symbols-outlined">error</span>Error<span class="n"></span></button>
  <button class="chip c-warn" data-cat="warn"><span class="material-symbols-outlined">warning</span>Warnings<span class="n"></span></button>
  <button class="chip c-info" data-cat="info">Informational<span class="n"></span></button>
  <span class="chip-sep"></span>
  <button class="chip src-chip" data-src="">All sources<span class="n"></span></button>
  <button class="chip src-chip" data-src="rel">Reliability<span class="n"></span></button>
  <button class="chip src-chip" data-src="sys">System log<span class="n"></span></button>
  <button id="clearDay"></button>
  <input id="search" type="text" placeholder="Search program, source, message or event ID">
</div>

<div id="list"></div>
<div id="empty">No events match.</div>
</div>
</div>

<div id="moboView" class="view dp-view"></div>
<div id="cpuView" class="view dp-view"></div>
<div id="drivesView" class="view dp-view"></div>
<div id="gpuView" class="view dp-view"></div>
<div id="memoryView" class="view dp-view"></div>
<div id="batteryView" class="view"></div>
<div id="netView" class="view dp-view"></div>
<div id="devicesView" class="view dp-view"></div>
<div id="securityView" class="view dp-view"></div>
<div id="processesView" class="view dp-view"></div>
<div id="appsView" class="view dp-view"></div>
<div id="updatesView" class="view dp-view"></div>
<div id="extensionsView" class="view dp-view"></div>
<div id="faqView" class="view"></div>
<div id="toolsView" class="view"><div class="spec-section"><h2>Diagnostics &amp; Monitoring</h2><div class="drive-grid"><a class="drive tool-card" id="tool-hwinfo" data-tool="HWiNFO" href="https://www.hwinfo.com/download/" target="_blank" rel="noopener"><h3>HWiNFO</h3><div class="sub" style="line-height:1.5">Real-time hardware sensor monitoring &mdash; temperatures, voltages, clock speeds, fan speeds.</div></a><a class="drive tool-card" id="tool-cpu-z" data-tool="CPU-Z" href="https://www.cpuid.com/softwares/cpu-z.html" target="_blank" rel="noopener"><h3>CPU-Z</h3><div class="sub" style="line-height:1.5">Quick reference for CPU, motherboard, and RAM specifications.</div></a><a class="drive tool-card" id="tool-gpu-z" data-tool="GPU-Z" href="https://www.techpowerup.com/gpuz/" target="_blank" rel="noopener"><h3>GPU-Z</h3><div class="sub" style="line-height:1.5">CPU-Z's GPU-focused equivalent &mdash; driver version, VRAM, clocks, sensors.</div></a><a class="drive tool-card" id="tool-crystaldiskinfo" data-tool="CrystalDiskInfo" href="https://crystalmark.info/en/software/crystaldiskinfo/" target="_blank" rel="noopener"><h3>CrystalDiskInfo</h3><div class="sub" style="line-height:1.5">Drive health and SMART status at a glance.</div></a><a class="drive tool-card" id="tool-hdsentinel" data-tool="HDSentinel" href="https://www.hdsentinel.com/" target="_blank" rel="noopener"><h3>HDSentinel</h3><div class="sub" style="line-height:1.5">Alternative drive health monitor with predictive failure estimates and more detailed SMART reporting.</div></a><a class="drive tool-card" id="tool-latencymon" data-tool="LatencyMon" href="https://www.resplendence.com/latencymon" target="_blank" rel="noopener"><h3>LatencyMon</h3><div class="sub" style="line-height:1.5">Measures system latency and DPC issues &mdash; the standard tool for diagnosing audio crackling and stuttering.</div></a></div></div><div class="spec-section"><h2>Stability &amp; Stress Testing</h2><div class="drive-grid"><a class="drive tool-card" id="tool-memtest86" data-tool="MemTest86" href="https://www.memtest86.com/" target="_blank" rel="noopener"><h3>MemTest86</h3><div class="sub" style="line-height:1.5">Bootable RAM stability test, run outside Windows &mdash; the standard way to confirm or rule out bad memory.</div></a><a class="drive tool-card" id="tool-occt" data-tool="OCCT" href="https://www.ocbase.com/" target="_blank" rel="noopener"><h3>OCCT</h3><div class="sub" style="line-height:1.5">Combined CPU/GPU/RAM stress test with built-in stability and error detection.</div></a><a class="drive tool-card" id="tool-furmark" data-tool="FurMark" href="https://geeks3d.com/furmark/" target="_blank" rel="noopener"><h3>FurMark</h3><div class="sub" style="line-height:1.5">GPU stress test &mdash; useful for spotting thermal throttling or instability under sustained load.</div></a></div></div><div class="spec-section"><h2>Crash Analysis</h2><div class="drive-grid"><a class="drive tool-card" id="tool-whocrashed" data-tool="WhoCrashed" href="https://www.resplendence.com/whocrashed" target="_blank" rel="noopener"><h3>WhoCrashed</h3><div class="sub" style="line-height:1.5">Plain-English analysis of minidump files &mdash; pairs directly with the .dmp files this tool collects.</div></a><a class="drive tool-card" id="tool-windbg" data-tool="WinDbg" href="https://learn.microsoft.com/en-us/windows-hardware/drivers/debugger/debugger-download-tools" target="_blank" rel="noopener"><h3>WinDbg</h3><div class="sub" style="line-height:1.5">Microsoft's own debugger &mdash; a more advanced tool for reading minidumps in full detail, down to the exact stack trace.</div></a></div></div><div class="spec-section"><h2>Advanced System Tools</h2><div class="drive-grid"><a class="drive tool-card" id="tool-process-explorer" data-tool="Process Explorer" href="https://learn.microsoft.com/en-us/sysinternals/downloads/process-explorer" target="_blank" rel="noopener"><h3>Process Explorer</h3><div class="sub" style="line-height:1.5">A far deeper Task Manager replacement from Microsoft's Sysinternals suite &mdash; inspect loaded DLLs, handles, and process trees.</div></a><a class="drive tool-card" id="tool-autoruns" data-tool="Autoruns" href="https://learn.microsoft.com/en-us/sysinternals/downloads/autoruns" target="_blank" rel="noopener"><h3>Autoruns</h3><div class="sub" style="line-height:1.5">The definitive startup-entry inspector from Sysinternals &mdash; see and control everything set to launch with Windows, in far more depth than this report's own startup check.</div></a></div></div><div class="spec-section"><h2>Cleanup &amp; Disk Space</h2><div class="drive-grid"><a class="drive tool-card" id="tool-bleachbit" data-tool="BleachBit" href="https://www.bleachbit.org/" target="_blank" rel="noopener"><h3>BleachBit</h3><div class="sub" style="line-height:1.5">Clears temporary files and caches to free up disk space.</div></a><a class="drive tool-card" id="tool-wiztree" data-tool="WizTree" href="https://diskanalyzer.com/" target="_blank" rel="noopener"><h3>WizTree</h3><div class="sub" style="line-height:1.5">Visualises what's actually taking up space on a drive.</div></a></div></div><div class="spec-section"><h2>Driver Management</h2><div class="drive-grid"><div class="drive tool-card-group" id="tool-display-driver-uninstaller-ddu" data-tool="Display Driver Uninstaller (DDU)"><a class="tool-card-link" href="https://www.wagnardsoft.com/" target="_blank" rel="noopener"><h3>Display Driver Uninstaller (DDU)</h3><div class="sub" style="line-height:1.5">Fully removes GPU drivers before a clean reinstall &mdash; the standard fix for driver-related instability.</div></a><a class="tool-video-link" href="https://youtu.be/ULgWBAlgpfk" target="_blank" rel="noopener">&#9654; Watch tutorial</a></div><a class="drive tool-card" id="tool-amd-drivers-amp-support" data-tool="AMD Drivers &amp; Support" href="https://www.amd.com/en/support" target="_blank" rel="noopener"><h3>AMD Drivers &amp; Support</h3><div class="sub" style="line-height:1.5">Official AMD driver downloads.</div></a><a class="drive tool-card" id="tool-nvidia-drivers-amp-support" data-tool="NVIDIA Drivers &amp; Support" href="https://www.nvidia.com/Download/index.aspx" target="_blank" rel="noopener"><h3>NVIDIA Drivers &amp; Support</h3><div class="sub" style="line-height:1.5">Official NVIDIA driver downloads.</div></a><a class="drive tool-card" id="tool-intel-drivers-amp-support" data-tool="Intel Drivers &amp; Support" href="https://www.intel.com/content/www/us/en/support/detect.html" target="_blank" rel="noopener"><h3>Intel Drivers &amp; Support</h3><div class="sub" style="line-height:1.5">Official Intel driver downloads.</div></a></div></div><div class="spec-section"><h2>Installation Media</h2><div class="drive-grid"><div class="drive tool-card-group" id="tool-windows-11-download" data-tool="Windows 11 Download"><a class="tool-card-link" href="https://www.microsoft.com/software-download/windows11" target="_blank" rel="noopener"><h3>Windows 11 Download</h3><div class="sub" style="line-height:1.5">Official Microsoft page for Windows 11 installation media.</div></a><a class="tool-video-link" href="https://youtu.be/TiqcfvO_8Tc" target="_blank" rel="noopener">&#9654; Watch tutorial</a></div><a class="drive tool-card" id="tool-rufus" data-tool="Rufus" href="https://rufus.ie/" target="_blank" rel="noopener"><h3>Rufus</h3><div class="sub" style="line-height:1.5">Creates bootable USB installers from a Windows ISO &mdash; the alternative to the official Windows 11 media creation tool.</div></a></div></div><div class="spec-section"><h2>Motherboard / BIOS Vendor Support</h2><div class="drive-grid"><a class="drive tool-card" id="tool-asus-support" data-tool="ASUS Support" href="https://www.asus.com/support/" target="_blank" rel="noopener"><h3>ASUS Support</h3><div class="sub" style="line-height:1.5">Official ASUS driver and BIOS downloads.</div></a><a class="drive tool-card" id="tool-msi-support" data-tool="MSI Support" href="https://www.msi.com/support/" target="_blank" rel="noopener"><h3>MSI Support</h3><div class="sub" style="line-height:1.5">Official MSI driver and BIOS downloads.</div></a><a class="drive tool-card" id="tool-gigabyte-support" data-tool="Gigabyte Support" href="https://www.gigabyte.com/Support" target="_blank" rel="noopener"><h3>Gigabyte Support</h3><div class="sub" style="line-height:1.5">Official Gigabyte driver and BIOS downloads.</div></a><a class="drive tool-card" id="tool-asrock-support" data-tool="ASRock Support" href="https://www.asrock.com/support/index.asp" target="_blank" rel="noopener"><h3>ASRock Support</h3><div class="sub" style="line-height:1.5">Official ASRock driver and BIOS downloads.</div></a><a class="drive tool-card" id="tool-dell-support" data-tool="Dell Support" href="https://www.dell.com/support/home/" target="_blank" rel="noopener"><h3>Dell Support</h3><div class="sub" style="line-height:1.5">Official Dell driver and BIOS downloads (by service tag).</div></a><a class="drive tool-card" id="tool-hp-support" data-tool="HP Support" href="https://support.hp.com/" target="_blank" rel="noopener"><h3>HP Support</h3><div class="sub" style="line-height:1.5">Official HP driver and BIOS downloads.</div></a><a class="drive tool-card" id="tool-lenovo-support" data-tool="Lenovo Support" href="https://support.lenovo.com/" target="_blank" rel="noopener"><h3>Lenovo Support</h3><div class="sub" style="line-height:1.5">Official Lenovo driver and BIOS downloads.</div></a></div></div></div>
<div id="dumpsView" class="view"></div>

</main>
<div id="smartModal" class="modal-overlay"><div class="modal-box"><button class="modal-close" id="smartModalClose">&times;</button><div id="smartModalBody"></div></div></div>
</div>

<script>
const RAW = /*__DATA__*/[];
const SPECS = /*__SPECS__*/"";
const DUMPS = /*__DUMPS__*/[];
const SYSEVT = /*__SYSEVT__*/[];
const SMART = /*__SMART__*/[];
const DIRTY = /*__DIRTY__*/[];
const DISKLAYOUT = /*__DISKLAYOUT__*/[];
const RAM = /*__RAM__*/[];
const PROGRAMS = /*__PROGRAMS__*/[];
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
  // The PowerShell side always formats timestamps as MM/dd/yyyy (see every ToString("MM'/'dd'/'yyyy...")
  // call in the collector) - never locale-dependent DD/MM. Guessing the order from the numbers
  // themselves silently mis-parsed any date where the day-of-month was 12 or under (e.g. 09/11
  // read as day 9 of month 11 instead of day 11 of month 9), scattering real events across the
  // wrong months and leaving the reliability timeline looking flat.
  const m = s.match(/(\d{1,2})\/(\d{1,2})\/(\d{4})[ ,]+(\d{1,2}):(\d{2}):(\d{2})\s*(AM|PM)?/i);
  if(!m) return null;
  let [,mon,day,y,h,mi,se,ap] = m;
  mon=+mon;day=+day;h=+h;
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
const CATNAMES={err:'Error events',warn:'Warnings',info:'Informational events'};

// events = the merged Events timeline: reliability history + curated System log entries, with the
// separate records of one unexpected shutdown (6008 in both logs, Kernel-Power 41) folded into a
// single incident row. relEvents keeps reliability history on its own for the summary counts.
let events=[], relEvents=[], state={cats:new Set(['err','warn']), src:null, q:'', day:null, tlEnd:null};
function sysCat(lvl){return lvl<=2?'err':lvl===3?'warn':'info';}
const SRC_LABEL={rel:'Reliability',sys:'System log',both:'Reliability + System log'};
const TL_WIN=14;

function load(raw){
  SHUTS_=null;
  relEvents = raw.map(r=>{
    const d=parseDate(r.t);
    return {...r, d, cat:classify(r), src:'rel', dayKey:d?d.toISOString().slice(0,10):'?'};
  }).filter(e=>e.d).sort((a,b)=>b.d-a.d);
  const sysEvents=SYSEVT.map(r=>{
    const d=parseDate(r.t);
    return {t:r.t, s:r.prov, e:String(r.id), p:r.prov, m:r.msg||'', bc:r.bc, cnt:r.cnt, d, cat:sysCat(r.lvl), src:'sys', dayKey:d?d.toISOString().slice(0,10):'?'};
  }).filter(e=>e.d);
  const shuts=getShutdowns();
  const isShutPart=e=>(e.src==='rel'&&e.s==='EventLog')||(e.src==='sys'&&(e.e==='41'||e.e==='6008'));
  const shutRows=shuts.map(x=>{
    const parts=[...relEvents,...sysEvents].filter(e=>isShutPart(e)&&Math.abs(e.d-x.d)<2*60*1000);
    return {kind:'shutdown', shut:x, d:x.when, cat:'err', p:'Unexpected shutdown', s:'', e:'',
      src:(x.rel&&(x.kp||x.sys))?'both':(x.rel?'rel':'sys'),
      m:parts.map(e=>'['+SRC_LABEL[e.src]+' \u00b7 '+e.s+' '+e.e+' \u00b7 logged '+fmtTime(e.d)+']\n'+e.m).join('\n\n'),
      dayKey:x.when.toISOString().slice(0,10), _parts:parts};
  });
  const absorbed=new Set(shutRows.flatMap(r=>r._parts));
  events=[...relEvents,...sysEvents].filter(e=>!absorbed.has(e)).concat(shutRows).sort((a,b)=>b.d-a.d);
  const relErrCount=events.filter(e=>e.cat==='err').length;
  const relBadgeEl=document.getElementById('relTabBadge');
  if(relBadgeEl){ if(relErrCount){relBadgeEl.textContent=relErrCount;relBadgeEl.style.display='';} else {relBadgeEl.style.display='none';} }
  state.day=null;
  state.tlEnd=null;
  render();
}

function fmtDay(k){const d=new Date(k);const dd=String(d.getDate()).padStart(2,'0');const mm=String(d.getMonth()+1).padStart(2,'0');return mm+'/'+dd+'/'+d.getFullYear();}
function fmtDayShort(k){const d=new Date(k);return (d.getMonth()+1)+'/'+d.getDate();}
function fmtTime(d){return d.toLocaleTimeString('en-GB',{hour:'2-digit',minute:'2-digit'});}

function render(){
  // counts per category (unfiltered by cat, filtered by search+day)
  const matchQ=e=>!state.q || ((e.p||'')+' '+e.m+' '+e.s+' '+e.e+(e.kind==='shutdown'?' unexpected shutdown '+e.shut.cause:'')).toLowerCase().includes(state.q);
  const matchSrc=e=>!state.src || e.src===state.src || e.src==='both';
  const base = events.filter(e=>(!state.day||e.dayKey===state.day) && matchQ(e) && matchSrc(e));
  document.querySelectorAll('.chip[data-src]').forEach(c=>{
    const v=c.dataset.src||null;
    c.classList.toggle('on',state.src===v);
    const n=c.querySelector('.n'); if(n)n.textContent=events.filter(e=>(!state.day||e.dayKey===state.day)&&matchQ(e)&&(!v||e.src===v||e.src==='both')).length;
  });
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
    if(!matchQ(e)||!matchSrc(e)) return;
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
    bar.title=fmtDay(k)+' \u00b7 '+tot+' event'+(tot===1?'':'s')+(b.err?' ('+b.err+' error)':'');
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
  cd.style.display=state.day?'flex':'none';
  cd.innerHTML=state.day?(fmtDay(state.day)+'<span class="material-symbols-outlined" style="font-size:18px">close</span>'):'';

  // list grouped by day
  const list=document.getElementById('list');
  list.innerHTML='';
  const dayGroups=new Map();
  shown.forEach(e=>{
    if(!dayGroups.has(e.dayKey))dayGroups.set(e.dayKey,{err:[],warn:[],info:[]});
    dayGroups.get(e.dayKey)[e.cat].push(e);
  });
  dayGroups.forEach((groups,dayKey)=>{
    const dayTotal=groups.err.length+groups.warn.length+groups.info.length;
    const h=document.createElement('div');h.className='day-head';
    h.innerHTML='<span>'+fmtDay(dayKey)+'</span><span class="n">'+dayTotal+' event'+(dayTotal===1?'':'s')+'</span><span class="ln"></span>';
    list.appendChild(h);
    ['err','warn','info'].forEach(cat=>{
      const evs=groups[cat];
      if(!evs.length)return;
      const sh=document.createElement('div');sh.className='sev-head sev-'+cat;
      sh.innerHTML=esc(CATNAMES[cat])+(evs.length>1?' <span class="n">'+evs.length+'</span>':'');
      list.appendChild(sh);
      const crashKey=m=>(m||'')
        .replace(/Faulting process id:.*$/m,'')
        .replace(/Faulting application start time:.*$/m,'')
        .replace(/Report Id:.*$/m,'')
        .replace(/Faulting package-relative application ID:.*$/m,'')
        .trim();
      const groupsByKey=new Map();
      evs.forEach(e=>{
        const key=e.kind==='shutdown'?'shut|'+e.d.getTime():(e.src+'|'+(e.p||'')+'|'+e.s+'|'+crashKey(e.m));
        if(!groupsByKey.has(key))groupsByKey.set(key,[]);
        groupsByKey.get(key).push(e);
      });
      [...groupsByKey.values()].forEach(dupes=>{
        const e=dupes[0];
        const row=document.createElement('div');row.className='row cat-'+e.cat;
        const open=false; // collapsed by default for an at-a-glance list; click a row for detail
        const times=dupes.map(x=>fmtTime(x.d));
        const shut=e.kind==='shutdown'?e.shut:null;
        let title=esc(e.p||'(unnamed)');
        if(!shut&&e.src==='sys'&&e.bc&&String(e.bc)!=='0')title+=' <span style="color:var(--err)">\u00b7 Bugcheck 0x'+esc(parseInt(e.bc).toString(16).toUpperCase())+'</span>';
        const n=dupes.length>1?dupes.length:(+e.cnt>1?+e.cnt:0);
        if(n)title+=' <span style="color:var(--faint);font-weight:400">\u00d7'+n+'</span>';
        const meta=shut?'':esc(e.s)+' \u00b7 '+esc(e.e);
        row.innerHTML='<span class="time mono">'+times[0]+'</span>'+
          '<span class="dot d-'+e.cat+'"></span>'+
          '<div style="flex:1;min-width:0"><div class="title">'+title+'</div><div class="src">'+summary(e)+'</div></div>'+
          '<span class="src-tag src-'+e.src+'">'+esc(SRC_LABEL[e.src])+'</span>'+
          (meta?'<span class="evt-meta mono">'+meta+'</span>':'')+
          '<span class="material-symbols-outlined evt-chevron">'+(open?'expand_less':'expand_more')+'</span>'+
          (shut?shutFactsHtml(shut):'')+
          '<div class="msg mono">'+esc(e.m)+(dupes.length>1?'\n\nAlso at: '+times.slice(1).join(', '):'')+'</div>';
        if(open)row.classList.add('open');
        row.onclick=(ev)=>{ if(ev.target.closest('.msg')||hasTextSelection())return; row.classList.toggle('open'); row.querySelector('.evt-chevron').textContent=row.classList.contains('open')?'expand_less':'expand_more'; };
        row.querySelector('.msg').onclick=ev=>ev.stopPropagation();
        list.appendChild(row);
      });
    });
  });
  document.getElementById('empty').style.display=shown.length?'none':'block';

  const relSubEl=document.getElementById('relSub');
  if(relSubEl&&events.length){
    relSubEl.textContent=events.length+' event'+(events.length===1?'':'s')+' from reliability history and the System log \u00b7 '+fmtDay(events[events.length-1].dayKey)+' \u2013 '+fmtDay(events[0].dayKey);
  }
}
function summary(e){
  if(e.kind==='shutdown')return esc(e.shut.bcLabel?'Blue screen \u00b7 '+e.shut.bcLabel:e.shut.cause);
  if(e.src==='sys'){
    if(/WHEA/i.test(e.s))return 'Hardware error reported by the CPU/chipset';
    if(e.e==='4101')return 'Display driver stopped responding and recovered';
    return e.cat==='err'?'System error':e.cat==='warn'?'System warning':'System event';
  }
  if(e.cat==='err'){
    if(e.s==='Application Error')return 'Stopped working';
    if(e.s==='EventLog')return 'Windows was not properly shut down';
    return 'Error event';
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
function fmtSize(gb){return gb>=1000?(gb/1000).toFixed(1)+' TB':Math.round(gb)+' GB';}
function fmtFree(gb){return gb>=1000?(gb/1000).toFixed(1)+'TB':gb.toFixed(1)+'GB';}
// Hero tile icons - reused verbatim from the matching sidebar tab icon wherever one exists
// (GPU, Storage, Memory), so a tile visually promises "click me to see more" honestly. CPU,
// Motherboard and System have no dedicated tab of their own, so they get their own icon.


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
document.querySelectorAll('.chip[data-src]').forEach(c=>c.onclick=()=>{
  state.src=c.dataset.src||null;
  render();
});
document.getElementById('clearDay').onclick=()=>{state.day=null;render();};
document.getElementById('tlPrev').onclick=()=>{state.tlEnd=Math.max(TL_WIN-1,state.tlEnd-TL_WIN);render();};
document.getElementById('tlNext').onclick=()=>{state.tlEnd=state.tlEnd+TL_WIN;render();};
document.getElementById('search').oninput=e=>{state.q=e.target.value.toLowerCase();render();};
const copyRelBtn=document.getElementById('copyRelBtn');
if(copyRelBtn)copyRelBtn.onclick=()=>{
  const rows=[...document.querySelectorAll('#list .row')].map(r=>r.textContent.replace(/\s*\n\s*/g,' ').trim());
  const txt=rows.join('\n');
  const done=()=>{const old=copyRelBtn.innerHTML;copyRelBtn.innerHTML='<span class="material-symbols-outlined" style="font-size:18px">check</span>Copied';setTimeout(()=>{copyRelBtn.innerHTML=old;},1500);};
  if(navigator.clipboard&&navigator.clipboard.writeText)navigator.clipboard.writeText(txt).then(done).catch(()=>{});
  else{const ta=document.createElement('textarea');ta.value=txt;document.body.appendChild(ta);ta.select();document.execCommand('copy');document.body.removeChild(ta);done();}
};
const printRelBtn=document.getElementById('printRelBtn');
if(printRelBtn)printRelBtn.onclick=()=>window.print();

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
  rd.onload=()=>{try{load(parseCSV(rd.result));syncNavGroups(false);}catch(err){alert('Could not parse that CSV: '+err.message);}};
  rd.readAsText(f);
}
document.querySelector('#drop input').onchange=e=>e.target.files[0]&&handleFile(e.target.files[0]);
['dragover','dragenter'].forEach(ev=>document.addEventListener(ev,e=>{e.preventDefault();document.body.classList.add('dragging');}));
['dragleave','drop'].forEach(ev=>document.addEventListener(ev,e=>{e.preventDefault();document.body.classList.remove('dragging');}));
document.addEventListener('drop',e=>{const f=e.dataTransfer.files[0];if(f)handleFile(f);});

// --- specs parsing & rendering ---
function parseSpecs(text){
  const out={info:[],drives:[]};
  if(!text||!text.trim())return out;
  const norm=text.replace(/\r/g,'');
  const [head, rest] = splitOnce(norm, /^Drive Information:\s*$/m);
  head.split('\n').forEach(l=>{
    const m=l.match(/^([^:]+):\s?(.*)$/);
    if(m&&m[2]!=='')out.info.push([m[1].trim(),m[2].trim()]);
  });
  let cur=null;
  (rest||'').split('\n').forEach(l=>{
    const m=l.match(/^([^:]+):\s?(.*)$/);
    if(!m)return;
    const k=m[1].trim(),v=m[2].trim();
    if(k==='Drive Label'){cur={};out.drives.push(cur);}
    if(cur)cur[k]=v;
  });
  return out;
}
function splitOnce(text,re){
  const m=text.match(re);
  if(!m)return[text,''];
  return[text.slice(0,m.index),text.slice(m.index+m[0].length)];
}
function renderSpecs(){
  const sp=parseSpecs(SPECS);
  const v=document.getElementById('drivesView');
  if(!(sp.drives&&sp.drives.length) && !DISKLAYOUT.length && !SMART.length){
    v.innerHTML='<div class="dp-head"><div class="dp-crumb"><span class="crumb">Hardware <span class="material-symbols-outlined" style="font-size:16px">chevron_right</span> <b>Storage</b></span></div>'+
      '<div class="dp-title-row"><div><div class="dp-title">Storage</div></div></div></div>'+
      '<div class="dp-content"><div class="disk-card"><div class="dp-empty">No storage data embedded.</div></div></div>';
    return;
  }

  const letterToDisk={};
  DISKLAYOUT.forEach(dk=>{(dk.partitions||[]).forEach(p=>{if(p.letter)letterToDisk[p.letter]=dk.disk;});});
  const smartByDisk={};
  SMART.forEach(d=>{smartByDisk[String(d.disk)]=d;});
  const TYPE_COLOR={'EFI System Partition':'#5C7AA6','Recovery':'var(--warn)','Recovery (MBR)':'var(--warn)','Microsoft Reserved':'#8C6FA6','Data':'var(--info-c)','System':'var(--dim)','Unallocated':'var(--panel)'};

  const drivesWithSize=(sp.drives||[]).filter(dr=>+dr['Total Size (GB)']>0);
  const totalAllGB=drivesWithSize.reduce((a,dr)=>a+(+dr['Total Size (GB)']||0),0);
  const freeAllGB=drivesWithSize.reduce((a,dr)=>a+(+dr['Free Space (GB)']||0),0);
  const diskCount=DISKLAYOUT.length||SMART.length;
  const storageTitle='Storage'+(totalAllGB?' '+fmtSize(totalAllGB)+' across '+diskCount+' disk'+(diskCount===1?'':'s'):'');
  const subParts=[drivesWithSize.length?drivesWithSize.length+' volume'+(drivesWithSize.length===1?'':'s'):'',totalAllGB?fmtFree(freeAllGB)+' free of '+fmtSize(totalAllGB):''].filter(Boolean);

  let anyLow=false,anyBad=false;
  drivesWithSize.forEach(dr=>{
    const totalGB=+dr['Total Size (GB)']||0, freeGB=+dr['Free Space (GB)']||0;
    const freePct=dr['Percentage Free (%)']!=null?Math.round(+dr['Percentage Free (%)']):Math.round(freeGB/totalGB*100);
    if(freePct<10)anyLow=true;
  });
  let anyCrc=false;
  SMART.forEach(d=>{ if(smartProbs(d).length)anyBad=true; else if(smartCrcProbs(d).length)anyCrc=true; });
  const statusCls=anyBad?'err':((anyLow||anyCrc)?'warn':'ok');
  const warnCountHere=(anyLow?1:0)+(anyBad?1:0)+(anyCrc?1:0);
  const statusText=anyBad?'SMART warning on this component':(anyCrc&&!anyLow)?'CRC errors on a drive':((anyLow||anyCrc)?warnCountHere+' warning'+(warnCountHere>1?'s':'')+' on this component':'No problems found');
  const drivesBadgeEl=document.getElementById('drivesTabBadge');
  if(drivesBadgeEl){ if(warnCountHere){drivesBadgeEl.textContent=warnCountHere;drivesBadgeEl.className='tab-badge'+(anyBad?'':' warn');drivesBadgeEl.style.display='';} else {drivesBadgeEl.style.display='none';} }

  let h='<div class="dp-head"><div class="dp-crumb"><span class="crumb">Hardware <span class="material-symbols-outlined" style="font-size:16px">chevron_right</span> <b>Storage</b></span>'+
    '<div class="dp-actions"><div class="m3-btn" id="copyStorageBtn"><span class="material-symbols-outlined" style="font-size:18px">content_copy</span>Copy</div></div></div>'+
    '<div class="dp-title-row"><div><div class="dp-title">'+esc(storageTitle)+'</div><div class="dp-sub">'+esc(subParts.join(' \u00b7 '))+'</div></div>'+
    '<div class="dp-status '+statusCls+'"><span class="status-dot"></span>'+esc(statusText)+'</div></div></div>';

  h+='<div class="dp-content">';

  if(drivesWithSize.length){
    h+='<div><div class="dp-section-label">Volumes</div><div class="vol-grid">';
    const drivesSorted=[...drivesWithSize].sort((a,b)=>(a['Drive Label']||'').localeCompare(b['Drive Label']||''));
    drivesSorted.forEach(dr=>{
      const totalGB=+dr['Total Size (GB)']||0, freeGB=+dr['Free Space (GB)']||0;
      const usedPct=Math.min(100,Math.round((totalGB-freeGB)/totalGB*100));
      const freePct=dr['Percentage Free (%)']!=null?Math.round(+dr['Percentage Free (%)']):Math.round(freeGB/totalGB*100);
      const low=freePct<10;
      const diskNum=letterToDisk[dr['Drive Label']];
      const sm=diskNum!=null?smartByDisk[String(diskNum)]:null;
      const bad=sm?smartProbs(sm).length>0:false;
      const crcWarn=!bad&&sm?smartCrcProbs(sm).length>0:false;
      const winName=(dr['Drive Name']&&dr['Drive Name']!=='No Name Found')?dr['Drive Name']:'Local Disk';
      let chip='';
      if(bad)chip='<span class="vol-chip err"><span class="material-symbols-outlined">error</span>SMART issue</span>';
      else if(crcWarn)chip='<span class="vol-chip warn"><span class="material-symbols-outlined">warning</span>CRC errors</span>';
      else if(low)chip='<span class="vol-chip warn"><span class="material-symbols-outlined">warning</span>'+freePct+'% free</span>';
      else if(sm&&sm.health)chip='<span class="vol-chip ok">'+esc(sm.health)+'</span>';
      h+='<div class="vol-card'+(bad?' vol-card-err':(low||crcWarn)?' vol-card-warn':'')+'"'+(diskNum!=null?' onclick="highlightDisk(\''+esc(diskNum)+'\')"':'')+'>'+
        '<div class="vol-top"><div class="vol-letter">'+esc(winName)+' ('+esc(dr['Drive Label']||'?')+')</div>'+
        '<div class="vol-sub">'+(diskNum!=null?'Disk '+esc(diskNum):'')+(sm&&sm.bus?' \u00b7 '+esc(sm.bus):'')+'</div>'+chip+'</div>'+
        '<div class="vol-bar-track"><div class="vol-bar-fill'+(bad?' err':low?' warn':'')+'" style="width:'+usedPct+'%"></div></div>'+
        '<div class="vol-foot"><span style="color:'+(low?'var(--warn)':'var(--dim)')+'">'+fmtFree(freeGB)+' free</span><span style="color:var(--faint)">of '+fmtSize(totalGB)+'</span></div>'+
        '</div>';
    });
    h+='</div></div>';
  }

  if(DISKLAYOUT.length||SMART.length){
    const usedSmartIds={};
    const disksSorted=[...DISKLAYOUT].sort((a,b)=>(+a.disk)-(+b.disk));
    h+='<div><div class="dp-section-label">Disk Layout</div>';
    disksSorted.forEach(dk=>{
      const partSum=dk.partitions.reduce((a,p)=>a+p.sizeGB,0);
      const total=dk.sizeGB||partSum||1;
      const unallocGB=Math.max(0,total-partSum);
      const parts=unallocGB>0.5?[...dk.partitions,{type:'Unallocated',sizeGB:unallocGB,letter:''}]:dk.partitions;
      const sm=smartByDisk[String(dk.disk)];
      if(sm)usedSmartIds[String(dk.disk)]=true;
      const crit=sm?smartProbs(sm):[];
      const crcProbs=sm?smartCrcProbs(sm):[];
      const bad=crit.length>0;
      const warnOnly=!bad&&crcProbs.length>0;
      const clickable=!!sm;
      const healthLabel=(sm&&sm.health&&!(bad&&/^healthy$/i.test(sm.health)))?sm.health+(sm.op&&sm.op!=='OK'&&sm.op!==sm.health?' ('+sm.op+')':''):'';
      h+='<div class="disk-card'+(bad?' vol-card-err':warnOnly?' vol-card-warn':'')+'" id="diskBlock-'+esc(dk.disk)+'">';
      h+='<div class="disk-top"><div class="disk-name">Disk '+esc(dk.disk)+'</div>'+
        (sm&&sm.name?'<div class="disk-model">'+esc(sm.name)+'</div>':'')+
        (sm&&sm.bus?'<span class="vol-chip plain">'+esc(sm.bus)+'</span>':'')+
        (healthLabel?'<span class="vol-chip '+(bad?'err':warnOnly?'warn':'ok')+'">SMART: '+esc(healthLabel)+'</span>':'')+
        '<div class="disk-size">'+fmtSize(dk.sizeGB)+'</div>'+
        (clickable?'<span class="material-symbols-outlined disk-expand" onclick="openSmartModal(\''+esc(dk.disk)+'\')">open_in_full</span>':'')+
        '</div>';
      h+='<div class="disk-bar">';
      // A small minimum width keeps a tiny EFI/MSR sliver visible, but clamping several of them
      // up without giving something back means the segments can add up to well over 100% and
      // spill the bar past the edge of the card - rescale everything back down to fit exactly.
      const rawPcts=parts.map(p=>Math.max(1.5,(p.sizeGB/total*100)));
      const pctSum=rawPcts.reduce((a,b)=>a+b,0);
      const scale=pctSum>100?100/pctSum:1;
      parts.forEach((p,pi)=>{
        const pctW=rawPcts[pi]*scale;
        const col=TYPE_COLOR[p.type]||'var(--dim)';
        const isUnalloc=p.type==='Unallocated';
        const style=isUnalloc?'flex:0 0 '+pctW+'%;background:repeating-linear-gradient(135deg,var(--panel2),var(--panel2) 4px,var(--line) 4px,var(--line) 8px);border:1px dashed var(--faint);box-sizing:border-box;display:flex;align-items:center;justify-content:center'
          :'flex:0 0 '+pctW+'%;background:'+col+';display:flex;align-items:center;padding:0 14px;gap:10px;overflow:hidden';
        const tip=esc(p.type)+(p.letter?' ('+esc(p.letter)+')':'')+' \u00b7 '+p.sizeGB.toFixed(1)+' GB';
        const label=isUnalloc?(pctW>10?'<span style="font:400 13px/18px Roboto;color:var(--faint)">Unallocated \u00b7 '+fmtSize(p.sizeGB)+'</span>':'')
          :(pctW>12?'<span style="font:500 14px/20px Roboto;color:#D1E4FF">'+esc(p.letter||'')+'</span><span style="font:400 13px/18px Roboto;color:#A0CAFD">'+esc(p.type)+' \u00b7 '+fmtSize(p.sizeGB)+'</span>':'');
        h+='<div style="'+style+'" onmouseenter="showPartTip(event,\''+tip.replace(/'/g,"\\'")+'\')" onmousemove="positionPartTip(event)" onmouseleave="hidePartTip()">'+label+'</div>';
      });
      h+='</div>';
      h+='<div class="disk-legend">'+parts.map(p=>{
        const isUnalloc=p.type==='Unallocated';
        const swatch=isUnalloc?'background:repeating-linear-gradient(135deg,var(--panel2),var(--panel2) 2px,var(--line) 2px,var(--line) 4px)':'background:'+(TYPE_COLOR[p.type]||'var(--dim)');
        return '<span class="sw"><span class="dot" style="'+swatch+'"></span>'+esc(p.type)+(p.letter?' ('+esc(p.letter)+')':'')+' \u00b7 '+fmtSize(p.sizeGB)+'</span>';
      }).join('')+'</div>';
      if(unallocGB>0.5){
        const pctUnalloc=Math.round(unallocGB/total*100);
        h+='<div class="dp-banner" onclick="return goFaq(\'unallocated-space\')"><span class="material-symbols-outlined">warning</span>'+
          '<div class="dp-banner-text">'+fmtSize(unallocGB)+' ('+pctUnalloc+'%) is not assigned to any partition \u2014 commonly left behind after cloning to a larger drive.</div>'+
          '<span class="dp-banner-link">Unallocated disk space \u2192</span></div>';
      } else if(bad||warnOnly){
        h+='<div style="color:'+(bad?'var(--err)':'var(--warn)')+';font:400 13.5px/19px Roboto;cursor:pointer" onclick="openSmartModal(\''+esc(dk.disk)+'\')">\u26a0 '+(bad?'SMART warning':'CRC errors')+' &mdash; click for details</div>';
      }
      h+='</div>';
    });
    SMART.forEach(sm=>{
      if(usedSmartIds[String(sm.disk)])return;
      const crit=smartProbs(sm);
      const crcProbs=smartCrcProbs(sm);
      const bad=crit.length>0;
      const warnOnly=!bad&&crcProbs.length>0;
      const healthLabel=(sm.health&&!(bad&&/^healthy$/i.test(sm.health)))?sm.health+(sm.op&&sm.op!=='OK'&&sm.op!==sm.health?' ('+sm.op+')':''):'';
      h+='<div class="disk-card'+(bad?' vol-card-err':warnOnly?' vol-card-warn':'')+'" id="diskBlock-'+esc(sm.disk)+'">'+
        '<div class="disk-top"><div class="disk-name">Disk '+esc(sm.disk)+'</div>'+
        (sm.name?'<div class="disk-model">'+esc(sm.name)+'</div>':'')+
        (sm.bus?'<span class="vol-chip plain">'+esc(sm.bus)+'</span>':'')+
        (healthLabel?'<span class="vol-chip '+(bad?'err':warnOnly?'warn':'ok')+'">SMART: '+esc(healthLabel)+'</span>':'')+
        '<span class="material-symbols-outlined disk-expand" onclick="openSmartModal(\''+esc(sm.disk)+'\')">open_in_full</span></div>'+
        (bad?'<div style="color:var(--err);font-size:13.5px;cursor:pointer" onclick="openSmartModal(\''+esc(sm.disk)+'\')">\u26a0 SMART warning \u2014 click for details</div>'
          :warnOnly?'<div style="color:var(--warn);font-size:13.5px;cursor:pointer" onclick="openSmartModal(\''+esc(sm.disk)+'\')">\u26a0 CRC errors \u2014 click for details</div>':'')+
        '<div class="disk-mismatch-note">No partition layout available for this drive (disk numbering mismatch between data sources)</div>'+
        '</div>';
    });
    h+='</div>';

    const alerts=[];
    SMART.forEach(d=>{
      const probs=smartProbs(d);
      const crc=smartCrcProbs(d);
      if(probs.length)alerts.push('<div class="dp-flag-row" style="background:var(--err-container);color:var(--err)"><span class="material-symbols-outlined">error</span>Disk '+esc(d.disk)+' ('+esc(d.name)+'): '+esc(probs.join(', '))+'</div>');
      if(crc.length)alerts.push('<div class="dp-flag-row">Disk '+esc(d.disk)+' ('+esc(d.name)+'): '+esc(crc.join(', '))+'</div>');
    });
    DIRTY.forEach(dv=>alerts.push('<div class="dp-flag-row">Volume '+esc(dv)+' has its dirty bit set</div>'));
    h+='<div><div class="dp-section-label">SMART data</div>'+
      (alerts.length?'<div style="display:flex;flex-direction:column;gap:8px">'+alerts.join('')+'</div>'
       :'<div class="disk-card" style="color:var(--ok)">\u2713 No SMART issues found. All disks report Healthy with no uncorrected errors.</div>')+'</div>';
  }

  h+='</div>';
  v.innerHTML=h;
  const copyBtn=document.getElementById('copyStorageBtn');
  if(copyBtn)copyBtn.onclick=()=>{
    const txt=v.textContent.replace(/\s*\n\s*/g,'\n').trim();
    const done=()=>{const old=copyBtn.innerHTML;copyBtn.innerHTML='<span class="material-symbols-outlined" style="font-size:18px">check</span>Copied';setTimeout(()=>{copyBtn.innerHTML=old;},1500);};
    if(navigator.clipboard&&navigator.clipboard.writeText)navigator.clipboard.writeText(txt).then(done).catch(()=>{});
    else{const ta=document.createElement('textarea');ta.value=txt;document.body.appendChild(ta);ta.select();document.execCommand('copy');document.body.removeChild(ta);done();}
  };
}
const PS_={q:'',page:1,key:'mem',dir:-1}, PG_={q:'',page:1,key:'date',dir:-1,flagFilter:'any'};
let PROGS_ALL=[];
function renderProcesses(){
  const v=document.getElementById('processesView');
  if(!PROCS.length){
    v.innerHTML='<div class="dp-head"><div class="dp-crumb"><span class="crumb">Software <span class="material-symbols-outlined" style="font-size:16px">chevron_right</span> <b>Running Processes</b></span></div>'+
      '<div class="dp-title-row"><div><div class="dp-title">Running processes</div></div></div></div>'+
      '<div class="dp-content"><div class="dp-card"><div class="dp-empty">No process data embedded.</div></div></div>';
    return;
  }
  const totalInstances=PROCS.reduce((a,p)=>a+(+p.cnt||0),0);
  const totalMemMB=PROCS.reduce((a,p)=>a+(+p.mem||0),0);
  const totalMemGB=totalMemMB/1024;

  let h='<div class="dp-head"><div class="dp-crumb"><span class="crumb">Software <span class="material-symbols-outlined" style="font-size:16px">chevron_right</span> <b>Running Processes</b></span></div>'+
    '<div class="dp-title-row"><div><div class="dp-title">Running processes</div><div class="dp-sub">'+PROCS.length+' distinct process name'+(PROCS.length===1?'':'s')+' \u00b7 '+totalInstances+' instance'+(totalInstances===1?'':'s')+' \u00b7 '+(totalMemGB>=1?totalMemGB.toFixed(1)+' GB':Math.round(totalMemMB)+' MB')+' working set at capture</div></div></div></div>';

  h+='<div class="list-controls">'+
    '<div class="list-search"><span class="material-symbols-outlined">search</span><input id="procSearch" type="text" placeholder="Search process name"></div>'+
    '</div>';

  h+='<div class="list-wrap">'+
    '<div class="list-head" style="grid-template-columns:1fr 140px 140px">'+
      '<div class="list-head-col sortable" data-key="name">Process<span class="material-symbols-outlined" id="procSortIconName"></span></div>'+
      '<div class="list-head-col sortable" data-key="cnt">Instances<span class="material-symbols-outlined" id="procSortIconCnt"></span></div>'+
      '<div class="list-head-col sortable" data-key="mem">Memory<span class="material-symbols-outlined" id="procSortIconMem"></span></div>'+
    '</div>'+
    '<div class="list-body" id="procList"></div>'+
    '</div>'+
    '<div class="list-pager" id="procPager"></div>';

  v.innerHTML=h;
  const pf=document.getElementById('procSearch');
  if(pf)pf.oninput=e=>{PS_.q=e.target.value.toLowerCase();PS_.page=1;renderProcList();};
  v.querySelectorAll('.list-head-col.sortable').forEach(hd=>hd.onclick=()=>{
    const k=hd.dataset.key;
    if(PS_.key===k)PS_.dir=-PS_.dir; else {PS_.key=k;PS_.dir=k==='name'?1:-1;}
    PS_.page=1;renderProcList();
  });
  renderProcList();
}
function flagForProgram(name){
  for(const f of SOFT_FLAGS){ if(f.re.test(name)) return f; }
  return null;
}
function renderAppsList(programs){
  PROGS_ALL=programs||[];
  const v=document.getElementById('appsView');
  const appsBadgeEl=document.getElementById('appsTabBadge');
  if(!PROGS_ALL.length){
    v.innerHTML='<div class="dp-head"><div class="dp-crumb"><span class="crumb">Software <span class="material-symbols-outlined" style="font-size:16px">chevron_right</span> <b>Installed Programs</b></span></div>'+
      '<div class="dp-title-row"><div><div class="dp-title">Installed programs</div></div></div></div>'+
      '<div class="dp-content"><div class="dp-card"><div class="dp-empty">No program data embedded.</div></div></div>';
    if(appsBadgeEl)appsBadgeEl.style.display='none';
    return;
  }
  const foundSoft=getSoftwareFlags(PROGS_ALL);
  const flaggedCount=PROGS_ALL.filter(p=>flagForProgram(p.name)).length;
  const GROUP_ORDER=['bloat','periph','oc','ac','audio','remote','fan','net','wallpaper','shell','cheat'];
  // Open on the notable-software view (anything matching a flag group); fall back to the full list
  // when nothing is flagged so the page never opens empty.
  if(!flaggedCount&&PG_.flagFilter==='any')PG_.flagFilter=null;

  if(appsBadgeEl){ if(foundSoft.cheat&&foundSoft.cheat.size){appsBadgeEl.textContent=foundSoft.cheat.size;appsBadgeEl.className='tab-badge';appsBadgeEl.style.display='';}
    else if(flaggedCount){appsBadgeEl.textContent=flaggedCount;appsBadgeEl.className='tab-badge warn';appsBadgeEl.style.display='';}
    else appsBadgeEl.style.display='none'; }

  let h='<div class="dp-head"><div class="dp-crumb"><span class="crumb">Software <span class="material-symbols-outlined" style="font-size:16px">chevron_right</span> <b>Installed Programs</b></span>'+
    '<div class="dp-actions"><div class="m3-btn" id="copyAppsBtn"><span class="material-symbols-outlined" style="font-size:18px">content_copy</span>Copy</div></div></div>'+
    '<div class="dp-title-row"><div><div class="dp-title">Installed programs</div><div class="dp-sub">'+PROGS_ALL.length+' program'+(PROGS_ALL.length===1?'':'s')+' from the uninstall registry'+(flaggedCount?' \u00b7 '+flaggedCount+' matched a known-software flag':'')+'</div></div></div></div>';

  h+='<div class="list-flagband"><div class="list-flagband-inner">'+
    '<div class="list-flagband-label"><div class="l1">Flag groups found</div><div class="l2">Filter the list</div></div>'+
    '<div style="flex:1;min-width:0;display:flex;flex-wrap:wrap;gap:8px">'+
    '<span class="flagpill'+(flaggedCount?'':' zero')+'" data-grp="any">Notable software <span class="n">'+flaggedCount+'</span></span>'+
    '<span class="flagpill" data-grp="all">All programs <span class="n">'+PROGS_ALL.length+'</span></span>'+
    '<span class="flag-sep"></span>'+
    GROUP_ORDER.map(grp=>{
      const n=foundSoft[grp]?foundSoft[grp].size:0;
      return '<span class="flagpill'+(n?'':' zero')+'" data-grp="'+grp+'">'+esc(SOFT_GROUP_LABEL[grp])+' <span class="n">'+n+'</span></span>';
    }).join('')+
    '</div></div></div>';

  h+='<div class="list-controls">'+
    '<div class="list-search"><span class="material-symbols-outlined">search</span><input id="progSearch" type="text" placeholder="Search program name"></div>'+
    '<div class="list-sort" id="progSortToggle"><span class="material-symbols-outlined">calendar_month</span><span id="progSortLabel">Newest first</span></div>'+
    '</div>';

  h+='<div class="list-wrap">'+
    '<div class="list-head" style="grid-template-columns:1fr 200px 190px">'+
      '<div class="list-head-col sortable" data-key="name">Program<span class="material-symbols-outlined" id="progSortIconName"></span></div>'+
      '<div class="list-head-col sortable" data-key="date">Install date<span class="material-symbols-outlined" id="progSortIconDate"></span></div>'+
      '<div class="list-head-col sortable" data-key="flag">Flag group<span class="material-symbols-outlined" id="progSortIconFlag"></span></div>'+
    '</div>'+
    '<div class="list-body" id="progList"></div>'+
    '</div>'+
    '<div class="list-pager" id="progPager"></div>';

  v.innerHTML=h;
  const ps=document.getElementById('progSearch');
  if(ps)ps.oninput=e=>{PG_.q=e.target.value.toLowerCase();PG_.page=1;renderProgList();};
  v.querySelectorAll('.list-head-col.sortable').forEach(hd=>hd.onclick=()=>{
    const k=hd.dataset.key;
    if(PG_.key===k)PG_.dir=-PG_.dir; else {PG_.key=k;PG_.dir=k==='date'?-1:1;}
    PG_.page=1;renderProgList();
  });
  v.querySelectorAll('.flagpill:not(.zero)').forEach(p=>p.onclick=()=>{
    const g=p.dataset.grp;
    const home=flaggedCount?'any':null;
    PG_.flagFilter=g==='all'?null:g==='any'?'any':(PG_.flagFilter===g?home:g);
    PG_.page=1;renderProgList();
  });
  const sortToggle=document.getElementById('progSortToggle');
  if(sortToggle)sortToggle.onclick=()=>{ PG_.key='date'; PG_.dir=-PG_.dir; PG_.page=1; renderProgList(); };
  const copyBtn=document.getElementById('copyAppsBtn');
  if(copyBtn)copyBtn.onclick=()=>{
    const txt=PROGS_ALL.map(p=>p.name+(p.date?' ('+p.date+')':'')).join('\n');
    const done=()=>{const old=copyBtn.innerHTML;copyBtn.innerHTML='<span class="material-symbols-outlined" style="font-size:18px">check</span>Copied';setTimeout(()=>{copyBtn.innerHTML=old;},1500);};
    if(navigator.clipboard&&navigator.clipboard.writeText)navigator.clipboard.writeText(txt).then(done).catch(()=>{});
    else{const ta=document.createElement('textarea');ta.value=txt;document.body.appendChild(ta);ta.select();document.execCommand('copy');document.body.removeChild(ta);done();}
  };
  renderProgList();
}
function listPager(el,page,pages,total,onGo,pageSize){
  if(!el)return;
  const sz=pageSize||60;
  const shownFrom=total?((page-1)*sz+1):0;
  const shownTo=Math.min(page*sz,total);
  let h='<div class="list-pager-count">Showing '+shownFrom+'\u2013'+shownTo+' of '+total+'</div>';
  if(pages>1){
    h+='<div class="list-pager-nums">';
    h+='<button class="list-pager-btn" data-go="prev" '+(page<=1?'disabled':'')+'><span class="material-symbols-outlined">chevron_left</span></button>';
    const lo=Math.max(1,page-2), hi=Math.min(pages,page+2);
    for(let i=lo;i<=hi;i++)h+='<button class="list-pager-num'+(i===page?' on':'')+'" data-page="'+i+'">'+i+'</button>';
    h+='<button class="list-pager-btn" data-go="next" '+(page>=pages?'disabled':'')+'><span class="material-symbols-outlined">chevron_right</span></button>';
    h+='</div>';
  }
  el.innerHTML=h;
  el.querySelectorAll('[data-go]').forEach(b=>b.onclick=()=>onGo(b.dataset.go==='prev'?-1:1));
  el.querySelectorAll('[data-page]').forEach(b=>b.onclick=()=>onGo(0,+b.dataset.page));
}
const WH_={page:1};
function renderUpdates(){
  const v=document.getElementById('updatesView');
  const w=WINUPDATE;
  const failCount=WUHISTORY.filter(u=>u.result==='Failed'||u.result==='Cancelled').length;
  if(!w&&!WUHISTORY.length&&!HOTFIXES.length){
    v.innerHTML='<div class="dp-head"><div class="dp-crumb"><span class="crumb">Software <span class="material-symbols-outlined" style="font-size:16px">chevron_right</span> <b>Windows Updates</b></span></div>'+
      '<div class="dp-title-row"><div><div class="dp-title">Windows updates</div></div></div></div>'+
      '<div class="dp-content"><div class="dp-card"><div class="dp-empty">No update data embedded.</div></div></div>';
    return;
  }
  const lastInstall=HOTFIXES.length?HOTFIXES.slice().sort((a,b)=>(b.date||'').localeCompare(a.date||''))[0]:null;
  const verdictWarn=failCount>0;
  const verdictInfo=!verdictWarn&&w&&w.pendingReboot;
  const updatesBadgeEl=document.getElementById('updatesTabBadge');
  if(updatesBadgeEl){ if(failCount){updatesBadgeEl.textContent=failCount;updatesBadgeEl.style.display='';} else {updatesBadgeEl.style.display='none';} }

  let h='<div class="dp-head"><div class="dp-crumb"><span class="crumb">Software <span class="material-symbols-outlined" style="font-size:16px">chevron_right</span> <b>Windows Updates</b></span></div>'+
    '<div class="dp-title-row"><div><div class="dp-title">Windows updates</div>'+
    (lastInstall?'<div class="dp-sub">Last installed '+esc(lastInstall.date)+(failCount?' \u00b7 '+failCount+' recent attempt'+(failCount===1?'':'s')+' failed':'')+'</div>':'')+
    '</div></div></div>';

  h+='<div class="list-flagband"><div class="list-flagband-inner">'+
    '<span class="material-symbols-outlined" style="font-size:32px;color:'+(verdictWarn?'var(--warn)':verdictInfo?'var(--info)':'var(--ok)')+'">'+(verdictWarn?'warning':verdictInfo?'info':'check_circle')+'</span>'+
    '<div style="min-width:0">'+
    '<div style="font:500 16px/22px Roboto">'+(verdictWarn?failCount+' update'+(failCount===1?'':'s')+' did not complete successfully':verdictInfo?'A restart is pending to finish installing updates':'Windows is up to date')+'</div>'+
    (w&&w.serviceStatus?'<div class="dp-card-note" style="margin:2px 0 0">Windows Update service: '+esc(w.serviceStatus)+(w.serviceStartType?' ('+esc(w.serviceStartType)+')':'')+'</div>':'')+
    '</div></div></div>';

  h+='<div class="dp-body" style="padding-top:0;grid-template-columns:1fr">';
  if(HOTFIXES.length){
    h+='<div class="dp-card"><div class="dp-card-head"><div class="dp-card-title">Installed updates</div><span class="dp-card-count">'+HOTFIXES.length+'</span></div>'+
      '<div style="margin:4px 0 12px"><div class="list-search" style="height:40px"><span class="material-symbols-outlined" style="font-size:18px">search</span><input id="hfSearch" type="text" placeholder="Filter updates"></div></div>'+
      '<dl class="dp-kv" id="hfList"></dl><div class="list-pager" id="hfPager"></div></div>';
  }
  if(WUHISTORY.length){
    h+='<div class="dp-card"><div class="dp-card-head"><div class="dp-card-title">Update history</div><span class="dp-card-count">'+WUHISTORY.length+'</span></div>'+
      '<dl class="dp-kv" id="wuHistList"></dl><div class="list-pager" id="wuHistPager"></div></div>';
  }
  h+='</div>';

  v.innerHTML=h;
  const hf=document.getElementById('hfSearch');
  if(hf)hf.oninput=e=>{HF_.q=e.target.value.toLowerCase();HF_.page=1;renderHfList();};
  renderHfList();
  renderWuHistList();
}
function renderWuHistList(){
  const el=document.getElementById('wuHistList');if(!el)return;
  const SZ=8,pages=Math.max(1,Math.ceil(WUHISTORY.length/SZ));
  if(WH_.page>pages)WH_.page=pages;
  const slice=WUHISTORY.slice((WH_.page-1)*SZ,WH_.page*SZ);
  el.innerHTML=slice.map(u=>{
    const col=u.result==='Succeeded'?'var(--ok)':(u.result==='Failed'||u.result==='Cancelled')?'var(--err)':'var(--warn)';
    return '<dt>'+esc(u.date)+'</dt><dd>'+esc(u.title)+' <span style="color:'+col+'">('+esc(u.result)+')</span></dd>';
  }).join('')||'<dd style="color:var(--faint)">No update history.</dd>';
  listPager(document.getElementById('wuHistPager'),WH_.page,pages,WUHISTORY.length,(delta,jumpTo)=>{WH_.page=jumpTo?jumpTo:WH_.page+delta;renderWuHistList();},SZ);
}
const FAQ_DATA=[
{id:'app-crashes',q:"Application Crashes",a:"This counts how many times a program on your PC has crashed and forced Windows to close it, based on the "+tabLink('rel','Windows Reliability History')+".<br><br>Occasional crashes are normal, especially in games or browsers. A rising number, especially if they're all the same program or all mention the same driver file, usually points to that specific program, a graphics driver, or a plugin/mod rather than Windows itself.",tools:["WhoCrashed","Display Driver Uninstaller (DDU)"]},
{id:'unexpected-shutdown',q:"Unexpected Shutdowns",a:"Windows didn't shut down properly last time, meaning it never received the normal 'the user is turning off the PC' signal. This can be caused by:<ul style='margin:8px 0 8px 20px;padding:0'><li>a full system crash (a 'blue screen')</li><li>a power cut</li><li>overheating (thermal shutdown)</li><li>someone holding the power button</li><li>the PC freezing and being force-restarted</li></ul>If a specific bugcheck code is shown, that's the technical reason Windows gave. It can point toward whether this is a hardware, driver, or Windows problem. Most bugcheck codes are Google-able and have common fixes.<br><br>When Windows detects the power button was physically held down for 4+ seconds, it records that moment separately from the shutdown itself - that's shown as 'Power button held down' with the exact time, which usually means the PC was unresponsive and had to be force-closed rather than crashing cleanly with a bugcheck.",tools:["WhoCrashed","OCCT","MemTest86","Display Driver Uninstaller (DDU)"]},
{id:'memory-dump',q:"Memory Dump",a:"When Windows crashes badly, a 'blue screen' happens. Windows tries to save a snapshot of exactly what the computer was doing at that moment to a file called a memory dump.<br><br>Memory dump(s) are included in the zip this tool creates. If you have them, you can share the zip file with us and we'll try to debug for you. Memory dumps are one of the most useful pieces of evidence for figuring out precisely what caused a crash.<br><br>If there are no memory dumps in the zip file but you've been experiencing crashes, shutdowns, or freezing, that means Windows wasn't able to create one. This can (but not always) indicate a hardware problem over a software one. Windows will usually try to generate a memory dump when the system crashes.",tools:["WhoCrashed"]},
{id:'whea',q:"Fatal Hardware Error (WHEA)",a:"WHEA is Windows' hardware error reporting system. A fatal WHEA error means a core piece of hardware, usually the CPU, memory controller, or a PCIe device, reported a serious problem Windows couldn't recover from, and the machine likely crashed or rebooted as a result.<br><br>This is a strong indication that something is physically wrong or unstable, often an overclock, degraded hardware, or insufficient voltage, rather than a software issue.",tools:["OCCT","MemTest86","HWiNFO"]},
{id:'disk-smart',q:"Storage / SMART Warnings",a:"Your drives (SSD, NVMe, hard drive) constantly track their own health statistics using something called SMART data. This data lists specific problems the drive itself has self-reported, such as:<ul style='margin:8px 0 8px 20px;padding:0'><li>reallocated sectors (damaged areas it's had to work around)</li><li>pending or uncorrectable sectors (data that couldn't be read reliably)</li></ul>If a drive predicts its own failure, it's important that you back up anything important from it immediately. Drive failures are often random and unpredictable.<br><br>A high <b>UltraDMA CRC error</b> count is shown separately as a warning rather than an error - it's usually a loose or failing cable or connection, not the drive itself dying, and is often fixed by reseating or replacing the cable.",tools:["CrystalDiskInfo"]},
{id:'dirty-bit',q:"Dirty Bit",a:"This means Windows flagged a drive as not having been cleanly unmounted, usually caused by the same unexpected shutdown or crash reported elsewhere in this report. It's a marker for Windows to check that drive's filesystem for errors next time it gets the chance.<br><br>On its own it isn't necessarily a sign of a failing drive, and is used as an indication that something might be wrong.",tools:[]},
{id:'device-manager-errors',q:"Device Manager Errors",a:"Windows found a piece of hardware but couldn't properly load a driver for it, or the device itself reported a problem. This usually means a missing, outdated, or corrupted driver. Occasionally it's a genuine hardware fault.",tools:["AMD Drivers & Support","NVIDIA Drivers & Support","Intel Drivers & Support"]},
{id:'mbr-secureboot',q:"MBR Partitioning",a:"Windows drives use one of two partitioning styles: MBR or the newer GPT. Secure Boot, a feature that helps stop malware loading before Windows starts, requires GPT.<br><br>If the main drive (the one with Windows installed on it) is MBR, Secure Boot can't be turned on without converting the drive or doing a clean reinstall of Windows, which is a bigger job and best not attempted without guidance.",tools:[]},
{id:'windows-on-slower-drive',q:"Windows Installed on a Slower Drive",a:"This PC has an NVMe drive - the fastest common type of storage, connecting directly over the motherboard's high-speed PCIe lanes - but Windows itself is installed on a different, slower drive (SATA SSD or hard drive) instead.<br><br>SATA SSDs are still fast for everyday use, but NVMe is typically several times quicker for boot times, app loading, and anything that reads/writes a lot of small files. If the NVMe drive has enough free space, migrating Windows over to it (via cloning software or a fresh install) would give a noticeable speed improvement, particularly for boot time and load screens.",tools:[]},
{id:'unallocated-space',q:"Unallocated Disk Space",a:"Part of this drive's physical capacity isn't assigned to any partition at all - it's not free space inside a drive letter that Windows can use, it's simply invisible and unusable until a partition is created or extended into it."
  +"<br><br>This most commonly happens after replacing a drive with a bigger one: cloning software or an in-place Windows install (choosing 'Keep personal files and apps' during setup) carries the old, smaller partition layout across onto the new drive without automatically resizing anything to fill it. The result is a drive that reports its full new capacity, but where Windows itself only ever sees the old, smaller amount."
  +"<br><br>The fix is to open Disk Management (right-click Start, or search for 'Create and format hard disk partitions'), right-click the main partition (usually C:), and choose 'Extend Volume' - this grows the partition into the unallocated space, right up alongside it. Extend Volume only works on unallocated space directly next to the partition, so if it's greyed out, the unallocated space likely sits after another partition (such as the Recovery partition) blocking it; a partition management tool that can move partitions, or a temporary Recovery partition deletion/recreation, may be needed in that case.",tools:[]},
{id:'low-disk-space',q:"Low Disk Space",a:"This drive is down to less than 10% free space. Windows and most apps rely on having some working room on every drive - for temp files, virtual memory paging, browser caches, and background maintenance tasks like Defender scans or Windows Update staging - so a drive running this low can slow the whole system down, not just that one drive."
  +"<br><br>On the system drive (usually C:) specifically, this can also directly affect Windows' own responsiveness, since the page file and various system caches live there. On a secondary data or games drive, the more common symptom is failed installs, corrupted saves, or apps refusing to update."
  +"<br><br>Freeing up space (uninstalling unused programs, clearing Downloads, running Disk Cleanup, or moving files to another drive) is the direct fix. If the drive is already fairly full of things that are actually needed, a larger replacement drive may be the more lasting solution.",tools:["WizTree","BleachBit"]},
{id:'pending-reboot',q:"Pending Reboot",a:"Windows or an update has made changes that only take full effect after a restart, and it's currently waiting on one. Until then the system can behave oddly and further updates may queue up behind it.<br><br>A normal restart resolves this.",tools:[]},
{id:'wu-service',q:"Windows Update Service",a:"The background service that lets Windows check for and install updates is disabled. Normally it's set to start on demand (so it's often shown as 'Stopped' when idle - that's expected and not a problem), but 'Disabled' means it can't start at all, so Windows won't be able to update until it's turned back on.",tools:[]},
{id:'wu-failed',q:"Failed Windows Updates",a:"One or more recent update attempts failed partway through rather than installing cleanly. This can happen for lots of reasons: a bad download, low disk space, corrupted update files, or a conflict with other software.<br><br>It can sometimes leave a PC feeling unstable or repeatedly nagging about the same update.",tools:["Windows 11 Download"]},
{id:'cores-vs-threads',q:"Cores vs Threads",a:"A CPU core is a physical processing unit - more cores generally means more work can genuinely happen at the same time. Threads (via Intel Hyper-Threading or AMD SMT) let each core handle two instruction streams instead of one, which improves throughput in well-threaded workloads but doesn't double real performance the way an extra physical core would.<br><br>An '8C/16T' CPU has 8 physical cores presenting 16 logical processors to Windows. Task Manager and this report both count threads (logical processors) unless stated otherwise.",tools:[]},
{id:'cpu-virtualization',q:"CPU Virtualisation (VT-x / AMD-V)",a:"This is hardware-level support for running virtual machines efficiently, built into the CPU itself. It needs to be enabled in the BIOS/UEFI (often labelled Intel VT-x, AMD-V, or SVM Mode) before Windows features that rely on it - Hyper-V, WSL2, Android emulators, VirtualBox/VMware with hardware acceleration - will work.<br><br>Enabling it is not overclocking and carries no risk. If a VM or emulator refuses to start with an error mentioning virtualization, this is almost always the cause.",tools:[]},
{id:'ram-speed',q:"RAM Speed (XMP/EXPO)",a:"Your memory (RAM) is capable of running faster than it currently is. This almost always means that a feature called XMP (Intel) or EXPO (AMD) isn't enabled.<br><br>XMP/EXPO is a one-click profile in the BIOS that allows your RAM to run at its advertised speed. When it's disabled, your RAM will default to a lower speed. Enabling it isn't overclocking, and isn't dangerous. We'd recommend enabling it, which can be done through your BIOS. If you're unsure how to do that, you can ask one of our advisors for more help.<br><br><i>Note: some systems can struggle to run RAM at its full advertised speed for various reasons, which is why it isn't enabled by default. When this happens, it can sometimes help to disable it, to prevent system instability or crashes.</i><br><br>This isn't dangerous either way, but running below the rated speed does mean the RAM isn't performing the way it was bought to.",tools:["CPU-Z"]},
{id:'pagefile-manual',q:"Page File Manually Managed",a:"Windows normally handles the page file (a portion of a drive used as overflow when physical RAM fills up) itself, growing and shrinking it as needed. Someone has turned off 'Automatically manage paging file size for all drives', meaning it's set to a fixed size (or a custom drive) by hand instead.<br><br>This isn't inherently a problem, but it's a common source of trouble if the size chosen is too small for the workload, or if it was set on a drive that's since become full or was removed/replaced. A page file that's too small can cause 'out of memory' errors or crashes even when the drive has plenty of free space otherwise.<br><br>If there isn't a specific reason it was changed (some people do this deliberately to save SSD writes, or as an old 'performance tweak' that no longer really applies on modern systems), switching it back to automatic under System Properties &gt; Advanced &gt; Performance Settings &gt; Advanced &gt; Virtual Memory is usually the simplest fix.",tools:[]},
{id:'pagefile-disabled',q:"No Page File Configured",a:"There is no page file on this PC at all - every drive is set to 'No paging file' rather than a size. This is more serious than a manually-sized page file, and isn't recommended even on a system with a lot of RAM.<br><br>Without a page file, Windows has nowhere to overflow to once physical RAM fills up, so instead of slowing down it can crash, refuse to launch programs, or throw 'out of memory' errors well before RAM actually looks full (some of it is reserved and can't be reallocated the way a page file's space can). It also prevents Windows from writing a memory dump when the system crashes, which removes a key diagnostic tool for tracking down the cause of any crash.<br><br>The fix is the same either way: System Properties &gt; Advanced &gt; Performance Settings &gt; Advanced &gt; Virtual Memory, then either switch back to 'Automatically manage paging file size for all drives', or manually set a page file on at least one drive.",tools:[]},
{id:'antivirus-conflict',q:"Multiple Antivirus Programs",a:"More than one antivirus program is trying to actively scan the system at the same time. This is a common, often-overlooked cause of slowdowns, false-positive quarantines, and general instability, since the two programs can end up fighting over the same files.",tools:[]},
{id:'defender-rtp',q:"Defender Real-Time Protection",a:"Windows' built-in antivirus isn't actively scanning for threats. This can be intentional if another antivirus is installed, or it can be accidental. Malware sometimes disables it deliberately to avoid detection.",tools:[]},
{id:'bitlocker-on',q:"BitLocker Enabled",a:"One or more drives are encrypted with BitLocker. This isn't a problem &mdash; it's just worth knowing about, since it affects a few things:<ul style='margin:8px 0 8px 20px;padding:0'><li>Before a wipe, reset, reinstall, or drive removal: without the recovery key, an encrypted drive that gets locked out cannot be read or recovered.</li><li>Before a <b>BIOS/UEFI update</b>, or any change to boot order, Secure Boot, or the TPM: these can change the measurements BitLocker checks at startup and trigger a recovery key prompt on the next boot. Suspending BitLocker first (Control Panel &gt; BitLocker Drive Encryption &gt; Suspend protection) avoids this, and it resumes automatically after the next restart.</li></ul>If a wipe, reset, or BIOS update is planned, confirm the recovery key is backed up somewhere accessible (Microsoft account, Active Directory, or a printed/saved copy) before proceeding.",tools:[]},
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
{id:'half-duplex',q:"Network Adapter at Half Duplex",a:"Half duplex means the connection can only send or receive at any one moment, not both at once. Modern Ethernet should always negotiate full duplex, so seeing half duplex almost always points to a damaged cable, a faulty port, or a speed/duplex setting that's been forced manually in the adapter's properties instead of left on Auto Negotiation. Expect slow, stuttery transfers and high ping until it's fixed.",tools:[]},
{id:'wifi-link-rate',q:"Low Wi-Fi Link Rate",a:"The link rate is the speed the PC and router have agreed to talk at over Wi-Fi. A modern Wi-Fi 5/6/7 connection normally runs at hundreds of Mbps; a rate this low means the connection has fallen back to a slow mode, usually because of distance, walls, interference, or a crowded channel. It caps real-world speed well below what your internet plan may offer.",tools:[]},
{id:'wifi-band',q:"Wi-Fi on 2.4 GHz",a:"This PC is connected on the 2.4 GHz band even though its Wi-Fi adapter supports 5 GHz. 2.4 GHz reaches further but is much slower and far more crowded (neighbours' networks, Bluetooth, microwaves). If the router is reasonably close, connecting to its 5 GHz network (often a separate name ending in '5G') usually gives a big speed and latency improvement.",tools:[]},
{id:'gigabit-slow',q:"Network Adapter Running Below Rated Speed",a:"This network adapter supports a faster speed than it's currently connected at - for example a Gigabit port running at 100 Mbps, or a 2.5 Gbps port running at 1 Gbps.<br><br>If the router or switch on the other end also supports the faster speed, this is a very common symptom of a damaged or low-quality cable, a loose connection, or a faulty port. Gigabit and faster need all 4 wire pairs in the cable to be good, while 100 Mbps only needs 2. If the other end simply doesn't support the faster speed (many routers are Gigabit-only), a 2.5 Gbps port running at 1 Gbps is expected and nothing to fix.",tools:[]},
{id:'commit-charge',q:"Commit Charge",a:"This measures how much memory (RAM plus the page file combined) the system had committed to running programs at the moment this report was generated.<br><br>Running close to the limit can cause slowdowns, stuttering, or 'out of memory' errors, and often points to either too little RAM for the workload or a page file set too small.",tools:["HWiNFO"]},
{id:'software-anticheat',q:"Anti-Cheat / Kernel Drivers",a:"Anti-cheat systems like Vanguard, Easy Anti-Cheat, and BattlEye run at a very deep level in Windows (a 'kernel driver') to detect cheating in games. That deep access makes them a common (though not the only) suspect when troubleshooting crashes tied to a specific game.<br><br>This is a factual note that it's installed, not a claim that it's causing a problem.",tools:[]},
{id:'software-overclock',q:"Overclocking / Monitoring Tools",a:"Tools like MSI Afterburner, RTSS, Intel XTU, and Ryzen Master can adjust CPU/GPU clock speeds, voltages, and power limits beyond default settings. If a system is unstable, an aggressive overclock applied through one of these is a common and easy-to-test cause.",tools:["OCCT"]},
{id:'software-rgb',q:"RGB / Peripheral Software",a:"Software like Corsair iCUE, Razer Synapse, Logitech G HUB, and similar RGB/peripheral control suites has a real history of causing background crashes, high idle CPU/RAM usage, and driver conflicts, even though each individual program is legitimate.",tools:[]},
{id:'software-audio',q:"Audio / Overlay Software",a:"Tools like Nahimic, GeForce Experience, Xbox Game Bar, and Streamlabs OBS can conflict with each other or with games, particularly when more than one is trying to add an overlay at the same time.",tools:[]},
{id:'software-network',q:"Flagged Network Software",a:"Software like Killer Network Manager or Hola VPN has a known history of causing latency spikes, packet loss, or other connectivity problems on some systems.",tools:[]},
{id:'software-shell',q:"Shell/Taskbar Tweak Tools",a:"Tools like TranslucentTB, ExplorerPatcher, StartAllBack, Start11, Open-Shell, or Windhawk modify Windows Explorer or the taskbar/Start menu's appearance and behaviour, often by hooking into or patching explorer.exe itself.<br><br>They're generally safe day-to-day, but because they hook into core shell processes, they're a common cause of taskbar/Start menu glitches, explorer.exe crashes, or freezes after a Windows feature update changes something they relied on. Worth ruling out first if that's the symptom.",tools:[]},
{id:'software-cheat',q:"Game Exploit / Cheat Tool",a:"Tools like JJSploit, Synapse X, Krnl, Fluxus, and similar Roblox/game script executors, along with general memory-editors like Cheat Engine, are flagged here because they carry real risk beyond just breaking the rules of a game:<ul style='margin:8px 0 8px 20px;padding:0'><li>they're a very common way to end up with genuine malware, since many are distributed through cracked/pirated download sites with a trojan bundled in</li><li>most inject code into a running game process, which is exactly the pattern antivirus and anti-cheat software is built to catch - a wave of false-positive detections or a sudden anti-cheat ban often traces straight back to one of these</li><li>some game accounts can be permanently banned the moment one of these is detected running, even once</li></ul>This is a factual note that it's installed, not an accusation - but if unexplained AV detections, game bans, or crashes tied to a specific game are the symptom, this is worth checking first.",tools:[]},
{id:'software-fancontrol',q:"Multiple Fan-Control Programs",a:"Programs like Lian Li L-Connect, FanControl, SpeedFan, Fan Xpert, and RGB/fan hubs such as Corsair iCUE, NZXT CAM, MSI Dragon Center, or ASUS Armoury Crate can all set fan curves directly through the motherboard or a fan controller.<br><br>Running more than one of these at the same time means they can end up fighting over the same fans - each one periodically re-applying its own curve over the other's - which shows up as fans that surge, stall, or cycle speed for no clear reason. The fix is usually to pick one and fully close (not just minimize) the others, since some keep running in the background even without a visible window.",tools:[]},
{id:'software-wallpaperengine',q:"Wallpaper Engine",a:"Wallpaper Engine renders an animated or interactive desktop background, which means it's continuously using the GPU in the background rather than sitting idle like a static wallpaper would.<br><br>This is a common, easy-to-miss cause of a GPU that never drops to idle, higher-than-expected power draw or fan noise while 'doing nothing', and lower FPS or stutter in games if it isn't set to pause automatically on fullscreen apps (check its Playback settings if so). Nothing wrong with the software itself - just worth knowing it's running if one of those symptoms shows up.",tools:[]},
{id:'software-remote',q:"Remote Access Software",a:"Tools like TeamViewer, AnyDesk, ScreenConnect, Splashtop, LogMeIn, and similar let someone log into or control this PC from another device over the internet or local network.<br><br>This is completely normal and often intentional (remote work, IT support, accessing a home PC while away), but it's also exactly what a remote-access scam relies on if someone was talked into installing one of these by an unsolicited caller. Worth confirming the person recognises installing it and knows it's still there, especially if it was set up a long time ago and forgotten about.",tools:[]},
{id:'windows-old',q:"Windows.old Folder",a:"Windows.old is a backup of the previous Windows installation, automatically created when Windows is upgraded in place or reset while keeping personal files. It lets Windows roll back to the previous version for about 10 days before it's automatically deleted to free up space, though it can stick around longer if that cleanup didn't run.<br><br>Its presence is a useful sign that this installation is newer than the hardware, which is handy context if a problem only started recently. It doesn't cover every case, though: a full wipe-and-reinstall or a reset that removes everything doesn't leave a Windows.old folder behind at all, so its absence doesn't rule out a recent reset.",tools:[]},
{id:'secure-boot',q:"Secure Boot",a:"Secure Boot is a security feature that checks the software involved in starting Windows hasn't been tampered with, before the operating system even loads. It helps stop a specific but nasty category of malware (called bootkits or rootkits) that tries to run before Windows, and before any antivirus, gets a chance to load.<br><br>Microsoft requires it for Windows 11, and leaving it disabled removes a real layer of protection for no real-world upside on most PCs. It requires the system disk to use GPT partitioning. See the note about MBR partitioning in this report if that's relevant.",tools:[]},
{id:'tpm',q:"TPM",a:"A TPM (Trusted Platform Module) is a small, dedicated security chip, or a feature built into the CPU (fTPM) on newer systems, that securely stores encryption keys and other sensitive data separately from the rest of the PC. It's what Windows 11 relies on for BitLocker drive encryption and for meeting its own minimum security requirements.<br><br>If it's disabled, Windows Hello, BitLocker, and some newer Windows security features either can't be used or fall back to a weaker mode. It can usually be turned on in the BIOS/UEFI settings (often listed as 'TPM', 'fTPM', 'PTT', or 'Security Device').",tools:[]},
{id:'wrong-gpu-slot',q:"Display on the Wrong GPU",a:"This PC has a dedicated graphics card, but the monitor cable is plugged into the motherboard's video output instead of the graphics card's. That routes everything through the slower integrated graphics built into the CPU, so the dedicated GPU sits there unused."
  +"<br><br>This is a very common cable mistake, especially after a fresh build or a cable getting knocked loose. The desktop will still work and look normal, but games and demanding programs will run far below the performance the GPU should be giving."
  +"<br><br>The fix is simple: move the monitor cable to one of the ports on the graphics card itself, usually found at the bottom of the case where the card's bracket is, rather than the ports built into the motherboard I/O panel at the top.",tools:["GPU-Z"]},
{id:'basic-display-adapter',q:"Microsoft Basic Display Adapter",a:"Windows falls back to this generic, built-in driver when it can't load the real driver for the graphics card - usually because the actual driver crashed, failed to install properly, or got corrupted, often triggered by an unstable overclock or XMP/EXPO profile causing a crash on the last restart."
  +"<br><br>Basic Display Adapter has no hardware acceleration and doesn't expose the monitor's real capabilities, which is why it causes poor performance everywhere (including the desktop, not just games) and often removes the ability to change refresh rate or resolution options that were available before."
  +"<br><br>The fix is a clean reinstall of the proper GPU driver. Fully removing the old one first with Display Driver Uninstaller (DDU), then installing a fresh driver from AMD/NVIDIA/Intel directly, resolves this far more reliably than installing over the top of the broken one.",tools:["Display Driver Uninstaller (DDU)"]},
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
  if(btn){
    const grp=btn.closest('.nav-group');
    if(grp)grp.classList.remove('collapsed');
    btn.click();
  }
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
    v.innerHTML='<div class="dp-head"><div class="dp-crumb"><span class="crumb">Software <span class="material-symbols-outlined" style="font-size:16px">chevron_right</span> <b>Browser Extensions</b></span></div>'+
      '<div class="dp-title-row"><div><div class="dp-title">Browser extensions</div></div></div></div>'+
      '<div class="dp-content"><div class="dp-card"><div class="dp-empty">No browser extension data embedded. Many machines genuinely have none installed.</div></div></div>';
    return;
  }
  const byBrowser={};
  SECURITY.extensions.forEach(e=>{
    (byBrowser[e.browser]=byBrowser[e.browser]||[]).push(e);
  });
  const browserCount=Object.keys(byBrowser).length;

  let h='<div class="dp-head"><div class="dp-crumb"><span class="crumb">Software <span class="material-symbols-outlined" style="font-size:16px">chevron_right</span> <b>Browser Extensions</b></span></div>'+
    '<div class="dp-title-row"><div><div class="dp-title">Browser extensions</div><div class="dp-sub">'+SECURITY.extensions.length+' enabled extension'+(SECURITY.extensions.length===1?'':'s')+' across '+browserCount+' browser'+(browserCount===1?'':'s')+'</div></div></div></div>';

  h+='<div class="dp-content"><div class="vol-grid">';
  Object.keys(byBrowser).sort().forEach(b=>{
    const items=byBrowser[b];
    const profiles=[...new Set(items.map(e=>e.profile).filter(Boolean))].sort();
    const names=[...new Set(items.map(e=>e.name))].sort((a,c)=>a.localeCompare(c,undefined,{sensitivity:'base'}));
    h+='<div class="dp-card"><div class="dp-card-head"><div class="dp-card-title" style="font-size:16px">'+esc(b)+'</div></div>'+
      '<div class="dp-card-note" style="margin-bottom:12px">'+names.length+' extension'+(names.length===1?'':'s')+(profiles.length?' \u00b7 '+esc(profiles.join(', ')):'')+'</div>'+
      '<div style="display:flex;flex-direction:column;gap:2px">'+
      names.map(n=>{
        const inProfiles=profiles.length>1?[...new Set(items.filter(e=>e.name===n).map(e=>e.profile))]:[];
        return '<div style="padding:7px 0;border-bottom:1px solid var(--line);font:400 14px/20px Roboto;color:var(--dim);display:flex;justify-content:space-between;gap:12px">'+
          '<span style="overflow-wrap:anywhere">'+esc(n)+'</span>'+
          (inProfiles.length>1&&inProfiles.length<profiles.length?'<span style="color:var(--faint);flex:none">'+esc(inProfiles.join(', '))+'</span>':'')+
          '</div>';
      }).join('')+
      '</div></div>';
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
  el.innerHTML=slice.map(p=>'<div class="list-row" style="grid-template-columns:1fr 140px 140px"><div class="c1">'+esc(p.name)+'</div><div class="c2">'+esc(String(p.cnt))+'</div><div class="c2 mono">'+esc(String(p.mem))+' MB</div></div>').join('')||'<div class="list-empty-row">No processes match.</div>';
  document.querySelectorAll('#processesView .list-head-col.sortable').forEach(hd=>hd.classList.toggle('active',hd.dataset.key===PS_.key));
  ['name','cnt','mem'].forEach(key=>{
    const icon=document.getElementById('procSortIcon'+(key==='name'?'Name':key==='cnt'?'Cnt':'Mem'));
    if(icon)icon.textContent=PS_.key===key?(PS_.dir>0?'arrow_upward':'arrow_downward'):'unfold_more';
  });
  listPager(document.getElementById('procPager'),PS_.page,pages,rows.length,(delta,jumpTo)=>{PS_.page=jumpTo?jumpTo:PS_.page+delta;renderProcList();},SZ);
}
function renderProgList(){
  const el=document.getElementById('progList');if(!el)return;
  let rows=PROGS_ALL.filter(p=>!PG_.q||p.name.toLowerCase().includes(PG_.q));
  if(PG_.flagFilter==='any')rows=rows.filter(p=>flagForProgram(p.name));
  else if(PG_.flagFilter)rows=rows.filter(p=>{const f=flagForProgram(p.name);return f&&f.grp===PG_.flagFilter;});
  const k=PG_.key,d=PG_.dir;
  // Install dates are stored as 'MM/dd/yyyy' strings (or blank when Windows never recorded one),
  // so sorting by date needs them parsed into a comparable timestamp rather than sorted as text.
  const parseInstallDate=s=>{const m=s&&s.match(/^(\d{2})\/(\d{2})\/(\d{4})$/);return m?Date.UTC(+m[3],+m[1]-1,+m[2]):0;};
  const flagLabelFor=p=>{const f=flagForProgram(p.name);return f?(SOFT_GROUP_LABEL[f.grp]||f.grp):'';};
  rows=rows.slice().sort((a,b)=>{
    if(k==='date')return d*(parseInstallDate(a.date)-parseInstallDate(b.date));
    if(k==='flag')return d*flagLabelFor(a).localeCompare(flagLabelFor(b),undefined,{sensitivity:'base'})||a.name.localeCompare(b.name,undefined,{sensitivity:'base'});
    return d*a.name.localeCompare(b.name,undefined,{sensitivity:'base'});
  });
  const SZ=60,pages=Math.max(1,Math.ceil(rows.length/SZ));
  if(PG_.page>pages)PG_.page=pages;
  const slice=rows.slice((PG_.page-1)*SZ,PG_.page*SZ);
  el.innerHTML=slice.map(p=>{
    const f=flagForProgram(p.name);
    return '<div class="list-row" style="grid-template-columns:1fr 200px 190px"><div class="c1">'+esc(p.name)+'</div>'+
      '<div class="c2'+(p.date?'':' faint')+'">'+esc(p.date||'\u2014')+'</div>'+
      '<div>'+(f?'<span class="list-tag" style="background:'+(SOFT_GROUP_COLOR[f.grp]?SOFT_GROUP_COLOR[f.grp].bg:'#272A2F')+';color:'+(SOFT_GROUP_COLOR[f.grp]?SOFT_GROUP_COLOR[f.grp].fg:'var(--dim)')+';border:none">'+esc(SOFT_GROUP_LABEL[f.grp]||f.grp)+'</span>':'')+'</div></div>';
  }).join('')||'<div class="list-empty-row">No programs match.</div>';
  ['name','date','flag'].forEach(key=>{
    const icon=document.getElementById('progSortIcon'+(key==='name'?'Name':key==='date'?'Date':'Flag'));
    if(icon)icon.textContent=PG_.key===key?(PG_.dir>0?'arrow_upward':'arrow_downward'):'unfold_more';
  });
  document.querySelectorAll('#appsView .list-head-col.sortable').forEach(hd=>hd.classList.toggle('active',hd.dataset.key===PG_.key));
  document.querySelectorAll('#appsView .flagpill').forEach(p=>p.classList.toggle('on',p.dataset.grp==='all'?!PG_.flagFilter:PG_.flagFilter===p.dataset.grp));
  const sortLabel=document.getElementById('progSortLabel');
  if(sortLabel)sortLabel.textContent=PG_.key==='date'?(PG_.dir<0?'Newest first':'Oldest first'):(PG_.dir>0?'A to Z':'Z to A');
  listPager(document.getElementById('progPager'),PG_.page,pages,rows.length,(delta,jumpTo)=>{
    PG_.page=jumpTo?jumpTo:PG_.page+delta;renderProgList();
  });
}
const HF_={q:'',page:1};
function renderHfList(){
  const el=document.getElementById('hfList');if(!el)return;
  const rows=HOTFIXES.filter(h=>!HF_.q||(h.id+' '+h.desc).toLowerCase().includes(HF_.q));
  const SZ=8,pages=Math.max(1,Math.ceil(rows.length/SZ));
  if(HF_.page>pages)HF_.page=pages;
  const slice=rows.slice((HF_.page-1)*SZ,HF_.page*SZ);
  el.innerHTML=slice.map(h=>'<dt>'+esc(h.date||'')+'</dt><dd>'+esc(h.id)+(h.desc?' <span style="color:var(--faint)">'+esc(h.desc)+'</span>':'')+'</dd>').join('')||'<dd style="color:var(--faint)">No matches.</dd>';
  listPager(document.getElementById('hfPager'),HF_.page,pages,rows.length,(delta,jumpTo)=>{HF_.page=jumpTo?jumpTo:HF_.page+delta;renderHfList();},SZ);
}
function smartProbs(d){
  const probs=[];
  if(d.pf==='1')probs.push('drive predicts its own failure');
  if(d.health&&d.health!=='Healthy')probs.push('health: '+d.health);
  if(+d.rl>0)probs.push(d.rl+' reallocated sectors');
  if(+d.pend>0)probs.push(d.pend+' pending sectors');
  if(+d.unc>0)probs.push(d.unc+' uncorrectable sectors');
  if(+d.reu>0)probs.push(d.reu+' uncorrected read errors');
  if(+d.weu>0)probs.push(d.weu+' uncorrected write errors');
  return probs;
}
// UltraDMA CRC errors are usually a cable/connection problem (a loose or marginal SATA cable,
// a bad port), not the drive's own media failing, so they're tracked separately from the
// error-signal attributes above and shown as a warning rather than a red flag.
function smartCrcProbs(d){
  const probs=[];
  if(+d.crc>0)probs.push(d.crc+' UltraDMA CRC errors (often a loose or failing cable)');
  return probs;
}
// Custom hover tooltip for the disk-layout partition bars - a native title attribute works but
// is slow to appear and easy to miss, so a small styled tooltip that follows the cursor gives an
// immediate, on-theme readout of each partition's size.
// Clicking a drive card in the Overview jumps to and briefly highlights the matching physical
// disk down in Disk layout, so the reader doesn't have to hunt for which disk a drive letter is on.
function highlightModule(i){flashEl(document.getElementById('ramModule-'+i));}
function highlightDisk(diskNum){flashEl(document.getElementById('diskBlock-'+diskNum));}
function flashEl(el){
  if(!el)return;
  document.querySelectorAll('.highlight-flash').forEach(x=>x.classList.remove('highlight-flash'));
  el.scrollIntoView({behavior:'smooth',block:'center'});
  void el.offsetWidth;
  el.classList.add('highlight-flash');
  el.addEventListener('animationend',()=>el.classList.remove('highlight-flash'),{once:true});
}
function showPartTip(e,text){
  let tip=document.getElementById('partTip');
  if(!tip){
    tip=document.createElement('div');
    tip.id='partTip';
    tip.style.cssText='position:fixed;pointer-events:none;background:var(--panel2);border:1px solid var(--line);padding:6px 10px;border-radius:6px;font-size:13px;color:var(--text);z-index:1000;white-space:nowrap;box-shadow:0 4px 12px rgba(0,0,0,.35)';
    document.body.appendChild(tip);
  }
  tip.textContent=text;
  tip.style.display='block';
  positionPartTip(e);
}
function positionPartTip(e){
  const tip=document.getElementById('partTip');
  if(!tip)return;
  tip.style.left=(e.clientX+14)+'px';
  tip.style.top=(e.clientY+14)+'px';
}
function hidePartTip(){
  const tip=document.getElementById('partTip');
  if(tip)tip.style.display='none';
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
// Known software flags: anti-cheat/kernel drivers, OC & monitoring tools, RGB/peripheral suites, bloatware/PUPs.
// Shared by the Summary/Diagnostic Summary notes and the Installed Programs page's flag groups,
// so both surfaces agree on exactly the same detection list.
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
    {re:/exitlag/i,              label:'ExitLag',                    grp:'net'},
    {re:/wallpaper engine/i,     label:'Wallpaper Engine',            grp:'wallpaper'},
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
    {re:/parsec/i,                label:'Parsec',                    grp:'remote'},
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
const FAN_CAPABLE_PERIPH=['Corsair iCUE','NZXT CAM','MSI Dragon Center','ASUS Armoury Crate'];
const SOFT_FAQ={ac:'software-anticheat',oc:'software-overclock',periph:'software-rgb',audio:'software-audio',net:'software-network',bloat:'software-bloatware',shell:'software-shell',cheat:'software-cheat',fan:'software-fancontrol',wallpaper:'software-wallpaperengine',remote:'software-remote'};
const SOFT_GROUP_LABEL={bloat:'Bloatware / PUPs',periph:'RGB / peripheral suites',oc:'OC & monitoring',ac:'Anti-cheat drivers',audio:'Audio & overlays',remote:'Remote access',fan:'Fan controllers',net:'Network tools',wallpaper:'Wallpaper Engine',shell:'Shell customisation',cheat:'Game exploit tools'};
const SOFT_GROUP_COLOR={
  ac:{bg:'#0E3A5F',fg:'#9ECBFF'}, oc:{bg:'#0B3B36',fg:'#6FE0CB'}, periph:{bg:'#3A2A5C',fg:'#D3B8FA'},
  bloat:{bg:'#332703',fg:'#FFDF9B'}, audio:{bg:'#4A2338',fg:'#FFAFD1'}, remote:{bg:'#0B3A42',fg:'#7FE0EE'},
  fan:{bg:'#0F2A16',fg:'#8BD17C'}, net:{bg:'#2A2E5C',fg:'#B7BCFF'}, wallpaper:{bg:'#4A3010',fg:'#FFB870'},
  shell:{bg:'#2A3542',fg:'#A9C2D9'}, cheat:{bg:'#93000A',fg:'#FFDAD6'},
};
function getSoftwareFlags(programs){
  const foundSoft={};
  (programs||[]).forEach(p=>{
    SOFT_FLAGS.forEach(f=>{ if(f.re.test(p.name)){ (foundSoft[f.grp]=foundSoft[f.grp]||new Set()).add(f.label); } });
  });
  return foundSoft;
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
  // Same DIY signature on the manufacturer side: with no real system OEM, Windows reports the
  // motherboard vendor's own legal name here (e.g. "Micro-Star International Co., Ltd.") instead
  // of an actual system brand. Comparing directly against Motherboard Manufacturer catches this
  // without needing a hardcoded list of vendor names - a genuine OEM (Dell, HP, Lenovo) never
  // matches its own motherboard supplier's name here, so this stays specific to DIY builds.
  const mbMfrForDedupe=specVal(sp.info,'Motherboard Manufacturer')||'';
  const sysMfrIsMobo=sysMfr&&mbMfrForDedupe&&sysMfr.trim().toLowerCase()===mbMfrForDedupe.trim().toLowerCase();
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
  const crashes=relEvents.filter(e=>e.cat==='err'&&e.s==='Application Error').length;
  const shutdowns=getShutdowns().length;
  // Prefer the speed embedded in the part number over Win32_PhysicalMemory.Speed when it's
  // higher - Speed often just reflects the JEDEC default the stick is currently running at,
  // not what it's actually rated for, which silently hides an XMP/EXPO-off situation.
  const effRated=m=>Math.max(+m.rated||0,+m.pnSpeed||0)||'';
  const notes=[];
  notes.push(crashes?dataLink('rel','app-crashes','<span class="r"><b>'+crashes+'</b> Application crash'+(crashes>1?'es':'')+'</span>'):'<span class="g">No application crashes</span>');
  // Unexpected shutdowns: reliability history (6008-derived) and Kernel-Power 41 record the
  // same incident. Report one merged line, using the larger count if they disagree.
  const shutdownCount=shutdowns;
  if(shutdownCount){
    notes.push(dataLink('rel','unexpected-shutdown','<span class="r"><b>'+shutdownCount+'</b> Unexpected shutdown'+(shutdownCount>1?'s':'')+'</span>'));
  }else{
    notes.push('<span class="g">No unexpected shutdowns</span>');
  }
  if(DUMPS.length)notes.push(dataLink('dumps','memory-dump','<span class="y"><b>'+DUMPS.length+'</b> Memory dump'+(DUMPS.length>1?'s':'')+' collected</span> <span style="color:var(--faint)">(in zip)</span>'));
  const wheaFatal=SYSEVT.filter(r=>/WHEA/i.test(r.prov)&&['18','46'].includes(String(r.id))).length;
  if(wheaFatal)notes.push(dataLink('rel','whea','<span class="r"><b>'+wheaFatal+'</b> Fatal hardware error'+(wheaFatal>1?'s':'')+' (WHEA)</span>'));
  SMART.forEach(d=>{
    const probs=smartProbs(d);
    const crc=smartCrcProbs(d);
    if(probs.length)notes.push(dataLink('drives','disk-smart','<span class="r">Disk '+esc(d.disk)+' ('+esc(d.name)+'): '+esc(probs.join(', '))+'</span>'));
    if(crc.length)notes.push(dataLink('drives','disk-smart','<span class="y">Disk '+esc(d.disk)+' ('+esc(d.name)+'): '+esc(crc.join(', '))+'</span>'));
  });
  DIRTY.forEach(v=>notes.push(dataLink('drives','dirty-bit','<span class="y">Volume '+esc(v)+' has its dirty bit set</span>')));
  if(DEVERR.length){
    const devNames=DEVERR.map(e=>e.name);
    const shown=devNames.slice(0,3).join(', ')+(devNames.length>3?' +'+(devNames.length-3)+' more':'');
    notes.push(anchorLink('summary','devErrSection','device-manager-errors','<span class="y"><b>'+DEVERR.length+'</b> device'+(DEVERR.length>1?'s':'')+' showing errors in Device Manager</span> <span style="color:var(--faint)">('+esc(shown)+')</span>'));
  }
  const sysDisk=DISKLAYOUT.find(dk=>dk.partitions.some(p=>p.letter==='C:'));
  if(sysDisk&&sysDisk.style&&sysDisk.style.toUpperCase()==='MBR')notes.push(dataLink('drives','mbr-secureboot','<span class="y">System disk uses MBR partitioning (Secure Boot requires GPT)</span>'));
  const sysDiskBus=sysDisk?(SMART.find(d=>String(d.disk)===String(sysDisk.disk))||{}).bus:null;
  if(sysDiskBus&&!/nvme/i.test(sysDiskBus)&&SMART.some(d=>/nvme/i.test(d.bus||''))){
    notes.push(dataLink('drives','windows-on-slower-drive','<span class="y">Windows is on '+esc(sysDiskBus)+', not the faster NVMe drive also in this PC</span>'));
  }
  // Large unallocated space usually means a partition never got extended after moving to a bigger
  // drive - very common after an in-place "keep files" install carries an old, smaller partition
  // layout onto a new, larger replacement drive without resizing anything.
  DISKLAYOUT.forEach(dk=>{
    const partSum=dk.partitions.reduce((a,p)=>a+p.sizeGB,0);
    const unallocGB=Math.max(0,(dk.sizeGB||0)-partSum);
    if(unallocGB>20&&dk.sizeGB&&unallocGB/dk.sizeGB>0.1){
      const pct=Math.round(unallocGB/dk.sizeGB*100);
      notes.push(dataLink('drives','unallocated-space','<span class="y">Disk '+esc(dk.disk)+' has '+Math.round(unallocGB)+' GB ('+pct+'%) of unallocated space not assigned to any partition</span>'));
    }
  });
  // Low free space on any drive letter, not just the system drive - a nearly-full data/games
  // drive can be just as disruptive (install failures, save-game corruption, browser cache
  // errors) as a nearly-full C:, and this was previously only visible by digging into the
  // Drives tab rather than shown anywhere upfront.
  (sp.drives||[]).forEach(dr=>{
    const totalGB=+dr['Total Size (GB)'],freeGB=+dr['Free Space (GB)'];
    if(!totalGB)return;
    const freePct=dr['Percentage Free (%)']!=null?+dr['Percentage Free (%)']:(freeGB/totalGB*100);
    if(freePct<10){
      notes.push(dataLink('drives','low-disk-space','<span class="y">Drive '+esc(dr['Drive Label']||'?')+' has only '+Math.round(freePct)+'% free space ('+freeGB.toFixed(1)+' GB) &mdash; performance can suffer when a drive runs this low</span>'));
    }
  });
  if(WINUPDATE&&WINUPDATE.pendingReboot)notes.push(dataLink('updates','pending-reboot','System has a pending reboot (Windows Update or servicing)'));
  if(WINUPDATE&&WINUPDATE.serviceStartType==='Disabled')notes.push(dataLink('updates','wu-service','<span class="y">Windows Update service is disabled</span>'));
  const wuFails=WUHISTORY.filter(u=>u.result==='Failed'||u.result==='Cancelled').length;
  if(wuFails)notes.push(dataLink('updates','wu-failed','<span class="y"><b>'+wuFails+'</b> Windows Update'+(wuFails>1?'s':'')+' did not complete successfully</span>'));
  if(RAM.length){
    const slow=RAM.filter(m=>effRated(m)&&m.conf&&+m.conf<+effRated(m));
    if(slow.length)notes.push(dataLink('memory','ram-speed','<span class="y">RAM configured at '+esc(slow[0].conf)+' MT/s, rated '+esc(effRated(slow[0]))+' MT/s</span>'));
  }
  const pgfileState=specVal(sp.info,'Page File Managed');
  if(pgfileState==='Disabled')notes.push(dataLink('memory','pagefile-disabled','<span class="r">No page file is configured &mdash; this is set to \'No paging file\' on every drive</span>'));
  else if(pgfileState==='Manual')notes.push(dataLink('memory','pagefile-manual','<span class="y">Page file is manually managed (automatic management is turned off)</span>'));
  const foundSoft=getSoftwareFlags(PROGRAMS);
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
      const onVols=SECURITY.bitlocker.filter(b=>b.status==='On');
      if(onVols.length){
        const drives=onVols.map(b=>b.drive).filter(Boolean);
        notes.push(dataLink('security','bitlocker-on','<span class="i">BitLocker is enabled'+(drives.length?' on '+esc(drives.join(', ')):'')+'</span>'));
      }
    }
  }
  const gpuDrvRe=/nvlddmkm|amdwddmg|amdkmdag|atikmdag/i;
  const tdrEvents=SYSEVT.filter(r=>String(r.id)==='4101'||gpuDrvRe.test(r.prov)||gpuDrvRe.test(r.msg||''));
  if(tdrEvents.length){
    const drv=[...new Set(tdrEvents.map(r=>{const m2=(r.prov+' '+(r.msg||'')).match(gpuDrvRe);return m2?m2[0].toLowerCase():null;}).filter(Boolean))];
    notes.push(dataLink('rel','gpu-tdr','<span class="r"><b>'+tdrEvents.length+'</b> display driver timeout/reset event'+(tdrEvents.length>1?'s':'')+(drv.length?' ('+esc(drv.join(', '))+')':'')+'</span>'));
  }
  // SourceName is 'LiveKernelEvent' for these reliability records - a fixed internal identifier,
  // never localized - so matching it directly is safer than matching the word "LiveKernelEvent"
  // inside the (potentially translated) message text.
  const lke=RAW.filter(r=>r.s==='LiveKernelEvent').length;
  if(lke)notes.push(dataLink('rel','livekernelevent','<span class="r"><b>'+lke+'</b> LiveKernelEvent record'+(lke>1?'s':'')+' in reliability history</span>'));
  netIssues().forEach(i=>notes.push(dataLink('net',i.faq,'<span class="'+(i.sev==='err'?'r':i.sev==='warn'?'y':'i')+'">'+i.text+'</span>')));
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
  // Windows falls back to this generic, unaccelerated driver when it can't load the real GPU
  // driver - almost always the result of a crash, a bad driver install, or (very commonly) an
  // unstable overclock/XMP profile that corrupted the driver state on the last restart. It
  // explains poor performance everywhere (including the desktop/BIOS-adjacent screens) and an
  // inability to change refresh rate, since the generic driver exposes neither.
  // Matched on PNPDeviceID (ROOT\BASICDISPLAY / ROOT\BASICRENDER), not the display name - the
  // name is localized ("Podstawowa karta graficzna Microsoft" on Polish Windows, for example)
  // but the PNP device ID is a fixed internal string regardless of Windows language.
  const basicGpu=GPUS.find(g=>/root\\basic(display|render)/i.test(g.pnp||'')||/microsoft basic (display|render)/i.test(g.name));
  if(basicGpu)notes.push(dataLink('gpu','basic-display-adapter','<span class="r">Windows is using the generic Microsoft Basic Display Adapter instead of a real GPU driver</span>'));
  if(WINDOWSOLD&&WINDOWSOLD.present)notes.push(flagLink('windows-old','<span style="color:var(--dim)">Windows.old folder present. Windows was upgraded or reset around '+esc(WINDOWSOLD.date)+'</span>'));
  if(POWERPLAN&&!POWERPLAN.isDefault)notes.push('<span style="color:var(--dim)">Non-default power plan active: '+esc(POWERPLAN.name)+'</span>');
  if(GENFLAGS&&GENFLAGS.tpmDisabled)notes.push(flagLink('tpm','<span style="color:var(--dim)">TPM is present but disabled</span>'));
  if(GENFLAGS&&GENFLAGS.secureBootDisabled)notes.push(dataLink('security','secure-boot','<span style="color:var(--dim)">Secure Boot disabled</span>'));
  if(CBS&&CBS.unresolvedCount>0)notes.push(dataLink('rel','cbs-corruption','<span class="r"><b>'+CBS.unresolvedCount+'</b> unresolved component corruption entr'+(CBS.unresolvedCount>1?'ies':'y')+' in CBS.log</span>'));
  if(up){
    const upDays=parseInt((up.match(/^(\d+)\s*days?/i)||[])[1]||'0',10);
    if(upDays>=7)notes.push(dataLink('rel','high-uptime','<span class="y">System has been running for <b>'+upDays+'</b> days without a restart</span>'));
  }

  // --- At-a-glance hero: identity strip + spec tiles ---
  // Everything here is a plain fact, nothing flagged or colour-coded - anything worth calling
  // out (RAM under its rated speed, a disk's SMART health, etc.) belongs in General Notes below,
  // not buried in a tile. The status pill is the one exception, and it only ever reflects a
  // count already computed for General Notes, never a new check of its own.
  let sysTitle='',sysSubParts=[];
  (function(){
    const heroEl=document.getElementById('summaryHero');
    const tiles=[];
    const cpuCT=specVal(sp.info,'CPU Cores/Threads'), cpuGHz=specVal(sp.info,'CPU Speed'), cpuSocket=specVal(sp.info,'CPU Socket');
    const cpuCache=specVal(sp.info,'CPU L3 Cache')||specVal(sp.info,'CPU L2 Cache');
    const cpuVirt=specVal(sp.info,'CPU Virtualization');
    if(cpu){
      const ctm=(cpuCT||'').match(/(\d+)C\s*\/\s*(\d+)T/i);
      tiles.push({cls:'cpu',icon:'memory',label:'Processor',tab:'cpu',value:cpu.trim(),lines:[
        ctm?'Cores: '+ctm[1]+' cores / '+ctm[2]+' threads':'',
        cpuGHz?'Base speed: '+cpuGHz:'',
        cpuCache?'Cache: '+cpuCache:'',
        cpuSocket?'Socket: '+cpuSocket:'',
        cpuVirt?'Virtualisation: '+cpuVirt:''
      ].filter(Boolean)});
    }
    if(GPUS.length||DISPLAYS.length){
      const gNames=[...new Set(GPUS.length?GPUS.map(g=>g.name):DISPLAYS.map(d=>d.gpu))];
      const g0=GPUS[0];
      const driverFriendly=g0&&g0.drv?friendlyDriver(g0.name,g0.drv,g0.radeon).replace(/\s*<span[^>]*>\(([^)]*)\)<\/span>/,' ($1)'):'';
      const isIGPUt=g=>/Intel\(R\)?\s*(UHD|HD|Iris)/i.test(g.name)||/^AMD Radeon(\(TM\))?\s*Graphics$/i.test(g.name.trim());
      const isDGPUt=g=>/NVIDIA|GeForce|RTX|GTX|Quadro|Radeon\s*(RX|VII|Pro\s*W)/i.test(g.name);
      const tIgpu=GPUS.find(isIGPUt), tDgpu=GPUS.find(isDGPUt);
      const secondaryGpu=(tIgpu&&tDgpu)?(g0&&g0.name===tDgpu.name?tIgpu:tDgpu):null;
      const activeDisplays=DISPLAYS.length;
      const d0=DISPLAYS[0];
      const dispRes=d0&&d0.res?d0.res.replace(/\s*x\s*/i,'\u00d7').replace(/\s+/g,''):'';
      const dispHz=d0&&d0.hz?' @'+d0.hz:'';
      tiles.push({cls:'gpu',icon:'videogame_asset',label:gNames.length>1?'Graphics ('+gNames.length+')':'Graphics',tab:'gpu',value:gNames[0]||'',lines:[
        g0&&g0.vram?'VRAM: '+g0.vram+' GB':'',
        driverFriendly?'Driver: '+driverFriendly:'',
        activeDisplays?'Displays: '+activeDisplays+' active'+(dispRes?' \u00b7 '+dispRes+dispHz:''):'',
        secondaryGpu?'Secondary: '+secondaryGpu.name+(secondaryGpu===tIgpu?' (iGPU)':''):'',
        g0&&g0.driverDate?'Driver date: '+fmtDay(g0.driverDate):''
      ].filter(Boolean)});
    }
    if(RAM.length){
      const heroRamGB=RAM.reduce((a,x)=>a+(+x.cap||0),0);
      const heroRamConf=[...new Set(RAM.map(m=>m.conf).filter(Boolean))].join('/');
      const heroRamRated=[...new Set(RAM.map(m=>effRated(m)).filter(Boolean))].join('/');
      // Only show a brand in the headline value when every stick agrees on one - a mixed-brand
      // kit (or one with no resolved brand) just falls back to plain capacity.
      const ramMfrs=[...new Set(RAM.map(m=>m.mfr).filter(Boolean))];
      const ramMfrLabel=ramMfrs.length===1?ramMfrs[0]:'';
      const ramTypes=[...new Set(RAM.map(m=>m.ddrType).filter(Boolean))];
      const ramTypeLabel=ramTypes.length===1?ramTypes[0]:'';
      const ramSlow=RAM.some(m=>effRated(m)&&m.conf&&+m.conf<+effRated(m));
      tiles.push({cls:'ram',icon:'developer_board',label:'Memory',tab:'memory',value:heroRamGB+' GB'+(ramMfrLabel?' '+ramMfrLabel:'')+(ramTypeLabel?' '+ramTypeLabel:''),
        badge:ramSlow,
        lines:[
        heroRamRated?'Rated: '+heroRamRated+' MT/s':'',
        heroRamConf?'Configured: '+heroRamConf+' MT/s'+(ramSlow?' \u2014 XMP/EXPO disabled':''):'',
        'Modules: '+RAM.length,
        (MEMUSE&&MEMUSE.pt)?'In use: '+MEMUSE.pu.toFixed(1)+' GB ('+Math.round(MEMUSE.pu/MEMUSE.pt*100)+'%)':''
      ].filter(Boolean)});
    }
    if(sp.drives&&sp.drives.length){
      const totalGB=DISKLAYOUT.length?DISKLAYOUT.reduce((a,d)=>a+(+d.sizeGB||0),0):sp.drives.reduce((a,d)=>a+(+d['Total Size (GB)']||0),0);
      const freeGB=sp.drives.reduce((a,d)=>a+(+d['Free Space (GB)']||0),0);
      // Windows reports drive capacity in binary GiB (1024-based), but SSD/HDD manufacturers market
      // capacity in decimal GB/TB (1000-based) - a "2TB" drive shows as ~1863 in Windows. Correcting
      // by the binary-to-decimal ratio before rounding gets back to the marketed figure (e.g. 1863
      // GiB -> ~2000 decimal GB -> "2TB") instead of under-reporting it as ~1.8TB.
      // Smaller drives (128/256/512GB class) are the exception - those are usually marketed using
      // binary GB instead, so the decimal correction overshoots them slightly; snapping to the
      // nearest common capacity when close catches that case.
      const COMMON_GB=[60,64,120,128,160,180,200,240,250,256,320,400,480,500,512,640,750,800,900,1000,1500,2000,3000,4000,5000,6000,8000,10000,12000,16000,20000];
      const marketingSize=gib=>{
        if(!gib)return '';
        const decGB=gib*1.073741824;
        const nearest=COMMON_GB.reduce((best,c)=>Math.abs(c-decGB)<Math.abs(best-decGB)?c:best,COMMON_GB[0]);
        const snapped=Math.abs(nearest-decGB)/decGB<0.03?nearest:Math.round(decGB/10)*10;
        if(snapped>=1000){
          const tb=snapped/1000;
          return (Math.abs(tb-Math.round(tb))<0.05?Math.round(tb):tb.toFixed(1))+'TB';
        }
        return snapped+'GB';
      };
      const freePct=totalGB?Math.round(freeGB/totalGB*100):null;
      const diskCount=DISKLAYOUT.length||sp.drives.length;
      const sysDiskSmart=sysDisk?SMART.find(d=>String(d.disk)===String(sysDisk.disk)):null;
      const sysDiskSize=sysDisk?marketingSize(+sysDisk.sizeGB||0):'';
      const sysDiskLabel=[sysDiskSize,sysDiskSmart&&sysDiskSmart.name].filter(Boolean).join(' ');
      const sysLogicalDrive=sp.drives.find(d=>d['Windows Drive']==='True');
      const sysFreeGB=sysLogicalDrive?+sysLogicalDrive['Free Space (GB)']||0:null;
      const sysTotalGB=sysLogicalDrive?+sysLogicalDrive['Total Size (GB)']||0:null;
      const sysFreePct=(sysTotalGB&&sysFreeGB!=null)?Math.round(sysFreeGB/sysTotalGB*100):null;
      const letterToDisk={};
      DISKLAYOUT.forEach(dk=>{(dk.partitions||[]).forEach(p=>{if(p.letter)letterToDisk[p.letter]=dk.disk;});});
      const smartByDiskEarly={};
      SMART.forEach(d=>{smartByDiskEarly[String(d.disk)]=d;});
      const driveBars=[...sp.drives].filter(dr=>+dr['Total Size (GB)']>0).sort((a,b)=>(a['Drive Label']||'').localeCompare(b['Drive Label']||'')).slice(0,4).map(dr=>{
        const dTotalGB=+dr['Total Size (GB)']||0, dFreeGB=+dr['Free Space (GB)']||0;
        const dFreePct=dr['Percentage Free (%)']!=null?Math.round(+dr['Percentage Free (%)']):Math.round(dFreeGB/dTotalGB*100);
        const diskNum=letterToDisk[dr['Drive Label']];
        const sm=diskNum!=null?smartByDiskEarly[String(diskNum)]:null;
        const label=[dr['Drive Label'],sm&&sm.bus,sm&&sm.health].filter(Boolean).join(' \u00b7 ');
        return {label,free:fmtSize(dFreeGB)+' free of '+fmtSize(dTotalGB),pct:100-dFreePct,low:dFreePct<10};
      });
      tiles.push({cls:'storage',icon:'hard_drive',label:diskCount>1?'Storage ('+diskCount+' disks)':'Storage',tab:'drives',value:sysDiskLabel||fmtSize(totalGB)+' total',bars:driveBars.length?driveBars:null,lines:[
        sysFreeGB!=null?'Free space: '+fmtSize(sysFreeGB)+(sysFreePct!=null?' ('+sysFreePct+'%)':''):'Free space: '+fmtSize(freeGB)+(freePct!=null?' ('+freePct+'%)':''),
        sysDiskSmart&&sysDiskSmart.bus?sysDiskSmart.bus:''
      ].filter(Boolean)});
    }
    if(mb){
      const mbClean=((mbMfr||'').replace(/ASUSTeK COMPUTER INC\./i,'ASUS').replace(/Micro-Star International.*/i,'MSI').replace(/Gigabyte Technology.*/i,'Gigabyte')+' '+mb).trim();
      const fastBoot=specVal(sp.info,'Fast Boot State');
      const activePowerPlan=specVal(sp.info,'Active Power Plan');
      let bdateAge='',bdateWarn=false;
      if(bdate){
        const parsed=new Date(bdate);
        if(!isNaN(parsed)){
          const yrs=(Date.now()-parsed)/(365.25*86400000);
          if(yrs>=1){bdateAge=' \u00b7 '+Math.floor(yrs)+' year'+(Math.floor(yrs)===1?'':'s')+' old';bdateWarn=yrs>=2;}
        }
      }
      tiles.push({cls:'mobo',icon:'dashboard_customize',label:'Motherboard',tab:'mobo',value:mbClean,
        warnKeys:[bdateWarn?'Date':'',fastBoot==='Enabled'?'Fast startup':''].filter(Boolean),
        lines:[
        bver?'BIOS: '+bver:'',
        bdate?'Date: '+bdate.replace(/\s+\d{1,2}:\d{2}(:\d{2})?(\s*[AP]M)?$/i,'')+bdateAge:'',
        fastBoot?'Fast startup: '+fastBoot:'',
        activePowerPlan?'Power plan: '+activePowerPlan:''
      ].filter(Boolean)});
    }
    if(os){
      const bMajor=build?build.split('.')[0]:'';
      const fv=WINVER[bMajor];
      const installDate=specVal(sp.info,'Windows Install Date');
      const lastUpdate=WUHISTORY.length?(WUHISTORY.find(u=>u.result==='Succeeded')||WUHISTORY[0]):null;
      const pgSize=specVal(sp.info,'Page File Size'), pgManaged=specVal(sp.info,'Page File Managed');
      const pgMB=pgSize?parseFloat(pgSize):null;
      const pgGBStr=(pgMB&&!isNaN(pgMB))?((Math.round(pgMB/1024*10)/10).toString().replace(/\.0$/,'')+' GB'):'';
      const pgLabel=pgManaged==='Automatic'?'System managed':pgManaged==='Manual'?'Manual':pgManaged==='Disabled'?'Disabled':pgManaged;
      const pgLine=pgLabel?pgLabel+(pgGBStr?' \u00b7 '+pgGBStr:''):'';
      tiles.push({cls:'os',icon:'desktop_windows',label:'Windows',tab:'summary',value:os.replace('Microsoft ',''),
        warnKeys:[pgManaged==='Disabled'?'Page file':''].filter(Boolean),
        lines:[
        fv?'Version: '+fv:'',
        build?'Build: '+build:'',
        up?'System uptime: '+up.replace(/ days?/,'d').replace(/ hours?/,'h').replace(/ minutes?/,'m').replace(/,/g,''):'',
        installDate?'Installed on: '+installDate:'',
        pgLine?'Page file: '+pgLine:'',
        lastUpdate?'Last update: '+lastUpdate.date:''
      ].filter(Boolean)});
    }
    if(!tiles.length){heroEl.innerHTML='';return;}

    const critCount=notes.filter(n=>/class="r"/.test(n)).length;
    const warnCount=notes.filter(n=>/class="y"/.test(n)).length;
    const totalFlags=critCount+warnCount;
    const chipCls=totalFlags===0?'ok':(critCount>0?'err':'warn');
    const chipParts=[];
    if(critCount)chipParts.push(critCount+' Error'+(critCount>1?'s':''));
    if(warnCount)chipParts.push(warnCount+' Warning'+(warnCount>1?'s':''));
    const chipText=totalFlags===0?'All clear':chipParts.join(', ');

    // Never fall back to the hostname (System Name) here - people commonly name their PC after
    // themselves (e.g. a literal "Rory-PC"), so showing it risks leaking a real name into a
    // report meant to be safely shareable. When manufacturer/model are the generic BIOS
    // placeholder strings (common on DIY boards), or the manufacturer is just the motherboard
    // vendor's own name restated with no real system model, fall back to a plainly generic
    // label instead - "Custom-built PC" is honest and reads far better than a stray legal
    // entity name (e.g. "Micro-Star International Co., Ltd.") sitting alone as the PC's title.
    const titleParts=(sysMfrIsMobo&&sysModelIsDupe)?[]:[sysMfr,(sysModel&&!sysModelIsDupe)?sysModel:''].filter(Boolean);
    const title=titleParts.length?titleParts.join(' '):(sysMfrIsMobo?'Custom-built PC':'System Manufacturer, System Product Name');
    const subParts=[mb,os&&os.replace('Microsoft ',''),up?'up '+up.replace(/ days?/,'d').replace(/ hours?/,'h').replace(/ minutes?/,'m').replace(/,/g,''):'',GEN?'scanned '+GEN:''].filter(Boolean);
    sysTitle=title; sysSubParts=subParts;

    document.getElementById('summaryTitle').textContent=title;
    document.getElementById('summarySub').textContent=subParts.join(' \u00b7 ');
    const chipEl=document.getElementById('summaryChip');
    chipEl.className=chipCls;
    document.getElementById('summaryChipText').textContent=chipText;

    // Reuse the same notes the Diagnostic Summary page categorises by tab, so a tile only lights
    // up amber/red when that module has an actual flagged issue somewhere else in the report -
    // one source of truth instead of re-deriving each module's warning condition a second time.
    const tabSeverity={};
    notes.forEach(n=>{
      const m=n.match(/goTab\('([a-z]+)'\)/);
      if(!m||m[1]==='summary')return;
      const sev=/class="r"/.test(n)?'err':/class="y"/.test(n)?'warn':null;
      if(!sev)return;
      if(!tabSeverity[m[1]]||(tabSeverity[m[1]]==='warn'&&sev==='err'))tabSeverity[m[1]]=sev;
    });

    let h='<div class="tile-grid">';
    tiles.forEach(t=>{
      const sev=tabSeverity[t.tab];
      h+='<div class="tile'+(sev?' tile-'+sev:'')+'" onclick="return goTab(\''+t.tab+'\')"><div class="tile-head">'+
        '<div class="tile-icon"><span class="material-symbols-outlined">'+t.icon+'</span></div>'+
        '<div class="tile-titles"><div class="tile-label">'+esc(t.label)+'</div><div class="tile-value">'+esc(t.value)+'</div></div>'+
        (sev?'<span class="tile-warnbadge tile-warnbadge-'+sev+'"><span class="material-symbols-outlined">'+(sev==='err'?'error':'warning')+'</span></span>'
          :'<span class="tile-chevron material-symbols-outlined">chevron_right</span>')+
        '</div><div class="tile-div"></div>';
      if(t.bars){
        h+='<div class="tile-bars">'+t.bars.map(b=>
          '<div class="tile-bar-row"><div class="tile-bar-label"><span>'+esc(b.label)+'</span><span'+(b.low?' class="tile-warn-text"':'')+'>'+esc(b.free)+'</span></div>'+
          '<div class="tile-bar-track"><div class="tile-bar-fill'+(b.low?' low':'')+'" style="width:'+Math.min(100,Math.max(2,b.pct))+'%"></div></div></div>'
        ).join('')+'</div>';
      }else{
        h+='<dl class="tile-kv">'+t.lines.map(l=>{
          const ci=l.indexOf(': ');
          const dt=ci>-1?l.slice(0,ci):'';
          const dd=ci>-1?l.slice(ci+2):l;
          const warnRow=(t.badge&&dt==='Configured')||(t.warnKeys&&t.warnKeys.includes(dt));
          return '<dt>'+esc(dt)+'</dt><dd'+(warnRow?' class="tile-warn-text"':'')+'>'+esc(dd)+'</dd>';
        }).join('')+
        (t.link?'<dt></dt><dd><a href="'+t.link.url+'" target="_blank" rel="noopener" onclick="event.stopPropagation()" style="color:var(--info)">'+esc(t.link.text)+'</a></dd>':'')+
        '</dl>';
      }
      h+='</div>';
    });
    h+='</div>';
    heroEl.innerHTML=h;

    const copyBtn=document.getElementById('copySpecsBtn');
    if(copyBtn)copyBtn.onclick=()=>{
      const lines=[title,...tiles.map(t=>t.label+': '+t.value)];
      const txt=lines.join('\n');
      const done=()=>{const old=copyBtn.innerHTML;copyBtn.innerHTML='<span class="material-symbols-outlined" style="font-size:18px">check</span>Copied';setTimeout(()=>{copyBtn.innerHTML=old;},1500);};
      if(navigator.clipboard&&navigator.clipboard.writeText)navigator.clipboard.writeText(txt).then(done).catch(()=>{});
      else{const ta=document.createElement('textarea');ta.value=txt;document.body.appendChild(ta);ta.select();document.execCommand('copy');document.body.removeChild(ta);done();}
    };
  })();

  const critItems=notes.filter(n=>/class="r"/.test(n));
  const warnItems=notes.filter(n=>/class="y"/.test(n));
  const infoItems=notes.filter(n=>!/class="[ry]"/.test(n)&&!/class="g"/.test(n));
  const DIAG_TAB_LABEL={cpu:'Processor',gpu:'Graphics',memory:'Memory',drives:'Storage',mobo:'Motherboard',net:'Network',devices:'Devices',security:'Security',apps:'Software',updates:'Updates',sys:'Events',shutdowns:'Events',rel:'Events',summary:'Operating system'};
  const diagCategory=html=>{const m=html.match(/goTab\('([a-z]+)'\)/);return m?{label:DIAG_TAB_LABEL[m[1]]||'',tabId:m[1]}:null;};
  const DIAG_GROUPS=[
    {key:'crit',label:'Error',cls:'crit',icon:'error',items:critItems},
    {key:'warn',label:'Warnings',cls:'warn',icon:'warning',items:warnItems},
    {key:'info',label:'Information',cls:'',icon:'info',items:infoItems},
    {key:'soft',label:'Notable software',cls:'',icon:'apps',items:softNotes},
  ];
  const diagTotalCount=DIAG_GROUPS.reduce((a,g)=>a+g.items.length,0);
  document.getElementById('diagSub').textContent=diagTotalCount+' note'+(diagTotalCount===1?'':'s')+' \u00b7 '+sysTitle+(sysSubParts.length?' \u00b7 '+sysSubParts.join(' \u00b7 '):'');
  const badgeCount=critItems.length+warnItems.length;
  const diagBadgeEl=document.getElementById('diagTabBadge');
  if(diagBadgeEl){ if(badgeCount){diagBadgeEl.textContent=badgeCount;diagBadgeEl.style.display='';} else {diagBadgeEl.style.display='none';} }

  document.getElementById('diagStats').innerHTML=DIAG_GROUPS.map(g=>
    '<div class="diag-stat '+g.cls+'" data-key="'+g.key+'"><span class="material-symbols-outlined">'+g.icon+'</span>'+
    '<div><div class="diag-stat-n">'+g.items.length+'</div><div class="diag-stat-l">'+esc(g.label)+'</div></div></div>'
  ).join('');

  let diagFilter=null;
  function renderDiagBody(){
    const q=(document.getElementById('diagSearch').value||'').toLowerCase();
    const body=document.getElementById('diagBody');
    let h='';
    DIAG_GROUPS.forEach(g=>{
      if(diagFilter&&diagFilter!==g.key)return;
      let items=g.items;
      if(q)items=items.filter(n=>n.toLowerCase().replace(/<[^>]+>/g,' ').includes(q));
      if(!items.length)return;
      h+='<div class="diag-group-head"><span class="diag-group-label '+g.cls+'">'+esc(g.label)+'</span><span class="diag-group-count">'+items.length+' note'+(items.length===1?'':'s')+'</span><span class="diag-group-line"></span></div>';
      // Errors share one red panel rather than each row carrying its own.
      if(g.key==='crit')h+='<div class="diag-crit-box">';
      items.forEach(n=>{
        const cat=diagCategory(n);
        h+='<div class="diag-row"><div class="diag-row-main">'+n+'</div>'+
          (cat&&cat.label?'<span class="diag-chip" onclick="return goTab(\''+cat.tabId+'\')">'+esc(cat.label)+'</span>':'')+'</div>';
      });
      if(g.key==='crit')h+='</div>';
    });
    if(!h)h='<div style="color:var(--faint);padding:32px 4px">No notes match.</div>';
    body.innerHTML=h;
  }
  renderDiagBody();
  document.getElementById('diagSearch').oninput=renderDiagBody;
  document.querySelectorAll('.diag-stat').forEach(el=>el.onclick=()=>{
    diagFilter=(diagFilter===el.dataset.key)?null:el.dataset.key;
    document.querySelectorAll('.diag-stat').forEach(x=>x.classList.toggle('on',x.dataset.key===diagFilter));
    renderDiagBody();
  });
  const copyNotesBtn=document.getElementById('copyNotesBtn');
  if(copyNotesBtn)copyNotesBtn.onclick=()=>{
    const txt=DIAG_GROUPS.flatMap(g=>g.items.map(n=>n.replace(/<[^>]+>/g,''))).join('\n');
    const done=()=>{const old=copyNotesBtn.innerHTML;copyNotesBtn.innerHTML='<span class="material-symbols-outlined" style="font-size:18px">check</span>Copied';setTimeout(()=>{copyNotesBtn.innerHTML=old;},1500);};
    if(navigator.clipboard&&navigator.clipboard.writeText)navigator.clipboard.writeText(txt).then(done).catch(()=>{});
    else{const ta=document.createElement('textarea');ta.value=txt;document.body.appendChild(ta);ta.select();document.execCommand('copy');document.body.removeChild(ta);done();}
  };
}
// 6008's message holds the real crash time ("The previous system shutdown at 8:53:04 AM on 9/24/2026 was
// unexpected"); the event itself is only logged on the next boot. Strip U+200E marks Windows puts
// around the date parts. Localised messages won't match - caller falls back to the logged time.
function parse6008(msg){
  const m=String(msg||'').replace(/[\u200e\u200f]/g,'')
    .match(/(\d{1,2}):(\d{2}):(\d{2})\s*(AM|PM)?.*?(\d{1,2})\/(\d{1,2})\/(\d{4})/i);
  return m?parseDate(m[5]+'/'+m[6]+'/'+m[7]+' '+m[1]+':'+m[2]+':'+m[3]+(m[4]?' '+m[4]:'')):null;
}
// Merges Kernel-Power 41 (System log) with reliability history's 'EventLog' (6008) records - both
// describe the same incident - and works out what can be said about each one. Shown inline on the
// matching Reliability History row rather than on a page of its own.
let SHUTS_=null;
function getShutdowns(){
  if(SHUTS_)return SHUTS_;
  const BC_NAMES={ '278':'VIDEO_TDR_FAILURE','279':'VIDEO_TDR_TIMEOUT_DETECTED','281':'VIDEO_SCHEDULER_INTERNAL_ERROR','321':'VIDEO_ENGINE_TIMEOUT_DETECTED','322':'VIDEO_TDR_APPLICATION_BLOCKED' };
  const kp41=SYSEVT.filter(r=>String(r.id)==='41').map(r=>{
    const bc=(r.bc&&String(r.bc)!=='0')?String(r.bc):'';
    return {d:parseDate(r.t),bc,pbt:r.pbt?parseDate(r.pbt):null,kp:true};
  }).filter(x=>x.d);
  const rel=relEvents.filter(e=>e.s==='EventLog').map(e=>({d:e.d,crash:parse6008(e.m),bc:'',pbt:null,rel:true}));
  const sys6008=SYSEVT.filter(r=>String(r.id)==='6008').map(r=>({d:parseDate(r.t),crash:parse6008(r.msg),bc:'',pbt:null,sys:true})).filter(x=>x.d);
  const merged=[];
  [...kp41,...rel,...sys6008].sort((a,b)=>b.d-a.d).forEach(item=>{
    const dup=merged.find(m=>Math.abs(m.d-item.d)<2*60*1000);
    if(dup){
      if(!dup.bc&&item.bc)dup.bc=item.bc;
      if(!dup.pbt&&item.pbt)dup.pbt=item.pbt;
      if(!dup.crash&&item.crash)dup.crash=item.crash;
      dup.kp=dup.kp||item.kp; dup.rel=dup.rel||item.rel; dup.sys=dup.sys||item.sys;
    }else merged.push({...item});
  });
  merged.forEach(x=>{
    x.when=x.crash||x.d;
    x.bcLabel=x.bc?('0x'+parseInt(x.bc).toString(16).toUpperCase()+(BC_NAMES[x.bc]?' '+BC_NAMES[x.bc]:'')):'';
    x.cause=x.bcLabel?'Blue screen (Windows crashed with a stop code)':x.pbt?'Forced off by holding the power button':'Power loss, hard reset, or a full system hang';
    x.dump=DUMPS.find(dm=>{const dd=parseDate(dm.d+':00');return dd&&Math.abs(dd-x.when)<2*60*1000;})||null;
  });
  SHUTS_=merged;
  return merged;
}
function shutFactsHtml(x){
  const sameDay=(a,b)=>a.toDateString()===b.toDateString();
  const rows=[];
  const fullTime=d=>d.toLocaleTimeString('en-GB',{hour:'2-digit',minute:'2-digit',second:'2-digit'});
  rows.push(['Went down',esc(fullTime(x.when))+' \u00b7 '+esc(fmtDay(x.when.toISOString().slice(0,10)))+(x.crash?'':' <span class="sf-dim">(time Windows logged it after restarting)</span>')]);
  if(x.crash)rows.push(['Logged',esc(fmtTime(x.d))+(sameDay(x.d,x.when)?'':' on '+esc(fmtDay(x.d.toISOString().slice(0,10))))+' <span class="sf-dim">when Windows next started</span>']);
  rows.push(['Crash code',x.bcLabel?'<span class="sf-err">'+esc(x.bcLabel)+'</span>':'None recorded']);
  if(x.pbt)rows.push(['Power button','Held at '+esc(fmtTime(x.pbt))]);
  rows.push(['Likely cause',esc(x.cause)]);
  if(x.dump)rows.push(['Memory dump','<a onclick="event.stopPropagation();return goTab(\'dumps\')">'+esc(x.dump.n)+'</a>']);
  rows.push(['Recorded by',[x.rel?'Reliability history (6008)':'',(x.kp||x.sys)?'System log ('+[x.sys?'6008':'',x.kp?'Kernel-Power 41':''].filter(Boolean).join(', ')+')':''].filter(Boolean).join(' + ')]);
  return '<div class="shut-facts">'+rows.map(r=>'<div class="sf-k">'+r[0]+'</div><div class="sf-v">'+r[1]+'</div>').join('')+
    '<div class="sf-k"></div><div class="sf-v"><a onclick="event.stopPropagation();return goFaq(\'unexpected-shutdown\')">What causes unexpected shutdowns \u2192</a></div></div>';
}
function renderSecurity(){
  const v=document.getElementById('securityView');
  const sp=parseSpecs(SPECS);
  const tpmStatus=specVal(sp.info,'TPM Status'), tpmVersion=specVal(sp.info,'TPM Version');
  const secureBoot=specVal(sp.info,'Secure Boot State'), uac=specVal(sp.info,'UAC');
  const d=SECURITY&&SECURITY.defender;

  if(!SECURITY&&!tpmStatus&&!secureBoot&&!uac){
    v.innerHTML='<div class="dp-head"><div class="dp-crumb"><span class="crumb">Software <span class="material-symbols-outlined" style="font-size:16px">chevron_right</span> <b>Security</b></span></div>'+
      '<div class="dp-title-row"><div><div class="dp-title">Security</div></div></div></div>'+
      '<div class="dp-body" style="grid-template-columns:1fr"><div class="dp-card"><div class="dp-empty">No security data embedded.</div></div></div>';
    return;
  }

  // --- posture strip: only shown when the underlying data exists ---
  const posture=[];
  if(d){
    const rtpOn=d.rtp==='True';
    posture.push({cls:rtpOn?'':'err',icon:rtpOn?'verified_user':'gpp_bad',title:'Real-time protection',sub:rtpOn?'Enabled':'Disabled'});
  }
  if(SECURITY&&SECURITY.firewall&&SECURITY.firewall.length){
    const onCount=SECURITY.firewall.filter(f=>f.enabled==='True').length;
    const allOn=onCount===SECURITY.firewall.length;
    posture.push({cls:allOn?'':(onCount>0?'warn':'err'),icon:allOn?'verified_user':'gpp_maybe',title:'Firewall',sub:allOn?'All '+SECURITY.firewall.length+' profiles on':onCount+' of '+SECURITY.firewall.length+' profiles on'});
  }
  if(SECURITY&&SECURITY.rdp){
    const rdpOn=!!SECURITY.rdp.enabled;
    posture.push({cls:rdpOn?'warn':'',icon:'desktop_windows',title:'Remote Desktop',sub:rdpOn?'Enabled':'Disabled'});
  }
  if(SECURITY&&SECURITY.bitlocker&&SECURITY.bitlocker.length){
    const onCount=SECURITY.bitlocker.filter(b=>b.status==='On').length;
    const allOn=onCount===SECURITY.bitlocker.length, allOff=onCount===0;
    posture.push({cls:allOn?'':'',icon:allOn?'lock':'lock_open',title:'BitLocker',sub:allOn?'On for all volumes':allOff?'Off on all volumes':onCount+' of '+SECURITY.bitlocker.length+' volumes on'});
  }
  if(SECURITY&&SECURITY.exclusions&&SECURITY.exclusions.length){
    const riskyCount=(SECURITY.exclFlags||[]).length;
    posture.push({cls:riskyCount?'warn':'',icon:riskyCount?'rule_folder':'folder_off',title:'Exclusions',sub:riskyCount?riskyCount+' risky of '+SECURITY.exclusions.length:SECURITY.exclusions.length+' entries, none flagged'});
  }

  // --- overall status line, top-right of the header ---
  let critCount=0,warnCount=0;
  if(d&&d.rtp!=='True')critCount++;
  if(SECURITY&&SECURITY.rdp&&SECURITY.rdp.enabled){warnCount++; if(SECURITY.rdp.nlaRequired===false)warnCount++;}
  if(SECURITY&&SECURITY.exclFlags&&SECURITY.exclFlags.length)warnCount++;
  if(SECURITY&&SECURITY.hostsFlags&&SECURITY.hostsFlags.length)warnCount++;
  if(SECURITY&&SECURITY.startupFlags&&SECURITY.startupFlags.length)warnCount++;
  if(SECURITY&&SECURITY.avProducts&&SECURITY.avProducts.filter(a=>a.enabled).length>1)warnCount++;
  if(tpmStatus&&tpmStatus!=='Enabled')critCount++;
  if(secureBoot&&secureBoot!=='Enabled')warnCount++;
  const statusCls=critCount?'err':(warnCount?'warn':'ok');
  const statusText=critCount?critCount+' error'+(critCount===1?'':'s')+', '+warnCount+' warning'+(warnCount===1?'':'s')+' here':(warnCount?warnCount+' warning'+(warnCount===1?'':'s')+' here':'No problems found');
  const secBadgeEl=document.getElementById('securityTabBadge');
  if(secBadgeEl){ const bc=critCount+warnCount; if(bc){secBadgeEl.textContent=bc;secBadgeEl.style.display='';} else {secBadgeEl.style.display='none';} }

  let h='<div class="dp-head"><div class="dp-crumb"><span class="crumb">Software <span class="material-symbols-outlined" style="font-size:16px">chevron_right</span> <b>Security</b></span>'+
    '<div class="dp-actions"><div class="m3-btn" id="copySecurityBtn"><span class="material-symbols-outlined" style="font-size:18px">content_copy</span>Copy</div></div></div>'+
    '<div class="dp-title-row"><div><div class="dp-title">Security</div><div class="dp-sub">Protection state, remote access and what has been excluded from scanning</div></div>'+
    '<div class="dp-status '+statusCls+'"><span class="status-dot"></span>'+esc(statusText)+'</div></div></div>';

  if(posture.length){
    h+='<div class="dp-posture" style="grid-template-columns:repeat('+posture.length+',1fr)">'+posture.map(p=>
      '<div class="dp-posture-card '+p.cls+'"><span class="material-symbols-outlined" style="color:'+(p.cls==='err'?'var(--err)':p.cls==='warn'?'var(--warn)':p.cls===''&&(p.icon==='verified_user'||p.icon==='lock')?'var(--ok)':'var(--faint)')+'">'+p.icon+'</span>'+
      '<div><div class="dp-posture-t">'+esc(p.title)+'</div><div class="dp-posture-s">'+esc(p.sub)+'</div></div></div>'
    ).join('')+'</div>';
  }

  const cards=[];
  if(tpmStatus||secureBoot||uac){
    let c='<div class="dp-card"><div class="dp-card-head"><div class="dp-card-title">Firmware &amp; account security</div></div><div class="dp-kv">';
    if(tpmStatus)c+='<dt>'+flagLink('tpm','TPM')+'</dt><dd style="color:'+(tpmStatus==='Enabled'?'var(--ok)':'var(--err)')+'">'+esc(tpmStatus)+(tpmVersion?' <span style="color:var(--faint)">('+esc(tpmVersion)+')</span>':'')+'</dd>';
    if(secureBoot)c+='<dt>'+flagLink('secure-boot','Secure Boot')+'</dt><dd style="color:'+(secureBoot==='Enabled'?'var(--ok)':'var(--warn)')+'">'+esc(secureBoot)+'</dd>';
    if(uac)c+='<dt>User Account Control (UAC)</dt><dd style="color:'+(uac==='Enabled'?'var(--ok)':'var(--err)')+'">'+esc(uac)+'</dd>';
    cards.push(c+'</div></div>');
  }
  if(SECURITY&&SECURITY.avProducts&&SECURITY.avProducts.length){
    let c='<div class="dp-card"><div class="dp-card-head"><div class="dp-card-title">Antivirus</div><span class="dp-card-count">'+SECURITY.avProducts.length+' product'+(SECURITY.avProducts.length===1?'':'s')+'</span></div>';
    SECURITY.avProducts.forEach(a=>{c+='<div class="dp-row"><div class="dp-row-label">'+esc(a.name)+'</div><div class="dp-row-val" style="color:'+(a.enabled?'var(--ok)':'var(--faint)')+'">'+(a.enabled?'Active':'Inactive')+'</div></div>';});
    const activeCount=SECURITY.avProducts.filter(a=>a.enabled).length;
    if(activeCount>1)c+='<div class="dp-banner"><span class="material-symbols-outlined">warning</span><div class="dp-banner-text">Two real-time engines active at once</div></div>';
    cards.push(c+'</div>');
  }
  if(d){
    let c='<div class="dp-card"><div class="dp-card-head"><div class="dp-card-title">Windows Defender</div></div><div class="dp-kv">';
    c+='<dt>Real-time protection</dt><dd style="color:'+(d.rtp==='True'?'var(--ok)':'var(--err)')+'">'+(d.rtp==='True'?'Enabled':'Disabled')+'</dd>';
    if(d.lastQuick)c+='<dt>Last quick scan</dt><dd>'+esc(d.lastQuick)+'</dd>';
    if(d.lastFull)c+='<dt>Last full scan</dt><dd>'+esc(d.lastFull)+'</dd>';
    if(d.sigAge)c+='<dt>Signature age</dt><dd>'+esc(d.sigAge)+' day'+(d.sigAge==='1'?'':'s')+'</dd>';
    if(d.sigVersion)c+='<dt>Security intelligence</dt><dd class="mono">'+esc(d.sigVersion)+'</dd>';
    cards.push(c+'</div></div>');
  }
  if(SECURITY&&SECURITY.firewall&&SECURITY.firewall.length){
    let c='<div class="dp-card"><div class="dp-card-head"><div class="dp-card-title">Firewall</div></div>';
    SECURITY.firewall.forEach(f=>{c+='<div class="dp-row"><div class="dp-row-label">'+esc(f.profile)+'</div><div class="dp-row-val" style="color:'+(f.enabled==='True'?'var(--ok)':'var(--err)')+'">'+(f.enabled==='True'?'Enabled':'Disabled')+'</div></div>';});
    cards.push(c+'</div>');
  }
  if(SECURITY&&(SECURITY.rdp||SECURITY.acctType)){
    let c='<div class="dp-card"><div class="dp-card-head"><div class="dp-card-title">Remote Desktop (RDP)</div></div><div class="dp-kv">';
    if(SECURITY.acctType)c+='<dt>Signed-in account</dt><dd>'+esc(SECURITY.acctType)+'</dd>';
    let bannerText='';
    if(SECURITY.rdp){
      const r=SECURITY.rdp;
      c+='<dt>Status</dt><dd style="color:'+(r.enabled?'var(--warn)':'var(--ok)')+'">'+(r.enabled?'Enabled':'Disabled')+'</dd>';
      if(r.enabled){
        if(r.nlaRequired!==null)c+='<dt>Network Level Authentication</dt><dd style="color:'+(r.nlaRequired?'var(--ok)':'var(--warn)')+'">'+(r.nlaRequired?'Required':'Not required')+'</dd>';
        if(!r.nlaRequired&&/local admin/i.test(SECURITY.acctType||''))bannerText='Reachable without NLA, on a local admin account';
        else if(!r.nlaRequired)bannerText='Reachable without Network Level Authentication';
      }
    }
    c+='</div>';
    if(bannerText)c+='<div class="dp-banner"><span class="material-symbols-outlined">warning</span><div class="dp-banner-text">'+esc(bannerText)+'</div></div>';
    cards.push(c+'</div>');
  }
  if(SECURITY&&SECURITY.bitlocker&&SECURITY.bitlocker.length){
    let c='<div class="dp-card"><div class="dp-card-head"><div class="dp-card-title">BitLocker</div><span class="dp-card-count">'+SECURITY.bitlocker.length+' volume'+(SECURITY.bitlocker.length===1?'':'s')+'</span></div>';
    SECURITY.bitlocker.forEach(b=>{
      const on=b.status==='On';
      c+='<div class="dp-row"><div class="dp-row-label">'+esc(b.drive||'?')+(b.type?' <span style="color:var(--faint)">('+esc(b.type)+')</span>':'')+'</div><div class="dp-row-val" style="color:'+(on?'var(--ok)':'var(--faint)')+'">'+(on?'On':'Off')+'</div></div>';
    });
    cards.push(c+'</div>');
  }
  if(SECURITY&&SECURITY.threats&&SECURITY.threats.length){
    let c='<div class="dp-card"><div class="dp-card-head"><div class="dp-card-title">Threat detections</div><span class="dp-card-count">'+SECURITY.threats.length+'</span></div>';
    SECURITY.threats.forEach(t=>{c+='<div class="dp-row"><div class="dp-row-label">'+esc(t.name)+' <span style="color:var(--faint)">'+esc(t.time)+'</span></div><div class="dp-row-val" style="color:'+(t.act==='True'?'var(--ok)':'var(--err)')+'">'+(t.act==='True'?'Action successful':'Action failed')+'</div></div>';});
    cards.push(c+'</div>');
  } else if(d){
    cards.push('<div class="dp-card"><div class="dp-card-head"><div class="dp-card-title">Threat detections</div></div><div class="dp-empty" style="color:var(--ok)">\u2713 No threats recorded by Windows Defender.</div></div>');
  }
  if(SECURITY&&SECURITY.exclusions&&SECURITY.exclusions.length){
    const flagged=SECURITY.exclFlags||[];
    let c='<div class="dp-card"><div class="dp-card-head"><div class="dp-card-title">Defender exclusions</div><span class="dp-card-count">'+SECURITY.exclusions.length+' entr'+(SECURITY.exclusions.length===1?'y':'ies')+'</span></div>';
    if(flagged.length)c+='<div class="dp-card-note">Anything listed here is not scanned. '+flagged.length+' entr'+(flagged.length===1?'y was':'ies were')+' flagged as risky.</div>';
    c+='<div style="display:flex;flex-direction:column;gap:8px">';
    flagged.slice(0,6).forEach(f=>{c+='<div class="dp-flag-row"><span class="material-symbols-outlined">warning</span><span class="mono">'+esc(f)+'</span></div>';});
    const shown=Math.min(6,flagged.length);
    const restCount=SECURITY.exclusions.length-shown;
    if(restCount>0)c+='<div class="dp-plain-row">'+restCount+' more exclusion'+(restCount===1?'':'s')+'</div>';
    cards.push(c+'</div></div>');
  }
  if(typeof (SECURITY&&SECURITY.hostsCustom)==='number'){
    const flags=SECURITY.hostsFlags||[];
    let c='<div class="dp-card"><div class="dp-card-head"><div class="dp-card-title">Hosts file</div></div><div class="dp-card-note">'+SECURITY.hostsCustom+' custom entr'+(SECURITY.hostsCustom===1?'y':'ies')+' found'+(flags.length?'.':', none flagged.')+'</div>';
    if(flags.length){
      c+='<div style="display:flex;flex-direction:column;gap:8px">';
      flags.forEach(f=>{c+='<div class="dp-flag-row"><span class="material-symbols-outlined">warning</span><span class="mono">'+esc(f)+'</span></div>';});
      c+='</div>';
    }
    cards.push(c+'</div>');
  }
  if(SECURITY&&SECURITY.startupFlags&&SECURITY.startupFlags.length){
    let c='<div class="dp-card"><div class="dp-card-head"><div class="dp-card-title">Startup entries flagged</div><span class="dp-card-count">'+SECURITY.startupFlags.length+'</span></div>'+
      '<div class="dp-card-note">No publisher, or launching from a temporary location.</div><div style="display:flex;flex-direction:column;gap:8px">';
    SECURITY.startupFlags.forEach(f=>{c+='<div class="dp-plain-row mono">'+esc(f)+'</div>';});
    cards.push(c+'</div></div>');
  }
  if(SECURITY&&SECURITY.firewallProducts&&SECURITY.firewallProducts.length){
    let c='<div class="dp-card"><div class="dp-card-head"><div class="dp-card-title">Third-party firewall software</div></div>';
    SECURITY.firewallProducts.forEach(a=>{c+='<div class="dp-row"><div class="dp-row-label">'+esc(a.name)+'</div><div class="dp-row-val" style="color:'+(a.enabled?'var(--ok)':'var(--faint)')+'">'+(a.enabled?'Active':'Inactive')+'</div></div>';});
    cards.push(c+'</div>');
  }

  h+='<div class="dp-body">'+(cards.length?cards.join(''):'<div class="dp-card"><div class="dp-empty">No security data embedded.</div></div>')+'</div>';
  v.innerHTML=h;
  const copyBtn=document.getElementById('copySecurityBtn');
  if(copyBtn)copyBtn.onclick=()=>{
    const txt=v.textContent.replace(/\s*\n\s*/g,'\n').trim();
    const done=()=>{const old=copyBtn.innerHTML;copyBtn.innerHTML='<span class="material-symbols-outlined" style="font-size:18px">check</span>Copied';setTimeout(()=>{copyBtn.innerHTML=old;},1500);};
    if(navigator.clipboard&&navigator.clipboard.writeText)navigator.clipboard.writeText(txt).then(done).catch(()=>{});
    else{const ta=document.createElement('textarea');ta.value=txt;document.body.appendChild(ta);ta.select();document.execCommand('copy');document.body.removeChild(ta);done();}
  };
}
function renderGPU(){
  const v=document.getElementById('gpuView');
  if(!GPUS.length && !DISPLAYS.length){
    v.innerHTML='<div class="dp-head"><div class="dp-crumb"><span class="crumb">Hardware <span class="material-symbols-outlined" style="font-size:16px">chevron_right</span> <b>Graphics</b></span></div>'+
      '<div class="dp-title-row"><div><div class="dp-title">Graphics (GPU)</div></div></div></div>'+
      '<div class="dp-content"><div class="dp-card"><div class="dp-empty">No GPU data embedded.</div></div></div>';
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
    const igpuActive=!!byGpu[igpu.name]||igpu.hres>0,dgpuActive=!!byGpu[dgpu.name]||dgpu.hres>0;
    if(igpuActive&&!dgpuActive)mismatchActive='igpu';
  }

  // Same layout vocabulary as Memory/Storage: title with the headline part, stat tiles, then one
  // card per adapter and per display. Which GPU drives which display is shown on the cards
  // ("Driving" / "Connected to") rather than a separate diagram.
  const basicRe=g=>/root\\basic(display|render)/i.test(g.pnp||'')||/microsoft basic (display|render)/i.test(g.name);
  const basicGpu=GPUS.find(basicRe);
  const gpuState=g=>{
    if(basicRe(g))return {cls:'err',label:'Generic driver'};
    if(mismatchActive==='igpu'&&g.name===igpu.name)return {cls:'warn',label:'Wrong port'};
    if(byGpu[g.name]||g.hres>0)return {cls:'ok',label:'Active'};
    return {cls:'plain',label:'Idle'};
  };
  const primary=(dgpu&&GPUS.includes(dgpu))?dgpu:GPUS[0];
  const drvPlain=g=>g&&g.drv?friendlyDriver(g.name,g.drv,g.radeon||'').replace(/\s*<span[^>]*>.*<\/span>/,''):'';
  const drvAge=g=>{if(!g||!g.driverDate)return null;const d=new Date(g.driverDate);return isNaN(d)?null:Math.floor((Date.now()-d)/86400000);};
  const ageTxt=n=>n==null?'':n<31?n+' day'+(n===1?'':'s')+' old':n<365?Math.floor(n/30)+' month'+(Math.floor(n/30)===1?'':'s')+' old':Math.floor(n/365)+' year'+(Math.floor(n/365)===1?'':'s')+' old';

  const gpuSubParts=[GPUS.length?GPUS.length+' adapter'+(GPUS.length===1?'':'s'):'',displays.length?displays.length+' display'+(displays.length===1?'':'s'):''].filter(Boolean);
  const issues=(mismatchActive?1:0)+(basicGpu?1:0);
  const gpuStatusCls=basicGpu?'err':mismatchActive?'warn':'ok';
  const gpuBadgeEl=document.getElementById('gpuTabBadge');
  if(gpuBadgeEl){ if(issues){gpuBadgeEl.textContent=issues;gpuBadgeEl.className='tab-badge'+(basicGpu?'':' warn');gpuBadgeEl.style.display='';} else {gpuBadgeEl.style.display='none';} }
  const gpuStatusText=issues?issues+' warning'+(issues>1?'s':'')+' on this component':'No problems found';
  const gpuTitle='Graphics (GPU)'+(primary?' '+primary.name.replace(/^NVIDIA\s+/i,'NVIDIA ').trim():'');

  let h='<div class="dp-head"><div class="dp-crumb"><span class="crumb">Hardware <span class="material-symbols-outlined" style="font-size:16px">chevron_right</span> <b>Graphics</b></span>'+
    '<div class="dp-actions"><div class="m3-btn" id="copyGpuBtn"><span class="material-symbols-outlined" style="font-size:18px">content_copy</span>Copy</div></div></div>'+
    '<div class="dp-title-row"><div><div class="dp-title">'+esc(gpuTitle)+'</div><div class="dp-sub">'+esc(gpuSubParts.join(' \u00b7 '))+'</div></div>'+
    '<div class="dp-status '+gpuStatusCls+'"><span class="status-dot"></span>'+esc(gpuStatusText)+'</div></div></div>';

  const age=drvAge(primary);
  const d0=displays[0];
  h+='<div class="dp-stats">'+
    '<div class="dp-stat"><div class="dp-stat-l">VRAM</div><div class="dp-stat-v">'+(primary&&primary.vram?primary.vram+'<span class="unit"> GB</span>':'\u2014')+'</div></div>'+
    '<div class="dp-stat"><div class="dp-stat-l">Driver</div><div class="dp-stat-v"'+(basicGpu?' style="color:var(--err)"':'')+'>'+esc(basicGpu?'Generic':(drvPlain(primary)||'\u2014'))+'</div>'+(primary&&primary.drv&&!basicGpu?'<div class="dp-stat-sub mono">'+esc(primary.drv)+'</div>':'')+'</div>'+
    '<div class="dp-stat"><div class="dp-stat-l">Driver date</div><div class="dp-stat-v">'+(primary&&primary.driverDate?esc(fmtDay(primary.driverDate)):'\u2014')+'</div>'+(age!=null?'<div class="dp-stat-sub">'+esc(ageTxt(age))+'</div>':'')+'</div>'+
    '<div class="dp-stat"><div class="dp-stat-l">Displays</div><div class="dp-stat-v">'+(displays.length+unmatchedMons.length)+'</div>'+(d0&&d0.res?'<div class="dp-stat-sub">'+esc(d0.res.replace(/\s*x\s*/i,'\u00d7'))+(d0.hz?' @ '+esc(d0.hz):'')+(displays.length>1?' (primary)':'')+'</div>':'')+'</div>'+
    '</div>';

  h+='<div class="dp-content">';
  if(basicGpu){
    h+='<div class="dp-banner err" onclick="return goFaq(\'basic-display-adapter\')" style="margin-top:0"><span class="material-symbols-outlined">error</span>'+
      '<div class="dp-banner-text">Windows is using the generic Microsoft Basic Display Adapter instead of a real GPU driver</div><span class="dp-banner-link">Explain \u2192</span></div>';
  }
  if(mismatchActive==='igpu'){
    h+='<div class="dp-banner" onclick="return goFaq(\'wrong-gpu-slot\')" style="margin-top:0"><span class="material-symbols-outlined">warning</span>'+
      '<div class="dp-banner-text">Display is connected to the integrated GPU ('+esc(igpu.name)+'), not the dedicated '+esc(dgpu.name)+'. Move the monitor cable to the graphics card\u2019s own ports.</div><span class="dp-banner-link">Explain \u2192</span></div>';
  }

  if(GPUS.length){
    h+='<div><div class="dp-section-label">Adapters ('+GPUS.length+')</div><div class="vol-grid">';
    GPUS.forEach(g=>{
      const st=gpuState(g);
      const drives=(byGpu[g.name]||[]).map(d=>d.mon||'Display');
      const url=gpuDriverUrl(g.name);
      const a=drvAge(g);
      h+='<div class="dp-card'+(st.cls==='err'?' vol-card-err':st.cls==='warn'?' vol-card-warn':'')+'"><div class="dp-card-head"><div class="dp-card-title" style="font-size:16px">'+esc(g.name)+'</div>'+
        '<span class="vol-chip '+st.cls+'">'+esc(st.label)+'</span></div><div class="dp-kv">'+
        (g.drv?'<dt>Driver</dt><dd>'+friendlyDriver(g.name,g.drv,g.radeon||'')+'</dd>':'')+
        (g.driverDate?'<dt>Driver date</dt><dd>'+esc(fmtDay(g.driverDate))+(a!=null?' <span style="color:var(--faint)">('+esc(ageTxt(a))+')</span>':'')+'</dd>':'')+
        (g.vram?'<dt>VRAM</dt><dd>'+esc(g.vram)+' GB</dd>':'')+
        (g.hres>0?'<dt>Current mode</dt><dd>'+esc(g.hres)+'\u00d7'+esc(g.vres)+(g.hz?' @ '+esc(g.hz)+' Hz':'')+'</dd>':'')+
        '<dt>Driving</dt><dd>'+(drives.length?esc(drives.join(', ')):'<span style="color:var(--faint)">No display</span>')+'</dd>'+
        (url?'<dt>Updates</dt><dd><a href="'+url+'" target="_blank" rel="noopener" style="color:var(--info)">Vendor driver page \u2197</a></dd>':'')+
        '</div></div>';
    });
    h+='</div></div>';
  }

  if(displays.length||unmatchedMons.length){
    h+='<div><div class="dp-section-label">Displays ('+(displays.length+unmatchedMons.length)+')</div><div class="vol-grid">';
    displays.forEach(d=>{
      const conn=((d.mon||'').match(/\((DP|HDMI|DVI|VGA|USB-C|Thunderbolt|eDP|Internal)\)\s*$/i)||[])[1];
      const name=(d.mon||'Display').replace(/\s*\((DP|HDMI|DVI|VGA|USB-C|Thunderbolt|eDP|Internal)\)\s*$/i,'');
      const warn=mismatchActive==='igpu'&&d.gpu===igpu.name;
      h+='<div class="dp-card'+(warn?' vol-card-warn':'')+'"><div class="dp-card-head"><div class="dp-card-title" style="font-size:16px">'+esc(name)+'</div>'+
        (conn?'<span class="vol-chip plain">'+esc(conn.toUpperCase()==='DP'?'DisplayPort':conn)+'</span>':'')+'</div><div class="dp-kv">'+
        (d.res?'<dt>Resolution</dt><dd>'+esc(d.res.replace(/\s*x\s*/i,' \u00d7 '))+'</dd>':'')+
        (d.hz?'<dt>Refresh rate</dt><dd>'+esc(d.hz)+'</dd>':'')+
        (d.bits?'<dt>Colour depth</dt><dd>'+esc(d.bits)+'-bit</dd>':'')+
        '<dt>Connected to</dt><dd'+(warn?' style="color:var(--warn)"':'')+'>'+esc(d.gpu)+'</dd>'+
        '</div></div>';
    });
    unmatchedMons.forEach(name=>{
      h+='<div class="dp-card"><div class="dp-card-head"><div class="dp-card-title" style="font-size:16px">'+esc(name)+'</div></div><div class="dp-kv">'+
        '<dt>Connected to</dt><dd style="color:var(--faint)">Unknown (detected via EDID only)</dd></div></div>';
    });
    h+='</div></div>';
  }

  h+='</div>';
  v.innerHTML=h;
  const copyBtn=document.getElementById('copyGpuBtn');
  if(copyBtn)copyBtn.onclick=()=>{
    const txt=v.textContent.replace(/\s*\n\s*/g,'\n').trim();
    const done=()=>{const old=copyBtn.innerHTML;copyBtn.innerHTML='<span class="material-symbols-outlined" style="font-size:18px">check</span>Copied';setTimeout(()=>{copyBtn.innerHTML=old;},1500);};
    if(navigator.clipboard&&navigator.clipboard.writeText)navigator.clipboard.writeText(txt).then(done).catch(()=>{});
    else{const ta=document.createElement('textarea');ta.value=txt;document.body.appendChild(ta);ta.select();document.execCommand('copy');document.body.removeChild(ta);done();}
  };
}
function renderMotherboard(){
  const v=document.getElementById('moboView');
  const sp=parseSpecs(SPECS);
  const mb=specVal(sp.info,'Motherboard'), mbMfr=specVal(sp.info,'Motherboard Manufacturer');
  if(!mb){
    v.innerHTML='<div class="dp-head"><div class="dp-crumb"><span class="crumb">Hardware <span class="material-symbols-outlined" style="font-size:16px">chevron_right</span> <b>Motherboard</b></span></div>'+
      '<div class="dp-title-row"><div><div class="dp-title">Motherboard</div></div></div></div>'+
      '<div class="dp-content"><div class="dp-card"><div class="dp-empty">No motherboard data embedded.</div></div></div>';
    return;
  }
  const mbClean=((mbMfr||'').replace(/ASUSTeK COMPUTER INC\./i,'ASUS').replace(/Micro-Star International.*/i,'MSI').replace(/Gigabyte Technology.*/i,'Gigabyte')+' '+mb).trim();
  const bver=specVal(sp.info,'BIOS Version');
  const bdate=specVal(sp.info,'BIOS Date');
  const biosMfr=specVal(sp.info,'BIOS Manufacturer');
  const firmwareMode=specVal(sp.info,'Firmware Mode');
  const fastBoot=specVal(sp.info,'Fast Boot State');
  const powerPlan=specVal(sp.info,'Active Power Plan');
  // OEM boards frequently leave the serial number field as an unset placeholder rather than
  // leaving it blank, so those need filtering out same as an actually-empty value would be.
  const serialRaw=specVal(sp.info,'Motherboard Serial');
  const serial=(serialRaw&&!/^(default string|none|to be filled by o\.?e\.?m\.?|not specified|n\/a|0+)$/i.test(serialRaw.trim()))?serialRaw.trim():'';
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

  let bdateAge='',bdateWarn=false;
  if(bdate){
    const parsed=new Date(bdate);
    if(!isNaN(parsed)){
      const yrs=(Date.now()-parsed)/(365.25*86400000);
      if(yrs>=1){bdateAge=' \u00b7 '+Math.floor(yrs)+' year'+(Math.floor(yrs)===1?'':'s')+' old';bdateWarn=yrs>=2;}
    }
  }
  const fastBootWarn=fastBoot==='Enabled';
  const moboWarnCount=(bdateWarn?1:0)+(fastBootWarn?1:0);
  const statusCls=moboWarnCount?'warn':'ok';
  const moboBadgeEl=document.getElementById('moboTabBadge');
  if(moboBadgeEl){ if(moboWarnCount){moboBadgeEl.textContent=moboWarnCount;moboBadgeEl.style.display='';} else {moboBadgeEl.style.display='none';} }
  const statusText=moboWarnCount?moboWarnCount+' warning'+(moboWarnCount>1?'s':'')+' here':'No problems found';

  let h='<div class="dp-head"><div class="dp-crumb"><span class="crumb">Hardware <span class="material-symbols-outlined" style="font-size:16px">chevron_right</span> <b>Motherboard</b></span>'+
    '<div class="dp-actions"><div class="m3-btn" id="copyMoboBtn"><span class="material-symbols-outlined" style="font-size:18px">content_copy</span>Copy</div></div></div>'+
    '<div class="dp-title-row"><div><div class="dp-title">Motherboard '+esc(mbClean)+'</div></div>'+
    '<div class="dp-status '+statusCls+'"><span class="status-dot"></span>'+esc(statusText)+'</div></div></div>';

  h+='<div class="dp-content"><div class="dp-card"><div class="dp-kv">'+
    (mb?'<dt>Model</dt><dd>'+esc(mb)+'</dd>':'')+
    (mbMfr?'<dt>Manufacturer</dt><dd>'+esc(mbMfr)+'</dd>':'')+
    (serial?'<dt>Serial number</dt><dd class="mono">'+esc(serial)+'</dd>':'')+
    (bver?'<dt>BIOS version</dt><dd>'+esc(bver)+(biosMfr?' <span style="color:var(--faint)">('+esc(biosMfr)+')</span>':'')+'</dd>':'')+
    (bdate?'<dt>BIOS date</dt><dd style="color:'+(bdateWarn?'var(--warn)':'var(--dim)')+'">'+esc(bdate.replace(/\s+\d{1,2}:\d{2}(:\d{2})?(\s*[AP]M)?$/i,''))+bdateAge+'</dd>':'')+
    (firmwareMode?'<dt>Firmware mode</dt><dd>'+esc(firmwareMode)+'</dd>':'')+
    (fastBoot?'<dt>Fast startup</dt><dd style="color:'+(fastBootWarn?'var(--warn)':'var(--dim)')+'">'+esc(fastBoot)+'</dd>':'')+
    (powerPlan?'<dt>Active power plan</dt><dd>'+esc(powerPlan)+'</dd>':'')+
    '</div>'+
    '<div class="dp-clickrow" style="margin-top:16px" onclick="window.open(\''+biosUrl+'\',\'_blank\')"><span class="material-symbols-outlined" style="color:var(--info)">system_update</span>'+
    '<div style="flex:1"><div class="dp-clickrow-t">Check for BIOS updates</div></div><span class="material-symbols-outlined" style="color:var(--faint)">open_in_new</span></div>'+
    '</div></div>';

  v.innerHTML=h;
  const copyBtn=document.getElementById('copyMoboBtn');
  if(copyBtn)copyBtn.onclick=()=>{
    const txt=v.textContent.replace(/\s*\n\s*/g,'\n').trim();
    const done=()=>{const old=copyBtn.innerHTML;copyBtn.innerHTML='<span class="material-symbols-outlined" style="font-size:18px">check</span>Copied';setTimeout(()=>{copyBtn.innerHTML=old;},1500);};
    if(navigator.clipboard&&navigator.clipboard.writeText)navigator.clipboard.writeText(txt).then(done).catch(()=>{});
    else{const ta=document.createElement('textarea');ta.value=txt;document.body.appendChild(ta);ta.select();document.execCommand('copy');document.body.removeChild(ta);done();}
  };
}
function renderCPU(){
  const v=document.getElementById('cpuView');
  const sp=parseSpecs(SPECS);
  const cpuName=specVal(sp.info,'CPU Name');
  if(!cpuName){
    v.innerHTML='<div class="dp-head"><div class="dp-crumb"><span class="crumb">Hardware <span class="material-symbols-outlined" style="font-size:16px">chevron_right</span> <b>Processor</b></span></div>'+
      '<div class="dp-title-row"><div><div class="dp-title">Processor</div></div></div></div>'+
      '<div class="dp-split"><div class="dp-split-main"><div class="dp-card"><div class="dp-empty">No processor data embedded.</div></div></div></div>';
    return;
  }
  const ct=specVal(sp.info,'CPU Cores/Threads'), ctm=(ct||'').match(/(\d+)C\s*\/\s*(\d+)T/i);
  const ghz=specVal(sp.info,'CPU Speed');
  const ghzm=(ghz||'').match(/^([\d.]+)\s*(.*)$/);
  const l2=specVal(sp.info,'CPU L2 Cache'), l3=specVal(sp.info,'CPU L3 Cache');
  const cacheHeadline=l3||l2, cacheHeadlineLabel=l3?'L3 cache':'L2 cache';
  const cachem=(cacheHeadline||'').match(/^([\d.]+)\s*(.*)$/);
  const socket=specVal(sp.info,'CPU Socket'), arch=specVal(sp.info,'CPU Architecture');
  const virt=specVal(sp.info,'CPU Virtualization');
  const subParts=[ctm?ctm[1]+' cores / '+ctm[2]+' threads':'',socket?'socket '+socket:'',arch||''].filter(Boolean);

  const cpuBadgeEl=document.getElementById('cpuTabBadge');
  if(cpuBadgeEl)cpuBadgeEl.style.display='none';

  let h='<div class="dp-head"><div class="dp-crumb"><span class="crumb">Hardware <span class="material-symbols-outlined" style="font-size:16px">chevron_right</span> <b>Processor</b></span>'+
    '<div class="dp-actions"><div class="m3-btn" id="copyCpuBtn"><span class="material-symbols-outlined" style="font-size:18px">content_copy</span>Copy</div></div></div>'+
    '<div class="dp-title-row"><div><div class="dp-title">CPU - '+esc(cpuName.trim())+'</div><div class="dp-sub">'+esc(subParts.join(' \u00b7 '))+'</div></div>'+
    '<div class="dp-status ok"><span class="status-dot"></span>No problems found</div></div></div>';

  h+='<div class="dp-stats">'+
    (ctm?'<div class="dp-stat"><div class="dp-stat-l">Cores</div><div class="dp-stat-v">'+ctm[1]+'</div><div class="dp-stat-s">physical cores</div></div>':'')+
    (ctm?'<div class="dp-stat"><div class="dp-stat-l">Threads</div><div class="dp-stat-v">'+ctm[2]+'</div><div class="dp-stat-s">logical processors</div></div>':'')+
    (ghzm?'<div class="dp-stat"><div class="dp-stat-l">Speed</div><div class="dp-stat-v">'+ghzm[1]+'<span class="unit"> '+esc(ghzm[2])+'</span></div><div class="dp-stat-s">as reported</div></div>':'')+
    (cachem?'<div class="dp-stat"><div class="dp-stat-l">'+cacheHeadlineLabel+'</div><div class="dp-stat-v">'+cachem[1]+'<span class="unit"> '+esc(cachem[2])+'</span></div><div class="dp-stat-s">shared</div></div>':'')+
    '</div>';

  h+='<div class="dp-content"><div class="dp-card">'+
    '<div class="dp-card-head"><div class="dp-card-title">All reported values</div></div><div class="dp-kv">'+
    '<dt>Name</dt><dd style="text-align:right">'+esc(cpuName.trim())+'</dd>'+
    (ctm?'<dt>Cores / threads</dt><dd style="text-align:right">'+ctm[1]+' / '+ctm[2]+'</dd>':'')+
    (ghz?'<dt>Speed</dt><dd style="text-align:right">'+esc(ghz)+'</dd>':'')+
    (socket?'<dt>Socket</dt><dd style="text-align:right">'+esc(socket)+'</dd>':'')+
    ((l2&&l3)?'<dt>L2 / L3 cache</dt><dd style="text-align:right">'+esc(l2)+' / '+esc(l3)+'</dd>':(l2?'<dt>L2 cache</dt><dd style="text-align:right">'+esc(l2)+'</dd>':(l3?'<dt>L3 cache</dt><dd style="text-align:right">'+esc(l3)+'</dd>':'')))+
    (arch?'<dt>Architecture</dt><dd style="text-align:right">'+esc(arch)+'</dd>':'')+
    (virt?'<dt>Virtualisation</dt><dd style="text-align:right">'+esc(virt)+'</dd>':'')+
    '</div></div></div>';

  v.innerHTML=h;
  const copyBtn=document.getElementById('copyCpuBtn');
  if(copyBtn)copyBtn.onclick=()=>{
    const txt=v.textContent.replace(/\s*\n\s*/g,'\n').trim();
    const done=()=>{const old=copyBtn.innerHTML;copyBtn.innerHTML='<span class="material-symbols-outlined" style="font-size:18px">check</span>Copied';setTimeout(()=>{copyBtn.innerHTML=old;},1500);};
    if(navigator.clipboard&&navigator.clipboard.writeText)navigator.clipboard.writeText(txt).then(done).catch(()=>{});
    else{const ta=document.createElement('textarea');ta.value=txt;document.body.appendChild(ta);ta.select();document.execCommand('copy');document.body.removeChild(ta);done();}
  };
}
function renderMemory(){
  const v=document.getElementById('memoryView');
  const sp=parseSpecs(SPECS);
  const pageFile=specVal(sp.info,'Page File Size');
  const pageFileManaged=specVal(sp.info,'Page File Managed');
  if(!RAM.length){
    v.innerHTML='<div class="dp-head"><div class="dp-crumb"><span class="crumb">Hardware <span class="material-symbols-outlined" style="font-size:16px">chevron_right</span> <b>Memory</b></span></div>'+
      '<div class="dp-title-row"><div><div class="dp-title">Memory (RAM)</div></div></div></div>'+
      '<div class="dp-content"><div class="dp-card"><div class="dp-empty">No memory data embedded.</div></div></div>';
    return;
  }
  const effRatedMem=m=>Math.max(+m.rated||0,+m.pnSpeed||0)||'';
  const totalGB=RAM.reduce((a,m)=>a+(+m.cap||0),0);
  const confSet=[...new Set(RAM.map(m=>m.conf).filter(Boolean))];
  const ratedSet=[...new Set(RAM.map(m=>effRatedMem(m)).filter(Boolean))];
  const typeSet=[...new Set(RAM.map(m=>m.ddrType).filter(Boolean))];
  const mfrSet=[...new Set(RAM.map(m=>m.mfr).filter(Boolean))];
  const ramSlow=RAM.some(m=>effRatedMem(m)&&m.conf&&+m.conf<+effRatedMem(m));

  const memTitle='Memory (RAM)'+(totalGB?' '+totalGB+'GB':'')+(typeSet.length===1?' '+typeSet[0]:'')+(confSet.length?' '+confSet.join('/')+'MT/s':'');
  const memSub=[mfrSet.length===1?mfrSet[0]:'',RAM.length+' module'+(RAM.length===1?'':'s')].filter(Boolean).join(' \u00b7 ');
  const statusCls=ramSlow?'warn':'ok';
  const memBadgeEl=document.getElementById('memoryTabBadge');
  if(memBadgeEl){ if(ramSlow){memBadgeEl.textContent='1';memBadgeEl.style.display='';} else {memBadgeEl.style.display='none';} }
  const statusText=ramSlow?'1 warning here':'No problems found';

  let h='<div class="dp-head"><div class="dp-crumb"><span class="crumb">Hardware <span class="material-symbols-outlined" style="font-size:16px">chevron_right</span> <b>Memory</b></span>'+
    '<div class="dp-actions"><div class="m3-btn" id="copyMemBtn"><span class="material-symbols-outlined" style="font-size:18px">content_copy</span>Copy</div></div></div>'+
    '<div class="dp-title-row"><div><div class="dp-title">'+esc(memTitle)+'</div>'+
    (memSub?'<div class="dp-sub">'+esc(memSub)+'</div>':'')+'</div>'+
    '<div class="dp-status '+statusCls+'"><span class="status-dot"></span>'+esc(statusText)+'</div></div></div>';

  h+='<div class="dp-stats">'+
    '<div class="dp-stat"><div class="dp-stat-l">Capacity</div><div class="dp-stat-v">'+totalGB+'<span class="unit"> GB</span></div></div>'+
    (confSet.length?'<div class="dp-stat"><div class="dp-stat-l">Configured speed</div><div class="dp-stat-v" style="color:'+(ramSlow?'var(--warn)':'var(--text)')+'">'+esc(confSet.join('/'))+'<span class="unit"> MT/s</span></div></div>':'')+
    (ratedSet.length?'<div class="dp-stat"><div class="dp-stat-l">Rated speed</div><div class="dp-stat-v">'+esc(ratedSet.join('/'))+'<span class="unit"> MT/s</span></div></div>':'')+
    '<div class="dp-stat"><div class="dp-stat-l">Modules</div><div class="dp-stat-v">'+RAM.length+(RAMSLOTS?'<span class="unit"> / '+RAMSLOTS+'</span>':'')+'</div></div>'+
    '</div>';

  h+='<div class="dp-content">';

  if(ramSlow){
    h+='<div class="dp-banner" onclick="return goFaq(\'ram-speed\')" style="margin-top:0"><span class="material-symbols-outlined">warning</span>'+
      '<div class="dp-banner-text">Running at '+esc(confSet.join('/'))+' of '+esc(ratedSet.join('/'))+' MT/s \u2014 XMP/EXPO appears disabled</div>'+
      '<span class="dp-banner-link">Explain \u2192</span></div>';
  }

  if(RAMSLOTS){
    const slotCols=Math.max(RAMSLOTS,RAM.length);
    h+='<div><div class="dp-section-label">Slot map</div><div class="dp-card slot-grid" style="grid-template-columns:repeat('+slotCols+',1fr)">'+
      RAM.map((m,i)=>'<span class="vol-chip plain slot-chip" onclick="highlightModule('+i+')" title="Show this module">'+esc(m.slot||'?')+' \u00b7 '+esc(m.cap)+' GB</span>').join('')+
      Array.from({length:Math.max(0,RAMSLOTS-RAM.length)},()=>'<span class="vol-chip plain slot-chip empty">Empty</span>').join('')+
      '</div></div>';
  }

  h+='<div><div class="dp-section-label">Modules ('+RAM.length+')</div><div class="vol-grid">';
  RAM.forEach((m,i)=>{
    const modSlow=effRatedMem(m)&&m.conf&&+m.conf<+effRatedMem(m);
    h+='<div class="dp-card" id="ramModule-'+i+'"><div class="dp-card-head"><div class="dp-card-title" style="font-size:16px">'+esc(m.slot)+'</div>'+(m.mfr?'<span class="dp-card-count">'+esc(m.mfr)+'</span>':'')+'</div><div class="dp-kv">'+
      '<dt>Part number</dt><dd class="mono" style="font-size:13px">'+esc(m.pn||'?')+'</dd>'+
      (m.ddrType?'<dt>Type</dt><dd>'+esc(m.ddrType)+'</dd>':'')+
      '<dt>Capacity</dt><dd>'+esc(m.cap)+' GB</dd>'+
      (m.rated?'<dt>Rated speed</dt><dd>'+esc(m.rated)+' MT/s</dd>':'')+
      (m.pnSpeed?'<dt>Speed (from part number)</dt><dd>'+esc(m.pnSpeed)+' MT/s</dd>':'')+
      (m.conf?'<dt>Configured speed</dt><dd style="color:'+(modSlow?'var(--warn)':'var(--dim)')+'">'+esc(m.conf)+' MT/s</dd>':'')+
      '</div></div>';
  });
  h+='</div></div>';

  const hasOtherBox=(MEMUSE&&(MEMUSE.avail!=null||MEMUSE.cache!=null||MEMUSE.pagedPool!=null||MEMUSE.nonPagedPool!=null))||pageFile;
  if((MEMUSE&&MEMUSE.pt)||hasOtherBox){
    h+='<div><div class="dp-section-label">Memory usage at capture</div><div class="vol-grid">';
    if(MEMUSE&&MEMUSE.pt){
      const physPct=Math.round(MEMUSE.pu/MEMUSE.pt*100);
      h+='<div class="dp-card"><div class="dp-card-head"><div class="dp-card-title" style="font-size:16px">In use (compressed)</div></div>'+
        '<div class="vol-bar-track" style="margin-bottom:10px"><div class="vol-bar-fill'+(physPct>85?' warn':'')+'" style="width:'+Math.min(physPct,100)+'%"></div></div>'+
        '<div class="mono" style="font-size:14px;color:var(--dim)">'+MEMUSE.pu.toFixed(1)+' GB used of '+MEMUSE.pt.toFixed(1)+' GB ('+physPct+'%)</div></div>';
      if(MEMUSE.ct){
        const commitPct=Math.round(MEMUSE.cu/MEMUSE.ct*100);
        h+='<div class="dp-card"><div class="dp-card-head"><div class="dp-card-title" style="font-size:16px">Committed</div></div>'+
          '<div class="vol-bar-track" style="margin-bottom:10px"><div class="vol-bar-fill'+(commitPct>90?' warn':'')+'" style="width:'+Math.min(commitPct,100)+'%"></div></div>'+
          '<div class="mono" style="font-size:14px;color:var(--dim)">'+MEMUSE.cu.toFixed(1)+' GB used of '+MEMUSE.ct.toFixed(1)+' GB ('+commitPct+'%)</div></div>';
      }
    }
    if(hasOtherBox){
      h+='<div class="dp-card"><div class="dp-card-head"><div class="dp-card-title" style="font-size:16px">Other</div></div><div class="dp-kv">'+
        (MEMUSE&&MEMUSE.avail!=null?'<dt>Available</dt><dd>'+MEMUSE.avail.toFixed(1)+' GB</dd>':'')+
        (MEMUSE&&MEMUSE.cache!=null?'<dt>Cached</dt><dd>'+MEMUSE.cache.toFixed(2)+' GB</dd>':'')+
        (MEMUSE&&MEMUSE.pagedPool!=null?'<dt>Paged pool</dt><dd>'+Math.round(MEMUSE.pagedPool)+' MB</dd>':'')+
        (MEMUSE&&MEMUSE.nonPagedPool!=null?'<dt>Non-paged pool</dt><dd>'+Math.round(MEMUSE.nonPagedPool)+' MB</dd>':'')+
        (pageFile?'<dt>Page file size</dt><dd>'+esc(pageFile)+'</dd>':'')+
        (pageFileManaged?'<dt>Page file management</dt><dd style="color:'+(pageFileManaged==='Manual'?'var(--warn)':pageFileManaged==='Disabled'?'var(--err)':'var(--dim)')+'">'+(pageFileManaged==='Manual'?'Manual (auto-manage off)':pageFileManaged==='Disabled'?'Disabled (no page file)':esc(pageFileManaged))+'</dd>':'')+
        '</div></div>';
    }
    h+='</div></div>';
  }

  h+='</div>';
  v.innerHTML=h;
  const copyBtn=document.getElementById('copyMemBtn');
  if(copyBtn)copyBtn.onclick=()=>{
    const txt=v.textContent.replace(/\s*\n\s*/g,'\n').trim();
    const done=()=>{const old=copyBtn.innerHTML;copyBtn.innerHTML='<span class="material-symbols-outlined" style="font-size:18px">check</span>Copied';setTimeout(()=>{copyBtn.innerHTML=old;},1500);};
    if(navigator.clipboard&&navigator.clipboard.writeText)navigator.clipboard.writeText(txt).then(done).catch(()=>{});
    else{const ta=document.createElement('textarea');ta.value=txt;document.body.appendChild(ta);ta.select();document.execCommand('copy');document.body.removeChild(ta);done();}
  };
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
// One list of network problems, used by both the Network page (banners, card outlines, status,
// badge) and the Diagnostic Summary notes, so the two can never disagree.
function fmtMbps(n){n=+n;return n>=1000?((n/1000)%1?(n/1000).toFixed(1):(n/1000))+' Gbps':Math.round(n)+' Mbps';}
function netIssues(){
  const out=[];
  if(!NET)return out;
  (NET.adapters||[]).forEach(a=>{
    if(!/^up$/i.test(a.status))return;
    const below=a.maxMbps!=null&&a.linkMbps!=null?(a.maxMbps>=1000&&a.linkMbps<a.maxMbps):a.gigabitBelowRated;
    if(below){
      const cap=a.maxMbps?fmtMbps(a.maxMbps):'Gigabit';
      // Under 1 Gbps on a Gigabit-or-better port is almost always a cable/port fault. A 2.5/5/10G
      // port at 1 Gbps is usually just a Gigabit router on the other end, so that's info only.
      const sev=(a.linkMbps!=null&&a.linkMbps>=1000)?'info':'warn';
      out.push({sev,faq:'gigabit-slow',target:'adapter:'+a.name,
        text:esc(a.name)+' is '+esc(cap)+'-capable but connected at only '+esc(a.linkMbps?fmtMbps(a.linkMbps):a.speed)});
    }
    if(a.fullDuplex===false)out.push({sev:'warn',faq:'half-duplex',target:'adapter:'+a.name,text:esc(a.name)+' is running at half duplex'});
  });
  const w=NET.wifi;
  if(w&&w.signal){
    const sig=parseInt(w.signal)||0;
    if(sig&&sig<30)out.push({sev:'err',faq:'wifi-signal',target:'wifi',text:'Very weak Wi-Fi signal ('+sig+'%)'+(w.band?' on '+esc(w.band):'')});
    else if(sig&&sig<50)out.push({sev:'warn',faq:'wifi-signal',target:'wifi',text:'Weak Wi-Fi signal ('+sig+'%)'+(w.band?' on '+esc(w.band):'')});
    const rate=Math.max(+w.rx||0,+w.tx||0);
    const modern=/802\.11(ac|ax|be)/.test(w.radio||''), n=/802\.11n/.test(w.radio||'');
    if(rate&&((modern&&rate<150)||(n&&rate<65)))out.push({sev:'warn',faq:'wifi-link-rate',target:'wifi',text:'Wi-Fi link rate is only '+rate+' Mbps on '+esc(w.radio)});
    if(/^2\.4/.test(w.band||'')&&w.supports5===true)out.push({sev:'info',faq:'wifi-band',target:'wifi',text:'Wi-Fi is on 2.4 GHz, but the adapter supports 5 GHz'});
  }
  return out;
}
function renderNet(){
  const v=document.getElementById('netView');
  if(!NET||(!NET.adapters||!NET.adapters.length)&&!NET.wifi){
    v.innerHTML='<div class="dp-head"><div class="dp-crumb"><span class="crumb">Hardware <span class="material-symbols-outlined" style="font-size:16px">chevron_right</span> <b>Network</b></span></div>'+
      '<div class="dp-title-row"><div><div class="dp-title">Network</div></div></div></div>'+
      '<div class="dp-content"><div class="dp-card"><div class="dp-empty">No network data embedded.</div></div></div>';
    return;
  }
  const connectedCount=(NET.adapters||[]).filter(a=>/^up$/i.test(a.status)).length;
  const SEV_ORDER={err:0,warn:1,info:2};
  const issues=netIssues().sort((a,b)=>SEV_ORDER[a.sev]-SEV_ORDER[b.sev]);
  const flagged=issues.filter(i=>i.sev!=='info');
  const netWarnCount=flagged.length, netHasErr=flagged.some(i=>i.sev==='err');
  const sevFor=t=>{const f=flagged.filter(i=>i.target===t);return f.some(i=>i.sev==='err')?'err':f.length?'warn':'';};
  const netSub=[(NET.adapters||[]).length?(NET.adapters||[]).length+' adapter'+((NET.adapters||[]).length===1?'':'s'):'',connectedCount?connectedCount+' connected':''].filter(Boolean);
  const netStatusCls=netHasErr?'err':netWarnCount?'warn':'ok';
  const netBadgeEl=document.getElementById('netTabBadge');
  if(netBadgeEl){ if(netWarnCount){netBadgeEl.textContent=netWarnCount;netBadgeEl.className='tab-badge'+(netHasErr?'':' warn');netBadgeEl.style.display='';} else {netBadgeEl.style.display='none';} }
  const nErr=flagged.filter(i=>i.sev==='err').length, nWarn=netWarnCount-nErr;
  const netStatusText=netWarnCount?[nErr?nErr+' error'+(nErr>1?'s':''):'',nWarn?nWarn+' warning'+(nWarn>1?'s':''):''].filter(Boolean).join(', '):'No problems found';

  let h='<div class="dp-head"><div class="dp-crumb"><span class="crumb">Hardware <span class="material-symbols-outlined" style="font-size:16px">chevron_right</span> <b>Network</b></span>'+
    '<div class="dp-actions"><div class="m3-btn" id="copyNetBtn"><span class="material-symbols-outlined" style="font-size:18px">content_copy</span>Copy</div></div></div>'+
    '<div class="dp-title-row"><div><div class="dp-title">Network</div><div class="dp-sub">'+esc(netSub.join(' \u00b7 '))+'</div></div>'+
    '<div class="dp-status '+netStatusCls+'"><span class="status-dot"></span>'+esc(netStatusText)+'</div></div></div>';

  h+='<div class="dp-content">';
  issues.forEach(i=>{
    h+='<div class="dp-banner'+(i.sev==='err'?' err':i.sev==='info'?' info':'')+'" onclick="return goFaq(\''+i.faq+'\')" style="margin-top:0"><span class="material-symbols-outlined">'+(i.sev==='err'?'error':i.sev==='info'?'info':'warning')+'</span>'+
      '<div class="dp-banner-text">'+i.text+'</div><span class="dp-banner-link">Explain \u2192</span></div>';
  });
  if(NET.adapters&&NET.adapters.length){
    h+='<div><div class="dp-section-label">Network adapters ('+NET.adapters.length+')</div><div class="vol-grid">';
    NET.adapters.forEach(a=>{
      const up=/^up$/i.test(a.status);
      const stCol=up?'var(--ok)':/disconnect/i.test(a.status)?'var(--warn)':'var(--faint)';
      const sev=sevFor('adapter:'+a.name)||(up&&/802\.11/.test(a.media||'')&&NET.wifi?sevFor('wifi'):'');
      const slow=flagged.some(i=>i.target==='adapter:'+a.name&&i.faq==='gigabit-slow');
      h+='<div class="dp-card'+(sev?' vol-card-'+sev:'')+'"><div class="dp-card-head"><div class="dp-card-title" style="font-size:16px">'+esc(a.name)+'</div></div>'+
        (a.desc?'<div class="dp-card-note">'+esc(a.desc)+'</div>':'')+
        '<div class="dp-kv">'+
        '<dt>Status</dt><dd style="color:'+stCol+'">'+esc(a.status)+'</dd>'+
        (up&&(a.linkMbps||a.speed)?'<dt>Link speed</dt><dd style="color:'+(slow?'var(--warn)':'var(--dim)')+'">'+esc(a.linkMbps?fmtMbps(a.linkMbps):a.speed)+'</dd>':'')+
        (a.maxMbps?'<dt>Maximum speed</dt><dd>'+esc(fmtMbps(a.maxMbps))+'</dd>':'')+
        (up&&a.fullDuplex!=null?'<dt>Duplex</dt><dd'+(a.fullDuplex?'':' style="color:var(--warn)"')+'>'+(a.fullDuplex?'Full':'Half')+'</dd>':'')+
        (a.media?'<dt>Media</dt><dd>'+esc(friendlyMedia(a.media))+'</dd>':'')+
        (a.driverVersion?'<dt>Driver version</dt><dd class="mono">'+esc(a.driverVersion)+'</dd>':'')+
        (a.driverDate?'<dt>Driver date</dt><dd>'+esc(a.driverDate)+'</dd>':'')+
        '</div></div>';
    });
    h+='</div></div>';
  }
  if(NET.vpns&&NET.vpns.length){
    h+='<div><div class="dp-section-label">Virtual adapters ('+NET.vpns.length+')</div><div class="vol-grid">';
    NET.vpns.forEach(a=>{
      const up=/^up$/i.test(a.status);
      h+='<div class="dp-card"><div class="dp-card-head"><div class="dp-card-title" style="font-size:16px">'+esc(a.name)+'</div></div>'+
        (a.desc?'<div class="dp-card-note">'+esc(a.desc)+'</div>':'')+
        '<div class="dp-kv"><dt>Status</dt><dd style="color:'+(up?'var(--ok)':'var(--faint)')+'">'+esc(a.status)+'</dd></div></div>';
    });
    h+='</div></div>';
  }
  if(NET.wifi&&NET.wifi.signal){
    const w=NET.wifi;
    const sig=parseInt(w.signal)||0;
    const wsev=sevFor('wifi');
    h+='<div><div class="dp-section-label">Wi-Fi connection</div><div class="dp-card'+(wsev?' vol-card-'+wsev:'')+'" style="max-width:420px">'+
      '<div class="dp-card-note" style="margin-bottom:8px">Signal '+esc(w.signal)+'</div>'+
      '<div class="vol-bar-track" style="margin-bottom:12px"><div class="vol-bar-fill'+(sig<30?' err':sig<50?' warn':'')+'" style="width:'+sig+'%"></div></div>'+
      '<div class="dp-kv">'+
      (w.band?'<dt>Band</dt><dd>'+esc(w.band)+'</dd>':'')+
      (w.channel?'<dt>Channel</dt><dd>'+esc(w.channel)+(w.width?' ('+esc(w.width)+')':'')+'</dd>':'')+
      (w.radio?'<dt>Radio type</dt><dd>'+esc(w.radio)+'</dd>':'')+
      (w.supports5!=null?'<dt>5 GHz capable</dt><dd>'+(w.supports5?'Yes':'No')+'</dd>':'')+
      (w.rx?'<dt>Receive rate</dt><dd>'+esc(w.rx)+' Mbps</dd>':'')+
      (w.tx?'<dt>Transmit rate</dt><dd>'+esc(w.tx)+' Mbps</dd>':'')+
      (w.auth?'<dt>Authentication</dt><dd>'+esc(w.auth)+'</dd>':'')+
      '</div>'+
      '<div class="dp-card-note" style="margin:12px 0 0">SSID, BSSID and IP address are intentionally not collected.</div></div></div>';
  }
  if(NET.dns&&NET.dns.length){
    h+='<div><div class="dp-section-label">DNS servers</div><div class="dp-card">'+esc(NET.dns.join(', '))+'</div></div>';
  }
  h+='</div>';
  v.innerHTML=h;
  const copyBtn=document.getElementById('copyNetBtn');
  if(copyBtn)copyBtn.onclick=()=>{
    const txt=v.textContent.replace(/\s*\n\s*/g,'\n').trim();
    const done=()=>{const old=copyBtn.innerHTML;copyBtn.innerHTML='<span class="material-symbols-outlined" style="font-size:18px">check</span>Copied';setTimeout(()=>{copyBtn.innerHTML=old;},1500);};
    if(navigator.clipboard&&navigator.clipboard.writeText)navigator.clipboard.writeText(txt).then(done).catch(()=>{});
    else{const ta=document.createElement('textarea');ta.value=txt;document.body.appendChild(ta);ta.select();document.execCommand('copy');document.body.removeChild(ta);done();}
  };
}
function renderDevices(){
  const v=document.getElementById('devicesView');
  const isVirtualAudio=n=>/vb-audio|voicemeeter|cable (input|output)|virtual audio/i.test(n);
  const isVirtualCam=n=>/obs virtual|virtual camera|droidcam|snap camera/i.test(n);
  const DEVERR_CODES={
    '1':'Device not configured correctly','3':'Driver may be corrupted, or system is low on resources',
    '10':'Device cannot start','12':'Not enough free resources','14':'Device needs a restart to work',
    '18':'Drivers need reinstalling','19':'Registry entries for the device are corrupted',
    '21':'Windows is in the process of removing the device','22':'Device is disabled',
    '24':'Device not present, not working, or missing drivers','28':'Drivers are not installed',
    '29':'Disabled by firmware \u2014 didn\u2019t give the device resources','31':'Windows cannot load the drivers',
    '32':'Driver service is disabled','37':'Driver returned a failure','39':'Driver is missing or corrupted',
    '41':'Driver loaded but can\u2019t find the device','42':'Duplicate device found','43':'Device reported a problem',
    '44':'An application or driver stopped the device','45':'Device not currently connected',
    '48':'A previous driver for this device is blocked from loading','52':'Drivers aren\u2019t digitally signed',
  };

  const hasAny=(AUDIO&&(AUDIO.playbackDevices&&AUDIO.playbackDevices.length||AUDIO.recordingDevices&&AUDIO.recordingDevices.length))
    ||(CAMERAS&&CAMERAS.length)||(USBDEVS&&USBDEVS.length)||DEVERR.length;

  const devBadgeEl=document.getElementById('devicesTabBadge');
  if(devBadgeEl){ if(DEVERR.length){devBadgeEl.textContent=DEVERR.length;devBadgeEl.style.display='';} else {devBadgeEl.style.display='none';} }

  if(!hasAny){
    v.innerHTML='<div class="dp-head"><div class="dp-crumb"><span class="crumb">Hardware <span class="material-symbols-outlined" style="font-size:16px">chevron_right</span> <b>Devices</b></span></div>'+
      '<div class="dp-title-row"><div><div class="dp-title">Devices and hardware</div></div></div></div>'+
      '<div class="dp-content"><div class="dp-card"><div class="dp-empty">No audio, webcam, or USB peripheral data was collected.</div></div></div>';
    return;
  }

  const statusCls=DEVERR.length?'err':'ok';
  const statusText=DEVERR.length?DEVERR.length+' device error'+(DEVERR.length===1?'':'s')+' here':'No problems found';
  let h='<div class="dp-head"><div class="dp-crumb"><span class="crumb">Hardware <span class="material-symbols-outlined" style="font-size:16px">chevron_right</span> <b>Devices</b></span>'+
    '<div class="dp-actions"><div class="m3-btn" id="copyDevBtn"><span class="material-symbols-outlined" style="font-size:18px">content_copy</span>Copy</div></div></div>'+
    '<div class="dp-title-row"><div><div class="dp-title">Devices and hardware</div></div>'+
    '<div class="dp-status '+statusCls+'"><span class="status-dot"></span>'+esc(statusText)+'</div></div></div>';

  h+='<div class="dp-content">';

  if(DEVERR.length){
    h+='<div id="devErrSection"><div class="dp-section-label">Device Manager errors ('+DEVERR.length+')</div><div class="dev-grid">';
    DEVERR.forEach(e=>{
      const desc=DEVERR_CODES[String(e.code)];
      h+='<div class="dev-card err"><div class="dev-icon err"><span class="material-symbols-outlined">error</span></div>'+
        '<div class="dev-body"><div class="dev-title">'+esc(e.name)+'</div>'+
        '<div class="dev-badges"><span class="dev-badge err">Error code '+esc(e.code)+'</span></div>'+
        (desc?'<div class="dev-desc">'+esc(desc)+'</div>':'')+
        '</div></div>';
    });
    h+='</div></div>';
  }

  if(AUDIO&&(AUDIO.playbackDevices&&AUDIO.playbackDevices.length||AUDIO.recordingDevices&&AUDIO.recordingDevices.length)){
    if(AUDIO.playbackDevices&&AUDIO.playbackDevices.length){
      h+='<div><div class="dp-section-label">Audio \u00b7 playback (output)</div><div class="dev-grid">';
      AUDIO.playbackDevices.forEach(d=>{
        const virtual=isVirtualAudio(d.name);
        h+='<div class="dev-card"><div class="dev-icon plain"><span class="material-symbols-outlined">volume_up</span></div>'+
          '<div class="dev-body"><div class="dev-title">'+esc(d.name)+'</div>'+
          (virtual?'<div class="dev-badges"><span class="dev-badge info">Virtual</span></div>':'')+
          '</div></div>';
      });
      h+='</div></div>';
    }
    if(AUDIO.recordingDevices&&AUDIO.recordingDevices.length){
      h+='<div><div class="dp-section-label">Audio \u00b7 recording (input)</div><div class="dev-grid">';
      AUDIO.recordingDevices.forEach(d=>{
        const virtual=isVirtualAudio(d.name);
        h+='<div class="dev-card"><div class="dev-icon ok"><span class="material-symbols-outlined">mic</span></div>'+
          '<div class="dev-body"><div class="dev-title">'+esc(d.name)+'</div>'+
          (virtual?'<div class="dev-badges"><span class="dev-badge info">Virtual</span></div>':'')+
          '</div></div>';
      });
      h+='</div></div>';
    }
  }

  if(CAMERAS&&CAMERAS.length){
    h+='<div><div class="dp-section-label">Webcams &amp; capture devices ('+CAMERAS.length+')</div><div class="dev-grid">';
    CAMERAS.forEach(c=>{
      const ok=/^ok$/i.test(c.status);
      const virtual=isVirtualCam(c.name);
      h+='<div class="dev-card'+(ok?'':' err')+'"><div class="dev-icon '+(ok?'ok':'warn')+'"><span class="material-symbols-outlined">videocam</span></div>'+
        '<div class="dev-body"><div class="dev-title">'+esc(c.name)+'</div>'+
        '<div class="dev-badges"><span class="dev-badge '+(ok?'ok':'warn')+'">'+esc(c.status||'Unknown')+'</span>'+
        (virtual?'<span class="dev-badge info">Virtual</span>':'')+'</div></div></div>';
    });
    h+='</div></div>';
  }

  if(USBDEVS&&USBDEVS.length){
    h+='<div><div class="dp-section-label">Peripherals ('+USBDEVS.length+')</div><div class="dev-grid">';
    USBDEVS.forEach(u=>{
      h+='<div class="dev-card"><div class="dev-icon plain"><span class="material-symbols-outlined">usb</span></div>'+
        '<div class="dev-body"><div class="dev-title">'+esc(u.name)+'</div></div></div>';
    });
    h+='</div></div>';
  }

  h+='</div>';
  v.innerHTML=h;
  const copyBtn=document.getElementById('copyDevBtn');
  if(copyBtn)copyBtn.onclick=()=>{
    const txt=v.textContent.replace(/\s*\n\s*/g,'\n').trim();
    const done=()=>{const old=copyBtn.innerHTML;copyBtn.innerHTML='<span class="material-symbols-outlined" style="font-size:18px">check</span>Copied';setTimeout(()=>{copyBtn.innerHTML=old;},1500);};
    if(navigator.clipboard&&navigator.clipboard.writeText)navigator.clipboard.writeText(txt).then(done).catch(()=>{});
    else{const ta=document.createElement('textarea');ta.value=txt;document.body.appendChild(ta);ta.select();document.execCommand('copy');document.body.removeChild(ta);done();}
  };
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
  const lbl=t.querySelector('.tab-label');
  document.getElementById('pageTitleSub').textContent='- '+(lbl?lbl.textContent:t.textContent);
});
// A nav group with a flagged page inside it opens on load, so a warning is never hidden behind a
// collapsed header. If the user collapses it again, the header carries a roll-up badge instead.
function syncNavGroups(expand){
  document.querySelectorAll('.nav-group').forEach(grp=>{
    const title=grp.querySelector('.nav-group-title:not(.static)');
    if(!title)return;
    const live=[...grp.querySelectorAll('.nav-group-items .tab-badge')].filter(b=>b.style.display!=='none'&&b.textContent.trim()&&(!b.closest('.tab')||b.closest('.tab').style.display!=='none'));
    let gb=title.querySelector('.group-badge');
    if(!gb){gb=document.createElement('span');gb.className='tab-badge group-badge';title.insertBefore(gb,title.querySelector('.chev'));}
    if(!live.length){gb.classList.remove('show');return;}
    const anyErr=live.some(b=>!b.classList.contains('warn'));
    gb.textContent='';
    gb.title=live.length+' page'+(live.length===1?'':'s')+' with notes';
    gb.className='tab-badge group-badge show'+(anyErr?'':' warn');
    if(expand)grp.classList.remove('collapsed');
  });
}
document.querySelectorAll('.nav-group-title:not(.static)').forEach(g=>g.onclick=()=>{
  g.closest('.nav-group').classList.toggle('collapsed');
});
renderSpecs();
load(RAW);
renderSummary();
renderDumps();
renderNet();
renderDevices();
renderGPU();
renderMotherboard();
renderCPU();
renderMemory();
renderBattery();
renderSecurity();
renderAppsList(PROGRAMS);
renderProcesses();
renderExtensions();
renderUpdates();
renderFAQ();
syncNavGroups(true);
document.getElementById('pageFoot').textContent=GEN?'Generated '+GEN:'';
document.getElementById('brand-sub').textContent=GEN?'Report \u00b7 '+GEN:'System report';
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
    Write-Host "                PCHH Triage                      " -ForegroundColor Green
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
    $motherboardSerial = Get-WmiObject Win32_BaseBoard | Select-Object -ExpandProperty SerialNumber
    $bios = Get-WmiObject Win32_BIOS
    $biosVersion = $bios | Select-Object -ExpandProperty SMBIOSBIOSVersion
    $biosDate = $bios | Select-Object -ExpandProperty ReleaseDate
    $biosMfr = $bios | Select-Object -ExpandProperty Manufacturer
    # Presence of this key is a long-standing, reliable proxy for UEFI firmware - Legacy BIOS
    # systems never create it, regardless of whether Secure Boot itself is turned on.
    $firmwareType = if (Test-Path "HKLM:\SYSTEM\CurrentControlSet\Control\SecureBoot\State") { "UEFI" } else { "Legacy BIOS" }
    $os = Get-WmiObject Win32_OperatingSystem
    $osName = $os | Select-Object -ExpandProperty Caption
    $osVersion = $os | Select-Object -ExpandProperty Version
    $secureBoot = try { Confirm-SecureBootUEFI } catch { $secCompat = $true }
    $fastboot = (Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power" -Name HiberbootEnabled).HiberbootEnabled

    $buildNumber = (Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion").CurrentBuild
    $ubr = (Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion").UBR
    $build = "$buildNumber.$ubr"


    $osInstallDate = try { ([System.Management.ManagementDateTimeConverter]::ToDateTime($os.InstallDate)).ToString("MM'/'dd'/'yyyy") } catch { "" }
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

    $pgfile = @(Get-WmiObject -Query "SELECT * FROM Win32_PageFileUsage")
    $pgfilesize = if ($pgfile.Count -gt 0) { ($pgfile | Measure-Object -Property AllocatedBaseSize -Sum).Sum } else { 0 }
    # AutomaticManagedPagefile reflects the "Automatically manage paging file size for all
    # drives" checkbox in System Properties > Advanced > Performance > Virtual Memory - people
    # commonly turn this off to hand-set a custom size, which is worth surfacing since a
    # manually-set size that's too small (or on the wrong drive) is a common cause of low-memory
    # symptoms that don't show up any other way in this report. A more serious variant of the
    # same setting is "No paging file" on every drive - Win32_PageFileUsage then returns zero
    # instances entirely (there's no page file to report on), so that's checked for separately
    # rather than just falling through to a size of 0 MB.
    $pgfileAuto = try { (Get-WmiObject Win32_ComputerSystem).AutomaticManagedPagefile } catch { $null }
    $pgfileManagedState = if ($pgfile.Count -eq 0) { "Disabled" } elseif ($null -eq $pgfileAuto) { "" } elseif ($pgfileAuto) { "Automatic" } else { "Manual" }

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
    specs "Motherboard Serial: $motherboardSerial"
    specs "BIOS Manufacturer: $biosMfr"
    specs "BIOS Version: $biosVersion"
    specs "BIOS Date: $([System.Management.ManagementDateTimeConverter]::ToDateTime($biosDate).ToString("MM'/'dd'/'yyyy HH:mm:ss"))"
    specs "Firmware Mode: $firmwareType"
    specs "`nOS: $osName"
    specs "OS Version: $osVersion"
    specs "System Uptime: $($uptime.Days) days, $($uptime.Hours) hours, $($uptime.Minutes) minutes"
    specs "Build: $build"
    specs "`nTPM Status: $tpmEnabled"
    if ($tpmEnabled -eq "Enabled") {
        specs "TPM Version: $tpmVersion"
    }
    specs "Secure Boot State: $secureBootState"
    specs "Fast Boot State: $fastbootState"
    specs "Page File Size: $(if ($pgfileManagedState -eq 'Disabled') { 'None' } else { "$pgfilesize MB" })"
    if ($pgfileManagedState) { specs "Page File Managed: $pgfileManagedState" }
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



    $installedPrograms = @(Get-ItemProperty HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*,
        HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\* -ErrorAction SilentlyContinue |
        Where-Object { $_.DisplayName } |
        ForEach-Object {
            $installDate = ""
            if ($_.InstallDate -and "$($_.InstallDate)" -match '^\d{8}$') {
                try { $installDate = [datetime]::ParseExact("$($_.InstallDate)", 'yyyyMMdd', $null).ToString('MM/dd/yyyy') } catch { }
            }
            [PSCustomObject]@{ name = "$($_.DisplayName)"; date = $installDate }
        })

    # The registry scan reads both the 32-bit and 64-bit Uninstall keys, so the same shared
    # redistributable (e.g. a .NET or Visual C++ runtime) commonly appears in both and shows up
    # twice with an identical name - dedupe before sorting so the count reflects reality, keeping
    # whichever copy actually has an install date recorded.
    $programsByName = @{}
    foreach ($p in $installedPrograms) {
        $key = $p.name.ToLowerInvariant()
        if (-not $programsByName.ContainsKey($key) -or (-not $programsByName[$key].date -and $p.date)) {
            $programsByName[$key] = $p
        }
    }
    $programs = @($programsByName.Values | Sort-Object { $_.name.ToLowerInvariant() })

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
                    $pbt = ([DateTime]::FromFileTime([long]$pbtRaw)).ToString("MM'/'dd'/'yyyy HH:mm:ss")
                }
            } catch { }
        }
        [PSCustomObject]@{
            t    = $_.TimeCreated.ToString("MM'/'dd'/'yyyy HH:mm:ss")
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
            t    = $latest.TimeCreated.ToString("MM'/'dd'/'yyyy HH:mm:ss")
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
                    t = $_.TimeGenerated.ToString("MM'/'dd'/'yyyy HH:mm:ss")
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
                    memType = if ($_.SMBIOSMemoryType) { $_.SMBIOSMemoryType } elseif ($_.MemoryType) { $_.MemoryType } else { 0 }
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
                $ddrType = switch ([int]$_.memType) {
                    20 { 'DDR' }
                    21 { 'DDR2' }
                    22 { 'DDR2 FB-DIMM' }
                    24 { 'DDR3' }
                    26 { 'DDR4' }
                    34 { 'DDR5' }
                    default { '' }
                }
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
                    ddrType  = $ddrType
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
                $woDate = (Get-Item $woPath -ErrorAction Stop).LastWriteTime.ToString("MM'/'dd'/'yyyy")
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
                    try { $lastDate = [datetime]::ParseExact($matches[1], 'yyyy-MM-dd HH:mm:ss', $null).ToString("MM'/'dd'/'yyyy HH:mm") } catch { }
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
                    date = if ($_.InstalledOn) { $_.InstalledOn.ToString("MM'/'dd'/'yyyy") } else { "" }
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
                # Definition Updates (Defender virus/spyware signature refreshes) are excluded here
                # as noise - they land multiple times a day and would drown out real update history.
                # The category ID is a fixed GUID from Microsoft's own update classification scheme,
                # so it works regardless of Windows display language; Title is localized (e.g. shows
                # up in Polish, German, etc. on non-English Windows) and matching against the English
                # phrase alone would silently stop filtering on those systems, so it's kept only as a
                # secondary check alongside the GUID, not the primary one.
                $definitionUpdateCategoryId = 'e0789628-ce08-4437-be74-2495b842f43b'
                $wuHistory = @($searcher.QueryHistory(0, [Math]::Min($historyCount, 200)) | Where-Object {
                    $isDefinitionUpdate = $_.Title -match 'Security Intelligence Update'
                    if (-not $isDefinitionUpdate) {
                        try { foreach ($cat in $_.Categories) { if ($cat.CategoryID -eq $definitionUpdateCategoryId) { $isDefinitionUpdate = $true; break } } } catch { }
                    }
                    -not $isDefinitionUpdate
                } | Select-Object -First 40 | ForEach-Object {
                    [PSCustomObject]@{
                        title  = "$($_.Title)"
                        date   = if ($_.Date) { $_.Date.ToString("MM'/'dd'/'yyyy HH:mm") } else { "" }
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
                # Get-CimInstance (unlike Get-WmiObject) already converts CIM_DATETIME properties
                # into a real [DateTime] object, so running that through
                # ManagementDateTimeConverter (which expects the raw DMTF string) throws and was
                # silently swallowed by the catch below, leaving driverDate blank on every machine.
                # Handle both shapes so it works regardless of which one this comes back as.
                $driverDate = ""
                if ($_.DriverDate) {
                    try {
                        if ($_.DriverDate -is [DateTime]) {
                            $driverDate = $_.DriverDate.ToString('yyyy-MM-dd')
                        } else {
                            $driverDate = ([System.Management.ManagementDateTimeConverter]::ToDateTime($_.DriverDate)).ToString('yyyy-MM-dd')
                        }
                    } catch { }
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
                    pnp        = "$($_.PNPDeviceID)"
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
                    lastQuick  = if ($mpStatus.QuickScanEndTime) { $mpStatus.QuickScanEndTime.ToString("MM'/'dd'/'yyyy HH:mm") } else { "" }
                    lastFull   = if ($mpStatus.FullScanEndTime) { $mpStatus.FullScanEndTime.ToString("MM'/'dd'/'yyyy HH:mm") } else { "" }
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
                        time = $_.InitialDetectionTime.ToString("MM'/'dd'/'yyyy HH:mm")
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
                # The fastest speed is read from every value the driver offers (10/100/1000/2500/
                # 5000/10000...), so a 2.5 GbE port stuck at 1 Gbps is caught as well as a Gigabit
                # port stuck at 100 Mbps. ReceiveLinkSpeed is a raw bits-per-second number, so the
                # current speed doesn't depend on parsing the localized LinkSpeed text.
                $gigabitBelowRated = $false
                $linkMbps = $null; $maxMbps = $null
                try {
                    if ($_.ReceiveLinkSpeed) { $linkMbps = [math]::Round([double]$_.ReceiveLinkSpeed / 1e6) }
                    elseif ("$($_.LinkSpeed)" -match '^([\d.,]+)\s*(G|M|K)') {
                        $val = [double]($Matches[1] -replace ',', '.')
                        $linkMbps = switch ($Matches[2]) { 'G' { $val * 1000 }; 'M' { $val }; 'K' { $val / 1000 } }
                    }
                    if ($_.PhysicalMediaType -eq '802.3') {
                        $speedProp = Get-NetAdapterAdvancedProperty -Name $_.Name -RegistryKeyword '*SpeedDuplex' -ErrorAction Stop
                        foreach ($opt in @($speedProp.ValidDisplayValues)) {
                            foreach ($m in [regex]::Matches("$opt", '(\d+(?:[.,]\d+)?)\s*([GM])\s*(?:bps|bit|b/s|B)', 'IgnoreCase')) {
                                $v = [double]($m.Groups[1].Value -replace ',', '.')
                                $optMbps = if ($m.Groups[2].Value -match 'G') { $v * 1000 } else { $v }
                                if ($null -eq $maxMbps -or $optMbps -gt $maxMbps) { $maxMbps = $optMbps }
                            }
                        }
                        if ($_.Status -eq 'Up' -and $maxMbps -ge 1000 -and $linkMbps -and $linkMbps -lt $maxMbps) { $gigabitBelowRated = $true }
                    }
                } catch { }
                [PSCustomObject]@{
                    name   = "$($_.Name)"
                    desc   = "$($_.InterfaceDescription)"
                    status = "$($_.Status)"
                    speed  = "$($_.LinkSpeed)"
                    media  = "$($_.PhysicalMediaType)"
                    gigabitBelowRated = $gigabitBelowRated
                    linkMbps   = $linkMbps
                    maxMbps    = $maxMbps
                    fullDuplex = if ($_.Status -eq 'Up' -and $_.PhysicalMediaType -eq '802.3' -and $null -ne $_.FullDuplex) { [bool]$_.FullDuplex } else { $null }
                    driverVersion = "$($_.DriverVersion)"
                    # Get-NetAdapter returns DriverDate as a plain 'yyyy-MM-dd' string, not a DateTime -
                    # calling .ToString(format) on it threw and wiped out the whole adapter list.
                    driverDate    = $(try { $dd = $_.DriverDate; if ($dd -is [datetime]) { $dd.ToString("MM'/'dd'/'yyyy") } elseif ("$dd") { ([datetime]::Parse("$dd", [Globalization.CultureInfo]::InvariantCulture)).ToString("MM'/'dd'/'yyyy") } else { "" } } catch { "" })
                }
            })
        } catch { }
        $vpns = @()
        try {
            # WAN Miniport entries are Microsoft's own built-in protocol adapters, present on every
            # Windows PC by default - not third-party VPN software. ComponentID is a fixed internal
            # driver identifier (never translated) and is the reliable way to recognise them; the
            # InterfaceDescription text below is Microsoft-authored and can be localized on non-English
            # Windows, so it's kept only as a secondary check alongside ComponentID, not the only one.
            $msWanMiniportIds = 'ms_pptpminiport','ms_l2tpminiport','ms_pppoeminiport','ms_sstpminiport','ms_ndiswanip','ms_ndiswanipv6','ms_ndiswanbh','ms_agilevpnminiport','ms_rasl2tp'
            $vpns = @(Get-NetAdapter -ErrorAction SilentlyContinue | Where-Object {
                -not $_.Physical -and (
                    $_.Status -eq 'Up' -or
                    "$($_.InterfaceDescription) $($_.Name)" -match 'TAP|Wintun|WireGuard|OpenVPN|Tailscale|Nord|ExpressVPN|Proton|Surfshark|Mullvad|ZeroTier|Hamachi|Radmin|Bright|VPN|AnyConnect|GlobalProtect|Forti|Cloudflare|WARP|Pulse|SonicWall|NetExtender|CheckPoint|SoftEther|PacketiX|Windscribe|IVPN|Psiphon|Betternet|Shadowsocks|Hotspot Shield'
                ) -and "$($_.InterfaceDescription)" -notmatch 'WAN Miniport|Bluetooth|Loopback|Kernel Debug' -and "$($_.ComponentID)" -notin $msWanMiniportIds
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
            $radioType = $null; $authDisplay = $null; $rxMbps = $null; $txMbps = $null; $apiChannel = $null; $phyId = $null
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
                                            $phyId = [int]$assoc.dot11PhyType
                                            $rxMbps = [math]::Round($assoc.ulRxRate / 1000)
                                            $txMbps = [math]::Round($assoc.ulTxRate / 1000)
                                        } finally { [PCHH.Wlan]::WlanFreeMemory($dataPtr) }
                                    }
                                    # wlan_intf_opcode_channel_number (8): the raw channel number,
                                    # locale-independent, used to work out the band when netsh's
                                    # English-only "Band" field isn't available.
                                    $cs = 0; $cp = [IntPtr]::Zero
                                    if ([PCHH.Wlan]::WlanQueryInterface($clientHandle, [ref]$guidCopy, 8, [IntPtr]::Zero, [ref]$cs, [ref]$cp, [IntPtr]::Zero) -eq 0) {
                                        try { $apiChannel = [Runtime.InteropServices.Marshal]::ReadInt32($cp) } finally { [PCHH.Wlan]::WlanFreeMemory($cp) }
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
            # Band fallback from the channel number: 1-14 is 2.4 GHz, 32+ is 5 GHz. 6 GHz reuses
            # low channel numbers, so a low channel on an 802.11ax/be link is left undetermined.
            if (-not $wf['Band'] -and $apiChannel) {
                if ($apiChannel -ge 32) { $wf['Band'] = '5 GHz' }
                elseif ($apiChannel -le 14 -and $phyId -notin 10, 11) { $wf['Band'] = '2.4 GHz' }
            }
            if (-not $wf['Channel'] -and $apiChannel) { $wf['Channel'] = "$apiChannel" }
            # Whether the adapter can do 5 GHz at all: the supported radio types in 'netsh wlan show
            # drivers' are standard names (802.11a/ac/ax/be) even when the labels are translated.
            $supports5 = $null
            try {
                $drv = (netsh wlan show drivers 2>$null) -join ' '
                if ($drv -match '802\.11') { $supports5 = [bool]($drv -match '802\.11(a|ac|ax|be)\b') }
            } catch { }
            if ($null -ne $wifiSignalPct) {
                $wifi = [PSCustomObject]@{
                    supports5 = $supports5
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
                    d = $_.LastWriteTime.ToString("MM'/'dd'/'yyyy HH:mm")
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
        $programsJson = if ($programs.Count -gt 0) { (ConvertTo-Json @($programs) -Compress -Depth 2).Replace('</', '<\/') } else { '[]' }
        $smartJson = if ($smart.Count -gt 0) { (ConvertTo-Json @($smart) -Compress -Depth 3).Replace('</', '<\/') } else { '[]' }
        $dirtyJson = if ($dirtyVols.Count -gt 0) { (ConvertTo-Json @($dirtyVols) -Compress).Replace('</', '<\/') } else { '[]' }
        $diskLayoutJson = if ($diskLayout.Count -gt 0) { (ConvertTo-Json @($diskLayout) -Compress -Depth 4).Replace('</', '<\/') } else { '[]' }
        $specsRaw = Get-Content -Path $infofile -Raw -ErrorAction SilentlyContinue
        if ($null -eq $specsRaw) { $specsRaw = "" }
        $specsJson = (ConvertTo-Json "$specsRaw" -Compress).Replace('</', '<\/')

        $genStamp = (Get-Date).ToString("MM'/'dd'/'yyyy HH:mm")
        $viewerHtml = $viewerTemplate.Replace('/*__VER__*/""', "`"$scriptVersion`"").Replace('/*__GEN__*/""', "`"$genStamp`"").Replace('/*__DATA__*/[]', $json).Replace('/*__SPECS__*/""', $specsJson).Replace('/*__DUMPS__*/[]', $dumpsJson).Replace('/*__SYSEVT__*/[]', $sysJson).Replace('/*__SMART__*/[]', $smartJson).Replace('/*__DIRTY__*/[]', $dirtyJson).Replace('/*__DISKLAYOUT__*/[]', $diskLayoutJson).Replace('/*__RAM__*/[]', $ramJson).Replace('/*__PROGRAMS__*/[]', $programsJson).Replace('/*__GPUS__*/[]', $gpusJson).Replace('/*__HAGS__*/null', $hagsJson).Replace('/*__ISLAPTOP__*/false', $isLaptopJson).Replace('/*__MONS__*/[]', $monsJson).Replace('/*__DISPLAYS__*/[]', $displaysJson).Replace('/*__PROCS__*/[]', $procsJson).Replace('/*__MEMUSE__*/null', $memuseJson).Replace('/*__NET__*/null', $netJson).Replace('/*__SECURITY__*/null', $securityJson).Replace('/*__HOTFIXES__*/[]', $hotfixesJson).Replace('/*__WINDOWSOLD__*/null', $windowsOldJson).Replace('/*__POWERPLAN__*/null', $powerPlanJson).Replace('/*__GENFLAGS__*/null', $generalFlagsJson).Replace('/*__CBS__*/null', $cbsJson).Replace('/*__WUHISTORY__*/[]', $wuHistoryJson).Replace('/*__WINUPDATE__*/null', $winUpdateJson).Replace('/*__DEVERR__*/[]', $devErrorsJson).Replace('/*__AUDIO__*/null', $audioJson).Replace('/*__USB__*/[]', $usbJson).Replace('/*__CAMERAS__*/[]', $camerasJson).Replace('/*__BATTERY__*/[]', $batteryJson).Replace('/*__RAMSLOTS__*/null', $ramSlotsJson)
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

    # wevtutil's export (epl) reads the log's on-disk file directly rather than needing exclusive
    # access to it, so this works even while the Event Log service has System/Application open -
    # a plain file copy of the live .evtx would fail with a sharing violation. The time filter
    # matches the memory dump retention window below, so both stay a similarly-sized recent slice
    # rather than the full log (which can run into the tens of MB on a machine that's been up a
    # long time).
    $evtxExports = @()
    $evtxCutoffMs = 60 * 24 * 60 * 60 * 1000
    foreach ($logName in @('System', 'Application')) {
        $exportPath = "$File\$logName.evtx"
        try {
            $query = "*[System[TimeCreated[timediff(@SystemTime) <= $evtxCutoffMs]]]"
            wevtutil epl $logName $exportPath "/q:$query" /ow:true 2>$null
            if (Test-Path $exportPath) { $evtxExports += $exportPath }
        } catch { }
    }

    $filesToCompress = @($infofile, $reliability_csv_path, $reliability_html_path) + $evtxExports

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
    if ($evtxExports.Count -gt 0) { Remove-Item -Path $evtxExports -Force -ErrorAction SilentlyContinue > $null 2>&1 }

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
