# FIX IT ALL: starts whatever is not running (Rainmeter, the watcher), clears stale TV/game state, re-applies the wallpaper,
# re-places the TV and the KAIJU SYSTEMS console, refreshes the widgets, and puts the TV's CRT filter back (or stops a stray one).
# Safe to run any time, as often as you like. Does not touch the TV or a game that is playing.
. (Join-Path (Split-Path $PSScriptRoot -Parent) 'scripts\Kaiju-Config.ps1')
$log = "$($K.State)\fix_desktop.log"
$st = $K.State
$games = $K.Games
$rm = $K.RainmeterExe
function Say($m) { Add-Content $log "$(Get-Date -Format s) $m" -ErrorAction SilentlyContinue }
function Pid-Alive([string]$file) {
    if (-not (Test-Path $file)) { return $false }
    $p = 0; [void][int]::TryParse(((Get-Content $file -Raw) + '').Trim(), [ref]$p)
    return ($p -gt 0 -and [bool](Get-Process -Id $p -ErrorAction SilentlyContinue))
}

if (-not (Get-Process Rainmeter -ErrorAction SilentlyContinue)) { Start-Process $rm; Say 'started Rainmeter' }
if (-not @(Get-KaijuWatcherProcess).Count) { Start-KaijuWatcher; Say 'started watcher' }

# --- state files the widgets read must always exist (a WebParser on a missing file logs an error every second)
if (-not (Test-Path "$st\tv_state.txt")) { Set-Content "$st\tv_state.txt" 'vol=35;mute=0;pause=0;subs=1;run=0;hid=0;title=' -NoNewline; Say 'recreated tv_state.txt' }
if (-not (Test-Path "$st\tv_game_state.txt")) { Set-Content "$st\tv_game_state.txt" '0' -NoNewline; Say 'recreated tv_game_state.txt' }
if (-not (Test-Path "$st\movies_playlist.m3u") -and (Test-Path "$($K.Tv)\make_playlist.ps1")) { & powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$($K.Tv)\make_playlist.ps1"; Say 'rebuilt the movie playlist' }

# --- stale game state: a game supervisor that died leaves the console saying STOP GAME and the TV "on" with nothing playing
$gameOn = Pid-Alive "$st\tv_game.flag"
if (-not $gameOn) {
    foreach ($f in 'tv_game.flag', 'tv_game_stop.flag', 'tv_game_emu.pid') { if (Test-Path "$st\$f") { Remove-Item "$st\$f" -ErrorAction SilentlyContinue; Say "cleared stale $f" } }
    Set-Content "$st\tv_game_state.txt" '0' -NoNewline
}
# --- stale TV state: run=1 with no player (after a reboot/crash) leaves no picture to click
$tvOn = [bool](Get-Process mpv -ErrorAction SilentlyContinue)
if (-not $gameOn -and -not $tvOn -and ((Get-Content "$st\tv_state.txt" -Raw) -match 'run=1')) {
    Set-Content "$st\tv_state.txt" ((Get-Content "$st\tv_state.txt" -Raw) -replace 'run=1', 'run=0' -replace 'hid=1', 'hid=0') -NoNewline
    Remove-Item "$st\tv_hidden_by_user.flag" -ErrorAction SilentlyContinue
    Say 'reset stale TV state to off'
}
# --- the console skin file must exist (regenerate it if it was lost)
if (-not (Test-Path "$($K.RainmeterDir)\Skins\KaijuHUD\Console\Console.ini")) { & $K.Python "$($K.Tv)\make_console.py"; Say 'regenerated the console skin' }

# --- emulator + TV-player settings (controller mappings, background input, no-confirm-on-close, mpv config): only the exact keys we set
& $K.Python -I "$games\kaiju_repair.py" | Out-Null; Say 'settings repair ran (changes, if any, are in games.log)'

& "$($K.Scripts)\apply_all.ps1"                         # wallpaper + TV and console positions + activates the console skin
& $rm '!RefreshApp'
# --- every widget skin must be loaded (harmless if it already is)
Start-Sleep 3
foreach ($k in @(@('KaijuHUD\Scene', 'Scene.ini'), @('KaijuHUD\Systems', 'Systems.ini'), @('KaijuHUD\TVRemote', 'TVRemote.ini'), @('KaijuHUD\Console', 'Console.ini'))) { & $rm '!ActivateConfig' $k[0] $k[1] }
& $rm '!DeactivateConfig' 'KaijuHUD\Cabinet'                                          # the drawer starts closed
# --- the TV player back exactly on its picture
if (Get-Process mpv -ErrorAction SilentlyContinue) { & powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$($K.Tv)\toggle_tv.ps1" place }

# --- the TV's CRT filter: back on if the TV (or a game) is showing and it is down; a stray one is stopped when nothing is showing
Start-Sleep 4
$filterOn = Pid-Alive "$st\overlay.pid"
$tvShowing = $gameOn -or [bool](Get-Process mpv -ErrorAction SilentlyContinue)
if ($tvShowing -and -not $filterOn) {
    Get-Process ShaderGlass -ErrorAction SilentlyContinue | Stop-Process -Force
    Start-Process powershell.exe -WindowStyle Hidden -ArgumentList '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "$games\shaderglass\tv_overlay.ps1"
    Say 'restarted the CRT filter'
}
elseif (-not $tvShowing -and ($filterOn -or (Get-Process ShaderGlass -ErrorAction SilentlyContinue))) {
    & "$games\shaderglass\tv_overlay.ps1" -Stop
    Say 'stopped a stray CRT filter'
}
# ===================== whole-desktop checks: every button must have something to run =====================
$report = New-Object System.Collections.Generic.List[string]
function Note([string]$m) { $report.Add($m); Say $m }

# 1) every script a button runs
foreach ($f in 'fix_desktop.ps1', 'kaiju_power.ps1', 'apply_all.ps1') {
    if (-not (Test-Path "$($K.Scripts)\$f")) { Note "MISSING script $f (run install.ps1 again to repair)" }
}
# 2) every folder the room uses (a drive may be offline)
foreach ($d in @($K.Cabinet, $K.Movies, $K.SnesRoms, $K.GcWiiRoms)) {
    if ($d -and -not (Test-Path $d)) { Note "MISSING folder: $d (the drive may be offline)" }
}
# 3) the room is on, so the normal desktop icons stay hidden (the file cabinet replaces them)
$hidden = ((Get-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' -ErrorAction SilentlyContinue).HideIcons -eq 1)
if (-not $hidden) {
    Add-Type -TypeDefinition 'using System;using System.Text;using System.Runtime.InteropServices;public class FixIcons{public delegate bool CB(IntPtr h,IntPtr l);[DllImport("user32.dll")]static extern bool EnumWindows(CB c,IntPtr l);[DllImport("user32.dll")]static extern IntPtr FindWindowEx(IntPtr p,IntPtr a,string c,string t);[DllImport("user32.dll")]static extern IntPtr SendMessage(IntPtr h,int m,IntPtr w,IntPtr l);[DllImport("user32.dll")]static extern int GetClassName(IntPtr h,StringBuilder s,int n);public static void Toggle(){IntPtr r=IntPtr.Zero;EnumWindows((h,l)=>{var s=new StringBuilder(64);GetClassName(h,s,64);string c=s.ToString();if(c=="Progman"||c=="WorkerW"){IntPtr d=FindWindowEx(h,IntPtr.Zero,"SHELLDLL_DefView",null);if(d!=IntPtr.Zero){r=d;return false;}}return true;},IntPtr.Zero);if(r!=IntPtr.Zero)SendMessage(r,0x111,(IntPtr)0x7402,IntPtr.Zero);}}' -ErrorAction SilentlyContinue
    [FixIcons]::Toggle(); Note 'desktop icons were showing: hidden again'
}
# 3b) the Windows taskbar(s) must be "always on top" (a fullscreen movie/game can leave one demoted behind your windows): put them back
Add-Type -TypeDefinition 'using System;using System.Runtime.InteropServices;public class FixTb{[DllImport("user32.dll")]public static extern IntPtr FindWindowEx(IntPtr p,IntPtr a,string c,string t);[DllImport("user32.dll")]public static extern int GetWindowLong(IntPtr h,int i);[DllImport("user32.dll")]public static extern bool SetWindowPos(IntPtr h,IntPtr a,int x,int y,int w,int hh,uint f);}' -ErrorAction SilentlyContinue
foreach ($c in 'Shell_TrayWnd', 'Shell_SecondaryTrayWnd') {
    $tb = [IntPtr]::Zero
    for ($i = 0; $i -lt 6; $i++) { $tb = [FixTb]::FindWindowEx([IntPtr]::Zero, $tb, $c, $null); if ($tb -eq [IntPtr]::Zero) { break }
        if (([FixTb]::GetWindowLong($tb, -20) -band 8) -eq 0) { [void][FixTb]::SetWindowPos($tb, [IntPtr]-1, 0, 0, 0, 0, 0x13); Note "a taskbar was not on top: fixed ($c)" } }
}
# 4) a hung TV player or Rainmeter is restarted (not while a game is running)
$rmp = Get-Process Rainmeter -ErrorAction SilentlyContinue | Select-Object -First 1
if ($rmp -and -not $rmp.Responding) { Stop-Process -Id $rmp.Id -Force; Start-Sleep 2; Start-Process $rm; Note 'Rainmeter was not responding: restarted' }
$mp = Get-Process mpv -ErrorAction SilentlyContinue | Select-Object -First 1
if ($mp -and -not $gameOn) {
    $ok = $false
    try { $pp = New-Object IO.Pipes.NamedPipeClientStream('.', 'kaijutv', [IO.Pipes.PipeDirection]::InOut); $pp.Connect(2500); $w = New-Object IO.StreamWriter($pp); $w.AutoFlush = $true; $rd = New-Object IO.StreamReader($pp)
          $w.WriteLine('{"command":["get_property","pause"]}'); $ok = [bool]($rd.ReadLine() -match 'success'); $pp.Dispose() } catch { $ok = $false }
    if (-not ($mp.Responding -and $ok)) {
        & powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$($K.Tv)\toggle_tv.ps1" -Action quit; Start-Sleep 2
        & powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$($K.Tv)\toggle_tv.ps1"; Note 'the TV player was stuck: restarted (same movie, same spot)'
    }
}
Set-Content "$st\fix_report.txt" ((@("Kaiju FIX DESKTOP  $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')", "repairs and notes this run: $($report.Count)", '') + @($report)) -join "`r`n")
Say 'fix-it-all done'
