# updateCloudflared
A simple way to update cloudflared running on Windows hosts.

## Notes and attribution
This script is based on [one created by "Dubz"](https://cloudflared.app/update.ps1)


Log file defaults to `%temp%\cloudflared_updater.log`.
I don't know anything about log file management, so there is no function currently to compress, archive, or delete this log file; therefor there is the potential for the file to grow to a massive size. However, even running the monthly would take something like 30 years for the log file to reach 1 MB.
Runs NON-interactive by default.

#### Can be configured to run from a scheduled task with:
```cmd
powershell.exe -ExecutionPolicy Bypass -File "C:\path\to\updateCloudflared.ps1"
```

#### Or return logging output to shell and wait for confirmation after each step with:
```cmd
Powershell.exe -ExecutionPolicy Bypass -File "C:\path\to\updateCloudflared.ps1" -interactive
```

#### Can also modify log file location with:
```cmd
powershell.exe -ExecutionPolicy Bypass -File "C:\path\to\updateCloudflared.ps1" -logFile "C:\Prefered\Log\Path\cloudflared-updater.log"
```
