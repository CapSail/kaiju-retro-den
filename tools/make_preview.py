"""Builds tools/preview/out/preview.html: the real wallpaper page plus the project's real Rainmeter skins drawn on top (see tools/preview/renderer.js).
Open it in a browser at a 1920x1080 viewport, then call  saveRoom(url, {drawer:true|false})  to post a JPEG to a local receiver.
Run it with Windows PowerShell (it calls open_cabinet.ps1 to draw the cabinet drawer):   python tools/make_preview.py
Only reads the repo and writes to a temp folder and tools/preview/out. Never touches an installed copy.
"""
import json, os, shutil, subprocess, sys, tempfile

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(REPO, "src")
tmp = tempfile.mkdtemp(prefix="kaiju_preview_")
os.makedirs(os.path.join(tmp, "scripts"))
for f in os.listdir(os.path.join(SRC, "scripts")):
    if f.endswith((".ps1", ".py")):
        shutil.copy(os.path.join(SRC, "scripts", f), os.path.join(tmp, "scripts", f))

# a sample cabinet: made-up desktop items
cab = os.path.join(tmp, "cabinet")
os.makedirs(os.path.join(cab, "Work Stuff")); os.makedirs(os.path.join(cab, "Photos"))
for n in ("Browser.lnk", "Notes.lnk", "Music Player.lnk", "Photo Editor.lnk", "Budget 2026.xlsx", "Game Launcher.lnk", "Resume.docx"):
    open(os.path.join(cab, n), "w").close()
json.dump({"cabinet_dir": cab, "music_player": "itunes", "plaque_text": "KAIJU"}, open(os.path.join(tmp, "config.json"), "w"))

env = dict(os.environ, KAIJU_ROOT=tmp, PYTHONDONTWRITEBYTECODE="1", KAIJU_CABINET_ONLY="1")
for g in ("make_scene.py", "make_remote.py", "make_console.py"):
    subprocess.run([sys.executable, "-I", "-B", os.path.join(SRC, "tv", g)], env=env, check=True, capture_output=True)
subprocess.run(["powershell.exe", "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", os.path.join(tmp, "scripts", "open_cabinet.ps1"), "-NoRainmeter"], env=env, check=True, capture_output=True)

skins_dir = os.path.join(tmp, "tools", "Rainmeter", "Skins", "KaijuHUD")
skins = {}
for n in ("Scene", "Systems", "TVRemote", "Console", "Cabinet"):
    raw = open(os.path.join(skins_dir, n, n + ".ini"), "rb").read()
    skins[n] = raw.decode("utf-16" if raw[:2] in (b"\xff\xfe", b"\xfe\xff") else "ascii")
theme = open(os.path.join(SRC, "rainmeter", "KaijuHUD", "@Resources", "Theme.inc"), encoding="utf-8-sig").read()

html = open(os.path.join(SRC, "wallpaper", "index.html"), encoding="utf-8").read()
inject = ("<script>window.SKINS=" + json.dumps(skins) + ";window.THEME=" + json.dumps(theme) + ";</script>\n<script>"
          + open(os.path.join(REPO, "tools", "preview", "renderer.js"), encoding="utf-8").read() + "</script>\n")
assert html.count("</body>") == 1
out_dir = os.path.join(REPO, "tools", "preview", "out"); os.makedirs(out_dir, exist_ok=True)
out = os.path.join(out_dir, "preview.html")
open(out, "w", encoding="utf-8", newline="\n").write(html.replace("</body>", inject + "</body>"))
shutil.rmtree(tmp, ignore_errors=True)
print("wrote", out)
