# Opens the KAIJU file cabinet drawer: rebuilds the Cabinet skin from what is in the cabinet folder (plus anything currently on the Desktop and the
# shared Public Desktop) and shows it next to the cabinet prop. Plain-text rows, no icons. 12 items per page, PREV/NEXT when there are more.
#   -Page n       : show page n (the PREV/NEXT rows call this)
#   -NoRainmeter  : only write the skin file (used by tests)
# Env KAIJU_CABINET_ONLY=1 limits the list to the cabinet folder (used by tests).
param([int]$Page = 1, [switch]$NoRainmeter)
. (Join-Path (Split-Path $PSScriptRoot -Parent) 'scripts\Kaiju-Config.ps1')
Add-Type -AssemblyName System.Windows.Forms
Add-Type -TypeDefinition 'using System.Runtime.InteropServices;public class CabDpi{[DllImport("user32.dll")]public static extern bool SetProcessDPIAware();}' -ErrorAction SilentlyContinue
[void][CabDpi]::SetProcessDPIAware()

$perPage = 12; $CW = 240; $RH = 26
$ps = 'powershell.exe -NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File'

# ---- what is in the cabinet
$roots = @()
if ($K.Cabinet -and (Test-Path $K.Cabinet)) { $roots += $K.Cabinet }
if (-not $env:KAIJU_CABINET_ONLY) {
    foreach ($sf in 'Desktop', 'CommonDesktopDirectory') { $d = [Environment]::GetFolderPath($sf); if ($d -and (Test-Path $d)) { $roots += $d } }
}
$items = @()
foreach ($r in $roots) {
    $items += Get-ChildItem $r -Force -ErrorAction SilentlyContinue | Where-Object {
        $_.Name -ne 'desktop.ini' -and (($_.Attributes -band 6) -eq 0) -and ($_.FullName -ne $K.Cabinet) }
}
$items = @($items | Sort-Object @{ Expression = { -not $_.PSIsContainer } }, @{ Expression = { $_.Name } })
$pages = [Math]::Max(1, [int][Math]::Ceiling($items.Count / $perPage))
$Page = [Math]::Min([Math]::Max(1, $Page), $pages)
$shown = @($items | Select-Object -Skip (($Page - 1) * $perPage) -First $perPage)

# the launcher reads this list (by position in the WHOLE list) for names Rainmeter would misread
Set-Content "$($K.State)\cabinet_items.txt" ($items | ForEach-Object { $_.FullName }) -Encoding UTF8

# ---- build the skin
$sb = New-Object Text.StringBuilder
function L([string]$s) { [void]$sb.AppendLine($s) }
function Clean([string]$s) { ($s -replace '#', '' -replace '\[', '(' -replace '\]', ')') }
$close = '[!DeactivateConfig "KaijuHUD\Cabinet"]'
$rows = New-Object Collections.Generic.List[object]       # @{ label; action; align }
if ($items.Count -eq 0) { $rows.Add(@{ label = '(the cabinet is empty)'; action = ''; align = 'Center' }) }
$idx = ($Page - 1) * $perPage
foreach ($it in $shown) {
    $idx++
    $name = if ($it.PSIsContainer) { $it.Name } elseif ($it.Extension -in '.lnk', '.url', '.appref-ms') { $it.BaseName } else { $it.Name }
    $safe = ($it.FullName -notmatch '[#\[\]%]')
    $act = if ($safe) { '["' + $it.FullName + '"]' + $close } else { '["' + $ps.Split(' ')[0] + '" ' + ($ps.Substring($ps.IndexOf(' ') + 1)) + ' "' + "$($K.Scripts)\open_cabinet_item.ps1" + '" -Index ' + $idx + ']' }
    $rows.Add(@{ label = (Clean $name); action = $act; align = 'Left' })
}
$navAt = $rows.Count
$fixed = @(
    @{ label = 'FIX DESKTOP'; action = '["powershell.exe" -NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File "' + "$($K.Scripts)\fix_desktop.ps1" + '"]' + $close },
    @{ label = 'RECYCLE BIN'; action = '["explorer.exe" "shell:RecycleBinFolder"]' + $close },
    @{ label = 'POWER OFF'; action = '["powershell.exe" -NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File "' + "$($K.Scripts)\kaiju_power.ps1" + '" off]' + $close },
    @{ label = 'CLOSE DRAWER'; action = $close })
$y0 = 40
$listH = $rows.Count * $RH
$navH = if ($pages -gt 1) { $RH } else { 0 }
$CH = $y0 + $listH + $navH + 10 + $fixed.Count * $RH + 10

L '[Rainmeter]'; L 'Update=1000'; L 'AccurateText=1'; L '@Include=#@#Theme.inc'; L ''
L '[BG]'; L 'Meter=Shape'
L ('Shape=Rectangle 0,0,' + $CW + ',' + $CH + ',9 | Fill Color #Cream# | StrokeWidth 3 | Stroke Color #WoodEdge#')
L ('Shape2=Rectangle 0,0,' + $CW + ',30,9 | Fill Color #CreamDk# | StrokeWidth 0')
L ('Shape3=Line 4,30,' + ($CW - 4) + ',30 | StrokeWidth 1 | Stroke Color #Ink#,110')
L ('W=' + $CW); L ('H=' + $CH); L ''
L '[Title]'; L 'Meter=String'; L 'Text=KAIJU FILE CABINET'; L 'X=14'; L 'Y=8'; L 'FontFace=#Font#'; L 'FontSize=10'; L 'FontColor=#Ink#'; L 'StringStyle=Bold'; L 'AntiAlias=1'; L ''

$n = 0
function Row([string]$label, [string]$action, [string]$align, [int]$y) {
    $script:n++; $i = $script:n
    $rect = 'Rectangle 10,' + $y + ',' + ($CW - 20) + ',' + ($RH - 4) + ',5'
    L ('[Row' + $i + ']'); L 'Meter=Shape'
    L ('Shape=' + $rect + ' | Fill Color #Bakelite# | StrokeWidth 1 | Stroke Color #WoodEdge#')
    if ($action) {
        L ('LeftMouseUpAction=' + $action)
        L ('MouseOverAction=[!SetOption Row' + $i + ' Shape "' + $rect + ' | Fill Color 90,62,36 | StrokeWidth 1 | Stroke Color #Amber#"][!UpdateMeter Row' + $i + '][!Redraw]')
        L ('MouseLeaveAction=[!SetOption Row' + $i + ' Shape "' + $rect + ' | Fill Color #Bakelite# | StrokeWidth 1 | Stroke Color #WoodEdge#"][!UpdateMeter Row' + $i + '][!Redraw]')
    }
    L ''
    L ('[Lbl' + $i + ']'); L 'Meter=String'; L ('Text=' + $label)
    if ($align -eq 'Left') { L 'X=20'; L ('Y=' + ($y + 5)); L ('W=' + ($CW - 40)); L ('H=' + ($RH - 8)); L 'ClipString=1' }
    else { L ('X=' + [int]($CW / 2)); L ('Y=' + ($y + 5)); L 'StringAlign=Center' }
    L 'FontFace=#Font#'; L 'FontSize=9'; L 'FontColor=#Cream#'; L 'StringStyle=Bold'; L 'AntiAlias=1'; L ''
}
$y = $y0
foreach ($r in $rows) { Row $r.label $r.action $r.align $y; $y += $RH }
if ($pages -gt 1) {
    $prev = if ($Page -gt 1) { '["powershell.exe" -NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File "' + "$($K.Scripts)\open_cabinet.ps1" + '" -Page ' + ($Page - 1) + ']' } else { '' }
    $next = if ($Page -lt $pages) { '["powershell.exe" -NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File "' + "$($K.Scripts)\open_cabinet.ps1" + '" -Page ' + ($Page + 1) + ']' } else { '' }
    Row ('<  PAGE ' + $Page + ' OF ' + $pages + '  >') '' 'Center' $y
    # the two ends of the page row are the PREV and NEXT buttons (transparent hit areas over the row)
    foreach ($b in @(@('Prev', 10, $prev), @('Next', ($CW - 10 - 70), $next))) {
        if ($b[2]) { L ('[Hit' + $b[0] + ']'); L 'Meter=Shape'; L ('Shape=Rectangle ' + $b[1] + ',' + $y + ',70,' + ($RH - 4) + ',5 | Fill Color 0,0,0,1 | StrokeWidth 0'); L ('LeftMouseUpAction=' + $b[2]); L '' }
    }
    $y += $RH
}
$y += 10
foreach ($f in $fixed) { Row $f.label $f.action 'Center' $y; $y += $RH }

$skinDir = "$($K.RainmeterDir)\Skins\KaijuHUD\Cabinet"
New-Item -ItemType Directory -Force $skinDir | Out-Null
[IO.File]::WriteAllText("$skinDir\Cabinet.ini", $sb.ToString(), (New-Object Text.UnicodeEncoding($false, $true)))   # UTF-16 with BOM: Rainmeter reads it, and any language's file names show correctly

if ($NoRainmeter -or -not (Test-Path $K.RainmeterExe) -or -not (Get-Process Rainmeter -ErrorAction SilentlyContinue)) { Write-Host "Cabinet skin written: $($items.Count) item(s), page $Page of $pages, ${CW}x$CH"; return }
# position: the drawer sits just above the cabinet prop (centre cx+400 room units, prop top = floor + 68 - 120 room units), kept on screen
$b = [Windows.Forms.Screen]::PrimaryScreen.Bounds; $s0 = $b.Height / 1080.0
$px = [int]($b.X + $b.Width / 2 + 400 * $s0 - $CW / 2); $px = [Math]::Max($b.X + 8, [Math]::Min($px, $b.X + $b.Width - $CW - 8))
$py = [int]($b.Y + $b.Height * 0.875 + 68 * $s0 - 120 * $s0 - $CH - 10); $py = [Math]::Max($b.Y + 8, $py)
& $K.RainmeterExe '!ActivateConfig' 'KaijuHUD\Cabinet' 'Cabinet.ini'
& $K.RainmeterExe '!Refresh' 'KaijuHUD\Cabinet'
& $K.RainmeterExe '!Move' $px $py 'KaijuHUD\Cabinet'
& $K.RainmeterExe '!ZPos' '1' 'KaijuHUD\Cabinet'            # "on top": the drawer must sit over the other widgets (not topmost, so fullscreen apps still cover it)
