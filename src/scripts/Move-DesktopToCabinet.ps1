# Moves the user's own Desktop items into the cabinet folder, and can put every one of them back.
#   (no switch) : PREVIEW only. Lists what would move. Changes nothing.
#   -Move       : moves the items into the cabinet folder and records each move in state\cabinet_manifest.json AS IT HAPPENS
#   -Restore    : puts every recorded item back where it came from (newest move first), then removes it from the manifest
#   -DesktopDir : test hook, use another folder instead of the real Desktop
# Safety: nothing is ever deleted or overwritten. A name clash gets " (2)" added. Hidden/system files (desktop.ini), the cabinet folder itself and
# Kaiju's own shortcuts stay where they are. The shared Public Desktop is not touched (that needs admin rights); the drawer still lists it.
param([switch]$Move, [switch]$Restore, [string]$DesktopDir)
. (Join-Path (Split-Path $PSScriptRoot -Parent) 'scripts\Kaiju-Config.ps1')
$desk = if ($DesktopDir) { $DesktopDir } else { [Environment]::GetFolderPath('Desktop') }       # follows a Desktop that Windows redirected to a cloud folder
$cab = $K.Cabinet
$manifestFile = "$($K.State)\cabinet_manifest.json"
function Load-Manifest {
    if (-not (Test-Path $manifestFile)) { return @() }
    $raw = (Get-Content $manifestFile -Raw -Encoding UTF8)
    if (-not $raw -or -not $raw.Trim()) { return @() }
    # Windows PowerShell 5.1 hands a JSON array back as ONE object; foreach unrolls it into the real entries
    return @(foreach ($x in (ConvertFrom-Json $raw)) { $x })
}
function Save-Manifest($list) {
    $json = if (@($list).Count) { ConvertTo-Json -InputObject @($list) -Depth 4 } else { '[]' }
    [IO.File]::WriteAllText($manifestFile, $json, (New-Object Text.UTF8Encoding($false)))
}
function Free-Name([string]$dir, [string]$name) {                    # a name that does not exist yet in $dir: "a.txt" -> "a (2).txt"
    $target = Join-Path $dir $name; if (-not (Test-Path -LiteralPath $target)) { return $target }
    $base = [IO.Path]::GetFileNameWithoutExtension($name); $ext = [IO.Path]::GetExtension($name)
    for ($i = 2; $i -lt 1000; $i++) { $t = Join-Path $dir "$base ($i)$ext"; if (-not (Test-Path -LiteralPath $t)) { return $t } }
    throw "no free name for $name in $dir"
}

if ($Restore) {
    $list = @(Load-Manifest)
    if (-not $list.Count) { Write-Host 'Nothing to put back: the manifest is empty.'; return }
    $kept = @()
    for ($i = $list.Count - 1; $i -ge 0; $i--) {
        $e = $list[$i]
        if (-not (Test-Path -LiteralPath $e.moved)) { Write-Host "skipped (no longer in the cabinet): $($e.name)"; continue }            # the user already moved or removed it: nothing to restore
        $origDir = Split-Path $e.original -Parent
        if (-not (Test-Path -LiteralPath $origDir)) { Write-Host "kept in the cabinet (original folder is gone): $($e.name)"; $kept += $e; continue }
        $dest = Free-Name $origDir (Split-Path $e.original -Leaf)
        try {
            Move-Item -LiteralPath $e.moved -Destination $dest -ErrorAction Stop
            Write-Host ("restored: {0}{1}" -f (Split-Path $dest -Leaf), $(if ($dest -ne $e.original) { '   (original name was taken)' } else { '' }))
        }
        catch { Write-Host "could not restore '$($e.name)': $($_.Exception.Message) (kept in the manifest, try again)"; $kept += $e }     # a failed restore is never forgotten
    }
    Save-Manifest @($kept | Sort-Object when)
    return
}

if (-not (Test-Path -LiteralPath $desk)) { Write-Host "Desktop folder not found: $desk"; return }
$cabFull = if ($cab) { [IO.Path]::GetFullPath($cab).TrimEnd('\') } else { '' }
$items = @(Get-ChildItem -LiteralPath $desk -Force -ErrorAction SilentlyContinue | Where-Object {
        $_.Name -ne 'desktop.ini' -and (($_.Attributes -band 6) -eq 0) -and ($_.Name -notlike 'Kaiju *') -and ($_.FullName.TrimEnd('\') -ne $cabFull) })
if (-not $Move) {
    Write-Host "PREVIEW: $($items.Count) item(s) on the Desktop would move into: $cab"
    $items | ForEach-Object { Write-Host "  $($_.Name)" }
    return
}
if (-not $cab) { throw 'No cabinet folder is set in config.json (cabinet_dir).' }
New-Item -ItemType Directory -Force $cab | Out-Null
$manifest = @(Load-Manifest)
$moved = 0
foreach ($it in $items) {
    $dest = Free-Name $cab $it.Name
    try {
        Move-Item -LiteralPath $it.FullName -Destination $dest -ErrorAction Stop
        $manifest += [pscustomobject]@{ name = $it.Name; original = $it.FullName; moved = $dest; when = (Get-Date -Format s) }
        Save-Manifest $manifest                                                    # written after EVERY move, so a crash half-way is still undoable
        $moved++
    }
    catch { Write-Host "could not move '$($it.Name)': $($_.Exception.Message)" }     # e.g. a file in use: it simply stays on the Desktop
}
Write-Host "Moved $moved of $($items.Count) item(s) into $cab. Undo any time with:  Move-DesktopToCabinet.ps1 -Restore"
