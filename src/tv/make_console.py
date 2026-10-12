"""Generate the KAIJU SYSTEMS console skin (Rainmeter): a small homemade-looking game console that sits by the TV.
Click it -> games\console_click.ps1: opens the KAIJU GAME GUIDE, or (while a game is playing in the TV) stops the game.
The hover tag reads KAIJU GAME GUIDE normally and STOP GAME while state\tv_game_state.txt says 1.
Placement is written by scripts\apply_all.ps1 (on top of the TV, right of the antennas).
Skin is 150x80; the console body sits on the bottom edge. Run:  python make_console.py   then   Rainmeter.exe !Refresh "KaijuHUD\\Console"
"""
import os, sys
sys.path.insert(0, os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "scripts"))
from kaiju_config import K        # install paths + choices, read from config.json (scripts/kaiju_config.py)

SK = os.environ.get("KAIJU_SKINS_DIR") or K.skins_dir
CLICK = rf'["powershell.exe" -NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File "{K.games}\console_click.ps1"]'
GAMESTATE = os.path.join(K.state, "tv_game_state.txt")      # always exists: 1 while a game plays in the TV, else 0
W, H = 150, 80
BX, BY, BW, BH = 17, 36, 116, 40            # body: x, y, width, height (feet end at y = H)
CX = BX + BW // 2

EDGE = "36,22,12"
GRADS = ["Wood=90 | 158,106,64 ; 0.0 | 126,82,48 ; 0.45 | 92,58,32 ; 1.0",
         "Chrome=90 | 250,248,240 ; 0.0 | 176,174,166 ; 0.55 | 120,118,110 ; 1.0",
         "Cream=90 | 238,226,196 ; 0.0 | 206,190,154 ; 1.0",
         "Plastic=90 | 96,94,90 ; 0.0 | 52,50,48 ; 1.0",
         "Gold=90 | 238,204,120 ; 0.0 | 168,128,56 ; 1.0"]


def cap(x, color):                            # a system button: metal rim, coloured cap, gloss
    return [f"Ellipse {x},{BY + 18},5.2 | Fill Color 30,26,22 | StrokeWidth 1 | Stroke Color 170,164,150",
            f"Ellipse {x},{BY + 18},3.6 | Fill Color {color} | StrokeWidth 0",
            f"Ellipse {x - 1},{BY + 17},1.2 | Fill Color 255,255,255,150 | StrokeWidth 0"]


o = ["[Rainmeter]", "Update=1000", "AccurateText=1", "@Include=#@#Theme.inc", "",
     "[mGame]", "Measure=WebParser", f"URL=File://{GAMESTATE}", r'RegExp="(?siU)(\d)"', "UpdateRate=1", "StringIndex=1",
     'Substitute="0":"KAIJU GAME GUIDE","1":"STOP GAME"', "",
     "[Shadow]", "Meter=Shape",
     f"Shape=Ellipse {CX},{H - 3},{BW // 2 + 8},5 | Fill Color 0,0,0,45 | StrokeWidth 0",
     f"Shape2=Ellipse {CX},{H - 3},{BW // 2 + 1},3.4 | Fill Color 0,0,0,80 | StrokeWidth 0", f"W={W}", f"H={H}", ""]

# rubber feet
o += ["[Feet]", "Meter=Shape", f"Shape=Rectangle {BX + 9},{BY + BH - 1},16,5,2 | Fill Color 22,18,14 | StrokeWidth 0",
      f"Shape2=Rectangle {BX + BW - 25},{BY + BH - 1},16,5,2 | Fill Color 22,18,14 | StrokeWidth 0", f"W={W}", f"H={H}", ""]

# cartridge standing in the slot: grey plastic, notched corner, cream label with a little sunburst
cx0, cy0, cw, ch = CX - 22, BY - 26, 44, 34
o += ["[Cart]", "Meter=Shape",
      f"Shape=Path Cart | Fill LinearGradient Plastic | StrokeWidth 1.2 | Stroke Color 18,16,14",
      f"Cart={cx0},{cy0 + 6} | LineTo {cx0 + 6},{cy0} | LineTo {cx0 + cw},{cy0} | LineTo {cx0 + cw},{cy0 + ch} | LineTo {cx0},{cy0 + ch} | ClosePath 1",
      f"Shape2=Rectangle {cx0 + 5},{cy0 + 6},{cw - 10},19,2 | Fill LinearGradient Cream | StrokeWidth 1 | Stroke Color 120,100,64",
      f"Shape3=Rectangle {cx0 + 5},{cy0 + 6},{cw - 10},5,2 | Fill Color 204,66,38 | StrokeWidth 0",
      f"Shape4=Ellipse {cx0 + cw // 2},{cy0 + 19},4 | Fill Color 232,164,40 | StrokeWidth 0",
      f"Shape5=Line {cx0 + cw // 2},{cy0 + 12},{cx0 + cw // 2},{cy0 + 14} | StrokeWidth 1 | Stroke Color 150,70,30",
      f"Shape6=Line {cx0 + cw // 2 - 8},{cy0 + 19},{cx0 + cw // 2 - 6},{cy0 + 19} | StrokeWidth 1 | Stroke Color 150,70,30",
      f"Shape7=Line {cx0 + cw // 2 + 6},{cy0 + 19},{cx0 + cw // 2 + 8},{cy0 + 19} | StrokeWidth 1 | Stroke Color 150,70,30",
      f"Shape8=Rectangle {cx0 + 8},{cy0 + ch - 7},{cw - 16},4,1 | Fill Color 190,150,70 | StrokeWidth 0",
      f"Shape9=Rectangle {cx0 + 2},{cy0 + 2},3,{ch - 6},1 | Fill Color 255,255,255,40 | StrokeWidth 0",
      *GRADS[3:4], *GRADS[2:3], f"W={W}", f"H={H}", ""]

body = [f"Shape=Rectangle {BX},{BY},{BW},{BH},7 | Fill LinearGradient Wood | StrokeWidth 2 | Stroke Color {EDGE}",
        # chrome top bezel with the cartridge slot
        f"Shape2=Rectangle {BX + 1},{BY + 1},{BW - 2},9,5 | Fill LinearGradient Chrome | StrokeWidth 1 | Stroke Color 70,66,60",
        f"Shape3=Rectangle {CX - 25},{BY + 3},50,5,2 | Fill Color 12,10,8 | StrokeWidth 0",
        f"Shape4=Line {BX + 8},{BY + 10.5},{BX + BW - 8},{BY + 10.5} | StrokeWidth 1 | Stroke Color 255,235,200,70",
        # wood grain and a soft sheen
        f"Shape5=Line {BX + 5},{BY + 17},{BX + BW - 5},{BY + 17} | StrokeWidth 1 | Stroke Color 70,40,20,55",
        f"Shape6=Line {BX + 5},{BY + 27},{BX + BW - 5},{BY + 28} | StrokeWidth 1 | Stroke Color 200,150,100,45",
        f"Shape7=Line {BX + 5},{BY + 35},{BX + BW - 5},{BY + 34} | StrokeWidth 1 | Stroke Color 70,40,20,50",
        f"Shape8=Rectangle {BX + 4},{BY + 12},{BW - 8},3,1 | Fill Color 255,230,190,22 | StrokeWidth 0",
        # brass-rimmed cream name plate
        f"Shape9=Rectangle {BX + 8},{BY + 14},84,17,3 | Fill LinearGradient Gold | StrokeWidth 1 | Stroke Color {EDGE}",
        f"Shape10=Rectangle {BX + 10},{BY + 16},80,13,2 | Fill LinearGradient Cream | StrokeWidth 1 | Stroke Color 120,96,60,160"]
n = 11
# the one power lamp, with a soft glow (everything stays inside the body: right edge is BX + BW)
body += [f"Shape{n}=Ellipse {BX + 104},{BY + 22},7 | Fill Color 255,70,50,55 | StrokeWidth 0",
         f"Shape{n + 1}=Ellipse {BX + 104},{BY + 22},3.2 | Fill Color 232,52,36 | StrokeWidth 1 | Stroke Color {EDGE}",
         f"Shape{n + 2}=Ellipse {BX + 103},{BY + 21},1.1 | Fill Color 255,200,190,210 | StrokeWidth 0"]
n += 3
for px in (BX + 11, BX + 27):
    body += [f"Shape{n}=Rectangle {px},{BY + 32},12,6,2 | Fill LinearGradient Plastic | StrokeWidth 1 | Stroke Color 150,142,126",
             f"Shape{n + 1}=Rectangle {px + 2},{BY + 34},8,2,1 | Fill Color 10,8,6 | StrokeWidth 0"]
    n += 2
for k in range(4):
    body.append(f"Shape{n}=Line {BX + 96 + k * 4},{BY + 31},{BX + 96 + k * 4},{BY + 36} | StrokeWidth 1.2 | Stroke Color {EDGE},150"); n += 1
body += GRADS + [f"W={W}", f"H={H}", ""]
o += ["[Body]", "Meter=Shape"] + body

o += ["[Name]", "Meter=String", "Text=KAIJU SYSTEMS", f"X={BX + 50}", f"Y={BY + 18.5}", "StringAlign=Center", "FontFace=#Font#", "FontSize=5.8",
      "FontColor=#Ink#", "StringStyle=Bold", "AntiAlias=1", ""]

zone = f"Rectangle {BX - 4},{BY - 30},{BW + 8},{BH + 34},9"
o += ["[Zone]", "Meter=Shape", f"Shape={zone} | Fill Color 0,0,0,1 | StrokeWidth 0", f"LeftMouseUpAction={CLICK}",
      f'MouseOverAction=[!SetOption Zone Shape "{zone} | Fill Color 255,226,160,40 | StrokeWidth 3 | Stroke Color 255,236,190,210"][!UpdateMeter Zone][!ShowMeter Tag][!Redraw]',
      f'MouseLeaveAction=[!SetOption Zone Shape "{zone} | Fill Color 0,0,0,1 | StrokeWidth 0"][!UpdateMeter Zone][!HideMeter Tag][!Redraw]',
      f"W={W}", f"H={H}", "",
      "[Tag]", "Meter=String", "MeasureName=mGame", f"X={W // 2}", "Y=0", "StringAlign=Center", "FontFace=#Font#", "FontSize=7", "FontColor=#Ink#",
      "StringStyle=Bold", "SolidColor=#Cream#,245", "Padding=7,3,7,3", "Hidden=1", "AntiAlias=1", ""]

os.makedirs(os.path.join(SK, "Console"), exist_ok=True)
open(os.path.join(SK, "Console", "Console.ini"), "w", encoding="ascii", newline="\r\n").write("\r\n".join(o) + "\r\n")
print("Console skin written:", W, "x", H, "-", n, "body shapes")
