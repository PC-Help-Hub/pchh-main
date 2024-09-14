<p align="center">
  <img src="https://github.com/shinthebean1/pchh-assets/blob/main/logo.png" width="300" height="300">
</p>


<div align="center">
  <h1><strong>Copilot</strong></h1>
</div>

‎ 

> [!IMPORTANT]
>
> We are **NOT** responsible for any data loss that occurs by these scripts, you are at your own risk at data loss; **Backup your data** before running scripts.

> [!NOTE]
> To run these scripts, open PowerShell as an Admin; You can do this by Pressing `Win + X`, then selecting `PowerShell (Admin)` or `Terminal (Admin)`.
> 
> With PowerShell opened, paste the code that matches what you would like to do.


## Enable Copilot
```pwsh
reg add HKCU\Software\Policies\Microsoft\Windows\WindowsCopilot /v "TurnOffWindowsCopilot" /t REG_DWORD /f /d 0
```

## Disable Copilot
```pwsh
reg add HKCU\Software\Policies\Microsoft\Windows\WindowsCopilot /v "TurnOffWindowsCopilot" /t REG_DWORD /f /d 1
```

Once entering one of these commands, restart your computer for changes to apply.
