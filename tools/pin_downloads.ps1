# Maintainer tool: fills in (or checks) the SHA-256 of every download in downloads.json.
#   (no switch) : for each item that has a url but no sha256, download it to a temp folder, hash it, write the hash into downloads.json
#   -Verify     : download every item again and check it still matches the pinned hash (run before a release)
# Downloads files from the urls in downloads.json. Run it yourself, on purpose. The installer never runs this.
param([switch]$Verify)
$ErrorActionPreference = 'Stop'
$file = Join-Path (Split-Path $PSScriptRoot -Parent) 'downloads.json'
$m = Get-Content $file -Raw | ConvertFrom-Json
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$tmp = Join-Path ([IO.Path]::GetTempPath()) ('kaiju_pin_' + [guid]::NewGuid().ToString('N')); New-Item -ItemType Directory $tmp | Out-Null
$bad = 0
foreach ($it in $m.items) {
    if (-not $it.url) { Write-Host "skip  $($it.id): no url yet"; continue }
    if (-not $Verify -and $it.sha256) { Write-Host "ok    $($it.id): already pinned"; continue }
    $f = Join-Path $tmp ([IO.Path]::GetFileName(([Uri]$it.url).AbsolutePath))
    Write-Host "get   $($it.id): $($it.url)"
    Invoke-WebRequest -Uri $it.url -OutFile $f -UseBasicParsing
    $h = (Get-FileHash $f -Algorithm SHA256).Hash.ToLower(); $mb = [Math]::Round((Get-Item $f).Length / 1MB, 1)
    if ($Verify) { if ($h -eq $it.sha256.ToLower()) { Write-Host "ok    $($it.id): matches ($mb MB)" } else { Write-Host "FAIL  $($it.id): hash changed! pinned $($it.sha256) now $h" -ForegroundColor Red; $bad++ } }
    else { $it.sha256 = $h; $it.size_mb = [Math]::Max(1, [int][Math]::Ceiling($mb)); Write-Host "pin   $($it.id): $h ($mb MB)" }
}
if (-not $Verify) { [IO.File]::WriteAllText($file, ($m | ConvertTo-Json -Depth 6), (New-Object Text.UTF8Encoding($false))) }
try { Remove-Item $tmp -Recurse -Force -ErrorAction Stop } catch {}
if ($bad) { exit 1 }
