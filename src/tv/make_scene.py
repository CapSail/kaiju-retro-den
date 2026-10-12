"""Generate two Rainmeter skins for the RETRO DEN theme (everything the user clicks or reads is part of the room):
  Scene/Scene.ini     full-screen transparent layer: the file-cabinet hover zone over the prop drawn by the wallpaper (wallpaper\\index.html)
                      and the record player's amber readout + transport buttons.
  Systems/Systems.ini a wall-mounted gauge panel: three needle dials (CPU, memory, disk free) + the nixie power-level window.
The coordinates below MUST match propXxx()/turntable() in wallpaper\\index.html: positions are in room units S0 = screen height / 1080,
measured from the screen centre CX; shelf props stand on SHELFY (0.70 H), floor props on FB = FLOORY + 68 S0 (FLOORY = 0.875 H).
Rerun after editing, then restart Rainmeter (or !RefreshApp).
"""
import math
import os, sys
sys.path.insert(0, os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "scripts"))
from kaiju_config import K        # install paths + choices, read from config.json (scripts/kaiju_config.py)
SK = os.environ.get("KAIJU_SKINS_DIR") or K.skins_dir   # default = inside the folder this copy lives in, never anybody's live Rainmeter

# name, dx (centre, room units), base, w, h, action, tag.  The file cabinet is the ONLY prop that opens anything.
ZONES = [
    ("Cabinet", 400, "FB", 130, 120, rf'["powershell.exe" -NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File "{K.scripts}\open_cabinet.ps1"]', "FILE CABINET"),   # rebuilds the drawer from the cabinet folder, then shows it
]
TRANSPORT = [("Prev", 108, "Previous"), ("Play", 134, "PlayPause"), ("Next", 160, "Next")]   # record-player buttons (dx of centre)
INK, CREAM, CREAM_DK, WOODEDGE = "52,34,20", "224,210,178", "198,182,148", "36,22,12"
HOVER = "Fill Color 255,226,160,40 | StrokeWidth 3 | Stroke Color 255,236,190,210"

def num(v):
    return f"{v:g}"

o = ["[Rainmeter]", "Update=1000", "DynamicWindowSize=1", "AccurateText=1", "@Include=#@#Theme.inc", "",
     "[Variables]",
     "S0=(#SCREENAREAHEIGHT#/1080)", "CX=(#SCREENAREAWIDTH#/2)", "SHELFY=(#SCREENAREAHEIGHT#*0.70)",
     "FLOORY=(#SCREENAREAHEIGHT#*0.875)", "FB=(#FLOORY#+68*#S0#)"]
for i, (n, dx, base, w, h, act, tag) in enumerate(ZONES, 1):
    o += [f"Z{i}X=(#CX#+({num(dx - w / 2)})*#S0#)", f"Z{i}Y=(#{base}#-{h}*#S0#)", f"Z{i}W=({w}*#S0#)", f"Z{i}H=({h}*#S0#)"]
o += [""]

# --- measures: now-playing (the record player readout)
# music_player in config.json: itunes | spotify. Rainmeter's NowPlaying plugin talks to both desktop apps without any API key; Spotify has no progress bar.
PLAYER = {"itunes": "iTunes", "spotify": "Spotify"}.get((K.music_player or "itunes").lower(), "iTunes")
o += ["[mTitle]", "Measure=Plugin", "Plugin=NowPlaying", "PlayerName=" + PLAYER, "PlayerType=TITLE", 'Substitute="":"-  nothing spinning  -"', "",
      "[mArtist]", "Measure=Plugin", "Plugin=NowPlaying", "PlayerName=" + PLAYER, "PlayerType=ARTIST", "",
      "[mProg]", "Measure=Plugin", "Plugin=NowPlaying", "PlayerName=" + PLAYER, "PlayerType=PROGRESS", "",
      "[mCtl]", "Measure=Plugin", "Plugin=NowPlaying", "PlayerName=" + PLAYER, "PlayerType=STATE", ""]

# --- the window itself: the whole screen, fully transparent
o += ["[Frame]", "Meter=Shape", "Shape=Rectangle 0,0,#SCREENAREAWIDTH#,#SCREENAREAHEIGHT# | Fill Color 0,0,0,0 | StrokeWidth 0",
      "W=#SCREENAREAWIDTH#", "H=#SCREENAREAHEIGHT#", ""]

# --- record player readout (amber text over the dark recess drawn in the wallpaper)
o += ["[Song]", "Meter=String", "MeasureName=mTitle", "X=(#CX#+(-97)*#S0#)", "Y=(#SHELFY#-44*#S0#)", "W=(177*#S0#)", "H=(16*#S0#)", "ClipString=1",
      "FontFace=#Font#", "FontSize=(8*#S0#)", "FontColor=255,176,66", "StringStyle=Bold", "AntiAlias=1", "",
      "[Artist]", "Meter=String", "MeasureName=mArtist", "X=(#CX#+(-97)*#S0#)", "Y=(#SHELFY#-28*#S0#)", "W=(177*#S0#)", "H=(14*#S0#)", "ClipString=1",
      "FontFace=#Font#", "FontSize=(7*#S0#)", "FontColor=190,140,60", "AntiAlias=1", "",
      "[Progress]", "Meter=Bar", "MeasureName=mProg", "X=(#CX#+(-103)*#S0#)", "Y=(#SHELFY#-14*#S0#)", "W=(189*#S0#)", "H=(2*#S0#)",
      "BarColor=255,176,66", "SolidColor=60,44,26", "BarOrientation=Horizontal"] + (["Hidden=1"] if PLAYER == "Spotify" else []) + [""]

# --- prop hover zones (clickable): highlight + a cream tag on hover
for i, (n, dx, base, w, h, act, tag) in enumerate(ZONES, 1):
    rect = f"Rectangle #Z{i}X#,#Z{i}Y#,#Z{i}W#,#Z{i}H#,10"
    o += [f"[Zone{i}]", "Meter=Shape", f"Shape={rect} | Fill Color 0,0,0,1 | StrokeWidth 0", f"LeftMouseUpAction={act}",
          f'MouseOverAction=[!SetOption Zone{i} Shape "{rect} | {HOVER}"][!UpdateMeter Zone{i}][!ShowMeter Tag{i}][!Redraw]',
          f'MouseLeaveAction=[!SetOption Zone{i} Shape "{rect} | Fill Color 0,0,0,1 | StrokeWidth 0"][!UpdateMeter Zone{i}][!HideMeter Tag{i}][!Redraw]', "",
          f"[Tag{i}]", "Meter=String", f"Text={tag}", f"X=(#CX#+({num(dx)})*#S0#)", f"Y=(#Z{i}Y#-26*#S0#)", "StringAlign=Center",
          "FontFace=#Font#", "FontSize=(8*#S0#)", f"FontColor={INK}", "StringStyle=Bold", f"SolidColor={CREAM},245", "Padding=8,3,8,3", "Hidden=1", "AntiAlias=1", ""]
# --- record player transport buttons (on top of the Music zone)
for n, dx, cmd in TRANSPORT:
    cell = f"Rectangle (#CX#+({num(dx - 11)})*#S0#),(#SHELFY#-{num(27 + 11)}*#S0#),(22*#S0#),(22*#S0#),11"
    o += [f"[Btn{n}]", "Meter=Shape", f"Shape={cell} | Fill Color 0,0,0,1 | StrokeWidth 0", f'LeftMouseUpAction=[!CommandMeasure mCtl "{cmd}"]',
          f'MouseOverAction=[!SetOption Btn{n} Shape "{cell} | Fill Color 255,226,160,60 | StrokeWidth 2 | Stroke Color 255,236,190,230"][!UpdateMeter Btn{n}][!Redraw]',
          f'MouseLeaveAction=[!SetOption Btn{n} Shape "{cell} | Fill Color 0,0,0,1 | StrokeWidth 0"][!UpdateMeter Btn{n}][!Redraw]', ""]
os.makedirs(os.path.join(SK, "Scene"), exist_ok=True)
open(os.path.join(SK, "Scene", "Scene.ini"), "w", encoding="ascii", newline="\r\n").write("\r\n".join(o) + "\r\n")
print("Scene skin written:", len(ZONES), "zone,", len(TRANSPORT), "transport buttons")

# =================================================== Systems: wall-mounted instrument panel (walnut case, brass screws, chrome-bezel needle dials, nixie window)
W, H = 372, 240
R = 38
dials = [("CPU", 66, "mCPU", "CPU"), ("MEM", 186, "mRAMp", "MEMORY"), ("DSK", 306, "mDp", "DISK C: FREE")]
s = ["[Rainmeter]", "Update=1000", "AccurateText=1", "DynamicWindowSize=1", "@Include=#@#Theme.inc", "",
     "[Variables]", "Tier=ALL SYSTEMS GO", "TierCol=224,210,178", "",
     "[mCPU]", "Measure=CPU", "",
     "[mRAM]", "Measure=PhysicalMemory", "[mRAMt]", "Measure=PhysicalMemory", "Total=1",
     "[mRAMp]", "Measure=Calc", "DynamicVariables=1", "MinValue=0", "MaxValue=100", "Formula=([mRAM]/[mRAMt])*100", "",
     "[mDfree]", "Measure=FreeDiskSpace", "Drive=C:", "UpdateDivider=30", "[mDtot]", "Measure=FreeDiskSpace", "Drive=C:", "Total=1", "UpdateDivider=30",
     "[mDp]", "Measure=Calc", "DynamicVariables=1", "MinValue=0", "MaxValue=100", "Formula=([mDfree]/[mDtot])*100", "UpdateDivider=30", "",
     "[mIn]", "Measure=NetIn", "[mOut]", "Measure=NetOut", "",
     "[mUp]", "Measure=Uptime", 'Format="%4!i!d %3!02i!h %2!02i!m"', "",
     "[mLoad]", "Measure=Calc", "DynamicVariables=1", "MinValue=0", "MaxValue=100", "Formula=[mCPU]",
     "IfCondition=mLoad>=70", "IfTrueAction=[!SetVariable Tier \"RUNNING HOT\"][!SetVariable TierCol \"255,120,70\"]",
     "IfCondition2=(mLoad<70) && (mLoad>=30)", "IfTrueAction2=[!SetVariable Tier \"WORKING HARD\"][!SetVariable TierCol \"255,200,90\"]",
     "IfCondition3=mLoad<30", "IfTrueAction3=[!SetVariable Tier \"ALL SYSTEMS GO\"][!SetVariable TierCol \"150,220,120\"]", "IfConditionMode=1", ""]
cy = 92
for key, cx, meas, label in dials:
    s += [f"[a{key}]", "Measure=Calc", "DynamicVariables=1", f"Formula=(-2.356+4.712*{meas}/100)", "MinValue=-3", "MaxValue=3",
          f"[x{key}]", "Measure=Calc", "DynamicVariables=1", f"Formula=({cx}+31*sin(a{key}))", "MinValue=0", "MaxValue=2000",
          f"[y{key}]", "Measure=Calc", "DynamicVariables=1", f"Formula=({cy}-31*cos(a{key}))", "MinValue=0", "MaxValue=2000",
          f"[xt{key}]", "Measure=Calc", "DynamicVariables=1", f"Formula=({cx}-9*sin(a{key}))", "MinValue=0", "MaxValue=2000",
          f"[yt{key}]", "Measure=Calc", "DynamicVariables=1", f"Formula=({cy}+9*cos(a{key}))", "MinValue=0", "MaxValue=2000", ""]
screws = []
for i, (sx, sy) in enumerate([(11, 11), (W - 11, 11), (11, H - 11), (W - 11, H - 11)]):
    screws += [f"Shape{20 + i * 2}=Ellipse {sx},{sy},4 | Fill Color #Brass# | StrokeWidth 1 | Stroke Color 70,48,14",
               f"Shape{21 + i * 2}=Line {sx - 2.4},{sy - 1.2},{sx + 2.4},{sy + 1.2} | StrokeWidth 1 | Stroke Color 70,48,14"]
s += ["[BG]", "Meter=Shape",
      f"Shape=Rectangle 0,0,{W},{H},12 | Fill LinearGradient Wd | StrokeWidth 3 | Stroke Color #WoodEdge#",
      "Wd=90 | 150,104,66 ; 0.0 | 112,74,46 ; 0.5 | 78,48,28 ; 1.0",
      f"Shape2=Rectangle 4,4,{W - 8},{H - 8},9 | Fill Color 0,0,0,0 | StrokeWidth 1 | Stroke Color 255,214,160,90",
      f"Shape3=Rectangle 14,34,{W - 28},{H - 48},8 | Fill Color 224,210,178 | StrokeWidth 2 | Stroke Color #WoodEdge#",      # cream inset face
      f"Shape4=Rectangle 22,6,{W - 44},22,5 | Fill Color #Brass# | StrokeWidth 2 | Stroke Color 70,48,14",                     # brass title plate
      f"Shape5=Rectangle 26,10,{W - 52},14,3 | Fill Color 0,0,0,0 | StrokeWidth 1 | Stroke Color 255,236,170,140",
      f"Shape6=Rectangle 24,152,{W - 48},50,7 | Fill Color #Glass# | StrokeWidth 3 | Stroke Color #WoodEdge#"] + screws + [f"W={W}", f"H={H}", "",
      "[Title]", "Meter=String", "Text=KAIJU SYSTEMS", f"X={W // 2}", "Y=11", "StringAlign=Center", "FontFace=#Font#", "FontSize=10", "FontColor=58,36,10", "StringStyle=Bold", "AntiAlias=1", ""]
for key, cx, meas, label in dials:
    face = [f"Shape=Ellipse {cx},{cy},{R + 5} | Fill LinearGradient Ch | StrokeWidth 1.5 | Stroke Color 60,56,50",
            "Ch=135 | 236,234,226 ; 0.0 | 140,138,130 ; 1.0",
            f"Shape2=Ellipse {cx},{cy},{R + 1} | Fill Color 38,28,20 | StrokeWidth 0",
            f"Shape3=Ellipse {cx},{cy},{R - 1} | Fill Color 250,243,220 | StrokeWidth 0"]
    for k in range(11):
        a = math.radians(-135 + 27 * k)
        r0, r1 = (R - 10, R - 3) if k % 5 == 0 else (R - 6, R - 3)
        red = "176,50,22" if k >= 9 else "52,34,20"
        face.append(f"Shape{k + 4}=Line {cx + r0 * math.sin(a):.1f},{cy - r0 * math.cos(a):.1f},{cx + r1 * math.sin(a):.1f},{cy - r1 * math.cos(a):.1f} | StrokeWidth {2 if k % 5 == 0 else 1} | Stroke Color {red}")
    face.append(f"Shape16=Ellipse {cx - 10},{cy - 18},14,6 | Fill Color 255,255,255,70 | StrokeWidth 0")
    s += [f"[Dial{key}]", "Meter=Shape"] + face + [f"W={W}", f"H={H}", ""]
    s += [f"[Needle{key}]", "Meter=Shape", "DynamicVariables=1",
          f"Shape=Line [xt{key}],[yt{key}],[x{key}],[y{key}] | StrokeWidth 2.6 | Stroke Color 176,50,22 | StrokeEndCap Round | StrokeStartCap Round",
          f"Shape2=Ellipse {cx},{cy},5 | Fill Color 40,30,24 | StrokeWidth 1 | Stroke Color 190,170,120", f"W={W}", f"H={H}", ""]
    s += [f"[Val{key}]", "Meter=String", f"MeasureName={meas}", "NumOfDecimals=0", "Text=%1%", f"X={cx}", f"Y={cy + 12}", "StringAlign=Center", "FontFace=#Font#", "FontSize=8", "FontColor=#Ink#", "StringStyle=Bold", "AntiAlias=1", "",
          f"[Lbl{key}]", "Meter=String", f"Text={label}", f"X={cx}", f"Y={cy + R + 8}", "StringAlign=Center", "FontFace=#Font#", "FontSize=7.5", "FontColor=#Ink#", "StringStyle=Bold", "AntiAlias=1", ""]
s += ["[PLlabel]", "Meter=String", "Text=UPTIME", "X=34", "Y=157", "FontFace=#Font#", "FontSize=7", "FontColor=#AmberDim#", "StringStyle=Bold", "AntiAlias=1", "",
      "[PL]", "Meter=String", "MeasureName=mUp", "X=34", "Y=170", "FontFace=#Font#", "FontSize=13", "FontColor=#Amber#", "StringStyle=Bold", "AntiAlias=1", "",
      "[TierTxt]", "Meter=String", "Text=#Tier#", "DynamicVariables=1", f"X={W - 34}", "Y=172", "StringAlign=Right", "FontFace=#Font#", "FontSize=10", "FontColor=#TierCol#", "StringStyle=Bold", "AntiAlias=1", "",
      "[NetIn]", "Meter=String", "MeasureName=mIn", "AutoScale=1", "NumOfDecimals=1", "Text=NET IN  %1B/s", "X=26", "Y=209", "FontFace=#Font#", "FontSize=8", "FontColor=#Ink#", "StringStyle=Bold", "AntiAlias=1", "",
      "[NetOut]", "Meter=String", "MeasureName=mOut", "AutoScale=1", "NumOfDecimals=1", "Text=NET OUT  %1B/s", f"X={W - 26}", "Y=209", "StringAlign=Right", "FontFace=#Font#", "FontSize=8", "FontColor=#Ink#", "StringStyle=Bold", "AntiAlias=1", ""]
os.makedirs(os.path.join(SK, "Systems"), exist_ok=True)
open(os.path.join(SK, "Systems", "Systems.ini"), "w", encoding="ascii", newline="\r\n").write("\r\n".join(s) + "\r\n")
print("Systems skin written (walnut instrument panel)")

# =================================================== Cabinet: pop-up card that holds the old desktop shortcuts (opened by clicking the floor cabinet)
FIX = rf'["powershell.exe" -NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File "{K.scripts}\fix_desktop.ps1"][!DeactivateConfig "KaijuHUD\Cabinet"]'
items = [("FIX DESKTOP", FIX), ("RECYCLE BIN", '["explorer.exe" "shell:RecycleBinFolder"][!DeactivateConfig "KaijuHUD\\Cabinet"]'),
         ("POWER OFF", rf'["powershell.exe" -NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File "{K.scripts}\kaiju_power.ps1" off][!DeactivateConfig "KaijuHUD\Cabinet"]'),
         ("CLOSE DRAWER", '[!DeactivateConfig "KaijuHUD\\Cabinet"]')]
CW, RH = 230, 28
CH = 40 + RH * len(items) + 10
k = ["[Rainmeter]", "Update=1000", "AccurateText=1", "@Include=#@#Theme.inc", "",
     "[BG]", "Meter=Shape", f"Shape=Rectangle 0,0,{CW},{CH},9 | Fill Color #Cream# | StrokeWidth 3 | Stroke Color #WoodEdge#",
     f"Shape2=Rectangle 0,0,{CW},30,9 | Fill Color #CreamDk# | StrokeWidth 0", f"Shape3=Line 4,30,{CW - 4},30 | StrokeWidth 1 | Stroke Color #Ink#,110", f"W={CW}", f"H={CH}", "",
     "[Title]", "Meter=String", "Text=KAIJU FILE CABINET", "X=14", "Y=8", "FontFace=#Font#", "FontSize=10", "FontColor=#Ink#", "StringStyle=Bold", "AntiAlias=1", ""]
for i, (label, act) in enumerate(items):
    y = 40 + i * RH
    rect = f"Rectangle 10,{y},{CW - 20},{RH - 4},5"
    k += [f"[Row{i}]", "Meter=Shape", f"Shape={rect} | Fill Color #Bakelite# | StrokeWidth 1 | Stroke Color #WoodEdge#", f"LeftMouseUpAction={act}",
          f'MouseOverAction=[!SetOption Row{i} Shape "{rect} | Fill Color 90,62,36 | StrokeWidth 1 | Stroke Color #Amber#"][!UpdateMeter Row{i}][!Redraw]',
          f'MouseLeaveAction=[!SetOption Row{i} Shape "{rect} | Fill Color #Bakelite# | StrokeWidth 1 | Stroke Color #WoodEdge#"][!UpdateMeter Row{i}][!Redraw]', "",
          f"[Lbl{i}]", "Meter=String", f"Text={label}", f"X={CW // 2}", f"Y={y + 5}", "StringAlign=Center", "FontFace=#Font#", "FontSize=9", "FontColor=#Cream#", "StringStyle=Bold", "AntiAlias=1", "Hidden=0", ""]
os.makedirs(os.path.join(SK, "Cabinet"), exist_ok=True)
open(os.path.join(SK, "Cabinet", "Cabinet.ini"), "w", encoding="ascii", newline="\r\n").write("\r\n".join(k) + "\r\n")
print("Cabinet skin written:", len(items), "rows, size", CW, "x", CH)
