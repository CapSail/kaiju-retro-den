# Mini TV control.
#   (no action) / toggle : start the TV, or hide/show it if it is running
#   quit | mute | subs | next | back | pause | volume -Value <0-100> : control a running TV (does nothing if it is not running)
#   place : put the player back exactly on the TV picture, at the bottom of the window stack (the watcher calls this every few seconds)
# The TV is part of the desktop: the player sits on the TV set in the wallpaper room and BEHIND every app.
param([string]$Action = 'toggle', [string]$Value = '')
. (Join-Path (Split-Path $PSScriptRoot -Parent) 'scripts\Kaiju-Config.ps1')
$dir = $K.State                                                  # state + flag files (tv_state.txt, tv_game.flag, ...)
Add-Type -AssemblyName System.Windows.Forms
Add-Type -TypeDefinition 'using System;using System.Runtime.InteropServices;public class TvWin{[DllImport("user32.dll")]public static extern bool SetWindowPos(IntPtr h,IntPtr a,int x,int y,int w,int hh,uint f);[DllImport("user32.dll")]public static extern bool SetProcessDPIAware();[DllImport("user32.dll")]public static extern bool IsIconic(IntPtr h);[DllImport("user32.dll")]public static extern bool ShowWindow(IntPtr h,int c);[DllImport("user32.dll")]public static extern IntPtr GetForegroundWindow();[DllImport("user32.dll")]public static extern bool SetForegroundWindow(IntPtr h);[DllImport("user32.dll")]public static extern int GetWindowLong(IntPtr h,int i);[DllImport("user32.dll")]public static extern int SetWindowLong(IntPtr h,int i,int v);[DllImport("user32.dll")]public static extern bool GetWindowRect(IntPtr h,out TvRc r);[DllImport("user32.dll")]public static extern void keybd_event(byte vk,byte sc,uint f,UIntPtr e);[DllImport("user32.dll")]public static extern IntPtr FindWindowEx(IntPtr p,IntPtr a,string c,string t);[DllImport("user32.dll")]public static extern bool IsWindow(IntPtr h);}public struct TvRc{public int L,T,R,B;}' -ErrorAction SilentlyContinue
[void][TvWin]::SetProcessDPIAware()
# one copy at a time: quick double clicks must not start two players or fight over the window
$script:gate = New-Object Threading.Mutex($false, 'Global\KaijuTvControl')
if (-not $script:gate.WaitOne(8000)) { return }

function Send-Mpv([string]$json) {
    $pipe = New-Object System.IO.Pipes.NamedPipeClientStream('.', 'kaijutv', [System.IO.Pipes.PipeDirection]::Out)
    try { $pipe.Connect(1500); $b = [Text.Encoding]::UTF8.GetBytes($json + "`n"); $pipe.Write($b, 0, $b.Length); $pipe.Flush() } finally { $pipe.Dispose() }
}

function Test-Fullscreen {
    try {
        $p = New-Object System.IO.Pipes.NamedPipeClientStream('.', 'kaijutv', [System.IO.Pipes.PipeDirection]::InOut)
        try { $p.Connect(600); $w = New-Object IO.StreamWriter($p); $w.AutoFlush = $true; $rd = New-Object IO.StreamReader($p)
              $w.WriteLine('{"command":["get_property","fullscreen"]}'); return ($rd.ReadLine() -match '"data":true') } finally { $p.Dispose() }
    } catch { return $false }
}

# Where the picture of the TV set is: the primary screen, credenza 700 room units left of centre (room unit = screen height / 1080)
function Get-TvSpot {
    $b = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds
    $s0 = $b.Height / 1080.0
    [pscustomobject]@{ X = $b.X + [int]($b.Width / 2 - 700 * $s0 - 226 + 16); Y = $b.Y + [int]($b.Height * 0.875 - 42 * $s0 - 357 + 72) }
}
function Place-Tv {
    $m = Get-Process mpv -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $m -or $m.MainWindowHandle -eq [IntPtr]::Zero) { return }
    if ([TvWin]::IsIconic($m.MainWindowHandle)) {                    # minimized: only the HIDE button may do that; Win+D / "minimize all" must not take the TV away
        if (Test-Path "$dir\tv_hidden_by_user.flag") { return }
        [void][TvWin]::ShowWindow($m.MainWindowHandle, 4)
    }
    $h = $m.MainWindowHandle
    $r = New-Object TvRc; [void][TvWin]::GetWindowRect($h, [ref]$r)
    if (($r.R - $r.L) -gt 600 -and (Test-Fullscreen)) { return }     # really fullscreen (hover button): leave it alone; any other odd size gets put right below
    $flags = 0x10
    $ex = [TvWin]::GetWindowLong($h, -20); $want = $ex -bor 0x08000000 -bor 0x80        # NOACTIVATE + TOOLWINDOW: clicking the picture never focuses or raises the player
    if ($ex -ne $want) { [void][TvWin]::SetWindowLong($h, -20, $want); $flags = 0x30 }
    $p = Get-TvSpot
    [void][TvWin]::SetWindowPos($h, [IntPtr]1, $p.X, $p.Y, 300, 225, $flags)   # bottom of the stack, no focus
}

$tv = Get-Process mpv -ErrorAction SilentlyContinue
if ($Action -eq 'place') { Place-Tv; return }
if ($Action -eq 'fsenter') {
    # the movie went fullscreen: make it a normal foreground window so Windows hides the taskbar (a window that covers the monitor and is in front is "truly fullscreen").
    # Place-Tv (run when fullscreen ends) gives the prop behaviour back: no focus, no taskbar button, bottom of the stack.
    $m = Get-Process mpv -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($m -and $m.MainWindowHandle -ne [IntPtr]::Zero) {
        $h = $m.MainWindowHandle
        $pf = [TvWin]::GetForegroundWindow(); if ($pf -ne $h) { Set-Content "$dir\fs_prev_fg.txt" ([string][int64]$pf) -NoNewline }   # whatever you were in, to hand focus back afterwards
        [void][TvWin]::SetWindowLong($h, -20, ([TvWin]::GetWindowLong($h, -20) -band (-bnot (0x08000000 -bor 0x80))))
        [TvWin]::keybd_event(0x12, 0, 0, [UIntPtr]::Zero); [TvWin]::keybd_event(0x12, 0, 2, [UIntPtr]::Zero)     # a tap of Alt lets this process change the foreground window
        [void][TvWin]::SetForegroundWindow($h)
    }
    return
}
if ($Action -eq 'fsexit') {
    # fullscreen ended: the player is a prop again, the taskbar(s) come back on top, and focus goes back to the window you were using
    Place-Tv
    if (Test-Path "$dir\fs_prev_fg.txt") {
        $pf = [IntPtr][int64]((Get-Content "$dir\fs_prev_fg.txt" -Raw).Trim()); Remove-Item "$dir\fs_prev_fg.txt" -ErrorAction SilentlyContinue
        if ($pf -ne [IntPtr]::Zero -and [TvWin]::IsWindow($pf)) { [TvWin]::keybd_event(0x12, 0, 0, [UIntPtr]::Zero); [TvWin]::keybd_event(0x12, 0, 2, [UIntPtr]::Zero); [void][TvWin]::SetForegroundWindow($pf) }
    }
    Start-Sleep -Milliseconds 400                                                  # let Windows notice the player is no longer the foreground window, then make sure the taskbar(s) are back on top
    foreach ($c in 'Shell_TrayWnd', 'Shell_SecondaryTrayWnd') {
        $tb = [IntPtr]::Zero
        for ($i = 0; $i -lt 6; $i++) { $tb = [TvWin]::FindWindowEx([IntPtr]::Zero, $tb, $c, $null); if ($tb -eq [IntPtr]::Zero) { break }; if (([TvWin]::GetWindowLong($tb, -20) -band 8) -eq 0) { [void][TvWin]::SetWindowPos($tb, [IntPtr]-1, 0, 0, 0, 0, 0x13) } }
    }
    return
}
# a game is playing in the TV: the volume bar and the SOUND button control the GAME's volume. tv_state.txt is the source of truth; games\tv_volume.ps1 applies it
# to the emulator's audio and keeps tv_prefs.txt in step (so the movie comes back at the same volume). The other buttons do nothing while a game runs.
$gf = "$dir\tv_game.flag"; $gameOn = $false
if (Test-Path $gf) { $gp = 0; [void][int]::TryParse(((Get-Content $gf -Raw) + '').Trim(), [ref]$gp); if ($gp -gt 0 -and (Get-Process -Id $gp -ErrorAction SilentlyContinue)) { $gameOn = $true } }
if ($gameOn -and $Action -in 'volume', 'mute') {
    $sp = "$dir\tv_state.txt"; $pp = "$dir\tv_prefs.txt"
    if (Test-Path $sp) {
        $t = Get-Content $sp -Raw
        if ($Action -eq 'volume') { $v = [int][Math]::Max(0, [Math]::Min(100, [Math]::Round([double]$Value))); $t = $t -replace 'vol=\d+', "vol=$v" -replace 'mute=\d', 'mute=0' }
        else { $mm = [regex]::Match($t, 'mute=(\d)'); $nm = if ($mm.Success -and $mm.Groups[1].Value -eq '1') { 0 } else { 1 }; $t = $t -replace 'mute=\d', "mute=$nm" }
        Set-Content $sp $t -NoNewline
        if (Test-Path $pp) { $vv = [regex]::Match($t, 'vol=(\d+)').Groups[1].Value; $mu = [regex]::Match($t, 'mute=(\d)').Groups[1].Value; Set-Content $pp ((Get-Content $pp -Raw) -replace 'vol=\d+', "vol=$vv" -replace 'mute=\d', "mute=$mu") -NoNewline }
    }
    return
}
if ($gameOn -and $Action -ne 'quit' -and $Action -ne 'place' -and $Action -ne 'toggle') { return }      # movie-only buttons (back/next/pause/subs/hide) do nothing during a game
if ($Action -eq 'quit') {
    if ($tv) {
        try { Send-Mpv '{"command":["quit"]}' } catch {}
        for ($i = 0; $i -lt 20 -and (Get-Process mpv -ErrorAction SilentlyContinue); $i++) { Start-Sleep -Milliseconds 150 }
        Get-Process mpv -ErrorAction SilentlyContinue | Stop-Process -Force
    }
    $sp = "$dir\tv_state.txt"
    $cur = if (Test-Path $sp) { (Get-Content $sp -Raw) } else { 'vol=35;mute=0;pause=0;subs=1;run=1;title=' }
    Set-Content $sp ($cur -replace 'run=\d', 'run=0') -NoNewline
    [IO.File]::Delete("$dir\tv_hidden_by_user.flag")
    return
}
if (-not $tv) {
    if ($Action -eq 'toggle') {
        # play the shuffled playlist built from the movies folder (tv\make_playlist.ps1, run by the installer), starting at the last file played
        $pl = "$dir\movies_playlist.m3u"
        $idx = 0
        if (Test-Path "$dir\tv_last.txt") { $t = (Get-Content "$dir\tv_last.txt" -Raw).Trim(); if ($t -match '^\d+$') { $idx = [int]$t } }
        $prevFg = [TvWin]::GetForegroundWindow()
        $mp = Start-Process $K.MpvExe -ArgumentList "--playlist=`"$pl`"", "--playlist-start=$idx" -PassThru
        for ($i = 0; $i -lt 40; $i++) { Start-Sleep -Milliseconds 250; $mp.Refresh(); if ($mp.MainWindowHandle -ne [IntPtr]::Zero) { Place-Tv; break } }
        # the retro CRT filter goes over the picture (one copy only; closing ShaderGlass is the off switch until the TV is started again)
        Start-Process powershell.exe -WindowStyle Hidden -ArgumentList '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "$($K.Games)\shaderglass\tv_overlay.ps1"
        # a new window grabs focus; give it back to whatever the user was in
        Start-Sleep -Milliseconds 300
        if ($prevFg -ne [IntPtr]::Zero -and $mp.MainWindowHandle -ne [IntPtr]::Zero -and [TvWin]::GetForegroundWindow() -eq $mp.MainWindowHandle) { [void][TvWin]::SetForegroundWindow($prevFg) }
    }
    return
}
switch ($Action) {
    'mute'   { Send-Mpv '{"command":["cycle","mute"]}' }
    'subs'   { Send-Mpv '{"command":["cycle","sub-visibility"]}' }
    'next'   { Send-Mpv '{"command":["playlist-next"]}' }
    'back'   { Send-Mpv '{"command":["script-message","kaiju-back"]}' }
    'pause'  { Send-Mpv '{"command":["cycle","pause"]}' }
    'volume' {
        $v = [int][Math]::Round([double]$Value); $v = [Math]::Max(0, [Math]::Min(100, $v))
        Send-Mpv '{"command":["set_property","mute",false]}'
        Send-Mpv ('{"command":["set_property","volume",' + $v + ']}')
        Send-Mpv ('{"command":["show-text","VOLUME ' + $v + '",700]}')
    }
    default  {                                                                    # HIDE / SHOW button (remembered so Place-Tv respects it)
        $m = Get-Process mpv -ErrorAction SilentlyContinue | Select-Object -First 1
        $flag = "$dir\tv_hidden_by_user.flag"
        if ($m -and [TvWin]::IsIconic($m.MainWindowHandle)) { [IO.File]::Delete($flag); [void][TvWin]::ShowWindow($m.MainWindowHandle, 4) }
        else { Set-Content $flag '1'; Send-Mpv '{"command":["set_property","window-minimized",true]}' }
        Start-Sleep -Milliseconds 600
    }
}
Place-Tv
