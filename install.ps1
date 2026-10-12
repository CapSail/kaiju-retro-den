# KAIJU Retro Den installer.   Run:  powershell -ExecutionPolicy Bypass -File install.ps1
#   -DryRun            show every step and change NOTHING
#   -Answers file.json answer the questions from a file (keys = the names in config.example.json, plus install_dir, accept_downloads, move_desktop, autostart)
#   -SkipDownloads     do not fetch mpv / Rainmeter / ShaderGlass / emulators (you put them in <install>\tools yourself)
#   -SkipSystem        do not touch Windows: no wallpaper copy into Wallpaper Engine, scheduled task, shortcuts, desktop move or start-up
#   -InstallDir path   where to install (default: %LOCALAPPDATA%\KaijuRetroDen)
# No admin rights are needed. Nothing is deleted. Safe to run again to repair or update.
param([switch]$DryRun, [string]$Answers, [switch]$SkipDownloads, [switch]$SkipSystem, [string]$InstallDir)
$ErrorActionPreference = 'Stop'
$repo = $PSScriptRoot
$srcDir = Join-Path $repo 'src'
$ans = $null; if ($Answers) { $ans = Get-Content $Answers -Raw | ConvertFrom-Json }
$script:logFile = $null
function Say([string]$m, [string]$color = 'Gray') { Write-Host $m -ForegroundColor $color; if ($script:logFile) { Add-Content $script:logFile "$(Get-Date -Format s) $m" -ErrorAction SilentlyContinue } }
function Step([string]$text, [scriptblock]$do) { Say "  - $text"; if (-not $DryRun) { & $do } }
function Fail([string]$m) { Say "`nSTOPPED: $m" 'Red'; exit 1 }
function Ask([string]$key, [string]$prompt, [string]$default) {
    if ($ans -and $ans.PSObject.Properties[$key]) { return [string]$ans.$key }
    $r = Read-Host "$prompt [$default]"; if ([string]::IsNullOrWhiteSpace($r)) { return $default } else { return $r.Trim().Trim('"') }
}
function AskYN([string]$key, [string]$prompt, [bool]$default) {
    if ($ans -and $ans.PSObject.Properties[$key]) { return [bool]$ans.$key }
    $d = if ($default) { 'Y/n' } else { 'y/N' }
    $r = Read-Host "$prompt [$d]"; if ([string]::IsNullOrWhiteSpace($r)) { return $default } else { return $r.Trim().ToLower().StartsWith('y') }
}

Say "`nKAIJU RETRO DEN installer$(if ($DryRun) { '  (DRY RUN: nothing will be changed)' })`n" 'Cyan'

# ============================================================ 1) preflight
if ([Environment]::OSVersion.Version.Major -lt 10) { Fail 'Windows 10 or 11 is required.' }
if ($PSVersionTable.PSVersion.Major -lt 5) { Fail 'Windows PowerShell 5.1 or newer is required.' }
if (-not (Test-Path $srcDir)) { Fail "The 'src' folder is missing next to install.ps1 ($srcDir). Download the whole repository." }

function Find-Steam {
    $p = (Get-ItemProperty 'HKCU:\Software\Valve\Steam' -ErrorAction SilentlyContinue).SteamPath
    if ($p) { $p = $p -replace '/', '\'; if (Test-Path "$p\steam.exe") { return $p } }
    foreach ($c in "${env:ProgramFiles(x86)}\Steam", "$env:ProgramFiles\Steam") { if (Test-Path "$c\steam.exe") { return $c } }
}
function Find-WallpaperEngine([string]$steam) {
    $libs = @($steam)
    $vdf = "$steam\steamapps\libraryfolders.vdf"
    if (Test-Path $vdf) { foreach ($m in [regex]::Matches((Get-Content $vdf -Raw), '"path"\s+"([^"]+)"')) { $libs += ($m.Groups[1].Value -replace '\\\\', '\') } }
    foreach ($l in $libs) { $w = "$l\steamapps\common\wallpaper_engine"; if (Test-Path "$w\wallpaper64.exe") { return $w } }
}
$steam = Find-Steam
$we = if ($steam) { Find-WallpaperEngine $steam }
if (-not $we) {
    $guess = Ask 'wallpaper_engine_dir' 'Wallpaper Engine was not found automatically. Its folder (contains wallpaper64.exe), or press Enter to stop' ''
    if ($guess -and (Test-Path "$guess\wallpaper64.exe")) { $we = $guess } else { Fail "Wallpaper Engine is required (it is a paid Steam app, about 4 USD): https://store.steampowered.com/app/431960/Wallpaper_Engine/ . Install it, start it once, then run this installer again." }
}
if (-not $steam) { $steam = (Split-Path (Split-Path (Split-Path $we -Parent) -Parent) -Parent) }
Say "Wallpaper Engine: $we" 'Green'

function Test-Tk([string]$py) { if (-not $py -or -not (Test-Path $py)) { return $false }; & $py -c 'import tkinter' 2>$null; return ($LASTEXITCODE -eq 0) }
function Find-Python {
    $c = @()
    $cmd = Get-Command python -ErrorAction SilentlyContinue; if ($cmd) { $c += $cmd.Source }
    $c += @(Get-ChildItem "$env:LOCALAPPDATA\Programs\Python\Python3*\python.exe", "$env:ProgramFiles\Python3*\python.exe" -ErrorAction SilentlyContinue | Sort-Object FullName -Descending | ForEach-Object { $_.FullName })
    foreach ($p in $c) { if (Test-Tk $p) { return $p } }
}
$python = Find-Python
if (-not $python) {
    Say 'Python 3 (with tkinter) was not found. The game list needs it.' 'Yellow'
    if (AskYN 'install_python' 'Install Python 3.11 now with winget?' $true) {
        if ($DryRun) { Say '  - (dry run) would run: winget install -e --id Python.Python.3.11' }
        else { & winget install -e --id Python.Python.3.11 --accept-package-agreements --accept-source-agreements; $python = Find-Python }
    }
    if (-not $python -and -not $DryRun) { Fail 'Python 3 with tkinter is required. Install it from https://www.python.org/downloads/ (keep "tcl/tk" ticked) and run this installer again.' }
}
Say "Python: $(if ($python) { $python } else { '(would be installed)' })" 'Green'

# ============================================================ 2) questions
Say "`nA few questions (press Enter to accept the suggestion)." 'Cyan'
$docs = [Environment]::GetFolderPath('MyDocuments')
$install = if ($InstallDir) { $InstallDir } else { Ask 'install_dir' 'Install folder' "$env:LOCALAPPDATA\KaijuRetroDen" }
$plaqueRaw = Ask 'plaque_text' 'Who or what is the brass plaque dedicated to?' 'KAIJU'
$plaque = ((($plaqueRaw -replace '[^\w \-\.&!]', '' -replace '\s+', ' ').Trim()).ToUpper()); if (-not $plaque) { $plaque = 'KAIJU' }; if ($plaque.Length -gt 28) { $plaque = $plaque.Substring(0, 28) }
$music = (Ask 'music_player' 'Music on the record player: itunes or spotify?' 'itunes').ToLower(); if ($music -notin 'itunes', 'spotify') { $music = 'itunes' }
$movies = Ask 'movies_dir' 'Folder with the movies for the TV' ([Environment]::GetFolderPath('MyVideos'))
$snes = Ask 'snes_rom_dir' 'Folder with your SNES games (ROMs)' "$docs\Kaiju ROMs\SNES"
$gc = Ask 'gamecube_wii_rom_dir' 'Folder with your GameCube / Wii games' "$docs\Kaiju ROMs\GameCube-Wii"
$cabinet = Ask 'cabinet_dir' 'Folder that becomes the file cabinet' "$docs\Kaiju Cabinet"
$autostart = AskYN 'autostart' 'Start the room automatically when you sign in?' $true

# ============================================================ 3) downloads
$manifest = Get-Content (Join-Path $repo 'downloads.json') -Raw | ConvertFrom-Json
$todo = @()
if (-not $SkipDownloads) {
    foreach ($it in $manifest.items) {
        if (Test-Path (Join-Path $install "$($it.extract_to)\$($it.expect)")) { continue }              # already there (re-run)
        if (-not $it.url -or -not $it.sha256) { Fail "'$($it.name)' is not pinned yet in downloads.json (no url/sha256). This is a development build: run tools\pin_downloads.ps1, or use -SkipDownloads and put the tool into $install\tools yourself." }
        $todo += $it
    }
    if ($todo.Count) {
        Say "`nThese will be downloaded from their official pages (each file is checked against a fixed SHA-256 before it is used):" 'Cyan'
        $todo | ForEach-Object { Say ("  {0,-44} ~{1,3} MB   {2}" -f $_.name, $_.size_mb, $_.url) }
        if (-not (AskYN 'accept_downloads' 'Download and install these now?' $true)) { Fail 'Downloads declined. Run again with -SkipDownloads if you already have the tools.' }
    }
}
$moveDesktop = $false
if (-not $SkipSystem) {
    $moveDesktop = AskYN 'move_desktop' "Move the items on your Desktop into the file cabinet ($cabinet)? You can undo this with uninstall.ps1, nothing is deleted" $true
}

# ============================================================ 4) install
Say "`nInstalling into $install" 'Cyan'
if (-not $DryRun) { New-Item -ItemType Directory -Force $install | Out-Null; $script:logFile = "$install\install.log" }
Step 'copy the program files' { Copy-Item "$srcDir\*" -Destination $install -Recurse -Force }
Step 'create the folders (state, tools, cabinet, ROMs)' { foreach ($d in "$install\state", "$install\tools", $cabinet, $snes, $gc) { New-Item -ItemType Directory -Force $d | Out-Null } }
$cfg = [ordered]@{ plaque_text = $plaque; music_player = $music; movies_dir = $movies; snes_rom_dir = $snes; gamecube_wii_rom_dir = $gc; cabinet_dir = $cabinet
                   wallpaper_engine_dir = $we; steam_exe = "$steam\steam.exe"; python_exe = $python }
Step 'write config.json' { [IO.File]::WriteAllText("$install\config.json", ($cfg | ConvertTo-Json), (New-Object Text.UTF8Encoding($false))) }

function Get-Sha([string]$f) { (Get-FileHash $f -Algorithm SHA256).Hash.ToLower() }
function Expand-Item($it, [string]$file) {
    $dest = Join-Path $install $it.extract_to
    New-Item -ItemType Directory -Force $dest | Out-Null
    switch ($it.kind) {
        'zip' { Expand-Archive -LiteralPath $file -DestinationPath $dest -Force }
        '7z' { $z = "$install\tools\_dl\7zr.exe"; if (-not (Test-Path $z)) { throw '7zr.exe is needed to unpack this archive' }; & $z x "-o$dest" -y $file | Out-Null; if ($LASTEXITCODE -ne 0) { throw "7zr failed ($LASTEXITCODE)" } }
        'exe' { Copy-Item $file "$dest\$($it.expect)" -Force }
        'rainmeter' { Start-Process -FilePath $file -ArgumentList '/S', '/PORTABLE=1', "/D=$dest" -Wait }       # NSIS: /D must be last
    }
    $kids = @(Get-ChildItem $dest -Force)
    if ($kids.Count -eq 1 -and $kids[0].PSIsContainer) {                                                      # archives that wrap everything in one folder: lift it up
        foreach ($k in Get-ChildItem $kids[0].FullName -Force) { Move-Item -LiteralPath $k.FullName -Destination $dest -Force }
        Remove-Item -LiteralPath $kids[0].FullName -Force
    }
    if (-not (Test-Path (Join-Path $dest $it.expect))) { throw "$($it.name): '$($it.expect)' not found after unpacking" }
}
if ($todo.Count) {
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    $order = @($todo | Sort-Object { if ($_.id -eq '7zr') { 0 } else { 1 } })
    foreach ($it in $order) {
        Step "download + verify + unpack $($it.name)" {
            $dl = "$install\tools\_dl"; New-Item -ItemType Directory -Force $dl | Out-Null
            $f = Join-Path $dl ([IO.Path]::GetFileName(([Uri]$it.url).AbsolutePath))
            Invoke-WebRequest -Uri $it.url -OutFile $f -UseBasicParsing
            if ((Get-Sha $f) -ne $it.sha256.ToLower()) { Remove-Item $f -Force; throw "$($it.name): the downloaded file does not match its fixed SHA-256, it was discarded. Not installing it." }
            Expand-Item $it $f
        }
    }
}
Step 'mpv settings and scripts' {
    $pc = "$install\tools\mpv\portable_config"; New-Item -ItemType Directory -Force "$pc\scripts" | Out-Null
    Copy-Item "$install\tv\mpv.conf", "$install\tv\input.conf" $pc -Force; Copy-Item "$install\tv\tvstate.lua", "$install\tv\tvhover.lua" "$pc\scripts" -Force }
Step 'Rainmeter theme' { $r = "$install\tools\Rainmeter\Skins\KaijuHUD\@Resources"; New-Item -ItemType Directory -Force $r | Out-Null; Copy-Item "$install\rainmeter\KaijuHUD\@Resources\Theme.inc" $r -Force }
Step 'state files and the movie playlist' {
    if (-not (Test-Path "$install\state\tv_state.txt")) { [IO.File]::WriteAllText("$install\state\tv_state.txt", 'vol=35;mute=0;pause=0;subs=1;run=0;hid=0;title=') }
    if (-not (Test-Path "$install\state\tv_game_state.txt")) { [IO.File]::WriteAllText("$install\state\tv_game_state.txt", '0') }
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$install\tv\make_playlist.ps1" | Out-Null }
Step 'plaque text into the wallpaper' {
    $f = "$install\wallpaper\index.html"; $t = [IO.File]::ReadAllText($f)
    $t2 = [regex]::Replace($t, "(?m)^const PLAQUE='[^']*';", { param($m) "const PLAQUE='$plaque';" })
    if ($t2 -eq $t -and $t -notmatch "const PLAQUE='$([regex]::Escape($plaque))';") { throw 'could not find the PLAQUE line in the wallpaper' }
    [IO.File]::WriteAllText($f, $t2, (New-Object Text.UTF8Encoding($false))) }
if ($python) {
    Step 'draw the widgets (Rainmeter skins) and the cabinet drawer' {
        foreach ($g in 'make_scene.py', 'make_remote.py', 'make_console.py') { & $python -I -B "$install\tv\$g" | Out-Null; if ($LASTEXITCODE -ne 0) { throw "$g failed" } }
        & powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$install\scripts\open_cabinet.ps1" -NoRainmeter | Out-Null }
}

# ============================================================ 5) Windows integration
if ($SkipSystem) { Say "`n(-SkipSystem: Wallpaper Engine, task, shortcuts, desktop and start-up were left alone)" 'Yellow' }
else {
    Say "`nConnecting to Windows" 'Cyan'
    Step 'put the wallpaper into Wallpaper Engine' { $wp = "$we\projects\myprojects\kaiju_retro_den"; New-Item -ItemType Directory -Force $wp | Out-Null; Copy-Item "$install\wallpaper\*" $wp -Recurse -Force }
    Step 'register the background watcher (scheduled task, runs at sign-in)' {
        try {
            $act = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument "-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$install\autopause\autopause.ps1`""
            $trg = New-ScheduledTaskTrigger -AtLogOn -User "$env:USERDOMAIN\$env:USERNAME"
            $set = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -RestartCount 3 -RestartInterval (New-TimeSpan -Minutes 1) -ExecutionTimeLimit ([TimeSpan]::Zero) -MultipleInstances IgnoreNew
            Register-ScheduledTask -TaskName KaijuAutopause -Action $act -Trigger $trg -Settings $set -Force | Out-Null
        } catch { Say "    (a scheduled task was not allowed: $($_.Exception.Message). The watcher will be started directly instead.)" 'Yellow' } }
    function New-Shortcut([string]$lnk, [string]$arg) {
        $w = New-Object -ComObject WScript.Shell; $s = $w.CreateShortcut($lnk)
        $s.TargetPath = 'powershell.exe'; $s.Arguments = "-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$arg"; $s.WorkingDirectory = $install; $s.Save() }
    Step 'shortcuts: Start menu (POWER ON, POWER OFF, FIX DESKTOP) and a Desktop "Kaiju POWER ON"' {
        $sm = "$([Environment]::GetFolderPath('Programs'))\Kaiju Retro Den"; New-Item -ItemType Directory -Force $sm | Out-Null
        New-Shortcut "$sm\Kaiju POWER ON.lnk" "$install\scripts\kaiju_power.ps1`" on"; New-Shortcut "$sm\Kaiju POWER OFF.lnk" "$install\scripts\kaiju_power.ps1`" off"
        New-Shortcut "$sm\Kaiju FIX DESKTOP.lnk" "$install\scripts\fix_desktop.ps1`""
        New-Shortcut "$([Environment]::GetFolderPath('Desktop'))\Kaiju POWER ON.lnk" "$install\scripts\kaiju_power.ps1`" on" }
    if ($autostart) { Step 'start the room at sign-in (Startup folder)' { New-Shortcut "$([Environment]::GetFolderPath('Startup'))\Kaiju POWER ON.lnk" "$install\scripts\kaiju_power.ps1`" on" } }
    if ($moveDesktop) {
        Step 'move the Desktop items into the file cabinet (recorded, undo with uninstall.ps1)' { & powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$install\scripts\Move-DesktopToCabinet.ps1" -Move }
    }
    Step 'switch the room on' {
        & powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$install\scripts\kaiju_power.ps1" on
        & powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$install\scripts\fix_desktop.ps1" }
}

Say "`nDone. $(if ($DryRun) { '(That was a dry run: nothing was changed.)' } else { "Installed in $install" })" 'Green'
Say "  POWER ON / OFF / FIX DESKTOP are in the Start menu under 'Kaiju Retro Den' (FIX DESKTOP and POWER OFF are also in the file cabinet drawer)."
Say "  Put your games in:  $snes   and   $gc"
Say "  Log: $install\install.log`n"
