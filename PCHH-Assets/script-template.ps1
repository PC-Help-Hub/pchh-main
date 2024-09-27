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

function scriptstart {
    Clear-Host 
    Write-Host ""
    Write-Host "============================================" -ForegroundColor DarkGreen
    Write-Host "-- Script is running as an Administrator --" -ForegroundColor Green
    Write-Host "--         Made by ShinTheBean           --" -ForegroundColor Green
    Write-Host "============================================" -ForegroundColor DarkGreen
    Write-Host ""
}

function eof {
    # script finish message

    endmessage
}

function functionerror {
    Write-Host -NoNewline -ForegroundColor Red "$(xmark)"

    # add error handling here.

    endmessage
}

function endmessage {
    Write-Host ""
    Write-Host "Press any key to exit.."
        
    $null = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    exit
}

scriptstart