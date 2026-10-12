# Plays an emulator game INSIDE the TV set: the game window is stripped to a bare picture, fitted exactly to the TV screen (300x225) and kept there
# (behind every app, like the movie player). The movie player is stopped while a game runs and comes back where it left off when the game ends.
#   -CmdFile : JSON written by kaiju_games.py { "cmd": ["exe","arg",...], "cwd": "...", "title": "Game name" }
# Live state for the TV skin goes into state\tv_state.txt (so the skin shows ON and the game name); state\tv_game.flag holds this script's PID
# so the watcher knows a game is on and does not reset the state. Log: state\games.log.
param([Parameter(Mandatory)][string]$CmdFile)
. (Join-Path (Split-Path $PSScriptRoot -Parent) 'scripts\Kaiju-Config.ps1')
$mpvDir = $K.State                                                  # state + flag files
$flag = "$mpvDir\tv_game.flag"
$state = "$mpvDir\tv_state.txt"
$stopFlag = "$mpvDir\tv_game_stop.flag"
[IO.File]::Delete($stopFlag)                                         # a stale stop request must never end the next game
$log = "$($K.State)\games.log"
function Say($m) { Add-Content $log "$(Get-Date -Format s) [tv] $m" -ErrorAction SilentlyContinue }
Add-Type -AssemblyName System.Windows.Forms
Add-Type -TypeDefinition @'
using System; using System.Runtime.InteropServices; using System.Text;
public class GW {
  [DllImport("user32.dll")] public static extern bool SetProcessDPIAware();
  [DllImport("user32.dll")] public static extern bool SetWindowPos(IntPtr h, IntPtr a, int x, int y, int w, int hh, uint f);
  [DllImport("user32.dll")] public static extern int GetWindowLong(IntPtr h, int i);
  [DllImport("user32.dll")] public static extern int SetWindowLong(IntPtr h, int i, int v);
  [DllImport("user32.dll")] public static extern bool SetMenu(IntPtr h, IntPtr m);
  [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RC r);
  [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr h);
  [DllImport("user32.dll")] public static extern bool IsIconic(IntPtr h);
  [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr h, int c);
  [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
  [DllImport("user32.dll")] public static extern void keybd_event(byte vk, byte sc, uint f, UIntPtr e);
  [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
  [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
  [DllImport("user32.dll")] public static extern bool EnumWindows(EnumCb cb, IntPtr l);
  [DllImport("user32.dll", CharSet = CharSet.Unicode)] public static extern int GetWindowText(IntPtr h, StringBuilder s, int n);
  public delegate bool EnumCb(IntPtr h, IntPtr l);
  [StructLayout(LayoutKind.Sequential)] public struct RC { public int L, T, R, B; }
  // biggest visible titled top-level window of a process (emulators sometimes show a splash first)
  public static IntPtr FindMain(uint pid) {
    IntPtr best = IntPtr.Zero; long area = 0;
    EnumWindows((h, l) => { uint p; GetWindowThreadProcessId(h, out p); if (p == pid && IsWindowVisible(h)) {
      var sb = new StringBuilder(256); GetWindowText(h, sb, 256); RC r; GetWindowRect(h, out r); long a = (long)(r.R - r.L) * (r.B - r.T);
      if (sb.Length > 0 && a > area) { area = a; best = h; } } return true; }, IntPtr.Zero);
    return best;
  }
}
'@ -ErrorAction SilentlyContinue
[void][GW]::SetProcessDPIAware()

# Where the TV picture is (same maths as toggle_tv.ps1 Get-TvSpot): the primary screen, credenza 700 room units left of centre
function Get-TvSpot {
    $b = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds
    $s0 = $b.Height / 1080.0
    [pscustomobject]@{ X = $b.X + [int]($b.Width / 2 - 700 * $s0 - 226 + 16); Y = $b.Y + [int]($b.Height * 0.875 - 42 * $s0 - 357 + 72); Bounds = $b }
}
function Write-State([int]$run, [string]$title) {
    $vol = 35; $mute = 0
    if (Test-Path $state) { $t = Get-Content $state -Raw; $m = [regex]::Match($t, 'vol=(\d+)'); if ($m.Success) { $vol = [int]$m.Groups[1].Value }; $mm = [regex]::Match($t, 'mute=(\d)'); if ($mm.Success) { $mute = [int]$mm.Groups[1].Value } }
    Set-Content $state "vol=$vol;mute=$mute;pause=0;subs=0;run=$run;hid=0;title=$title" -NoNewline
}

# one game at a time: if another supervisor is alive, this request is dropped (the console click stops the running game first)
if (Test-Path $flag) { $op = 0; [void][int]::TryParse(((Get-Content $flag -Raw) + '').Trim(), [ref]$op); if ($op -gt 0 -and (Get-Process -Id $op -ErrorAction SilentlyContinue)) { Say 'ignored: a game is already running'; Remove-Item $CmdFile -ErrorAction SilentlyContinue; return } }
$spec = Get-Content $CmdFile -Raw | ConvertFrom-Json
$title = ($spec.title -replace '[;\r\n]', ' ')
$exe = $spec.cmd[0]; $argList = @($spec.cmd | Select-Object -Skip 1)
$mode = if ($spec.mode -eq 'full') { 'full' } else { 'tv' }          # tv = inside the TV picture; full = the whole TV monitor (the CRT filter follows)
$emuPid = "$mpvDir\tv_game_emu.pid"
Say "start ($mode) '$title': $($spec.cmd -join ' | ')"

# 1) the movie player gives way (it resumes the same movie and spot afterwards)
$tvWasOn = [bool](Get-Process mpv -ErrorAction SilentlyContinue)
if ($tvWasOn) { & "$($K.Tv)\toggle_tv.ps1" quit }
Set-Content $flag $PID -NoNewline
Set-Content "$mpvDir\tv_game_state.txt" '1' -NoNewline                 # the console skin reads this: tag says STOP GAME while 1

try {
    # 1b) make sure the emulator settings (controller, quick save/load, background input) are in place before it starts
    & $K.Python -I "$PSScriptRoot\kaiju_repair.py" | Out-Null
    # 2) start the emulator
    $psi = New-Object Diagnostics.ProcessStartInfo
    $psi.FileName = $exe; $psi.WorkingDirectory = $spec.cwd; $psi.UseShellExecute = $false
    $psi.Arguments = ($argList | ForEach-Object { '"' + (([string]$_) -replace '(\\*)"', '$1$1\"' -replace '(\\+)$', '$1$1') + '"' }) -join ' '   # Windows PowerShell 5.1 has no ArgumentList
    $proc = [Diagnostics.Process]::Start($psi)
    Set-Content $emuPid $proc.Id -NoNewline                         # the CRT filter finds the game window through this
    Write-State 1 $title
    Start-Process powershell.exe -WindowStyle Hidden -ArgumentList '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "$PSScriptRoot\shaderglass\tv_overlay.ps1"   # starts the filter (one copy only; it does nothing if it is already running)
    Start-Process powershell.exe -WindowStyle Hidden -ArgumentList '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "$PSScriptRoot\tv_volume.ps1"   # the TV's volume (bar, SOUND, mouse wheel) controls the game's volume; it stops when the game ends
    $placed = $false; $focused = $false
    for ($tick = 0; ; $tick++) {
        if ($proc.HasExited) { Say "game ended (exit $($proc.ExitCode))"; break }
        if (Test-Path $stopFlag) {                                   # the console was clicked while a game runs: end it politely, then hard if it ignores us
            [IO.File]::Delete($stopFlag); Say 'stop requested'
            [void]$proc.CloseMainWindow(); if (-not $proc.WaitForExit(4000)) { $proc.Kill() }
            continue
        }
        $h = [GW]::FindMain([uint32]$proc.Id)
        if ($h -ne [IntPtr]::Zero) {
            $p = Get-TvSpot
            $r = New-Object GW+RC; [void][GW]::GetWindowRect($h, [ref]$r)
            $style = [GW]::GetWindowLong($h, -16); $ex = [GW]::GetWindowLong($h, -20)
            $wantStyle = $style -band (-bnot (0x00C00000 -bor 0x00040000 -bor 0x00080000 -bor 0x00020000 -bor 0x00010000))   # no caption, border, sizing frame, buttons
            if ($mode -eq 'full') {
                $b = $p.Bounds; $tx = $b.X; $ty = $b.Y; $tw = $b.Width; $th = $b.Height
                $wantEx = $ex -band (-bnot (0x40000 -bor 0x200 -bor 0x100 -bor 0x80))                                        # a normal focusable window again, edges off
                $zorder = [IntPtr]-1; $flags = 0x60                                                                             # topmost (above the taskbar), frame refreshed, shown (may take focus)
            } else {
                $tx = $p.X; $ty = $p.Y; $tw = 300; $th = 225
                $wantEx = ($ex -bor 0x08000000 -bor 0x80) -band (-bnot (0x40000 -bor 0x200 -bor 0x100))                      # never raises itself, no taskbar button, no edges
                $zorder = [IntPtr]1; $flags = 0x70                                                                              # bottom of the stack, no focus change
            }
            $off = ($r.L -ne $tx) -or ($r.T -ne $ty) -or (($r.R - $r.L) -ne $tw) -or (($r.B - $r.T) -ne $th)
            if ($wantStyle -ne $style -or $wantEx -ne $ex -or $off) {
                if ([GW]::IsIconic($h)) { [void][GW]::ShowWindow($h, 4) }
                [void][GW]::SetMenu($h, [IntPtr]::Zero)
                [void][GW]::SetWindowLong($h, -16, $wantStyle); [void][GW]::SetWindowLong($h, -20, $wantEx)
                [void][GW]::SetWindowPos($h, $zorder, $tx, $ty, $tw, $th, $flags)
                if (-not $placed) { Say "placed ($mode) window $h at $tx,$ty ${tw}x$th"; $placed = $true }
            }
            if ($mode -eq 'full' -and -not $focused) {                                                                    # full screen: the game takes the foreground (keyboard/controller, and Windows hides the taskbar)
                [GW]::keybd_event(0x12, 0, 0, [UIntPtr]::Zero); [GW]::keybd_event(0x12, 0, 2, [UIntPtr]::Zero)          # a tap of Alt lets this process change the foreground window
                [void][GW]::SetForegroundWindow($h); $focused = $true
            }
        }
        Start-Sleep -Milliseconds 700
    }
}
catch { Say "ERROR: $($_.Exception.Message)" }
finally {
    [IO.File]::Delete($flag); [IO.File]::Delete($emuPid)
    Set-Content "$mpvDir\tv_game_state.txt" '0' -NoNewline
    Remove-Item $CmdFile -ErrorAction SilentlyContinue
    if ($tvWasOn) { Say 'bringing the movie back'; Write-State 0 ''; & "$($K.Tv)\toggle_tv.ps1" }
    else { Write-State 0 '' }
}
