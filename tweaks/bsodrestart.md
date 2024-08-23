# Disable Auto-Restart in a BSOD

Paste into PowerShell as an admin ( Win + X and click Terminal (Admin)

### Enable
```
Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\CrashControl" -Name "AutoReboot" -Value 0 -Type DWord -Force
```
Doing this will make it to where if you Blue Screen, the system won't automatically restart when it's done gathering information.

### Disable
```
Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\CrashControl" -Name "AutoReboot" -Value 1 -Type DWord -Force
```
Doing this will make it to where if you Blue Screen, the system will automatically restart when it's done gathering information.
