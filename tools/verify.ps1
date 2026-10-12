# Repo self-check. Run:  powershell -NoProfile -File tools\verify.ps1
# Reads and generates only inside this repo and a temp folder. Never executes the product scripts.
$root = Split-Path $PSScriptRoot -Parent
$src = Join-Path $root 'src'
$fail = 0
function Bad($m) { $script:fail++; Write-Host "FAIL  $m" -ForegroundColor Red }
function Ok($m) { Write-Host "ok    $m" }

# 1) PowerShell: parses, and ASCII only (Windows PowerShell 5.1 reads BOM-less files as ANSI, so non-ASCII text corrupts)
$ps = @(Get-ChildItem $src -Recurse -Filter *.ps1) + @(Get-ChildItem $root -File -Filter *.ps1) + @(Get-ChildItem $PSScriptRoot -File -Filter *.ps1 | Where-Object { $_.Name -ne 'verify.ps1' })   # product + installers + tools
foreach ($f in $ps) {
    $e = $null; $t = $null; [void][System.Management.Automation.Language.Parser]::ParseFile($f.FullName, [ref]$t, [ref]$e)
    if ($e.Count) { Bad "$($f.Name): $($e[0].Message)" }
    if ([IO.File]::ReadAllBytes($f.FullName) | Where-Object { $_ -gt 127 } | Select-Object -First 1) { Bad "$($f.Name): non-ASCII characters" }
}
Ok "$($ps.Count) PowerShell files parsed"

# 2) Python: valid syntax (no bytecode written)
$py = Get-ChildItem $src -Recurse -Filter *.py
foreach ($f in $py) {
    $r = & python -I -c "import ast,sys; ast.parse(open(sys.argv[1],encoding='utf-8-sig').read())" $f.FullName 2>&1
    if ($LASTEXITCODE -ne 0) { Bad "$($f.Name): $r" }
}
Ok "$($py.Count) Python files checked"

# 3) stray control characters (a '\t' or '\f' inside a Windows path in a normal string silently becomes a tab / form feed)
$all = Get-ChildItem $src -Recurse -File | Where-Object { $_.Extension -in '.ps1', '.py', '.lua', '.ini', '.inc', '.json', '.conf', '.sgp', '.html', '.js' }
foreach ($f in $all) {
    $txt = [IO.File]::ReadAllText($f.FullName)
    if ($txt -match '[\x00-\x08\x0b\x0c\x0e-\x1f]') { Bad "$($f.Name): control character" }
    if ($f.Extension -in '.ps1', '.py') { foreach ($m in [regex]::Matches($txt, '"[^"\r\n]*\t[^"\r\n]*"|''[^''\r\n]*\t[^''\r\n]*''')) { Bad "$($f.Name): TAB inside a quoted string near: $($m.Value.Substring(0, [Math]::Min(60, $m.Value.Length)))" } }
}
Ok "$($all.Count) files scanned for control characters"

# 4) generate every skin into a fake install and check each script a skin can launch exists in the repo layout
$tmp = Join-Path ([IO.Path]::GetTempPath()) ('kaiju_verify_' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory $tmp | Out-Null
$env:KAIJU_ROOT = $tmp; $env:PYTHONDONTWRITEBYTECODE = '1'
foreach ($g in 'make_scene.py', 'make_remote.py', 'make_console.py') { & python -I -B (Join-Path $src "tv\$g") | Out-Null; if ($LASTEXITCODE -ne 0) { Bad "generator $g failed" } }
$skins = Join-Path $tmp 'tools\Rainmeter\Skins\KaijuHUD'
$refs = Get-ChildItem $skins -Recurse -Filter *.ini | ForEach-Object { [regex]::Matches((Get-Content $_.FullName -Raw), [regex]::Escape($tmp) + '\\([^"]+?\.ps1)') } | ForEach-Object { $_.Groups[1].Value } | Sort-Object -Unique
foreach ($r in $refs) { if (-not (Test-Path (Join-Path $src $r))) { Bad "a skin launches '$r' but it is not in src" } }
Ok "$(@($refs).Count) distinct scripts launched by skins all exist: $($refs -join ', ')"
try { Remove-Item $tmp -Recurse -Force -ErrorAction Stop } catch {}; Remove-Item Env:KAIJU_ROOT -ErrorAction SilentlyContinue

# 5) personal data / machine paths
& powershell -NoProfile -File (Join-Path $PSScriptRoot 'grep_gate.ps1') | Select-Object -Last 1 | ForEach-Object { if ($_ -eq 'CLEAN') { Ok 'grep gate CLEAN' } else { Write-Host "todo  grep gate: $_" -ForegroundColor Yellow } }

if ($fail) { Write-Host "`n$fail FAILURE(s)" -ForegroundColor Red; exit 1 } else { Write-Host "`nALL CHECKS PASSED (grep gate may still list work to do)" -ForegroundColor Green }
