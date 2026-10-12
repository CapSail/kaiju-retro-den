# Troubleshooting

## First, always: FIX DESKTOP

Start menu, **Kaiju Retro Den, Kaiju FIX DESKTOP** (or the **FIX DESKTOP** row in the file cabinet drawer). It is safe any time and does not stop a movie or game that is playing. It restarts anything that is down, clears stale TV and game state, repairs the emulator and TV settings, re-applies the wallpaper, puts the TV and console back on their stand, restarts the CRT filter, hides the Desktop icons again and puts a demoted taskbar back on top. What it did is written to `<install folder>\state\fix_report.txt`.

## Logs

All in `<install folder>\state\`: `fix_desktop.log`, `power.log`, `autopause.log`, `games.log`, `apply_all.log`, `install.log` (in the install folder). Rainmeter's own log is in `tools\Rainmeter\Rainmeter.log`.

## Common questions

**The room is gone / my Desktop icons are back.** You used POWER OFF. Use **Kaiju POWER ON** (Start menu or Desktop).

**Where did my Desktop icons go?** Into the file cabinet. Click the cabinet in the room; the drawer lists them. While the room is on, the normal Desktop icons are hidden (POWER OFF shows them). To put everything back for good, run `uninstall.ps1`, or `scripts\Move-DesktopToCabinet.ps1 -Restore` from the install folder.

**Wallpaper Engine shows a "Safe Start" dialog.** It does this after it was force-closed. Click OK. Never kill Wallpaper Engine from Task Manager; use POWER OFF.

**Clicking the TV does nothing / the picture is dark glass.** Dark glass means the TV is off; click it. If nothing happens, run FIX DESKTOP. Check that your movies folder (see `config.json`) exists and contains video files, then run FIX DESKTOP again (it rebuilds the playlist when it is missing).

**The TV picture looks blurry or the subtitles are hard to read.** That is the CRT filter doing its job. Close the small **ShaderGlass** window (it has no title bar; it is the app named ShaderGlass in Task Manager) to turn it off. It comes back the next time the TV or a game starts. Note that ShaderGlass hides its output from screenshots by design, so screenshots show an unfiltered TV.

**Windows SmartScreen warns about ShaderGlass.** It is an unsigned open-source program. The installer verified the exact file against a fixed checksum before using it.

**The game list is empty.** Your game files must be in the folder you chose (subfolders are fine). SNES: `.sfc .smc .fig .swc .zip .7z`. GameCube / Wii: `.iso .gcm .rvz .wbfs .gcz .ciso .wia .tgc`. The list header button **OPEN ROM FOLDER** opens the right folder.

**"Emulator not found".** Run the installer again, or put `snes9x-x64.exe` in `tools\snes9x\` and `Dolphin.exe` in `tools\dolphin\`.

**The turntable shows "nothing spinning".** iTunes or the Spotify **desktop** app must be running and playing. Spotify shows song and artist but no progress bar (and only while it is playing).

**The room is the wrong size after changing the screen resolution.** The watcher re-applies it after a few seconds; run FIX DESKTOP if it does not.

## Controls for games

This project does **not** set any controller or key bindings, because everyone's controller and layout is different. Set yours up once in each emulator and it is remembered:

* **SNES (Snes9x):** on the game list press **SET UP EMULATOR**, then *Config > Input / Joypad* (and *Config > Hotkeys* for save states).
* **GameCube / Wii (Dolphin):** on the game list press **SET UP EMULATOR**, then *Controllers*, and *Options > Hotkey Settings* for save states.

The room only makes sure the emulators keep reading your controller while the game sits in the TV (it never takes the keyboard focus) and that the picture fits the TV screen. It leaves your button layout and hotkeys alone.

## Known limits

* Tested on Windows 11 at 1920x1080 on a single screen. Other sizes should scale (everything is drawn relative to the screen height) but are untested.
* The installer is **not yet tested on a clean machine**. Copying files, writing the config, building the playlist, drawing the widgets, the cabinet and the Desktop move/undo were tested in a sandbox. The downloads, the silent Rainmeter install, the scheduled task and the shortcuts have **never been run for real yet**.
* Spotify support relies on Rainmeter's built-in Spotify reader and has not been confirmed yet. iTunes uses the same mechanism and is the safer choice for now.
* Snes9x only creates its settings file the first time it runs, so the room's fixes for it (keeps running in the TV, 4:3 picture) apply from the second game onward. Run FIX DESKTOP after your first game if the picture looks stretched wrong.
* The mpv scripts that find their folder (`tvstate.lua`, `tvhover.lua`) have not yet been run inside mpv after the move to the new folder layout.
* PlayStation 2 is not supported in this version.
* The Dolphin picture scaling fix (stretching GameCube games to the 4:3 TV) is a best guess and unconfirmed.
* A monitor that has been switched to another computer's input is invisible to Windows. Switch it back, then run FIX DESKTOP.
* Fullscreen apps pause the TV and hide the widgets on purpose; they come back when the app leaves the front.
