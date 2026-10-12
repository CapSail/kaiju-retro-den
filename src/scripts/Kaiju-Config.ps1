# Dot-source this at the top of every Kaiju PowerShell script:
#     . (Join-Path (Split-Path $PSScriptRoot -Parent) 'scripts\Kaiju-Config.ps1')
# It finds the install folder from where THIS file lives (<install>\scripts\), reads <install>\config.json (written by install.ps1)
# and gives every script the same `$K` object, so no script hardcodes a path.
#
# Install layout:
#   <install>\config.json  scripts\  tv\  games\  autopause\  wallpaper\
#   <install>\state\   the TV/game state + flag files and the logs (tv_state.txt, tv_game.flag, power.log, ...)
#   <install>\tools\   mpv\  Rainmeter\  shaderglass\  snes9x\  dolphin\   (downloaded by the installer)
$KRoot = Split-Path $PSScriptRoot -Parent
$KCfgFile = Join-Path $KRoot 'config.json'
if (-not (Test-Path $KCfgFile)) { throw "Kaiju: config.json not found at $KCfgFile. Run install.ps1 first." }
$KC = Get-Content $KCfgFile -Raw | ConvertFrom-Json
New-Item -ItemType Directory -Force "$KRoot\state" | Out-Null
$K = [pscustomobject]@{
    Root         = $KRoot
    Scripts      = "$KRoot\scripts"
    Tv           = "$KRoot\tv"
    Games        = "$KRoot\games"
    Autopause    = "$KRoot\autopause"
    State        = "$KRoot\state"
    Tools        = "$KRoot\tools"
    MpvDir       = "$KRoot\tools\mpv"
    MpvExe       = "$KRoot\tools\mpv\mpv.exe"
    RainmeterDir = "$KRoot\tools\Rainmeter"
    RainmeterExe = "$KRoot\tools\Rainmeter\Rainmeter.exe"
    ShaderGlass  = "$KRoot\tools\shaderglass"
    ShaderGlassExe = "$KRoot\tools\shaderglass\ShaderGlass.exe"
    Snes9xDir    = "$KRoot\tools\snes9x"
    DolphinDir   = "$KRoot\tools\dolphin"
    # chosen by the user in install.ps1 (see config.example.json)
    WallpaperEngineDir = $KC.wallpaper_engine_dir
    SteamExe     = $KC.steam_exe
    Cabinet      = $KC.cabinet_dir
    Movies       = $KC.movies_dir
    SnesRoms     = $KC.snes_rom_dir
    GcWiiRoms    = $KC.gamecube_wii_rom_dir
    Plaque       = $KC.plaque_text
    MusicPlayer  = $KC.music_player
    Python       = $KC.python_exe
    WallpaperProject = $(if ($KC.wallpaper_engine_dir) { "$($KC.wallpaper_engine_dir)\projects\myprojects\kaiju_retro_den" } else { '' })   # where install.ps1 puts the wallpaper
}
function Get-KaijuScreen {            # the ONE screen the room lives on: the primary monitor (other monitors are left alone)
    Add-Type -AssemblyName System.Windows.Forms -ErrorAction SilentlyContinue
    [System.Windows.Forms.Screen]::PrimaryScreen.Bounds
}

# ---- the watcher (autopause.ps1): a per-user scheduled task if install.ps1 could create one, else a plain hidden background process
function Get-KaijuWatcherProcess {
    Get-CimInstance Win32_Process -Filter "Name='powershell.exe'" -ErrorAction SilentlyContinue | Where-Object { $_.CommandLine -like '*autopause.ps1*' }
}
function Start-KaijuWatcher {
    if (@(Get-KaijuWatcherProcess).Count) { return }                                       # already running (the watcher also guards itself with a mutex)
    if (Get-ScheduledTask -TaskName KaijuAutopause -ErrorAction SilentlyContinue) { Start-ScheduledTask -TaskName KaijuAutopause -ErrorAction SilentlyContinue; return }
    Start-Process powershell.exe -WindowStyle Hidden -ArgumentList '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "$($K.Autopause)\autopause.ps1"
}
function Stop-KaijuWatcher {
    if (Get-ScheduledTask -TaskName KaijuAutopause -ErrorAction SilentlyContinue) { Stop-ScheduledTask -TaskName KaijuAutopause -ErrorAction SilentlyContinue }
    Get-KaijuWatcherProcess | ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
}
