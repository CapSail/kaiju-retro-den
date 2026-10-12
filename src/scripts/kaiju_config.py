"""Python twin of Kaiju-Config.ps1: finds the install folder from where THIS file lives (<install>\\scripts\\) and reads <install>\\config.json.

    import os, sys; sys.path.insert(0, os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "scripts"))
    from kaiju_config import K        # K.root, K.state, K.mpv_exe, K.movies, K.snes_roms, ...

Set KAIJU_ROOT to point at a different install folder (used for tests; never needed in normal use).
"""
import json, os

root = os.environ.get("KAIJU_ROOT") or os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


class _K:
    pass


K = _K()
K.root = root
K.scripts = os.path.join(root, "scripts")
K.tv = os.path.join(root, "tv")
K.games = os.path.join(root, "games")
K.autopause = os.path.join(root, "autopause")
K.state = os.path.join(root, "state")
K.tools = os.path.join(root, "tools")
K.mpv_dir = os.path.join(K.tools, "mpv")
K.mpv_exe = os.path.join(K.mpv_dir, "mpv.exe")
K.rainmeter_dir = os.path.join(K.tools, "Rainmeter")
K.rainmeter_exe = os.path.join(K.rainmeter_dir, "Rainmeter.exe")
K.skins_dir = os.path.join(K.rainmeter_dir, "Skins", "KaijuHUD")
K.shaderglass = os.path.join(K.tools, "shaderglass")
K.snes9x_dir = os.path.join(K.tools, "snes9x")
K.dolphin_dir = os.path.join(K.tools, "dolphin")

_cfg = os.path.join(root, "config.json")
if os.path.exists(_cfg):
    with open(_cfg, encoding="utf-8") as f:
        _c = json.load(f)
else:
    _c = {}                      # generators can still run for tests; missing values stay empty
K.cabinet = _c.get("cabinet_dir", "")
K.movies = _c.get("movies_dir", "")
K.snes_roms = _c.get("snes_rom_dir", "")
K.gcwii_roms = _c.get("gamecube_wii_rom_dir", "")
K.plaque = _c.get("plaque_text", "KAIJU")
K.music_player = _c.get("music_player", "itunes")
K.we_dir = _c.get("wallpaper_engine_dir", "")
K.steam_exe = _c.get("steam_exe", "")
K.python_exe = _c.get("python_exe", "")
os.makedirs(K.state, exist_ok=True) if os.path.isdir(root) and os.access(root, os.W_OK) and os.path.exists(_cfg) else None
