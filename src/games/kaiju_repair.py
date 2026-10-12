"""Repairs the KAIJU TV / game settings that can get lost (called by FIX DESKTOP; safe to run any time, idempotent).
It only touches the exact keys listed here, so anything else you changed in an emulator is left alone. Every change is logged to state/games.log.
  - mpv TV player: mpv.conf keys, input.conf present
  - Snes9x: pause-when-inactive off, background input on, Xbox controller on player 1
  - Dolphin: portable.txt, background input, no confirm-on-stop, Xbox controller on GameCube pad 1 and Wii Remote 1
  - required files exist (reported, not recreated)
"""
import os, re, sys, time
sys.path.insert(0, os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "scripts"))
from kaiju_config import K                     # install paths (config.json)

LOG = os.path.join(K.state, "games.log")
changes = []


def log(msg):
    changes.append(msg)
    try:
        with open(LOG, "a", encoding="utf-8") as f:
            f.write(time.strftime("%Y-%m-%dT%H:%M:%S ") + "[repair] " + msg + "\n")
    except OSError:
        pass


def read(p):
    with open(p, encoding="utf-8", errors="replace", newline="") as f:
        return f.read()


def write(p, s):
    try:
        with open(p, "w", encoding="utf-8", newline="") as f:
            f.write(s)
    except (PermissionError, OSError) as e:       # the emulator has its config open (a game is running): leave it, the next run applies it
        log(f"skipped {os.path.basename(p)}: locked by a running program ({e.__class__.__name__}); will apply when it is closed")


# ---------------------------------------------------------------- mpv (the TV player)
MPV_CONF = os.path.join(K.mpv_dir, "portable_config", "mpv.conf")
MPV_NEED = ["ontop=no", "focus-on=never", "show-in-taskbar=no", "input-default-bindings=no", "input-builtin-bindings=no",
            "border=no", "keepaspect-window=no", r"input-ipc-server=\\.\pipe\kaijutv", "geometry=300x225", "auto-window-resize=no", "title=KAIJU-TV"]
if os.path.isfile(MPV_CONF):
    s = read(MPV_CONF)
    have = {ln.split("=", 1)[0].strip(): ln.strip() for ln in s.splitlines() if "=" in ln and not ln.lstrip().startswith("#")}
    add = []
    for need in MPV_NEED:
        k, v = need.split("=", 1)
        if have.get(k) != need:
            if k in have:
                s = re.sub(r"(?m)^\s*" + re.escape(k) + r"\s*=.*$", lambda m: need, s)
                log(f"mpv.conf: set {need}")
            else:
                add.append(need)
    if add:
        s = s.rstrip("\r\n") + "\n" + "\n".join(add) + "\n"
        log("mpv.conf: added " + ", ".join(add))
    if s != read(MPV_CONF):
        write(MPV_CONF, s)

# ---------------------------------------------------------------- Snes9x
S9 = os.path.join(K.snes9x_dir, "snes9x.conf")      # Snes9x writes this file the first time it runs
PAD = {"A": "(J0)Button 1", "B": "(J0)Button 0", "X": "(J0)Button 3", "Y": "(J0)Button 2", "L": "(J0)Button 4", "R": "(J0)Button 5",
       "Start": "(J0)Button 7", "Select": "(J0)Button 6", "Up": "(J0)POV Up", "Down": "(J0)POV Down", "Left": "(J0)POV Left", "Right": "(J0)POV Right"}


def conf_set(s, key_regex, value, label):
    """Set 'key = value' keeping the original spacing and any trailing comment; returns (text, changed)."""
    m = re.search(r"(?m)^(\s*" + key_regex + r"\s*=\s*)([^\r\n#]*?)(\s*(#.*)?)$", s)
    if not m or m.group(2).strip() == value:
        return s, False
    new = m.group(1) + value + (m.group(3) if m.group(3).strip() else "")
    log(f"{label}: {m.group(2).strip()!r} -> {value!r}")
    return s[:m.start()] + new + s[m.end():], True


if os.path.isfile(S9):
    s = read(S9); o = s
    s, _ = conf_set(s, r"PauseWhenInactive", "FALSE", "snes9x PauseWhenInactive")
    s, _ = conf_set(s, r"Input:Background", "ON", "snes9x Input:Background")                       # the Xbox controller keeps working while the game is not focused
    s, _ = conf_set(s, r"Input:BackgroundKeyHotkeys", "OFF", "snes9x Input:BackgroundKeyHotkeys")  # ...but typing in other apps must NOT trigger Snes9x hotkeys (a comma toggled its input display)
    s, _ = conf_set(s, r"Joypad2:Enabled", "FALSE", "snes9x Joypad2:Enabled")                       # player 2 was on keyboard letters, which background input would read while typing
    for k, v in PAD.items():
        s, _ = conf_set(s, r"Joypad1:" + re.escape(k), v, f"snes9x Joypad1:{k}")
    # the TV picture is 4:3: draw SNES games 4:3 too (base width 299 = 4:3) so they fill it instead of leaving black bars at the sides
    s, _ = conf_set(s, r"Stretch:AspectRatioBaseWidth", "299", "snes9x Stretch:AspectRatioBaseWidth")
    # quick save / quick load (slot 0) on the stick clicks: right stick click = save, left stick click = load (Snes9x cannot do button combos)
    for k, v in (("Key:SaveSlot0", "(J0)Button 9"), ("Mods:SaveSlot0", "none"), ("Key:LoadSlot0", "(J0)Button 8"), ("Mods:LoadSlot0", "none")):
        s, _ = conf_set(s, re.escape(k), v, f"snes9x hotkey {k}")
    if s != o:
        write(S9, s)

# ---------------------------------------------------------------- Dolphin
DOL = K.dolphin_dir
if os.path.isdir(DOL):
    port = os.path.join(DOL, "portable.txt")
    if not os.path.isfile(port):
        open(port, "w").close(); log("dolphin: created portable.txt (settings stay in the Dolphin folder)")
    cfg = os.path.join(DOL, "User", "Config")
    os.makedirs(cfg, exist_ok=True)

    def ini_set(path, section, kv):
        s = read(path) if os.path.isfile(path) else ""
        o = s
        head = f"[{section}]"
        if head not in s:
            s = s.rstrip("\r\n") + ("\n" if s else "") + head + "\n"
        lines = s.split("\n")
        i = next(n for n, ln in enumerate(lines) if ln.strip() == head)
        j = i + 1
        while j < len(lines) and not lines[j].startswith("["):
            j += 1
        body = lines[i + 1:j]
        for k, v in kv:
            idx = next((n for n, ln in enumerate(body) if re.match(r"^" + re.escape(k) + r"\s*=", ln)), None)
            want = f"{k} = {v}"
            if idx is None:
                while body and body[-1] == "":
                    body.pop()
                body.append(want); log(f"{os.path.basename(path)} [{section}]: added {want}")
            elif body[idx].strip() != want:
                log(f"{os.path.basename(path)} [{section}]: {body[idx].strip()!r} -> {want!r}"); body[idx] = want
        lines[i + 1:j] = body
        s = "\n".join(lines)
        if s != o:
            write(path, s)

    ini_set(os.path.join(cfg, "Dolphin.ini"), "Input", [("BackgroundInput", "True")])
    ini_set(os.path.join(cfg, "Dolphin.ini"), "Interface", [("ConfirmStop", "False")])
    # the TV picture is a fixed 4:3 window: always fill it (3 = stretch to window) instead of following the game's own aspect, which jumps between
    # 4:3 menus and widescreen gameplay; and never resize the window to the game
    ini_set(os.path.join(cfg, "GFX.ini"), "Settings", [("AspectRatio", "3")])
    ini_set(os.path.join(cfg, "Dolphin.ini"), "Display", [("RenderWindowAutoSize", "False"), ("KeepWindowOnTop", "False")])
    # quick save / quick load (state slot 1): Back + right bumper = save, Back + left bumper = load
    ini_set(os.path.join(cfg, "Hotkeys.ini"), "Hotkeys", [("Device", "XInput/0/Gamepad"), ("Save State/Save State Slot 1", "Back & `Shoulder R`"),
                                                         ("Load State/Load State Slot 1", "Back & `Shoulder L`")])

    CAL = "100.00 141.42 100.00 141.42 100.00 141.42 100.00 141.42"
    GC = [("Device", "XInput/0/Gamepad"), ("Buttons/A", "`Button A`"), ("Buttons/B", "`Button X`"), ("Buttons/X", "`Button B`"), ("Buttons/Y", "`Button Y`"),
          ("Buttons/Z", "`Shoulder R`"), ("Buttons/Start", "Start"), ("Main Stick/Up", "`Left Y+`"), ("Main Stick/Down", "`Left Y-`"),
          ("Main Stick/Left", "`Left X-`"), ("Main Stick/Right", "`Left X+`"), ("Main Stick/Modifier", "`Thumb L`"), ("Main Stick/Calibration", CAL),
          ("C-Stick/Up", "`Right Y+`"), ("C-Stick/Down", "`Right Y-`"), ("C-Stick/Left", "`Right X-`"), ("C-Stick/Right", "`Right X+`"),
          ("C-Stick/Modifier", "`Thumb R`"), ("C-Stick/Calibration", CAL), ("Triggers/L", "`Trigger L`"), ("Triggers/R", "`Trigger R`"),
          ("Triggers/L-Analog", "`Trigger L`"), ("Triggers/R-Analog", "`Trigger R`"), ("D-Pad/Up", "`Pad N`"), ("D-Pad/Down", "`Pad S`"),
          ("D-Pad/Left", "`Pad W`"), ("D-Pad/Right", "`Pad E`"), ("Rumble/Motor", "`Motor L`|`Motor R`")]
    WM = [("Device", "XInput/0/Gamepad"), ("Buttons/A", "`Button A`"), ("Buttons/B", "`Button B`"), ("Buttons/1", "`Button X`"), ("Buttons/2", "`Button Y`"),
          ("Buttons/-", "Back"), ("Buttons/+", "Start"), ("Buttons/Home", "Guide"), ("IR/Up", "`Right Y+`"), ("IR/Down", "`Right Y-`"),
          ("IR/Left", "`Right X-`"), ("IR/Right", "`Right X+`"), ("Shake/X", "`Shoulder R`"), ("Shake/Y", "`Shoulder R`"), ("Shake/Z", "`Shoulder R`"),
          ("Nunchuk/Buttons/C", "`Shoulder L`"), ("Nunchuk/Buttons/Z", "`Trigger L`"), ("Nunchuk/Stick/Up", "`Left Y+`"), ("Nunchuk/Stick/Down", "`Left Y-`"),
          ("Nunchuk/Stick/Left", "`Left X-`"), ("Nunchuk/Stick/Right", "`Left X+`"), ("Nunchuk/Shake/X", "`Thumb L`"), ("Nunchuk/Shake/Y", "`Thumb L`"),
          ("Nunchuk/Shake/Z", "`Thumb L`"), ("D-Pad/Up", "`Pad N`"), ("D-Pad/Down", "`Pad S`"), ("D-Pad/Left", "`Pad W`"), ("D-Pad/Right", "`Pad E`"),
          ("Rumble/Motor", "`Motor L`|`Motor R`")]
    for fname, sec, table in (("GCPadNew.ini", "GCPad1", GC), ("WiimoteNew.ini", "Wiimote1", WM)):
        path = os.path.join(cfg, fname)
        cur = read(path) if os.path.isfile(path) else ""
        if re.search(r"(?ms)^\[" + sec + r"\]\s*\r?\nDevice = XInput/0/Gamepad", cur):
            continue                      # already on the Xbox controller: leave it (it may hold your own tweaks)
        ini_set(path, sec, table)

# ---------------------------------------------------------------- required files (reported only)
_j = os.path.join
REQ = [_j(K.games, "kaiju_games.py"), _j(K.games, "tv_game.ps1"), _j(K.games, "console_click.ps1"), _j(K.games, "tv_volume.ps1"),
       _j(K.shaderglass, "ShaderGlass.exe"), _j(K.games, "shaderglass", "kaiju_tv.sgp"), _j(K.games, "shaderglass", "tv_overlay.ps1"),
       _j(K.tv, "toggle_tv.ps1"), K.mpv_exe, _j(K.mpv_dir, "portable_config", "input.conf"),
       _j(K.mpv_dir, "portable_config", "scripts", "tvhover.lua"), _j(K.mpv_dir, "portable_config", "scripts", "tvstate.lua"),
       _j(K.autopause, "autopause.ps1"), K.rainmeter_exe]
REQ += [_j(K.skins_dir, n, n + ".ini") for n in ("TVRemote", "Scene", "Systems", "Cabinet", "Console")]
missing = [p for p in REQ if not os.path.isfile(p)]
for p in missing:
    log("MISSING FILE (run install.ps1 again to repair): " + p)
print(f"repair: {len(changes)} change(s), {len(missing)} missing file(s)")
for c in changes:
    print("  -", c)
sys.exit(0)
