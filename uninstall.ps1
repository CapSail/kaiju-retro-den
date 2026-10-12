# KAIJU Retro Den uninstaller.   Run:  powershell -ExecutionPolicy Bypass -File uninstall.ps1
#   -DryRun            show every step and change NOTHING
#   -InstallDir path   the install folder (default: %LOCALAPPDATA%\KaijuRetroDen)
#   -SkipSystem        do not touch Windows (task, shortcuts, Wallpaper Engine entry, desktop items): only move the install folder aside
# Order: switch the room off -> put your Desktop items back -> remove what the installer created -> move the install folder aside.
# Nothing of yours is deleted. The install folder and the Wallpaper Engine entry are MOVED into a "Kaiju-removed-<date>" folder in your Documents.
param([switch]$DryRun, [string]$InstallDir, [switch]$SkipSystem)
$ErrorActionPreference = 'Stop'
$install = if ($InstallDir) { $InstallDir } else { "$env:LOCALAPPDATA\KaijuRetroDen" }
function Say([string]$m, [string]$color = 'Gray') { Write-Host $m -ForegroundColor $color }
function Step([string]$text, [scriptblock]$do) { Say "  - $text"; if (-not $DryRun) { try { & $do } catch { Say "    (skipped: $($_.Exception.Message))" 'Yellow' } } }
if (-not (Test-Path "$install\config.json")) { Say "No Kaiju install found at $install" 'Red'; exit 1 }
$cfg = Get-Content "$install\config.json" -Raw | ConvertFrom-Json
$aside = "$([Environment]::GetFolderPath('MyDocuments'))\Kaiju-removed-$(Get-Date -Format yyyyMMdd-HHmmss)"
Say "`nKAIJU RETRO DEN uninstaller$(if ($DryRun) { '  (DRY RUN: nothing will be changed)' })`n" 'Cyan'
Say "Install folder: $install"

if (-not $SkipSystem) {
    Step 'switch the room off (TV, widgets, wallpaper, watcher)' { & powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$install\scripts\kaiju_power.ps1" off }
    Step 'put your Desktop items back where they were' { & powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$install\scripts\Move-DesktopToCabinet.ps1" -Restore }
    Step 'remove the background watcher task' { Unregister-ScheduledTask -TaskName KaijuAutopause -Confirm:$false -ErrorAction Stop }
    Step 'remove the shortcuts the installer made' {
        foreach ($p in "$([Environment]::GetFolderPath('Desktop'))\Kaiju POWER ON.lnk", "$([Environment]::GetFolderPath('Startup'))\Kaiju POWER ON.lnk") { if (Test-Path -LiteralPath $p) { Remove-Item -LiteralPath $p -Force } }
        $sm = "$([Environment]::GetFolderPath('Programs'))\Kaiju Retro Den"; if (Test-Path $sm) { Remove-Item -LiteralPath $sm -Recurse -Force } }
    Step 'move the Wallpaper Engine entry aside' {
        $wp = "$($cfg.wallpaper_engine_dir)\projects\myprojects\kaiju_retro_den"
        if (Test-Path $wp) { New-Item -ItemType Directory -Force $aside | Out-Null; Move-Item -LiteralPath $wp -Destination "$aside\wallpaper_entry" } }
}
Step "move the install folder aside to $aside" {
    New-Item -ItemType Directory -Force $aside | Out-Null
    Move-Item -LiteralPath $install -Destination "$aside\KaijuRetroDen" }
Say "`nDone. Your file cabinet folder ($($cfg.cabinet_dir)) and your game/movie folders were not touched." 'Green'
Say "You can delete $aside whenever you like.`n"
