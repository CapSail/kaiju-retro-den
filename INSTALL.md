# Install guide

Plan for about 15 minutes, most of it downloads.

## Before you start

1. **Wallpaper Engine** from Steam ([store page](https://store.steampowered.com/app/431960/Wallpaper_Engine/)). Start it once so it creates its folders.
2. Have your **movies in one folder** (subfolders are fine).
3. If you want the game console: your **SNES games** in one folder and your **GameCube / Wii games** in another. You must supply these yourself; none are included.
4. Optional: iTunes or the Spotify desktop app, for the turntable.

You do **not** need administrator rights.

## Run the installer

1. On this page click **Code, Download ZIP**, then unzip it somewhere (for example your Downloads folder).
2. Open the unzipped folder. Right-click `install.ps1`, **Run with PowerShell**.
   If Windows says scripts are disabled, open PowerShell in that folder and run:
   ```
   powershell -ExecutionPolicy Bypass -File install.ps1
   ```
3. To see what it would do without changing anything, add `-DryRun`.

### What it asks

| Question | Notes |
|---|---|
| Install folder | Where the program goes. The default is fine. |
| Plaque text | The brass plaque under the rainbow print says "DEDICATED TO ...". Put a name, a pet, your band. Letters, numbers and a few symbols only. |
| iTunes or Spotify | For the turntable. Spotify shows song and artist but no progress bar. |
| Movies folder | The TV plays everything it finds in here. |
| SNES / GameCube-Wii folders | Where your game files are (they are only read, never changed). The folders are created if missing. |
| File cabinet folder | Where your Desktop items will be tidied to. |
| Start at sign-in | Whether the room comes up by itself when you log in. |
| Move Desktop items | **Moves** (never deletes) everything on your Desktop into the cabinet. Every move is recorded so it can be undone. |

It then lists the downloads (name, size, source) and waits for your OK. Each file is checked against a fixed SHA-256 checksum; if one does not match, it is thrown away and the install stops.

## After it finishes

* The room switches on. Click the **TV picture** to start a movie, the **console** for games, the **file cabinet** for your old Desktop icons.
* Start menu, **Kaiju Retro Den**: POWER ON, POWER OFF, FIX DESKTOP. Also a **Kaiju POWER ON** shortcut on the Desktop.
* **Games:** put your game files in the folders you chose, click the console, pick one, double-click. Set up your own controller or keys once in each emulator (SET UP EMULATOR button in the game list; see TROUBLESHOOTING.md, Controls for games).
* If something looks off, run **FIX DESKTOP**; it repairs almost everything (see [TROUBLESHOOTING.md](TROUBLESHOOTING.md)).

## Updating or repairing

Download the new version and run `install.ps1` again with the same folder. It overwrites the program files and keeps your settings, downloaded tools and cabinet.

## Uninstalling

Run `uninstall.ps1`. It switches the room off, **puts your Desktop items back where they were**, removes the shortcuts and the background task, and moves the install folder and the Wallpaper Engine entry into a `Kaiju-removed-<date>` folder in your Documents (delete it whenever you like). Your movies, games and cabinet folder are never touched. Wallpaper Engine and Steam stay installed.

## Doing it by hand (no downloads)

If you already have the tools, run `install.ps1 -SkipDownloads` and put them here yourself:

```
<install folder>\tools\mpv\mpv.exe
<install folder>\tools\Rainmeter\Rainmeter.exe        (portable Rainmeter)
<install folder>\tools\shaderglass\ShaderGlass.exe
<install folder>\tools\snes9x\snes9x-x64.exe
<install folder>\tools\dolphin\Dolphin.exe
```
