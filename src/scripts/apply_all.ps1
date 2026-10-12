# Put the Retro Den wallpaper on the primary screen (Wallpaper Engine slot 0) and put the TV and the game console on the TV stand.
# One room, one screen: other monitors are left alone.
. (Join-Path (Split-Path $PSScriptRoot -Parent) 'scripts\Kaiju-Config.ps1')
$we = $K.WallpaperEngineDir
if (-not (Get-Process steam -ErrorAction SilentlyContinue)) { Start-Process $K.SteamExe -ArgumentList '-silent'; Start-Sleep 20 }
if (-not (Get-Process wallpaper64 -ErrorAction SilentlyContinue)) { Start-Process "$we\wallpaper64.exe" -ArgumentList '-silent'; Start-Sleep 10 }
& "$we\wallpaper64.exe" -control openWallpaper -file "$($K.WallpaperProject)\project.json" -monitor 0; Start-Sleep 2

# TV remote skin position (Rainmeter expressions, room units = screen height / 1080): the TV stands on the credenza at the left of the room
$rm = $K.RainmeterExe; $ini = "$($K.RainmeterDir)\Rainmeter.ini"
$x = '(#SCREENAREAWIDTH#/2-700*#SCREENAREAHEIGHT#/1080-226)'; $y = '(#SCREENAREAHEIGHT#*0.875-42*#SCREENAREAHEIGHT#/1080-357)'
if (Get-Process Rainmeter -ErrorAction SilentlyContinue) {
    & $rm '!WriteKeyValue' 'KaijuHUD\TVRemote' 'WindowX' $x $ini
    & $rm '!WriteKeyValue' 'KaijuHUD\TVRemote' 'WindowY' $y $ini
    & $rm '!Refresh' 'KaijuHUD\TVRemote'
    # KAIJU SYSTEMS console (150x80 skin, body on its bottom edge): on top of the TV, right of the antennas
    $cx = '(#SCREENAREAWIDTH#/2-700*#SCREENAREAHEIGHT#/1080+150-75)'; $cy = '(#SCREENAREAHEIGHT#*0.875-42*#SCREENAREAHEIGHT#/1080-357+56-78)'
    & $rm '!WriteKeyValue' 'KaijuHUD\Console' 'WindowX' $cx $ini
    & $rm '!WriteKeyValue' 'KaijuHUD\Console' 'WindowY' $cy $ini
    & $rm '!WriteKeyValue' 'KaijuHUD\Console' 'AlwaysOnTop' '-2' $ini
    & $rm '!WriteKeyValue' 'KaijuHUD\Console' 'Draggable' '0' $ini
    & $rm '!ActivateConfig' 'KaijuHUD\Console' 'Console.ini'
    & $rm '!Refresh' 'KaijuHUD\Console'
}
Add-Content "$($K.State)\apply_all.log" "$(Get-Date -Format s) applied" -ErrorAction SilentlyContinue
