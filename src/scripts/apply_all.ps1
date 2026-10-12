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
    & $rm '!WriteKeyValue' 'KaijuHUD\TVRemote' 'AlwaysOnTop' '-2' $ini         # desktop level: the TV player sits UNDER the frame and shows through its window
    & $rm '!WriteKeyValue' 'KaijuHUD\TVRemote' 'Draggable' '0' $ini
    # the click layer over the whole wallpaper, and the wall-mounted gauge panel at the top right (372 wide, 24 px from the edge)
    & $rm '!WriteKeyValue' 'KaijuHUD\Scene' 'WindowX' '0' $ini
    & $rm '!WriteKeyValue' 'KaijuHUD\Scene' 'WindowY' '0' $ini
    & $rm '!WriteKeyValue' 'KaijuHUD\Scene' 'AlwaysOnTop' '-2' $ini
    & $rm '!WriteKeyValue' 'KaijuHUD\Scene' 'Draggable' '0' $ini
    & $rm '!WriteKeyValue' 'KaijuHUD\Systems' 'WindowX' '(#SCREENAREAWIDTH#-392)' $ini
    & $rm '!WriteKeyValue' 'KaijuHUD\Systems' 'WindowY' '24' $ini
    & $rm '!WriteKeyValue' 'KaijuHUD\Systems' 'AlwaysOnTop' '-2' $ini
    & $rm '!WriteKeyValue' 'KaijuHUD\Systems' 'Draggable' '0' $ini
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
