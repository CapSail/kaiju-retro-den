# Builds the TV's playlist (state\movies_playlist.m3u) from the movies folder chosen in install.ps1.
# Every video file under the folder is listed once, in a fixed "shuffled" order: the order depends only on the file path, so running this again
# (FIX DESKTOP does when the playlist is missing) never reshuffles what is already there, and new files slot in without moving the old ones much.
. (Join-Path (Split-Path $PSScriptRoot -Parent) 'scripts\Kaiju-Config.ps1')
$exts = '.mkv', '.mp4', '.avi', '.m4v', '.mov', '.wmv', '.mpg', '.mpeg', '.ts', '.webm', '.flv'
$out = "$($K.State)\movies_playlist.m3u"
if (-not $K.Movies -or -not (Test-Path $K.Movies)) {
    [IO.File]::WriteAllLines($out, [string[]]@('#EXTM3U'), (New-Object Text.UTF8Encoding($false)))   # empty playlist: the TV starts but has nothing to play until a folder is set
    Write-Host "Movies folder not found: '$($K.Movies)'. Wrote an empty playlist."
    return
}
$sha = [Security.Cryptography.SHA1]::Create()
function Path-Key([string]$p) { [BitConverter]::ToString($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($p.ToLowerInvariant()))) }
$files = Get-ChildItem $K.Movies -Recurse -File -ErrorAction SilentlyContinue | Where-Object { $exts -contains $_.Extension.ToLowerInvariant() }
$sorted = $files | Sort-Object { Path-Key $_.FullName }
$lines = @('#EXTM3U') + ($sorted | ForEach-Object { $_.FullName })
[IO.File]::WriteAllLines($out, [string[]]$lines, (New-Object Text.UTF8Encoding($false)))   # UTF-8 without a BOM (mpv)
Write-Host "Playlist: $(@($sorted).Count) video file(s) -> $out"
