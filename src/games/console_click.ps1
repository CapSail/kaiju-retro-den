# What a click on the KAIJU SYSTEMS console does:
#   a game is playing inside the TV  -> stop it (tv_game.ps1 then brings the movie back where it left off)
#   otherwise                        -> open the KAIJU GAME GUIDE
. (Join-Path (Split-Path $PSScriptRoot -Parent) 'scripts\Kaiju-Config.ps1')
$flag = "$($K.State)\tv_game.flag"
$stop = "$($K.State)\tv_game_stop.flag"
$running = $false
if (Test-Path $flag) {
    $p = 0; [void][int]::TryParse(((Get-Content $flag -Raw) + '').Trim(), [ref]$p)
    if ($p -gt 0 -and (Get-Process -Id $p -ErrorAction SilentlyContinue)) { $running = $true }
}
if ($running) { Set-Content $stop '1' -NoNewline }
else { Start-Process (Join-Path (Split-Path $K.Python -Parent) 'pythonw.exe') -ArgumentList """$($K.Games)\kaiju_games.py""" }
