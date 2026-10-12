# Opens one item of the file cabinet by its position in the list that open_cabinet.ps1 saved (state\cabinet_items.txt).
# Used for names that Rainmeter would misread inside a skin file (# [ ] %); ordinary names open directly from the drawer.
param([int]$Index)
. (Join-Path (Split-Path $PSScriptRoot -Parent) 'scripts\Kaiju-Config.ps1')
$listFile = "$($K.State)\cabinet_items.txt"
if (Test-Path $listFile) {
    $list = @(Get-Content $listFile -Encoding UTF8)
    if ($Index -ge 1 -and $Index -le $list.Count -and (Test-Path -LiteralPath $list[$Index - 1])) { Start-Process -FilePath $list[$Index - 1] }
}
if (Test-Path $K.RainmeterExe) { & $K.RainmeterExe '!DeactivateConfig' 'KaijuHUD\Cabinet' }     # the drawer closes after an item opens
