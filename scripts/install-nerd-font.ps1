param([string]$Version = 'v3.5.1')
$ErrorActionPreference = 'Stop'

$work = Join-Path $env:TEMP "hack-nerd-font-$(Get-Date -Format yyyyMMddHHmmss)"
New-Item -ItemType Directory -Path $work | Out-Null
$zip = Join-Path $work 'Hack.zip'
Invoke-WebRequest "https://github.com/ryanoasis/nerd-fonts/releases/download/$Version/Hack.zip" -OutFile $zip -UseBasicParsing
Expand-Archive $zip -DestinationPath (Join-Path $work 'x')

$fontDir = Join-Path $env:LOCALAPPDATA 'Microsoft\Windows\Fonts'
New-Item -ItemType Directory -Force -Path $fontDir | Out-Null
$reg = 'HKCU:\Software\Microsoft\Windows NT\CurrentVersion\Fonts'

Get-ChildItem (Join-Path $work 'x') -Filter '*.ttf' | Where-Object { $_.Name -match '^HackNerdFont(Mono)?-' } | ForEach-Object {
    $dest = Join-Path $fontDir $_.Name
    Copy-Item $_.FullName $dest -Force
    New-ItemProperty -Path $reg -Name "$($_.BaseName) (TrueType)" -Value $dest -PropertyType String -Force | Out-Null
    Write-Host "Installed $($_.Name)"
}
