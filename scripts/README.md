# PC Help Hub Main
PC Help Hub "Official" Main Repo

## Current Windows Repair Scripts:

### Minidump Grabber
> https://github.com/PC-Help-Hub/pchh-main/blob/main/scripts/Windows%20Repair/bsod.ps1
This will search for any .dmp files in the %systemroot%\minidump directory. If found, it will zip up those files along with your system & application event logs to the .zip file.

### System Files Repair (DISM & SFC)
> https://github.com/PC-Help-Hub/pchh-main/blob/main/scripts/Windows%20Repair/image.ps1
This will check the current state of your windows image and if any corruption is found, it will be repaired promptly; Required to be ran as an Administrator.
