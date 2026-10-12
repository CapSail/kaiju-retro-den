-- Hover controls for the mini TV: a tiny fullscreen button and a scrub bar (click or drag to pick the time).
-- Drawn ONLY while the pointer is over the TV; gone the moment it leaves. A plain click elsewhere still pauses/plays.
-- While the TV is fullscreen, the Rainmeter TV frame is deactivated (it is topmost and would sit over the video); it returns on exit.
-- install folder = two levels above mpv.exe (<install>\tools\mpv\mpv.exe)
local exe_dir = (mp.command_native({"expand-path", "~~exe_dir/"}) or ""):gsub("/", "\\"):gsub("\\+$", "")
local root = exe_dir:match("^(.*)\\tools\\mpv$") or exe_dir
local rainmeter = root .. "\\tools\\Rainmeter\\Rainmeter.exe"
local toggle_tv = root .. "\\tv\\toggle_tv.ps1"
local ov = mp.create_osd_overlay("ass-events")
local hovering, dragging, down_elsewhere = false, false, false
local mx, my = 0, 0

local function col(r, g, b) return string.format("&H%02X%02X%02X&", b, g, r) end
local ORANGE, DIM, WHITE, BLACK = col(205, 172, 105), col(80, 80, 80), col(238, 228, 205), col(0, 0, 0)

local function rect(x1, y1, x2, y2, c, a)
  return string.format("{\\an7\\pos(0,0)\\bord0\\shad0\\1c%s\\1a&H%02X&\\p1}m %d %d l %d %d %d %d %d %d{\\p0}\n",
    c, a or 0, x1, y1, x2, y1, x2, y2, x1, y2)
end

local function text(x, y, s, size, c)
  return string.format("{\\an4\\pos(%d,%d)\\fs%d\\bord1\\shad0\\1c%s\\3c%s\\fnConsolas}%s\n", x, y, size, c, BLACK, s)
end

local function fmt(t)
  t = math.max(0, math.floor((t or 0) + 0.5))
  local h, m, s = math.floor(t / 3600), math.floor(t % 3600 / 60), t % 60
  if h > 0 then return string.format("%d:%02d:%02d", h, m, s) end
  return string.format("%d:%02d", m, s)
end

-- layout, scaled from a 225 px tall reference so it looks the same in the small window and in fullscreen
local function geom()
  local w, h = mp.get_osd_size()
  if not w or w == 0 or h == 0 then return nil end
  local s = h / 225
  return { w = w, h = h, s = s, x0 = 10 * s, x1 = w - 40 * s, by = h - 13 * s, bh = 5 * s,
           fx1 = w - 30 * s, fy1 = h - 24 * s, fx2 = w - 8 * s, fy2 = h - 6 * s }
end
local function in_fs(g, x, y) return x >= g.fx1 - 4 * g.s and x <= g.fx2 + 4 * g.s and y >= g.fy1 - 4 * g.s and y <= g.fy2 + 4 * g.s end
local function in_bar(g, x, y) return x >= g.x0 - 6 * g.s and x <= g.x1 + 6 * g.s and y >= g.h - 24 * g.s and y <= g.h - 5 * g.s end

local function seek_to(g, x)
  local dur = mp.get_property_number("duration", 0) or 0
  if dur <= 0 then return end
  local f = math.min(1, math.max(0, (x - g.x0) / (g.x1 - g.x0)))
  mp.commandv("seek", tostring(f * 100), "absolute-percent+keyframes")
end

local idle_hidden, last_move = false, 0   -- fullscreen: the bar shows only while the mouse moves, and goes away after 2.5 s without movement

local function draw()
  if not hovering or idle_hidden then ov:remove(); return end
  local g = geom()
  if not g then return end
  local s = g.s
  local dur = mp.get_property_number("duration", 0) or 0
  local pos = mp.get_property_number("time-pos", 0) or 0
  local frac = (dur > 0) and math.min(1, math.max(0, pos / dur)) or 0
  local a = ""
  a = a .. rect(0, g.h - 32 * s, g.w, g.h, BLACK, 0x70)                                   -- soft backdrop
  a = a .. rect(g.x0, g.by, g.x1, g.by + g.bh, DIM, 0x30)                                 -- track
  a = a .. rect(g.x0, g.by, g.x0 + (g.x1 - g.x0) * frac, g.by + g.bh, ORANGE, 0)         -- played part
  local hx = g.x0 + (g.x1 - g.x0) * frac
  a = a .. rect(hx - 2 * s, g.by - 2.5 * s, hx + 2 * s, g.by + g.bh + 2.5 * s, WHITE, 0) -- handle
  -- time readout: the time under the pointer while it is on the bar (the "picker"), otherwise the current time
  if in_bar(g, mx, my) and dur > 0 then
    local f = math.min(1, math.max(0, (mx - g.x0) / (g.x1 - g.x0)))
    a = a .. text(g.x0, g.h - 22 * s, "go to " .. fmt(f * dur) .. " / " .. fmt(dur), 9 * s, ORANGE)
  else
    a = a .. text(g.x0, g.h - 22 * s, fmt(pos) .. " / " .. fmt(dur), 9 * s, WHITE)
  end
  -- fullscreen button: four corner brackets
  local c = in_fs(g, mx, my) and WHITE or ORANGE
  local L, T = 5 * s, 2 * s
  for _, k in ipairs({ { g.fx1, g.fy1, 1, 1 }, { g.fx2, g.fy1, -1, 1 }, { g.fx1, g.fy2, 1, -1 }, { g.fx2, g.fy2, -1, -1 } }) do
    local x, y, dx, dy = k[1], k[2], k[3], k[4]
    a = a .. rect(math.min(x, x + dx * L), math.min(y, y + dy * T), math.max(x, x + dx * L), math.max(y, y + dy * T), c, 0)
    a = a .. rect(math.min(x, x + dx * T), math.min(y, y + dy * L), math.max(x, x + dx * T), math.max(y, y + dy * L), c, 0)
  end
  ov.res_x, ov.res_y = g.w, g.h
  ov.data = a
  ov:update()
end

mp.observe_property("mouse-pos", "native", function(_, m)
  if not m then return end
  if m.x ~= mx or m.y ~= my then last_move = mp.get_time(); idle_hidden = false end   -- the mouse actually moved: show the bar again
  mx, my = m.x, m.y
  hovering = m.hover and true or false
  if dragging then
    local g = geom()
    if g then seek_to(g, mx) end
  end
  draw()
end)
for _, p in ipairs({ "time-pos", "duration", "pause", "osd-dimensions" }) do
  mp.observe_property(p, "native", function() if hovering then draw() end end)
end
mp.add_periodic_timer(0.4, function()
  if hovering and not idle_hidden and not dragging and mp.get_property_bool("fullscreen") and (mp.get_time() - last_move) > 2.5 then
    idle_hidden = true; draw()
  end
end)

-- left button: fullscreen button / drag the bar / plain click = pause-play
mp.add_forced_key_binding("MBTN_LEFT", "tv_left", function(e)
  local g = geom()
  if not g then return end
  local x, y = mp.get_mouse_pos()
  mx, my = x, y
  if e.event == "down" then
    if in_fs(g, x, y) then
      mp.commandv("cycle", "fullscreen"); down_elsewhere = false
    elseif in_bar(g, x, y) then
      dragging = true; down_elsewhere = false; seek_to(g, x); draw()
    else
      down_elsewhere = true
    end
  elseif e.event == "up" then
    if dragging then
      dragging = false; draw()
    elseif down_elsewhere then
      down_elsewhere = false; mp.commandv("cycle", "pause")
    end
  end
end, { complex = true })

-- the TV never takes keyboard focus, so Esc cannot leave fullscreen: right click does it (the corner button works too)
mp.add_forced_key_binding("MBTN_RIGHT", "tv_right", function()
  if mp.get_property_bool("fullscreen") then mp.set_property_bool("fullscreen", false) end
end)

-- while fullscreen, hide EVERY desktop widget (they are drawn above the player: the TV frame, the gauge panel, the scene's buttons and the console),
-- and bring them all back afterwards
local WIDGETS = { { "KaijuHUD\\TVRemote", "TVRemote.ini" }, { "KaijuHUD\\Console", "Console.ini" },
                  { "KaijuHUD\\Systems", "Systems.ini" }, { "KaijuHUD\\Scene", "Scene.ini" } }
local function widgets(show)
  for _, w in ipairs(WIDGETS) do
    if show then mp.commandv("run", rainmeter, "!ActivateConfig", w[1], w[2])
    else mp.commandv("run", rainmeter, "!DeactivateConfig", w[1]) end
  end
end
local first = true
local was_full = false
mp.observe_property("fullscreen", "bool", function(_, fs)
  if first then first = false; was_full = fs and true or false; return end
  if fs == nil then return end
  if fs and not was_full then
    widgets(false)
    mp.commandv("run", "powershell.exe", "-NoProfile", "-WindowStyle", "Hidden", "-ExecutionPolicy", "Bypass",
                "-File", toggle_tv, "-Action", "fsenter")   -- truly fullscreen: take the foreground so the taskbar hides
    idle_hidden = false; last_move = mp.get_time()
  elseif (not fs) and was_full then
    widgets(true)
    mp.commandv("run", "powershell.exe", "-NoProfile", "-WindowStyle", "Hidden", "-ExecutionPolicy", "Bypass",
                "-File", toggle_tv, "-Action", "fsexit")   -- ...back behind every app on the picture, taskbar back on top, focus back to you
    idle_hidden = false
  end
  was_full = fs and true or false
end)
mp.register_event("shutdown", function()
  if was_full then widgets(true) end
end)
