A simple way to update cloudflared running on Windows hosts

Log file defaults to %temp%\cloudflared_updater.log
By default, runs NON-interactive

Can be configured to run from a scheduled task with:

```cmd
powershell.exe -ExecutionPolicy Bypass -File "C:\path\to\logs\updateCloudflared.ps1"
```

Or return logging output to shell and wait for confirmation after each step with:
```cmd
Powershell.exe -ExecutionPolicy Bypass -File "C:\path\to\logs\updateCloudflared.ps1" -interactive
```

Can also modify log file location with:
powershell.exe -ExecutionPolicy Bypass -File "C:\path\to\logs\updateCloudflared.ps1" -logFile "C:\Prefered\Log\Path\cloudflared-updater.log"
