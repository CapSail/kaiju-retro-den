# POWER switch for the whole Kaiju desktop.
#   off : quit the TV, stop the watcher, close the widgets, take the wallpaper down (Wallpaper Engine idles), and bring the normal desktop icons back
#   on  : start Steam + Wallpaper Engine + Rainmeter + the watcher, hide the desktop icons (the cabinet replaces them), apply the room
param([Parameter(Mandatory)][ValidateSet('on', 'off')][string]$State)
. (Join-Path (Split-Path $PSScriptRoot -Parent) 'scripts\Kaiju-Config.ps1')
$st = $K.State
$we = $K.WallpaperEngineDir
function Say($m) { Add-Content "$st\power.log" "$(Get-Date -Format s) $m" -ErrorAction SilentlyContinue }
Add-Type -TypeDefinition @'
using System;using System.Text;using System.Runtime.InteropServices;
public class DeskIcons{public delegate bool CB(IntPtr h,IntPtr l);[DllImport("user32.dll")]static extern bool EnumWindows(CB c,IntPtr l);[DllImport("user32.dll")]static extern IntPtr FindWindowEx(IntPtr p,IntPtr a,string c,string t);[DllImport("user32.dll")]static extern IntPtr SendMessage(IntPtr h,int m,IntPtr w,IntPtr l);[DllImport("user32.dll")]static extern int GetClassName(IntPtr h,StringBuilder s,int n);
public static IntPtr View(){IntPtr r=IntPtr.Zero;EnumWindows((h,l)=>{var s=new StringBuilder(64);GetClassName(h,s,64);string c=s.ToString();if(c=="Progman"||c=="WorkerW"){IntPtr d=FindWindowEx(h,IntPtr.Zero,"SHELLDLL_DefView",null);if(d!=IntPtr.Zero){r=d;return false;}}return true;},IntPtr.Zero);return r;}
public static void Toggle(){IntPtr v=View();if(v!=IntPtr.Zero)SendMessage(v,0x111,(IntPtr)0x7402,IntPtr.Zero);}}
'@
function Set-Icons([bool]$show) {
    $k = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'
    $hidden = ((Get-ItemProperty $k).HideIcons -eq 1)
    if ($hidden -eq $show) { [DeskIcons]::Toggle(); Start-Sleep 1 }          # toggling flips HideIcons itself
}
if ($State -eq 'off') {
    Say 'OFF'
    if (Get-Process mpv -ErrorAction SilentlyContinue) { Set-Content "$st\tv_resume.flag" '1' -NoNewline; Say 'TV was playing: will resume on ON' }   # POWER ON restarts it, same movie and spot (mpv keeps both)
    # a game playing in the TV ends first (its supervisor would otherwise bring the movie back after we quit it)
    $gf = "$st\tv_game.flag"
    if (Test-Path $gf) {
        $gp = 0; [void][int]::TryParse(((Get-Content $gf -Raw) + '').Trim(), [ref]$gp)
        if ($gp -gt 0 -and (Get-Process -Id $gp -ErrorAction SilentlyContinue)) {
            Set-Content "$st\tv_game_stop.flag" '1' -NoNewline; Say 'ending the running game first'
            for ($i = 0; $i -lt 24 -and (Get-Process -Id $gp -ErrorAction SilentlyContinue); $i++) { Start-Sleep -Milliseconds 500 }
            Start-Sleep 2
        }
    }
    & "$($K.Tv)\toggle_tv.ps1" quit
    & "$($K.Games)\shaderglass\tv_overlay.ps1" -Stop        # the CRT filter goes down with the TV
    Stop-KaijuWatcher
    & $K.RainmeterExe '!Quit'; Start-Sleep 2
    Get-Process Rainmeter -ErrorAction SilentlyContinue | Stop-Process -Force
    # Never kill Wallpaper Engine (a kill makes it show its "Safe Start" dialog next time): just take the wallpaper off, it then sits idle
    & "$we\wallpaper64.exe" -control closeWallpaper -monitor 0; Start-Sleep -Milliseconds 700
    Set-Icons $true
    Say 'OFF done'
}
else {
    Say 'ON'
    if (-not (Get-Process steam -ErrorAction SilentlyContinue)) { Start-Process $K.SteamExe -ArgumentList '-silent'; Start-Sleep 15 }
    if (-not (Get-Process Rainmeter -ErrorAction SilentlyContinue)) { Start-Process $K.RainmeterExe; Start-Sleep 3 }
    Start-KaijuWatcher
    & "$($K.Scripts)\apply_all.ps1"                         # starts Wallpaper Engine if needed, applies the room
    & $K.RainmeterExe '!RefreshApp'
    & $K.RainmeterExe '!DeactivateConfig' 'KaijuHUD\Cabinet'   # drawer starts closed
    Set-Icons $false
    if (Test-Path "$st\tv_resume.flag") {                # the TV was playing when powered off: start it again where it stopped
        [IO.File]::Delete("$st\tv_resume.flag"); Start-Sleep 3
        & "$($K.Tv)\toggle_tv.ps1"; Say 'TV resumed'
    }
    Say 'ON done'
}
