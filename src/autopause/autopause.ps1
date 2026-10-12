# Autopause watcher for the Kaiju desktop.
# - A fullscreen / borderless-fullscreen window (a game, a video, a presentation) in front:
#     pause the mini TV, hide the Rainmeter widgets. Everything comes back when it leaves the front.
# - Wallpaper Engine pauses itself (its own settings: fullscreen, maximized and focus = pause).
# - The screen resolution or the number of monitors changes: re-apply the room after a few seconds.
# Config: autopause.json next to this script. "tv_pause_on_any_app": true also pauses the TV whenever any normal app is in front.
. (Join-Path (Split-Path $PSScriptRoot -Parent) 'scripts\Kaiju-Config.ps1')
$cfgPath = Join-Path $PSScriptRoot 'autopause.json'
$logPath = "$($K.State)\autopause.log"
$rm = $K.RainmeterExe
$skins = @(@('KaijuHUD\Systems','Systems.ini'), @('KaijuHUD\Scene','Scene.ini'), @('KaijuHUD\TVRemote','TVRemote.ini'), @('KaijuHUD\Console','Console.ini'))
$ignore = @('Rainmeter','mpv','wallpaper64','webwallpaper64','wallpaperui','explorer','SearchHost','ShellExperienceHost','StartMenuExperienceHost','TextInputHost','LockApp','pwsh','powershell','steamwebhelper','NVIDIA Overlay','nvcontainer')

Add-Type @'
using System; using System.Runtime.InteropServices; using System.Text;
public class AP {
  [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
  [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r);
  [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
  [DllImport("user32.dll")] public static extern int GetClassName(IntPtr h, StringBuilder s, int n);
  [DllImport("user32.dll")] public static extern IntPtr MonitorFromWindow(IntPtr h, uint f);
  [DllImport("user32.dll")] public static extern bool GetMonitorInfo(IntPtr m, ref MONITORINFO mi);
  [StructLayout(LayoutKind.Sequential)] public struct RECT { public int L, T, R, B; }
  [StructLayout(LayoutKind.Sequential)] public struct MONITORINFO { public int cb; public RECT mon; public RECT work; public uint flags; }
}
'@

function Get-State {
    $h = [AP]::GetForegroundWindow()
    if ($h -eq [IntPtr]::Zero) { return @{ any = $false; full = $false; name = '' } }
    $sb = New-Object Text.StringBuilder 256; [void][AP]::GetClassName($h, $sb, 256); $cls = $sb.ToString()
    if ($cls -in 'Progman','WorkerW','Shell_TrayWnd','Shell_SecondaryTrayWnd') { return @{ any = $false; full = $false; name = $cls } }
    $pid2 = 0; [void][AP]::GetWindowThreadProcessId($h, [ref]$pid2)
    $name = (Get-Process -Id $pid2 -ErrorAction SilentlyContinue).ProcessName
    if ($name -in $ignore) { return @{ any = $false; full = $false; name = $name } }
    $r = New-Object AP+RECT; [void][AP]::GetWindowRect($h, [ref]$r)
    $mi = New-Object AP+MONITORINFO; $mi.cb = [Runtime.InteropServices.Marshal]::SizeOf($mi)
    [void][AP]::GetMonitorInfo([AP]::MonitorFromWindow($h, 2), [ref]$mi)
    $full = ($r.L -le $mi.mon.L) -and ($r.T -le $mi.mon.T) -and ($r.R -ge $mi.mon.R) -and ($r.B -ge $mi.mon.B)
    return @{ any = $true; full = $full; name = $name }
}
function Send-Mpv([string]$json) {
    try { $p = New-Object IO.Pipes.NamedPipeClientStream('.', 'kaijutv', [IO.Pipes.PipeDirection]::Out); $p.Connect(300)
          $b = [Text.Encoding]::UTF8.GetBytes($json + "`n"); $p.Write($b, 0, $b.Length); $p.Flush(); $p.Dispose(); return $true } catch { return $false }
}
function Log($m) { Add-Content $logPath "$(Get-Date -Format 'HH:mm:ss') $m" }

# single instance only
$mutex = New-Object Threading.Mutex($false, 'Global\KaijuAutopause')
if (-not $mutex.WaitOne(0)) { exit }

$applyScript = "$($K.Scripts)\apply_all.ps1"
# Screen layout signature, read live: [Windows.Forms.Screen]::AllScreens is cached for the life of a process and never sees a monitor or a resolution change.
Add-Type -TypeDefinition 'using System.Runtime.InteropServices;public class KgMetrics{[DllImport("user32.dll")]public static extern int GetSystemMetrics(int n);}' -ErrorAction SilentlyContinue   # 80 = monitor count, 0/1 = primary width/height
function Get-ScreenSig { "$([KgMetrics]::GetSystemMetrics(80)):$([KgMetrics]::GetSystemMetrics(0))x$([KgMetrics]::GetSystemMetrics(1))" }
$lastSig = Get-ScreenSig

$tvPausedByUs = $false; $widgetsHidden = $false
Log "watcher started (screens: $lastSig)"
try {
Add-Type -TypeDefinition 'using System;using System.Runtime.InteropServices;public class TvLow{[DllImport("user32.dll")]public static extern bool SetWindowPos(IntPtr h,IntPtr a,int x,int y,int w,int hh,uint f);}' -ErrorAction SilentlyContinue
$tick = 0
while ($true) {
    try {
        $sig = Get-ScreenSig
        if ($sig -ne $lastSig) {
            Log "screen layout changed $lastSig -> $sig"
            Start-Sleep 6                                                                    # let Windows settle
            $lastSig = Get-ScreenSig
            Log 're-applying wallpaper and refreshing widgets'
            & powershell -NoProfile -ExecutionPolicy Bypass -File $applyScript
            Start-Sleep 3
            & $rm '!RefreshApp'
        }
        # the TV skin trusts tv_state.txt: after a reboot / crash it may still say run=1 with no player, which leaves no picture to click to start it
        # a game playing inside the TV (tv_game.ps1) owns the state file while its supervisor is alive; a stale flag (reboot/crash) is cleared
        $gf = "$($K.State)\tv_game.flag"; $gameOn = $false
        if (Test-Path $gf) { $gp = 0; [void][int]::TryParse(((Get-Content $gf -Raw) + '').Trim(), [ref]$gp); if ($gp -gt 0 -and (Get-Process -Id $gp -ErrorAction SilentlyContinue)) { $gameOn = $true } else { Remove-Item $gf -ErrorAction SilentlyContinue; Set-Content "$($K.State)\tv_game_state.txt" '0' -NoNewline; Log 'stale game flag cleared' } }
        if (-not $gameOn -and -not (Get-Process mpv -ErrorAction SilentlyContinue)) {
            $sp = "$($K.State)\tv_state.txt"
            if ((Test-Path $sp) -and ((Get-Content $sp -Raw) -match 'run=1')) { Set-Content $sp ((Get-Content $sp -Raw) -replace 'run=1', 'run=0' -replace 'hid=1', 'hid=0') -NoNewline; Log 'TV not running: state reset to off' }
        }
        $cfg = if (Test-Path $cfgPath) { Get-Content $cfgPath -Raw | ConvertFrom-Json } else { [pscustomobject]@{ tv_pause_on_any_app = $false } }
        $s = Get-State
        $wantTvPause = $s.full -or ($cfg.tv_pause_on_any_app -and $s.any)
        if ($wantTvPause -and -not $tvPausedByUs) { if (Send-Mpv '{"command":["set_property","pause",true]}') { $tvPausedByUs = $true; Log "TV paused ($($s.name))" } }
        if (-not $wantTvPause -and $tvPausedByUs) { Send-Mpv '{"command":["set_property","pause",false]}' | Out-Null; $tvPausedByUs = $false; Log 'TV resumed' }
        if ($s.full -and -not $widgetsHidden) {
            foreach ($k in $skins) { & $rm '!DeactivateConfig' $k[0] }; $widgetsHidden = $true; Log "widgets hidden ($($s.name))"
        }
        if (-not $s.full -and $widgetsHidden) {
            foreach ($k in $skins) { & $rm '!ActivateConfig' $k[0] $k[1] }; $widgetsHidden = $false; Log 'widgets restored'
        }
    } catch { Log "error: $($_.Exception.Message)" }
    # the TV is part of the desktop: keep the player exactly on its picture, behind every app.
    # separate process on purpose: toggle_tv.ps1 holds a lock and caches its Win32 helper types, so it must never run inside the long-lived watcher
    try { $tick++; if ($tick % 3 -eq 0 -and (Get-Process mpv -ErrorAction SilentlyContinue)) { & powershell.exe -NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File "$($K.Tv)\toggle_tv.ps1" place } } catch { Log "place error: $($_.Exception.Message)" }
    Start-Sleep -Milliseconds 1500
}
} catch { Log "fatal: $($_.Exception.Message)"; $failed = $true } finally { Log 'watcher exiting' }
if ($failed) { exit 1 }    # non-zero so the scheduled task restarts it
