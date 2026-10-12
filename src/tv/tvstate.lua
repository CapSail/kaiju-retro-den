-- Mini TV helper:
--  * writes live state (volume, mute, pause, subtitles, running, episode title) for the Rainmeter remote
--  * remembers the last episode (tv_last.txt) and saves the position every 10 s, so playback resumes exactly where it stopped
--  * remembers volume / mute / subtitle choices (tv_prefs.txt)
-- install folder = two levels above mpv.exe (<install>\tools\mpv\mpv.exe); state files live in <install>\state
local exe_dir = (mp.command_native({"expand-path", "~~exe_dir/"}) or ""):gsub("/", "\\"):gsub("\\+$", "")
local root = exe_dir:match("^(.*)\\tools\\mpv$") or exe_dir
local dir = root .. "\\state\\"
local statepath = dir .. "tv_state.txt"
local prefspath = dir .. "tv_prefs.txt"
local lastpath = dir .. "tv_last.txt"
local ready = false   -- true once saved prefs have been applied (so start-up defaults don't overwrite them)

-- Readable title from a file name: "Dragon Ball Z Kai - S01E02 - Name" -> "S01E02 - Name";
-- movie release names -> "Title (Year)" (everything after the year is dropped)
local function title_of()
  local p = mp.get_property("path") or ""
  local name = p:match("([^\\/]+)$") or p
  name = name:gsub("%.[^%.]+$", "")
  name = name:gsub("^Dragon Ball Z Kai %- ", "")
  if not name:find("^S%d%dE%d%d") then
    local s, e, year = name:find("[%.%s%(%[_](%d%d%d%d)[%.%s%)%]_]")
    if not s then s, e, year = name:find("[%.%s%(%[_](%d%d%d%d)$") end
    if s and (year:find("^19") or year:find("^20")) then
      local t = name:sub(1, s - 1):gsub("[%._]", " "):gsub("^%s+", ""):gsub("%s+$", "")
      if #t > 0 then name = t .. " (" .. year .. ")" end
    else
      name = name:gsub("%b[]", ""):gsub("[%._]", " "):gsub("%s+", " ")
    end
  end
  name = name:gsub("[;\r\n]", " ")
  return name
end

local function write_state(run)
  local vol = math.floor((mp.get_property_number("volume", 0) or 0) + 0.5)
  local mute = mp.get_property_bool("mute") and 1 or 0
  local pause = mp.get_property_bool("pause") and 1 or 0
  local subs = mp.get_property_bool("sub-visibility") and 1 or 0
  local hid = mp.get_property_bool("window-minimized") and 1 or 0
  local f = io.open(statepath, "w")
  if f then
    f:write(string.format("vol=%d;mute=%d;pause=%d;subs=%d;run=%d;hid=%d;title=%s", vol, mute, pause, subs, run, hid, title_of()))
    f:close()
  end
end

local function save_prefs()
  if not ready then return end
  local vol = math.floor((mp.get_property_number("volume", 35) or 35) + 0.5)
  local mute = mp.get_property_bool("mute") and 1 or 0
  local subs = mp.get_property_bool("sub-visibility") and 1 or 0
  local f = io.open(prefspath, "w")
  if f then f:write(string.format("vol=%d;mute=%d;subs=%d", vol, mute, subs)); f:close() end
end

local function load_prefs()
  local f = io.open(prefspath, "r")
  if f then
    local s = f:read("*a"); f:close()
    local v, m, sb = s:match("vol=(%d+)"), s:match("mute=(%d)"), s:match("subs=(%d)")
    if v then mp.set_property_number("volume", tonumber(v)) end
    if m then mp.set_property_bool("mute", m == "1") end
    if sb then mp.set_property_bool("sub-visibility", sb == "1") end
  end
  ready = true
end

for _, p in ipairs({"volume", "mute", "pause", "sub-visibility", "window-minimized"}) do
  mp.observe_property(p, "native", function() write_state(1); save_prefs() end)
end

mp.register_event("file-loaded", function()
  if not ready then load_prefs() end
  local pos = mp.get_property_number("playlist-pos", 0) or 0
  local f = io.open(lastpath, "w")
  if f then f:write(tostring(pos)); f:close() end
  write_state(1)
end)

mp.add_periodic_timer(10, function()
  if mp.get_property("path") then mp.command("write-watch-later-config") end
end)

-- BACK button: more than 5 s into an episode -> restart it; otherwise -> previous episode (restart if already on the first)
mp.register_script_message("kaiju-back", function()
  local t = mp.get_property_number("time-pos", 0) or 0
  local pos = mp.get_property_number("playlist-pos", 0) or 0
  if t > 5 or pos <= 0 then
    mp.commandv("seek", "0", "absolute")
    mp.osd_message("RESTART", 0.8)
  else
    mp.commandv("playlist-prev")
    mp.osd_message("PREVIOUS EPISODE", 0.8)
  end
end)

mp.register_event("shutdown", function() write_state(0) end)
write_state(1)
