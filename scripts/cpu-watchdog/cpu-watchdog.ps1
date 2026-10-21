param(
    [string]$StateDir = $PSScriptRoot,
    [switch]$TestNotification
)

$configPath = Join-Path $PSScriptRoot 'config.json'
$statePath = Join-Path $StateDir 'state.json'
$logPath = Join-Path $StateDir 'watchdog.log'
$config = Get-Content $configPath -Raw | ConvertFrom-Json

function Show-Toast([string]$Title, [string]$Body) {
    [Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime] | Out-Null
    [Windows.Data.Xml.Dom.XmlDocument, Windows.Data.Xml.Dom.XmlDocument, ContentType = WindowsRuntime] | Out-Null
    $xml = New-Object Windows.Data.Xml.Dom.XmlDocument
    $title = [Security.SecurityElement]::Escape($Title)
    $body = [Security.SecurityElement]::Escape($Body)
    $xml.LoadXml("<toast><visual><binding template='ToastGeneric'><text>$title</text><text>$body</text></binding></visual></toast>")
    # Reuses PowerShell's registered app ID so the toast is delivered without registering a new app.
    $appId = '{1AC14E77-02E7-4E5D-B744-2EB1AE5198B7}\WindowsPowerShell\v1.0\powershell.exe'
    [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier($appId).Show([Windows.UI.Notifications.ToastNotification]::new($xml))
}

function Write-Log([string]$Message) {
    Add-Content -Path $logPath -Value "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') $Message"
    $lines = Get-Content $logPath
    if ($lines.Count -gt 500) { $lines | Select-Object -Last 500 | Set-Content $logPath }
}

if ($TestNotification) {
    Show-Toast 'CPU watchdog' 'Notifications are working.'
    return
}

Add-Type -Namespace Watchdog -Name Win32 -MemberDefinition @'
[DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
[DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint pid);
'@
$foregroundPid = 0
[void][Watchdog.Win32]::GetWindowThreadProcessId([Watchdog.Win32]::GetForegroundWindow(), [ref]$foregroundPid)

$now = Get-Date
$ignore = @($config.ignore | ForEach-Object { $_.ToLowerInvariant() })
$current = @{}
foreach ($p in Get-Process) {
    if ($null -eq $p.CPU -or $p.Id -eq $foregroundPid -or $ignore -contains $p.ProcessName.ToLowerInvariant()) { continue }
    $path = $p.Path
    if (-not $path -or -not ($config.watchPaths | Where-Object { $path -like "$_*" })) { continue }
    try { $start = $p.StartTime.ToFileTimeUtc() } catch { continue }
    $current["$($p.Id):$start"] = @{ name = $p.ProcessName; cpu = $p.CPU }
}

$state = if (Test-Path $statePath) { Get-Content $statePath -Raw | ConvertFrom-Json } else { $null }
$strikes = @{}
$lastAlert = @{}
if ($state) {
    $elapsed = ($now - [datetime]$state.time).TotalSeconds
    if ($state.lastAlert) { $state.lastAlert.PSObject.Properties | ForEach-Object { $lastAlert[$_.Name] = [datetime]$_.Value } }

    # A gap much longer than the interval means the laptop was asleep; start a fresh window.
    if ($elapsed -gt 0 -and $elapsed -lt $config.intervalMinutes * 60 * 2) {
        foreach ($key in $current.Keys) {
            $prev = $state.processes.$key
            if (-not $prev) { continue }
            $percent = ($current[$key].cpu - $prev.cpu) / $elapsed * 100
            if ($percent -ge $config.thresholdPercent) {
                $strikes[$key] = [int]$prev.strikes + 1
                if ($strikes[$key] -ge $config.consecutiveChecks) {
                    $name = $current[$key].name
                    $cooledDown = -not $lastAlert[$name] -or ($now - $lastAlert[$name]).TotalMinutes -ge $config.cooldownMinutes
                    if ($cooledDown) {
                        $minutes = [math]::Round($strikes[$key] * $elapsed / 60)
                        Show-Toast "$name is using a lot of CPU" ("About {0:N0}% of a core for {1} minutes. End it in Task Manager if you aren't using it." -f $percent, $minutes)
                        Write-Log ("ALERT {0} (pid {1}) {2:N0}% for {3} min" -f $name, $key.Split(':')[0], $percent, $minutes)
                        $lastAlert[$name] = $now
                    }
                }
            }
        }
    }
}

$processes = @{}
foreach ($key in $current.Keys) {
    $processes[$key] = @{ cpu = $current[$key].cpu; strikes = [int]$strikes[$key] }
}
$alerts = @{}
foreach ($name in $lastAlert.Keys) { $alerts[$name] = $lastAlert[$name].ToString('o') }
@{ time = $now.ToString('o'); processes = $processes; lastAlert = $alerts } | ConvertTo-Json -Depth 4 -Compress | Set-Content $statePath
