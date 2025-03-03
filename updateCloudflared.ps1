<#
.Synopsis
    Update cloudflared
.DESCRIPTION
    Automate the update process for users running cloudflared
.NOTES
    !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
    !!!! THIS IS NOT CREATED NOR MAINTAINED BY CLOUDFLARE !!!!
    !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
    Author:         teutonicGoat
    Version:        2025.02.25
    Creation:       2025.02.25
    Hosted at:      https://github.com/teutonicGoat/updateCloudflared
    Original:       https://cloudflared.app/update.ps1
        By:         Dubz
        Discord:    Dubz#0001 | https://discord.gg/cloudflaredev
        
#>

# Find executables (configure as needed)
param(
    # Name of Cloudflared service
    [string]$service = "cloudflared",

    # Name of executable
    [string]$filename = "cloudflared.exe",

    #Z: Assuming that $filename (cloudflared.exe) is on PATH
    #Z: If we know for a fact that cloudflared.exe will ALWAYS be in the same place, this path can be hardcoded
    # Finds the executable using environmental paths
    [string]$cloudflared_path = (Get-Command $filename).Path,

    # Cloudflare seems to behave in two different ways depending on whether the service is running at the time of update
    [string]$cloudflared_path_dot_old = $cloudflared_path + ".old",
    [string]$cloudflared_path_dot_new = $cloudflared_path + ".new",

    # Commands used by cloudflared
        # Update
    [string]$cloudflared_command_update = "$filename update",
        # Version
    [string]$cloudflared_command_version = "$filename version",

    # Set log file location
    [string]$logFile = "$env:TEMP\cloudflared_updater.log",
    # Show output with -interactive $true
    [switch]$interactive = $false
)

# Ensures that the account used to run the script has admin privileges
#Requires -RunAsAdministrator

function Write-Log {
    param(
        [int]$Code,
        [string]$MESSAGE
    )
    switch ($Code) {
        0 { $status = "SUCCESS"; $color = "Green" }
        1 { $status = " INFO  "; $color = "Yellow" }
        2 { $status = "WARNING"; $color = "Red" }
        3 { $status = "FAILURE"; $color = "DarkRed" }
        default { $status = "UNKNOWN"; $color = "Gray" }
    }
    $logEntry = "[ $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') ]`t[  $status  ]`t$MESSAGE"
    Add-Content $logFile -Value $logEntry
    # Optionally write to the console (commented out if not needed)
    if ($interactive){
        Write-Host $logEntry -ForegroundColor $color
        Read-Host "Continue? [Enter / Ctrl+C]"
    }
}

# Script will fail to run properly if old binaries are still in place; exits script and raises an error for greater visibility.
If (Test-Path $cloudflared_path_dot_old){
    Write-Log -Code 3 -MESSAGE "Old binaries are still in place. Exiting to avoid conflict."
    Write-Error -Message "Old cloudflared binaries are still in place. Exiting to avoid failure." `
        -ErrorAction Stop `
        -Category ResourceExists `
        -CategoryTargetName $cloudflared_path_dot_old `
        -RecommendedAction "Delete $cloudflared_path_dot_old and try again."
}

# Is the file cloudflared.exe found where it is expected?
# If not, it probably isn't installed, so exit clean
If (!(Test-Path -LiteralPath $cloudflared_path -PathType Leaf)) {
    Write-Log -Code 2 -MESSAGE ($filename + " not found.  Unable to update. Exiting.")
    Write-Error -Message "Cloudflared binaries not found." `
        -ErrorAction Stop `
        -Category ObjectNotFound `
        -CategoryTargetName $cloudflared_path `
        -RecommendedAction "It looks like cloudflared is not properly installed on this host."
}

$installed_version = (& $cloudflared_path "version") -replace '^cloudflared version (\S+).*$', '$1'
Write-Log -Code 1 -MESSAGE "Cloudflared found - installed version: $installed_version"

# Is the service currently running?
$running = ((Get-Service -Name $service).Status -eq "Running")
if($running) {
    Write-Log -Code 1 -MESSAGE "Current status of cloudflared service: running"
} else {
    Write-Log -Code 2 -MESSAGE "Current status of cloudflared service: stopped"
}

# Attempt to update cloudflared
& $cloudflared_path "update"
$exitCode = $LASTEXITCODE
Start-Sleep 5

if ($exitCode -eq 11){
    Write-Log -Code 0 -MESSAGE "Updated Cloudflared"
} elseif ($exitCode -eq 0){
    Write-Log -Code 1 -MESSAGE "Cloudflared is up-to-date.  Nothing else to do."
    exit
} else {
    Write-Log -Code 3 -MESSAGE "Cloudflared update failed with exit code: $exitCode"
    Write-Error -Message "Cloudflared update failed with exit code: $exitCode" `
        -ErrorAction Stop `
        -Category NotSpecified `
        -CategoryTargetName "$cloudflared_path update" `
        -RecommendedAction "Run update command from console and investigate based on output."

}

# Check for legacy update method and do some needful
if (Test-Path $cloudflared_path_dot_new){
    # Stop the service and rename the old binary file
    Stop-Service $service
    Rename-Item -Path $cloudflared_path -NewName "$filename.old" -Force
    $renameOldExitCode = $LASTEXITCODE
    if ($renameOldExitCode -ne 0){
        Write-Log -Code 0 -MESSAGE "Renamed old cloudflared binary."
    } else {
        # Attempt to restart the service to avoid downtime
        Start-Service $service
        Write-Log -Code 3 -MESSAGE "Failed to rename old cloudflared binary with code $renameOldExitCode; exiting to avoid conflict."
        Write-Error -Message "Failed to rename old cloudflared binary with code $renameOldExitCode; exiting to avoid conflict." `
            -ErrorAction Stop `
            -Category ResourceExists `
            -RecommendedAction "Stop the service, rename $filename old and or new files, and start the service."
    }

    # Rename the new binary file and restart the service (if it was running initially)
    Rename-Item -Path $cloudflared_path_dot_new -NewName $filename
    if ($?){
        Write-Log -Code 0 -MESSAGE "Renamed new cloudflared binary."
    } else {
        Write-Log -Code 3 -MESSAGE "Failed to rename new cloudflared binary; service will not be able to start."
        Write-Error -Message "Failed to rename new cloudflared binary; service will not be able to start." `
            -ErrorAction Stop `
            -Category ResourceExists `
            -RecommendedAction "Rename $filename.new to $filename and start the $service service manually."
    }
}

# Get the updated version and log it
$newVersion = (& $cloudflared_path "version") -replace '^cloudflared version (\S+).*$', '$1'
Write-Log -Code 1 -MESSAGE "Cloudflared updated to version $newVersion"

# Restart the service if it was running before
if ($running -and ((Get-Service $service).Status -eq 'Stopped')){
    Start-Service $service
    if ($?){
        Write-Log -Code 0 -MESSAGE "Starting updated cloudflared service."
    } else {
        Write-Log -Code 3 -MESSAGE "Updated cloudflared service failed to start."
        Write-Error -Message "Failed to start cloudflared service." `
            -ErrorAction Stop `
            -Category NotSpecified `
            -RecommendedAction "Attempt to start the $service service manually."
    }
    Start-Sleep 5
    if ((Get-Service $service).Status -eq 'Running'){
        Write-Log -Code 0 -MESSAGE "Updated cloudflared service is running."
    } else {
        Write-Log -Code 3 -MESSAGE "Updated cloudflared service is not running."
        Write-Error -Message "Cloudflared service is not running." `
            -ErrorAction Stop `
            -Category ResourceUnavailable `
            -RecommendedAction "Attempt to start the $service service manually and investigate output."
    }
# Just log it if it is already running again (new update method)
} elseif ($running -and ((Get-Service $service).Status -eq 'Running')){
    Write-Log -Code 1 -MESSAGE "Cloudflared service is already running again."
} elseif ((Get-Service $service).Status -ne 'Running' -and (Get-Service $service).Status -ne 'Stopped'){
    Write-Log -Code 3 -MESSAGE "Cloudflared service is in an invalid state. Exiting."
    Write-Error -Message "Cloudflared service is in an invalid state." `
        -ErrorAction Stop `
        -Category InvalidResult
        -RecommendedAction "Examine the $service service's status."
}

# Remove the old binaries

Remove-Item $cloudflared_path_dot_old -Force
if ($?){
    Write-Log -Code 0 -MESSAGE "Old cloudflared binaries removed."
} else {
    Write-Log -Code 3 -MESSAGE "Removal of old binaries failed."
    Write-Error -Message "Removal of old binaries failed." `
        -ErrorAction Stop `
        -RecommendedAction "Delete $cloudflared_path_dot_old before running this script again."
}
