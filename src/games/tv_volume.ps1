# While a game plays on the TV, the TV's volume controls the GAME's volume.
#   - tv_state.txt (vol / mute) is the source of truth, exactly like for the movie: the remote's volume bar and SOUND button (toggle_tv.ps1) write it,
#     and the mouse wheel over the game picture changes it (low-level mouse hook below).
#   - This helper applies it to the emulator's Windows audio session (per-app volume, same as the Volume Mixer) and persists it to tv_prefs.txt,
#     so the movie comes back at the same volume. It stops by itself when the game ends.
# Started by tv_game.ps1. Log: state\games.log
. (Join-Path (Split-Path $PSScriptRoot -Parent) 'scripts\Kaiju-Config.ps1')
$mpv = $K.State                                                  # state + flag files (tv_state.txt, tv_prefs.txt, ...)
$log = "$($K.State)\games.log"
function Say($m) { Add-Content $log "$(Get-Date -Format s) [volume] $m" -ErrorAction SilentlyContinue }
Add-Type -AssemblyName System.Windows.Forms
Add-Type -TypeDefinition @'
using System; using System.Runtime.InteropServices; using System.Diagnostics; using System.Threading;

// ---- Windows Core Audio (per-application session volume)
[ComImport, Guid("BCDE0395-E52F-467C-8E3D-C4579291692E")] public class KgMMDevEnum { }
[ComImport, Guid("A95664D2-9614-4F35-A746-DE8DB63617E6"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
public interface IKgMMDevEnum { int EnumAudioEndpoints(int flow, int mask, out IntPtr devs); int GetDefaultAudioEndpoint(int flow, int role, out IKgMMDevice dev); }
[ComImport, Guid("D666063F-1587-4E43-81F1-B948E807363F"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
public interface IKgMMDevice { int Activate(ref Guid iid, int ctx, IntPtr p, [MarshalAs(UnmanagedType.IUnknown)] out object o); }
[ComImport, Guid("77AA99A0-1BD6-484F-8BC7-2C654C9A9B6F"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
public interface IKgSessMgr2 { int GetAudioSessionControl(IntPtr a, int f, out IntPtr c); int GetSimpleAudioVolume(IntPtr a, int f, out IntPtr v); int GetSessionEnumerator(out IKgSessEnum e); }
[ComImport, Guid("E2F5BB11-0570-40CA-ACDD-3AA01277DEE8"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
public interface IKgSessEnum { int GetCount(out int n); int GetSession(int i, out IKgSessCtl2 s); }
[ComImport, Guid("bfb7ff88-7239-4fc9-8fa2-07c950be9c6d"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
public interface IKgSessCtl2 {
  int GetState(out int s); int GetDisplayName([MarshalAs(UnmanagedType.LPWStr)] out string n); int SetDisplayName([MarshalAs(UnmanagedType.LPWStr)] string n, ref Guid c);
  int GetIconPath([MarshalAs(UnmanagedType.LPWStr)] out string p); int SetIconPath([MarshalAs(UnmanagedType.LPWStr)] string p, ref Guid c);
  int GetGroupingParam(out Guid g); int SetGroupingParam(ref Guid g, ref Guid c); int RegisterAudioSessionNotification(IntPtr n); int UnregisterAudioSessionNotification(IntPtr n);
  int GetSessionIdentifier([MarshalAs(UnmanagedType.LPWStr)] out string i); int GetSessionInstanceIdentifier([MarshalAs(UnmanagedType.LPWStr)] out string i);
  int GetProcessId(out uint pid); int IsSystemSoundsSession(); int SetDuckingPreference(bool b); }
[ComImport, Guid("87CE5498-68D6-44E5-9215-6DA47EF883D8"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
public interface IKgSimpleVol { int SetMasterVolume(float v, ref Guid c); int GetMasterVolume(out float v); int SetMute(bool m, ref Guid c); int GetMute(out bool m); }

public static class KgAudio {
  // set volume (0..1) and mute on every audio session of the process; returns how many sessions were found
  public static int Apply(uint pid, float vol, bool mute) {
    int found = 0;
    var en = (IKgMMDevEnum)new KgMMDevEnum(); IKgMMDevice dev; en.GetDefaultAudioEndpoint(0, 1, out dev);   // render, multimedia
    Guid iid = new Guid("77AA99A0-1BD6-484F-8BC7-2C654C9A9B6F"); object o; dev.Activate(ref iid, 23, IntPtr.Zero, out o);
    var mgr = (IKgSessMgr2)o; IKgSessEnum se; mgr.GetSessionEnumerator(out se); int n; se.GetCount(out n);
    for (int i = 0; i < n; i++) {
      IKgSessCtl2 c; se.GetSession(i, out c); uint p; c.GetProcessId(out p);
      if (p == pid) { var sv = (IKgSimpleVol)c; Guid g = Guid.Empty; float cur; sv.GetMasterVolume(out cur); bool cm; sv.GetMute(out cm);
        if (Math.Abs(cur - vol) > 0.004f) sv.SetMasterVolume(vol, ref g); if (cm != mute) sv.SetMute(mute, ref g); found++; }
    }
    return found;
  }
}

// ---- low-level mouse hook: wheel over the game picture changes the TV volume
public static class KgWheel {
  [StructLayout(LayoutKind.Sequential)] struct PT { public int X, Y; }
  [StructLayout(LayoutKind.Sequential)] struct MSLL { public PT pt; public int mouseData, flags, time; public IntPtr extra; }
  delegate IntPtr HookProc(int code, IntPtr w, IntPtr l);
  [DllImport("user32.dll")] static extern IntPtr SetWindowsHookEx(int id, HookProc cb, IntPtr mod, uint tid);
  [DllImport("user32.dll")] static extern bool UnhookWindowsHookEx(IntPtr h);
  [DllImport("user32.dll")] static extern IntPtr CallNextHookEx(IntPtr h, int code, IntPtr w, IntPtr l);
  [DllImport("kernel32.dll")] static extern IntPtr GetModuleHandle(string n);
  static HookProc cb; static IntPtr hook = IntPtr.Zero;
  public static volatile int Left, Top, Right, Bottom;      // the game picture, updated by the script
  static int pending;                                         // wheel notches not yet applied
  public static int TakeNotches() { return Interlocked.Exchange(ref pending, 0); }
  public static void Install() {
    cb = Proc; using (var m = Process.GetCurrentProcess().MainModule) hook = SetWindowsHookEx(14, cb, GetModuleHandle(m.ModuleName), 0);
  }
  public static void Remove() { if (hook != IntPtr.Zero) UnhookWindowsHookEx(hook); hook = IntPtr.Zero; }
  static IntPtr Proc(int code, IntPtr w, IntPtr l) {
    if (code >= 0 && w.ToInt32() == 0x020A) {                 // WM_MOUSEWHEEL
      var s = (MSLL)Marshal.PtrToStructure(l, typeof(MSLL));
      if (s.pt.X >= Left && s.pt.X < Right && s.pt.Y >= Top && s.pt.Y < Bottom) {
        int delta = (short)((s.mouseData >> 16) & 0xFFFF);
        Interlocked.Add(ref pending, delta > 0 ? 1 : -1);
      }
    }
    return CallNextHookEx(hook, code, w, l);
  }
}
'@ -ErrorAction Stop
Add-Type -TypeDefinition 'using System;using System.Runtime.InteropServices;using System.Text;public class KgWin{[DllImport("user32.dll")]public static extern bool SetProcessDPIAware();[DllImport("user32.dll")]public static extern bool GetWindowRect(IntPtr h,out RC r);[StructLayout(LayoutKind.Sequential)]public struct RC{public int L,T,R,B;}}' -ErrorAction SilentlyContinue
[void][KgWin]::SetProcessDPIAware()

$statePath = "$mpv\tv_state.txt"; $prefsPath = "$mpv\tv_prefs.txt"
function Read-Vol { $v = 35; $m = 0
    if (Test-Path $statePath) { $t = Get-Content $statePath -Raw; $a = [regex]::Match($t, 'vol=(\d+)'); if ($a.Success) { $v = [int]$a.Groups[1].Value }; $b = [regex]::Match($t, 'mute=(\d)'); if ($b.Success) { $m = [int]$b.Groups[1].Value } }
    [pscustomobject]@{ Vol = $v; Mute = $m } }
function Write-Vol([int]$v, [int]$m) {
    if (Test-Path $statePath) { $t = Get-Content $statePath -Raw; $t = $t -replace 'vol=\d+', "vol=$v" -replace 'mute=\d', "mute=$m"; Set-Content $statePath $t -NoNewline }
    if (Test-Path $prefsPath) { $t = Get-Content $prefsPath -Raw; $t = $t -replace 'vol=\d+', "vol=$v" -replace 'mute=\d', "mute=$m"; Set-Content $prefsPath $t -NoNewline } }
function Game-Alive { $f = "$mpv\tv_game.flag"; if (-not (Test-Path $f)) { return $false }; $p = 0; [void][int]::TryParse(((Get-Content $f -Raw) + '').Trim(), [ref]$p); return ($p -gt 0 -and [bool](Get-Process -Id $p -ErrorAction SilentlyContinue)) }

[KgWheel]::Install(); Say 'started'
$lastSet = ''; $tick = 0
try {
    while (Game-Alive) {
        [Windows.Forms.Application]::DoEvents()                                            # the mouse hook is serviced by this thread's message loop
        if ($tick % 3 -eq 0) {                                                             # about every 100 ms: wheel notches -> volume
            $n = [KgWheel]::TakeNotches()
            if ($n -ne 0) { $cur = Read-Vol; $nv = [Math]::Max(0, [Math]::Min(100, $cur.Vol + 3 * $n)); Write-Vol $nv 0 }
        }
        if ($tick % 10 -eq 0) {                                                            # about every 330 ms: the game window rect + apply the volume
            $ep = "$mpv\tv_game_emu.pid"
            if (Test-Path $ep) {
                $gp = 0; [void][int]::TryParse(((Get-Content $ep -Raw) + '').Trim(), [ref]$gp)
                $pr = Get-Process -Id $gp -ErrorAction SilentlyContinue
                if ($pr) {
                    $pr.Refresh(); if ($pr.MainWindowHandle -ne [IntPtr]::Zero) { $r = New-Object KgWin+RC; [void][KgWin]::GetWindowRect($pr.MainWindowHandle, [ref]$r); [KgWheel]::Left = $r.L; [KgWheel]::Top = $r.T; [KgWheel]::Right = $r.R; [KgWheel]::Bottom = $r.B }
                    $cur = Read-Vol
                    try { $found = [KgAudio]::Apply([uint32]$gp, [float]($cur.Vol / 100.0), [bool]($cur.Mute -eq 1)); $key = "$($cur.Vol)/$($cur.Mute)/$found"; if ($key -ne $lastSet) { Say "applied volume $($cur.Vol) mute $($cur.Mute) to $found audio session(s) of pid $gp"; $lastSet = $key } }
                    catch { if ($lastSet -ne 'err') { Say "audio error: $($_.Exception.Message)"; $lastSet = 'err' } }
                }
            }
        }
        $tick++; Start-Sleep -Milliseconds 33
    }
}
finally { [KgWheel]::Remove(); Say 'stopped' }
