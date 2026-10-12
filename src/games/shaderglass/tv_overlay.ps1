# KAIJU TV filter: a retro CRT look (ShaderGlass, Desktop Glass mode) laid over whatever the TV is showing (movie or game).
#   (no switch) : start the filter and keep it fitted until the TV is off, or until ShaderGlass is closed (closing it is the "off switch")
#   -Stop       : stop the filter now
# The glass window has its title bar and menu stripped (no UI), sits exactly on the TV picture (300x225), is click-through, and follows a
# movie/game that goes fullscreen by covering its whole monitor. One copy only. Log: state\games.log
param([switch]$Stop)
. (Join-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) 'scripts\Kaiju-Config.ps1')
$dir = $PSScriptRoot                                   # kaiju_tv.sgp (the profile template) lives next to this script; ShaderGlass.exe itself is in tools\shaderglass
$mpvDir = $K.State                                     # state + flag files
$log = "$($K.State)\games.log"
function Say($m) { Add-Content $log "$(Get-Date -Format s) [overlay] $m" -ErrorAction SilentlyContinue }
Add-Type -AssemblyName System.Windows.Forms
Add-Type -TypeDefinition @'
using System; using System.Runtime.InteropServices; using System.Text;
public class SGW {
  [DllImport("user32.dll")] public static extern bool SetProcessDPIAware();
  [DllImport("user32.dll")] public static extern bool EnumWindows(EnumCb cb, IntPtr l);
  [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
  [DllImport("user32.dll", CharSet = CharSet.Unicode)] public static extern int GetClassName(IntPtr h, StringBuilder s, int n);
  [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RC r);
  [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr h);
  [DllImport("user32.dll")] public static extern bool IsIconic(IntPtr h);
  [DllImport("user32.dll")] public static extern int GetWindowLong(IntPtr h, int i);
  [DllImport("user32.dll")] public static extern int SetWindowLong(IntPtr h, int i, int v);
  [DllImport("user32.dll")] public static extern bool SetMenu(IntPtr h, IntPtr m);
  [DllImport("user32.dll")] public static extern IntPtr GetMenu(IntPtr h);
  [DllImport("user32.dll")] public static extern bool SetWindowPos(IntPtr h, IntPtr a, int x, int y, int w, int hh, uint f);
  [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr h, int c);
  [DllImport("user32.dll")] public static extern IntPtr GetWindow(IntPtr h, uint cmd);
  public delegate bool EnumCb(IntPtr h, IntPtr l);
  [StructLayout(LayoutKind.Sequential)] public struct RC { public int L, T, R, B; }
  public static IntPtr FindGlass(uint pid) {
    IntPtr found = IntPtr.Zero;
    EnumWindows((h, l) => { uint p; GetWindowThreadProcessId(h, out p); if (p == pid) { var c = new StringBuilder(64); GetClassName(h, c, 64); if (c.ToString() == "SHADERGLASS") { found = h; return false; } } return true; }, IntPtr.Zero);
    return found;
  }
}
'@ -ErrorAction SilentlyContinue
[void][SGW]::SetProcessDPIAware()
Add-Type -TypeDefinition 'using System.Runtime.InteropServices;public class SGM{[DllImport("user32.dll")]public static extern int GetSystemMetrics(int n);}' -ErrorAction SilentlyContinue
$monitors0 = [SGM]::GetSystemMetrics(80)         # live monitor count: if it changes while we run (a screen came or went) the TV moves, so we stop; the next TV start fits it again

$pidFile = "$($K.State)\overlay.pid"
if ($Stop) {
    if (Test-Path $pidFile) { $op = 0; [void][int]::TryParse(((Get-Content $pidFile -Raw) + '').Trim(), [ref]$op); if ($op -gt 0 -and $op -ne $PID) { Stop-Process -Id $op -Force -ErrorAction SilentlyContinue } }
    Get-Process ShaderGlass -ErrorAction SilentlyContinue | Stop-Process -Force
    Remove-Item $pidFile -ErrorAction SilentlyContinue
    return
}
$mutex = New-Object Threading.Mutex($false, 'Global\KaijuTvOverlay')
if (-not $mutex.WaitOne(0)) { return }
Set-Content $pidFile $PID -NoNewline

# the TV picture (same maths as toggle_tv.ps1): the primary screen, credenza 700 room units left of centre
function Get-TvSpot {
    $scr = [System.Windows.Forms.Screen]::PrimaryScreen
    $b = $scr.Bounds; $s0 = $b.Height / 1080.0
    [pscustomobject]@{ X = $b.X + [int]($b.Width / 2 - 700 * $s0 - 226 + 16); Y = $b.Y + [int]($b.Height * 0.875 - 42 * $s0 - 357 + 72); Screen = $scr }
}
function Game-Window {
    $f = "$mpvDir\tv_game.flag"; $ef = "$mpvDir\tv_game_emu.pid"
    if (-not (Test-Path $f) -or -not (Test-Path $ef)) { return [IntPtr]::Zero }
    $sp = 0; [void][int]::TryParse(((Get-Content $f -Raw) + '').Trim(), [ref]$sp)
    if ($sp -le 0 -or -not (Get-Process -Id $sp -ErrorAction SilentlyContinue)) { return [IntPtr]::Zero }
    $ep = 0; [void][int]::TryParse(((Get-Content $ef -Raw) + '').Trim(), [ref]$ep)
    $p = Get-Process -Id $ep -ErrorAction SilentlyContinue
    if ($p) { $p.Refresh(); return $p.MainWindowHandle } else { return [IntPtr]::Zero }
}

try {
    $spot = Get-TvSpot
    # the profile is rewritten each start so the capture follows the monitor the TV is on
    $prof = Get-Content "$dir\kaiju_tv.sgp" -Raw
    $dev = $spot.Screen.DeviceName -replace '\\', '\\\\'
    $prof = [regex]::Replace($prof, '(?m)^CaptureDesktop .*$', "CaptureDesktop `"$dev`"")
    Set-Content "$($K.State)\kaiju_tv_live.sgp" $prof -Encoding ASCII
    $psi = New-Object Diagnostics.ProcessStartInfo
    $psi.FileName = $K.ShaderGlassExe; $psi.Arguments = "`"$($K.State)\kaiju_tv_live.sgp`""; $psi.WorkingDirectory = $K.ShaderGlass
    $psi.UseShellExecute = $true; $psi.WindowStyle = 'Hidden'
    $sg = [Diagnostics.Process]::Start($psi)
    Say "started ShaderGlass pid $($sg.Id) on $($spot.Screen.DeviceName)"
    $h = [IntPtr]::Zero; $styled = $false; $idle = 0; $last = ''
    while ($true) {
        if ($sg.HasExited) { Say 'ShaderGlass closed: filter off'; break }
        if ([SGM]::GetSystemMetrics(80) -ne $monitors0) { Say 'monitors changed: filter stopped (it returns when the TV starts)'; break }
        if ($h -eq [IntPtr]::Zero) { $h = [SGW]::FindGlass([uint32]$sg.Id); if ($h -eq [IntPtr]::Zero) { Start-Sleep -Milliseconds 300; continue } }
        # what is the TV showing?
        $tv = Game-Window
        if ($tv -eq [IntPtr]::Zero) { $m = Get-Process mpv -ErrorAction SilentlyContinue | Select-Object -First 1; if ($m) { $tv = $m.MainWindowHandle } }
        $showing = ($tv -ne [IntPtr]::Zero) -and -not [SGW]::IsIconic($tv) -and [SGW]::IsWindowVisible($tv)
        if (-not $showing) {
            [void][SGW]::ShowWindow($h, 0); $last = ''
            if (++$idle -gt 30) { Say 'TV off: filter stopped'; break }          # about 15 s with nothing on the TV
            Start-Sleep -Milliseconds 500; continue
        }
        $idle = 0
        $spot = Get-TvSpot
        $r = New-Object SGW+RC; [void][SGW]::GetWindowRect($tv, [ref]$r)
        $scr = [System.Windows.Forms.Screen]::FromHandle($tv); $sb = $scr.Bounds
        if (($r.R - $r.L) -ge $sb.Width -and ($r.B - $r.T) -ge $sb.Height) { $x = $sb.X; $y = $sb.Y; $w = $sb.Width; $ht = $sb.Height; $mode = 'full' }   # fullscreen: the filter covers the whole monitor
        else { $x = $spot.X; $y = $spot.Y; $w = 300; $ht = 225; $mode = 'tv' }
        if (-not $styled) {
            $style = [SGW]::GetWindowLong($h, -16); [void][SGW]::SetWindowLong($h, -16, ($style -band (-bnot 0x00CF0000)))   # no title bar, border, buttons
            [void][SGW]::SetMenu($h, [IntPtr]::Zero)                                                                          # no menu: no UI at all
            $ex = [SGW]::GetWindowLong($h, -20); [void][SGW]::SetWindowLong($h, -20, ($ex -bor 0x80 -bor 0x08000000))        # no taskbar button, never takes focus
            $styled = $true; Say 'frame and menu stripped'
        }
        $want = "$x,$y,$w,$ht"
        # Z-ORDER: directly ABOVE the movie/game window and below every other window, never topmost. ShaderGlass processes whatever is under it, so a topmost
        # filter would also "filter" any app dragged over the TV (and hide it from screenshots). ShaderGlass puts itself topmost now and then; this puts it back.
        $prev = [SGW]::GetWindow($tv, 3)                                                  # GW_HWNDPREV: the window just above the TV window
        $isTopmost = (([SGW]::GetWindowLong($h, -20) -band 0x8) -ne 0)
        $tvTop = (([SGW]::GetWindowLong($tv, -20) -band 0x8) -ne 0)                        # a fullscreen movie/game is topmost (above the taskbar): the filter must be too
        if ($tvTop) {
            $zIns = [IntPtr]-1                                                            # HWND_TOPMOST: top of the topmost group, above the TV window
            $isAbove = $false; $wn = $prev; for ($n = 0; $wn -ne [IntPtr]::Zero -and $n -lt 500; $n++) { if ($wn -eq $h) { $isAbove = $true; break }; $wn = [SGW]::GetWindow($wn, 3) }
            $fix = (-not $isAbove) -or (-not $isTopmost)
        } else {
            $zIns = if ($prev -eq [IntPtr]::Zero -or $prev -eq $h) { [IntPtr]::Zero } else { $prev }   # directly above the TV window (nothing above it -> HWND_TOP)
            $fix = ($prev -ne $h) -or $isTopmost
        }
        if ($want -ne $last) {
            [void][SGW]::SetWindowPos($h, $zIns, $x, $y, $w, $ht, 0x70)                  # moved/resized, frame refreshed, no focus change, shown
            Say "placed ($mode) $want"; $last = $want
        }
        elseif ($fix) {
            [void][SGW]::SetWindowPos($h, $zIns, 0, 0, 0, 0, 0x13)                       # same place, only the stacking order is repaired
        }
        Start-Sleep -Milliseconds 300
    }
}
catch { Say "ERROR: $($_.Exception.Message)" }
finally {
    Get-Process ShaderGlass -ErrorAction SilentlyContinue | Stop-Process -Force
    Remove-Item $pidFile -ErrorAction SilentlyContinue
}
