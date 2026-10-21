param([string]$InstallDir = (Join-Path $env:USERPROFILE 'Scripts\cpu-watchdog'))
$ErrorActionPreference = 'Stop'

New-Item -ItemType Directory -Force -Path $InstallDir | Out-Null
Copy-Item (Join-Path $PSScriptRoot 'cpu-watchdog.ps1') $InstallDir -Force
if (-not (Test-Path (Join-Path $InstallDir 'config.json'))) {
    Copy-Item (Join-Path $PSScriptRoot 'config.json') $InstallDir
}

$script = Join-Path $InstallDir 'cpu-watchdog.ps1'
$user = "$env:USERDOMAIN\$env:USERNAME"
# conhost --headless runs PowerShell without flashing a console window every interval.
$action = New-ScheduledTaskAction -Execute "$env:WINDIR\System32\conhost.exe" -Argument "--headless powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$script`""
$triggers = @(
    New-ScheduledTaskTrigger -Once -At (Get-Date).AddMinutes(1) -RepetitionInterval (New-TimeSpan -Minutes 5)
    New-ScheduledTaskTrigger -AtLogOn -User $user
)
$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable -ExecutionTimeLimit (New-TimeSpan -Minutes 2) -MultipleInstances IgnoreNew
$principal = New-ScheduledTaskPrincipal -UserId $user -LogonType Interactive -RunLevel Limited

Register-ScheduledTask -TaskName 'CPU Watchdog' -Description "Notifies when a Windows background component uses a lot of CPU. Script: $InstallDir" -Action $action -Trigger $triggers -Settings $settings -Principal $principal -Force | Out-Null
Write-Host "Installed to $InstallDir and registered the 'CPU Watchdog' task."
