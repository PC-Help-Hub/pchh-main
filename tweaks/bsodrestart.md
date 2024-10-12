<p align="center">
  <img src="https://github.com/shinthebean1/pchh-assets/blob/main/logo.png" width="300" height="300">
</p>


<div align="center">
  <h1><strong>BSOD-RESTART</strong></h1>
</div>

‎ 

> [!IMPORTANT]
>
> We are **NOT** responsible for any data loss that occurs by these scripts, you are at your own risk at data loss; **Backup your data** before running specific scripts.

> [!NOTE]
> To run these scripts, open PowerShell as an Admin; You can do this by Pressing `Win + X`, then selecting `PowerShell (Admin)` or `Terminal (Admin)`.
> 
> With PowerShell opened, paste the code that matches what you would like to do.

# Auto-Restart

### Enable Auto-Restart
```pwsh
Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\CrashControl" -Name "AutoReboot" -Value 0 -Type DWord -Force
```

### Disable Auto-Restart
```pwsh
Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\CrashControl" -Name "AutoReboot" -Value 1 -Type DWord -Force
```

# On-Screen Parameters

### Enable On-Screen Parameters
```pwsh
Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\CrashControl" -Name "DisplayParameters" -Value 1 -Type DWord -Force
```

### Disable On-Screen Parameters
```pwsh
Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\CrashControl" -Name "DisplayParameters" -Value 0 -Type DWord -Force
```

Once entering one of these commands, restart your computer for changes to apply.
