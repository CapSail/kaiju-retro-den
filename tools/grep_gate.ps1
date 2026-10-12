# Fails (exit 1) if machine-specific paths or personal strings remain in the repo files.
# Run from anywhere: powershell -File tools\grep_gate.ps1
# Generic patterns are built in. Add your own strings (names, usernames, e-mail fragments), one regex per line, to tools\grep_gate_patterns.local.txt
# (that file is git-ignored on purpose: it is never published).
$root = Split-Path $PSScriptRoot -Parent
$pat = '(?<![A-Za-z])[A-Z]:\\(?![nrt])|OneDrive|[/\\]Users[/\\][A-Za-z0-9_.-]+'          # a drive path like C:\..., a cloud-synced folder, a user-profile path (not "in:\n" text or HKCU:\ registry paths)
$local = Join-Path $PSScriptRoot 'grep_gate_patterns.local.txt'
if (Test-Path $local) { $extra = @(Get-Content $local | Where-Object { $_.Trim() -and -not $_.StartsWith('#') }); if ($extra.Count) { $pat = $pat + '|' + ($extra -join '|') } }
$skip = '\\(\.git|tools|__pycache__)\\|PLAN\.md$|WORKLOG\.md$|config\.example\.json$|TESTER-CHECKLIST\.md$'
$hits = Get-ChildItem $root -Recurse -File | Where-Object { $_.FullName -notmatch $skip -and $_.Extension -notin '.jpg', '.png' } |
    Select-String -Pattern $pat -CaseSensitive:$false
$hits | ForEach-Object { '{0}:{1}: {2}' -f $_.Path.Replace($root, '.'), $_.LineNumber, $_.Line.Trim().Substring(0, [Math]::Min(110, $_.Line.Trim().Length)) }
$files = ($hits | Select-Object -ExpandProperty Path -Unique).Count
"`n$($hits.Count) hit(s) in $files file(s)"
if ($hits) { exit 1 } else { 'CLEAN' }
