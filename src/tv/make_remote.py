"""Generate the Rainmeter TV skin: a 1970s wood-cabinet TV with rabbit ears. The mini player (mpv) is the picture tube; the remote is the TV's side control panel.
Look: walnut cabinet with grain, black rubber bezel round the screen, recessed dark side panel with a cream KAIJU plate, black bakelite buttons
with cream lettering, brass volume slider, pilot lamp, a dark "channel" window under the picture for the movie title, two little wooden legs.
No neon, straight and level, no tooltips. Live state comes from tv_state.txt (written by mpv's tvstate.lua).
Rerun after editing, then:  Rainmeter.exe !Refresh "KaijuHUD\\TVRemote"

Window is 452 x 357:  y 0-56 rabbit ears | y 56-72 top bezel | y 72-297 picture (300x225 at x 16, where the mpv window sits) | y 297-345 title window + cabinet bottom
                      | y 345-357 legs.  Side panel x 330-438, y 72-297.
Placement (apply_all.ps1 / toggle_tv.ps1): the TV stands on the credenza, centred on it: frame X = credenza centre - 226, frame bottom (legs) = credenza top
= floorY - 42 S0. The picture sits at frame + (16, 72). Credenza is 480 wide in the wallpaper (retro_den\\index.html).
TV off or hidden -> the picture is dark glass (click it to turn the TV on). TV playing -> the picture is transparent and the video shows through.
"""
import os, sys
sys.path.insert(0, os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "scripts"))
from kaiju_config import K        # install paths + choices, read from config.json (scripts/kaiju_config.py)
PS = rf'"powershell.exe" -NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File "{K.tv}\toggle_tv.ps1"'
STATE = os.path.join(K.state, "tv_state.txt")
os.makedirs(K.state, exist_ok=True)
if not os.path.exists(STATE):
    open(STATE, "w").write("vol=35;mute=0;pause=0;subs=1;run=0;hid=0;title=")

# ---- vintage palette (r,g,b)
WOOD, WOOD_HI, WOOD_LO, WOOD_EDGE = "112,74,46", "150,104,66", "70,44,26", "36,22,12"
BEZEL, BEZEL_RIM = "20,18,16", "150,144,132"
CHROME = "196,194,186"
CREAM, CREAM_DK, INK = "224,210,178", "198,182,148", "52,34,20"
BTN, BTN_HOV, BTN_RIM, BTN_TXT = "30,27,25", "66,58,50", "168,162,150", "236,224,196"
BRASS, GROOVE = "184,148,78", "40,30,22"
PANEL = "58,38,24"
LAMP_ON, LAMP_OFF = "255,226,160", "78,64,50"
W, H = 452, 357
SX, SY, SW, SH = 16, 72, 300, 225      # the picture (where the mpv window sits)
BODY_BOTTOM = 345
FONT = "Courier New"

o = ["[Rainmeter]", "Update=1000", "AccurateText=1", "DynamicWindowSize=1", "@Include=#@#Theme.inc", "",
     "[mS]", "Measure=WebParser", f"URL=File://{STATE}",
     r'RegExp="(?si)vol=(\d+);mute=(\d);pause=(\d);subs=(\d);run=(\d);hid=(\d);title=([^\r\n]*)"', "UpdateRate=1", "Disabled=0", ""]
for name, idx, extra in (("mVol", 1, ["MinValue=0", "MaxValue=100"]),
                         ("mMute", 2, ['Substitute="0":"SOUND","1":"MUTED"']),
                         ("mPause", 3, ['Substitute="0":"PAUSE","1":"PLAY"']),
                         ("mSubs", 4, ['Substitute="1":"SUBS ON","0":"SUBS OFF"']),
                         ("mRun", 5, ['Substitute="0":"OFF","1":"ON"']),
                         ("mHid", 6, ['Substitute="0":"0","1":"1"']),
                         ("mHidT", 6, ['Substitute="0":"HIDE","1":"SHOW"']),
                         ("mGlassMsg", 6, ['Substitute="0":"KAIJU TV  (click to turn on)","1":"KAIJU TV  (click to show)"']),
                         ("mTitle", 7, ['Substitute="":"Nothing playing"'])):
    o += [f"[{name}]", "Measure=WebParser", "URL=[mS]", f"StringIndex={idx}"] + extra + [""]
# dark glass when the TV is off OR hidden; transparent (video shows through) otherwise
o += ["[mGlass]", "Measure=Calc", "Formula=(mHid+(1-mRun))", "IfCondition=mGlass>0",
      "IfTrueAction=[!ShowMeter Glass][!ShowMeter GlassShine][!ShowMeter GlassText][!Redraw]",
      "IfFalseAction=[!HideMeter Glass][!HideMeter GlassShine][!HideMeter GlassText][!Redraw]", "IfConditionMode=1", ""]

# ---- legs, rabbit ears and cabinet
o += ["[Legs]", "Meter=Shape",
      f"Shape=Path L1 | Fill Color {WOOD_LO} | StrokeWidth 2 | Stroke Color {WOOD_EDGE}",
      f"L1=38,{BODY_BOTTOM - 4} | LineTo 70,{BODY_BOTTOM - 4} | LineTo 66,{H} | LineTo 42,{H} | ClosePath 1",
      f"Shape2=Path L2 | Fill Color {WOOD_LO} | StrokeWidth 2 | Stroke Color {WOOD_EDGE}",
      f"L2={W - 70},{BODY_BOTTOM - 4} | LineTo {W - 38},{BODY_BOTTOM - 4} | LineTo {W - 42},{H} | LineTo {W - 66},{H} | ClosePath 1",
      f"W={W}", f"H={H}", ""]
cx = W // 2
o += ["[Antenna]", "Meter=Shape",
      f"Shape=Line {cx},60,{cx - 70},8 | StrokeWidth 3 | Stroke Color {CHROME} | StrokeStartCap Round | StrokeEndCap Round",
      f"Shape2=Line {cx},60,{cx + 70},12 | StrokeWidth 3 | Stroke Color {CHROME} | StrokeStartCap Round | StrokeEndCap Round",
      f"Shape3=Ellipse {cx - 70},8,4,4 | Fill Color {CHROME} | StrokeWidth 0",
      f"Shape4=Ellipse {cx + 70},12,4,4 | Fill Color {CHROME} | StrokeWidth 0",
      f"Shape5=Ellipse {cx},62,34,12 | Fill Color {BEZEL} | StrokeWidth 2 | Stroke Color {CHROME},200",
      f"W={W}", f"H={H}", ""]
grain = []
ky = 6
hole_y1, hole_y2, hole_x2 = SY - 6, SY + SH + 6, SX + SW + 6        # the picture opening (plus bezel): grain lines must not run across it
for k, (y, c, a) in enumerate([(92, WOOD_LO, 70), (122, WOOD_HI, 55), (156, WOOD_LO, 60), (190, WOOD_HI, 45), (224, WOOD_LO, 65),
                               (258, WOOD_HI, 50), (288, WOOD_LO, 60), (318, WOOD_HI, 45)]):
    x1, x2 = (3 if k % 2 == 0 else 6), (W - 3 if k % 2 == 0 else W - 6)
    if hole_y1 <= y <= hole_y2: x1 = hole_x2 + 2
    grain.append(f"Shape{ky + k}=Line {x1},{y},{x2},{y} | StrokeWidth 1 | Stroke Color {c},{a}")
# The picture is the real player window UNDER this skin, so the skin must be see-through there: wood body and rubber bezel are built
# with a window cut out (Combine ... Exclude), never filled across the picture.
o += ["[Body]", "Meter=Shape",
      f"Shape=Rectangle 0,56,{W},{BODY_BOTTOM - 56},18 | Fill Color {WOOD} | StrokeWidth 0",
      f"Shape2=Rectangle {SX},{SY},{SW},{SH},10 | StrokeWidth 0",
      f"Shape3=Combine Shape | Exclude Shape2",
      f"Shape4=Rectangle 0,56,{W},{BODY_BOTTOM - 56},18 | Fill Color 0,0,0,0 | StrokeWidth 3 | Stroke Color {WOOD_EDGE}",
      f"Shape5=Rectangle 3,59,{W - 6},{BODY_BOTTOM - 62},15 | Fill Color 0,0,0,0 | StrokeWidth 1 | Stroke Color {WOOD_HI},120"] + grain + [
      f"Shape{ky + 8}=Rectangle {SX - 6},{SY - 6},{SW + 12},{SH + 12},14 | Fill Color {BEZEL} | StrokeWidth 0",                       # black rubber bezel ring
      f"Shape{ky + 9}=Rectangle {SX},{SY},{SW},{SH},10 | StrokeWidth 0",
      f"Shape{ky + 10}=Combine Shape{ky + 8} | Exclude Shape{ky + 9}",
      f"Shape{ky + 11}=Rectangle {SX - 6},{SY - 6},{SW + 12},{SH + 12},14 | Fill Color 0,0,0,0 | StrokeWidth 2 | Stroke Color {BEZEL_RIM},170",
      f"W={W}", f"H={H}", ""]

# ---- picture glass (shown only when the TV is off or hidden); click it to switch the TV on / show it
o += ["[Glass]", "Meter=Shape",
      f"Shape=Rectangle {SX},{SY},{SW},{SH},10 | Fill Color 20,26,24,255 | StrokeWidth 0",
      f"LeftMouseUpAction=[{PS}]", f"W={W}", f"H={H}", ""]
o += ["[GlassShine]", "Meter=Shape",
      "Shape=Path Shn | Fill Color 255,255,255,20 | StrokeWidth 0",
      f"Shn={SX + 16},{SY + 12} | LineTo {SX + 118},{SY + 12} | LineTo {SX + 62},{SY + 92} | LineTo {SX + 16},{SY + 92} | ClosePath 1",
      f"W={W}", f"H={H}", ""]
o += ["[GlassText]", "Meter=String", "MeasureName=mGlassMsg", f"X={SX + SW // 2}", f"Y={SY + SH // 2 - 6}",
      "StringAlign=Center", f"FontFace={FONT}", "FontSize=9", "FontColor=92,108,100", "AntiAlias=1", ""]

# ---- title window under the picture
o += ["[NowBG]", "Meter=Shape", f"Shape=Rectangle {SX},{SY + SH + 12},{SW},20,4 | Fill Color 38,30,24,255 | StrokeWidth 2 | Stroke Color {WOOD_EDGE}",
      f"W={W}", f"H={H}", "",
      "[NowPlaying]", "Meter=String", "MeasureName=mTitle", f"X={SX + 8}", f"Y={SY + SH + 15}", f"W={SW - 16}", "H=14", "ClipString=1",
      f"FontFace={FONT}", "FontSize=9", f"FontColor={BTN_TXT}", "AntiAlias=1", ""]

# ---- side control panel: recessed dark wood, cream KAIJU plate, pilot lamp, bakelite buttons, brass volume slider
PX, PY_, PW, PH = 330, 72, 108, 225
o += ["[Panel]", "Meter=Shape",
      f"Shape=Rectangle {PX},{PY_},{PW},{PH},9 | Fill Color {PANEL} | StrokeWidth 3 | Stroke Color {WOOD_EDGE}",
      f"Shape2=Rectangle {PX + 3},{PY_ + 3},{PW - 6},{PH - 6},7 | Fill Color 0,0,0,0 | StrokeWidth 1 | Stroke Color {WOOD_HI},90",
      f"Shape3=Rectangle {PX + 8},{PY_ + 8},{PW - 16},24,4 | Fill Color {CREAM} | StrokeWidth 2 | Stroke Color {WOOD_EDGE}",
      f"Shape4=Ellipse {PX + 6},{PY_ + 6},2 | Fill Color {BRASS} | StrokeWidth 0", f"Shape5=Ellipse {PX + PW - 6},{PY_ + 6},2 | Fill Color {BRASS} | StrokeWidth 0",
      f"Shape6=Ellipse {PX + 6},{PY_ + PH - 6},2 | Fill Color {BRASS} | StrokeWidth 0", f"Shape7=Ellipse {PX + PW - 6},{PY_ + PH - 6},2 | Fill Color {BRASS} | StrokeWidth 0",
      f"W={W}", f"H={H}", ""]
o += ["[Brand]", "Meter=String", "Text=KAIJU", f"X={PX + PW // 2}", f"Y={PY_ + 13}", "StringAlign=Center", f"FontFace={FONT}", "FontSize=11",
      f"FontColor={INK}", "StringStyle=Bold", "AntiAlias=1", ""]
LX, LY = PX + 16, PY_ + 48
o += ["[LampOff]", "Meter=Shape", f"Shape=Ellipse {LX},{LY},5.5 | Fill Color {LAMP_OFF} | StrokeWidth 2 | Stroke Color {INK},230", f"W={W}", f"H={H}", "",
      "[LampOn]", "Meter=Shape", f"Shape=Ellipse {LX},{LY},5.5 | Fill Color {LAMP_ON} | StrokeWidth 2 | Stroke Color {INK},230",
      "Hidden=1", f"W={W}", f"H={H}", "",
      "[mLamp]", "Measure=Calc", "Formula=mRun", "IfCondition=mLamp>0",
      "IfTrueAction=[!ShowMeter LampOn][!HideMeter LampOff][!Redraw]", "IfFalseAction=[!ShowMeter LampOff][!HideMeter LampOn][!Redraw]", "IfConditionMode=1", "",
      "[Status]", "Meter=String", "MeasureName=mRun", f"X={LX + 14}", f"Y={LY - 7}",
      f"FontFace={FONT}", "FontSize=9", f"FontColor={BTN_TXT}", "StringStyle=Bold", "AntiAlias=1", ""]

# (key, col, row, measure, action)   two columns x three rows
buttons = [
    ("Back",  0, 0, "",       f"[{PS} -Action back]"),
    ("Next",  1, 0, "",       f"[{PS} -Action next]"),
    ("Pause", 0, 1, "mPause", f"[{PS} -Action pause]"),
    ("Sound", 1, 1, "mMute",  f"[{PS} -Action mute]"),
    ("Subs",  0, 2, "mSubs",  f"[{PS} -Action subs]"),
    ("Hide",  1, 2, "mHidT",  f"[{PS}]"),
]
BW, BH = 46, 24
for key, col, row, meas, act in buttons:
    x, y = PX + 8 + col * 50, PY_ + 66 + row * 30
    base = f"Rectangle {x},{y},{BW},{BH},6 | Fill Color {BTN} | StrokeWidth 2 | Stroke Color {BTN_RIM}"
    hov = f"Rectangle {x},{y},{BW},{BH},6 | Fill Color {BTN_HOV} | StrokeWidth 2 | Stroke Color {CHROME}"
    o += [f"[Btn{key}]", "Meter=Shape", f"Shape={base}", f"LeftMouseUpAction={act}",
          f'MouseOverAction=[!SetOption Btn{key} Shape "{hov}"][!UpdateMeter Btn{key}][!Redraw]',
          f'MouseLeaveAction=[!SetOption Btn{key} Shape "{base}"][!UpdateMeter Btn{key}][!Redraw]', ""]
    t = [f"[Txt{key}]", "Meter=String"]
    t += [f"MeasureName={meas}"] if meas else [f"Text={key.upper()}"]
    t += [f"X={x + BW // 2}", f"Y={y + 6}", "StringAlign=Center", f"FontFace={FONT}", "FontSize=7",
          f"FontColor={BTN_TXT}", "StringStyle=Bold", "AntiAlias=1", ""]
    o += t

# volume: lettering, a dark groove and a brass fill (click the slider to set)
VY = PY_ + 160
o += ["[VolLabel]", "Meter=String", "Text=VOLUME", f"X={PX + 10}", f"Y={VY}", f"FontFace={FONT}", "FontSize=8",
      f"FontColor={BTN_TXT}", "StringStyle=Bold", "AntiAlias=1", "",
      "[VolVal]", "Meter=String", "MeasureName=mVol", "Text=%1%", "NumOfDecimals=0", f"X={PX + PW - 10}", f"Y={VY}", "StringAlign=Right",
      f"FontFace={FONT}", "FontSize=8", f"FontColor={BTN_TXT}", "StringStyle=Bold", "AntiAlias=1", "",
      "[VolBar]", "Meter=Bar", "MeasureName=mVol", f"X={PX + 10}", f"Y={VY + 16}", "W=88", "H=12", f"BarColor={BRASS}", f"SolidColor={GROOVE}",
      "BarOrientation=Horizontal", f"LeftMouseUpAction=[{PS} -Action volume -Value $MouseX:%$]", ""]

path = os.path.join(os.environ.get("KAIJU_SKINS_DIR") or K.skins_dir, "TVRemote")
os.makedirs(path, exist_ok=True)
open(os.path.join(path, "TVRemote.ini"), "w", encoding="ascii", newline="\r\n").write("\r\n".join(o) + "\r\n")
print("TV skin written (wood-cabinet TV: bezel, side control panel, title window, legs)")


