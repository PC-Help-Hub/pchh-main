# PC Help Hub Main
PC Help Hub "Official" Main Repo

# Disable Windows Copilot
Commands to disable Windows Copilot.

## Quick Commands
Paste into Run dialogue (Windows Key + R) then press Control + Shift + Enter (and accept the prompt)

### Disable
```
powershell -W H -NOP -NONI reg add HKCU\Software\Policies\Microsoft\Windows\WindowsCopilot /v "TurnOffWindowsCopilot" /t REG_DWORD /f /d 1
```
### (Re)Enable
```
powershell -W H -NOP -NONI reg add HKCU\Software\Policies\Microsoft\Windows\WindowsCopilot /v "TurnOffWindowsCopilot" /t REG_DWORD /f /d 0
```

