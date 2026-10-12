"""KAIJU GAME GUIDE: the list that opens when you click the KAIJU SYSTEMS console.
Pick a system, type to filter, double-click (or Enter) to play. One list per emulator; ROMs stay where they are.
Edit SYSTEMS below to add a folder or change how a game starts. Launch log: state\\games.log.
"""
import json, os, re, socket, subprocess, sys, time
import tkinter as tk
from tkinter import messagebox

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(os.path.dirname(HERE), "scripts"))
from kaiju_config import K                      # install paths + the ROM folders the user chose in install.ps1 (config.json)
LOG = os.path.join(K.state, "games.log")
PREFS = os.path.join(K.state, "games_prefs.json")
DOLPHIN_DIR = K.dolphin_dir
SNES9X_DIR = K.snes9x_dir

# palette = the Rainmeter theme (cream card, walnut, amber)
CREAM, CREAM_DK, INK, WOOD, WOOD_EDGE, BAKELITE, AMBER = "#e0d2b2", "#c6b694", "#342214", "#704a2e", "#241608", "#1e1b19", "#ffb042"
FONT = "Courier New"


def launch_snes(rom, tv=False):
    return [os.path.join(SNES9X_DIR, "snes9x-x64.exe"), rom], SNES9X_DIR

def launch_dolphin(rom, tv=False):
    return [os.path.join(DOLPHIN_DIR, "Dolphin.exe"), "-b", "-e", rom], DOLPHIN_DIR


# key, button label, emulator exe, rom folders, extensions, launcher, first-run note
SYSTEMS = [
    ("snes", "SUPER NINTENDO", os.path.join(SNES9X_DIR, "snes9x-x64.exe"),
     [K.snes_roms], {".sfc", ".smc", ".fig", ".swc", ".zip", ".7z"}, launch_snes, ""),
    ("gc", "GAMECUBE / WII", os.path.join(DOLPHIN_DIR, "Dolphin.exe"),
     [K.gcwii_roms], {".iso", ".gcm", ".rvz", ".wbfs", ".gcz", ".ciso", ".wia", ".tgc"}, launch_dolphin, ""),
]


def log(msg):
    try:
        with open(LOG, "a", encoding="utf-8") as f:
            f.write(time.strftime("%Y-%m-%dT%H:%M:%S ") + msg + "\n")
    except OSError:
        pass


def clean_title(path):
    name = os.path.splitext(os.path.basename(path))[0]
    disc = re.search(r"\((Disc \d+)\)", name, re.I)
    name = re.sub(r"\s*[\(\[][^\)\]]*[\)\]]", "", name).strip()
    m = re.match(r"^(.*?), (The|A|An)( - .*)?$", name)          # "Legend of Zelda, The - A Link to the Past" -> "The Legend of Zelda - A Link to the Past"
    if m:
        name = f"{m.group(2)} {m.group(1)}{m.group(3) or ''}"
    return f"{name} ({disc.group(1)})" if disc else name


def scan(folders, exts):
    """[(title, path)] sorted; a .bin with a matching .cue is listed once, as the .cue."""
    found = []
    for root in folders:
        if not os.path.isdir(root):
            continue
        for dp, _dn, files in os.walk(root):
            low = {f.lower() for f in files}
            for f in files:
                stem, ext = os.path.splitext(f)
                ext = ext.lower()
                if ext not in exts:
                    continue
                if ext == ".bin" and (stem + ".cue").lower() in low:
                    continue
                full = os.path.join(dp, f)
                found.append((clean_title(full), full))
    found.sort(key=lambda t: (re.sub(r"^(the|a|an) ", "", t[0].lower()), t[0].lower()))
    return found


def load_prefs():
    try:
        with open(PREFS, encoding="utf-8") as f:
            return json.load(f)
    except (OSError, ValueError):
        return {}


def save_prefs(d):
    try:
        with open(PREFS, "w", encoding="utf-8") as f:
            json.dump(d, f)
    except OSError:
        pass


class Guide(tk.Tk):
    def __init__(self):
        super().__init__()
        self.title("KAIJU GAME GUIDE")
        self.configure(bg=WOOD_EDGE)
        self.geometry("760x600")
        self.minsize(560, 420)
        self.prefs = load_prefs()
        self.on_tv = self.prefs.get("tv", True)       # True = the game plays inside the TV set; False = its own window / fullscreen
        self.sys = None
        self.items = []
        self.shown = []

        head = tk.Frame(self, bg=WOOD_EDGE)
        head.pack(fill="x", padx=14, pady=(12, 6))
        tk.Label(head, text="KAIJU SYSTEMS", bg=WOOD_EDGE, fg=AMBER, font=(FONT, 16, "bold")).pack(side="left")
        tk.Label(head, text="GAME GUIDE", bg=WOOD_EDGE, fg=CREAM, font=(FONT, 11)).pack(side="left", padx=10, pady=(5, 0))
        last = self.prefs.get("last")
        self.resumebtn = tk.Button(head, command=self.resume, font=(FONT, 10, "bold"), bd=0, padx=12, pady=6, cursor="hand2",
                                   bg=AMBER if last else CREAM_DK, fg=INK, state="normal" if last else "disabled",
                                   text=("RESUME: " + last["title"][:34]) if last else "RESUME: nothing played yet")
        self.resumebtn.pack(side="right")

        tabs = tk.Frame(self, bg=WOOD_EDGE)
        tabs.pack(fill="x", padx=14)
        self.tabbtn = {}
        for s in SYSTEMS:
            b = tk.Button(tabs, text=s[1], font=(FONT, 10, "bold"), bd=0, padx=14, pady=7, cursor="hand2",
                          command=lambda k=s[0]: self.pick(k))
            b.pack(side="left", padx=(0, 6))
            self.tabbtn[s[0]] = b

        card = tk.Frame(self, bg=CREAM, highlightbackground=WOOD, highlightthickness=3)
        card.pack(fill="both", expand=True, padx=14, pady=8)
        bar = tk.Frame(card, bg=CREAM_DK)
        bar.pack(fill="x")
        tk.Label(bar, text="FIND", bg=CREAM_DK, fg=INK, font=(FONT, 10, "bold")).pack(side="left", padx=(10, 6), pady=6)
        self.q = tk.StringVar()
        self.q.trace_add("write", lambda *_: self.refilter())
        self.entry = tk.Entry(bar, textvariable=self.q, font=(FONT, 11), bg="#f3ead3", fg=INK, relief="flat", insertbackground=INK)
        self.entry.pack(side="left", fill="x", expand=True, padx=(0, 10), pady=6, ipady=3)
        self.count = tk.Label(bar, text="", bg=CREAM_DK, fg=INK, font=(FONT, 9))
        self.count.pack(side="right", padx=10)

        body = tk.Frame(card, bg=CREAM)
        body.pack(fill="both", expand=True, padx=6, pady=6)
        sb = tk.Scrollbar(body)
        sb.pack(side="right", fill="y")
        self.lb = tk.Listbox(body, font=(FONT, 12), bg=CREAM, fg=INK, bd=0, highlightthickness=0, activestyle="none",
                             selectbackground=BAKELITE, selectforeground=AMBER, yscrollcommand=sb.set)
        self.lb.pack(side="left", fill="both", expand=True)
        sb.config(command=self.lb.yview)

        foot = tk.Frame(self, bg=WOOD_EDGE)
        foot.pack(fill="x", padx=14, pady=(0, 12))
        self.status = tk.Label(foot, text="", bg=WOOD_EDGE, fg=CREAM, font=(FONT, 9), anchor="w", justify="left")
        self.status.pack(side="left", fill="x", expand=True)
        self.modebtn = tk.Button(foot, command=self.toggle_mode, font=(FONT, 10, "bold"), bd=0, padx=12, pady=6, cursor="hand2", bg=CREAM_DK, fg=INK)
        self.modebtn.pack(side="right", padx=(6, 0))
        self.show_mode()
        for text, cmd in (("OPEN ROM FOLDER", self.open_folder), ("SET UP EMULATOR", self.setup_emu), ("PLAY", self.play)):
            tk.Button(foot, text=text, command=cmd, font=(FONT, 10, "bold"), bd=0, padx=12, pady=6, cursor="hand2",
                      bg=AMBER if text == "PLAY" else CREAM_DK, fg=INK).pack(side="right", padx=(6, 0))

        self.lb.bind("<Double-Button-1>", lambda _e: self.play())
        self.lb.bind("<Return>", lambda _e: self.play())
        self.entry.bind("<Return>", lambda _e: self.play())
        self.entry.bind("<Down>", lambda _e: (self.lb.focus_set(), self.lb.selection_set(0) if not self.lb.curselection() else None))
        self.bind("<Escape>", lambda _e: self.destroy())
        self.pick(self.prefs.get("system", "snes"))
        self.entry.focus_set()
        self.center()

    def center(self):
        self.update_idletasks()
        w, h = self.winfo_width(), self.winfo_height()
        self.geometry(f"+{(self.winfo_screenwidth() - w) // 2}+{(self.winfo_screenheight() - h) // 3}")

    def pick(self, key):
        self.sys = next(s for s in SYSTEMS if s[0] == key) if any(s[0] == key for s in SYSTEMS) else SYSTEMS[0]
        for k, b in self.tabbtn.items():
            on = k == self.sys[0]
            b.config(bg=AMBER if on else CREAM_DK, fg=INK, activebackground=AMBER, activeforeground=INK)
        self.items = scan(self.sys[3], self.sys[4])
        self.q.set("")
        self.refilter()
        self.prefs["system"] = self.sys[0]
        save_prefs(self.prefs)

    def refilter(self):
        if not self.sys:
            return
        words = self.q.get().lower().split()
        self.shown = [t for t in self.items if all(w in t[0].lower() for w in words)]
        self.lb.delete(0, "end")
        for t in self.shown:
            self.lb.insert("end", "  " + t[0])
        if self.shown:
            self.lb.selection_set(0)
        self.count.config(text=f"{len(self.shown)} OF {len(self.items)}")
        if not self.items:
            self.status.config(text="No games found yet. Drop ROMs in:\n" + "\n".join(self.sys[3]))
        else:
            self.status.config(text="Double-click or press Enter to play. Esc closes.")

    def show_mode(self):
        self.modebtn.config(text="PLAY ON: TV" if self.on_tv else "PLAY ON: FULL SCREEN")

    def toggle_mode(self):
        self.on_tv = not self.on_tv
        self.prefs["tv"] = self.on_tv
        save_prefs(self.prefs)
        self.show_mode()

    def selected(self):
        sel = self.lb.curselection()
        return self.shown[sel[0]] if sel else (self.shown[0] if len(self.shown) == 1 else None)

    def play(self):
        item = self.selected()
        if item:
            self.start(self.sys, item[0], item[1])

    def resume(self):
        last = self.prefs.get("last")
        if not last:
            return
        sysrow = next((x for x in SYSTEMS if x[0] == last.get("key")), None)
        if not sysrow or not os.path.isfile(last.get("path", "")):
            messagebox.showinfo("KAIJU GAME GUIDE", "The last game is not on the drive any more:\n" + last.get("path", ""))
            return
        self.start(sysrow, last["title"], last["path"])

    def start(self, sysrow, title, path):
        key, _label, exe, _f, _e, launcher, note = sysrow
        if not os.path.isfile(exe):
            messagebox.showerror("KAIJU GAME GUIDE", "Emulator not found:\n" + exe)
            return
        cmd, cwd = launcher(path, tv=self.on_tv)
        try:
            # tv_game.ps1 puts the game window in the TV picture (mode "tv") or maximizes it over the TV's whole monitor (mode "full"),
            # keeps the CRT filter over it, and brings the movie back afterwards
            spec = os.path.join(K.state, "tv_game_cmd.json")
            with open(spec, "w", encoding="utf-8") as f:
                json.dump({"cmd": cmd, "cwd": cwd, "title": title, "mode": "tv" if self.on_tv else "full"}, f)
            subprocess.Popen(["powershell.exe", "-NoProfile", "-WindowStyle", "Hidden", "-ExecutionPolicy", "Bypass",
                              "-File", os.path.join(HERE, "tv_game.ps1"), "-CmdFile", spec], close_fds=True,
                             creationflags=0x08000000)
            log(("LAUNCH TV " if self.on_tv else "LAUNCH FULL ") + " | ".join(cmd))
        except OSError as e:
            log(f"FAILED {cmd}: {e}")
            messagebox.showerror("KAIJU GAME GUIDE", f"Could not start the game:\n{e}")
            return
        self.prefs["last"] = {"key": key, "title": title, "path": path}      # what RESUME plays next time
        save_prefs(self.prefs)
        self.destroy()

    def open_folder(self):
        target = self.sys[3][0]
        if not target:
            messagebox.showinfo("KAIJU GAME GUIDE", "No ROM folder is set. Run install.ps1 again to choose one.")
            return
        os.makedirs(target, exist_ok=True)                   # the folder may not exist yet: make it so the user can drop ROMs in
        os.startfile(target)

    def setup_emu(self):
        exe = self.sys[2]
        if os.path.isfile(exe):
            subprocess.Popen([exe], cwd=os.path.dirname(exe), close_fds=True)
            log("SETUP " + exe)
            self.destroy()


def main():
    lock = socket.socket()                                   # one guide at a time: a second click does nothing
    try:
        lock.bind(("127.0.0.1", 47831))
    except OSError:
        return
    Guide().mainloop()


if __name__ == "__main__":
    if "--selftest" in sys.argv:                             # no window, no emulator: just scan and print counts
        for s in SYSTEMS:
            games = scan(s[3], s[4])
            print(f"{s[0]}: exe={'OK' if os.path.isfile(s[2]) else 'MISSING'} games={len(games)}  first={[g[0] for g in games[:3]]}")
        sys.exit(0)
    main()
