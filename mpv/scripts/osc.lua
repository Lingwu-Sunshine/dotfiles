--[[
   参考链接：https://github.com/po5/thumbfast/blob/vanilla-osc/player/lua/osc.lua
--]]
mp.set_property("osc", "no")
if mp.get_script_name() ~= "osc" then
   -- reclaim osc script name after the builtin osc unloads
   local script_path = debug.getinfo(1, "S").source:match("^@?(.*[\\/]osc%.lua)$")
   if script_path then
      mp.add_timeout(0.05, function()
			mp.commandv("load-script", script_path)
      end)
      return
   end
end
local assdraw = require 'mp.assdraw'
local msg = require 'mp.msg'
local opt = require 'mp.options'
local utils = require 'mp.utils'

--
-- Parameters
--
-- default user option values
-- do not touch, change them in osc.conf
local user_opts = {
   showwindowed = true,        -- show OSC when windowed?
   showfullscreen = true,      -- show OSC when fullscreen?
   idlescreen = true,          -- show mpv logo on idle
   scalewindowed = 1,          -- scaling of the controller when windowed
   scalefullscreen = 1,        -- scaling of the controller when fullscreen
   scaleforcedwindow = 2,      -- scaling when rendered on a forced window
   vidscale = true,            -- scale the controller with the video?
   valign = 0.8,               -- vertical alignment, -1 (top) to 1 (bottom)
   halign = 0,                 -- horizontal alignment, -1 (left) to 1 (right)
   barmargin = 0,              -- vertical margin of top/bottombar
   boxalpha = 80,              -- alpha of the background box,
   -- 0 (opaque) to 255 (fully transparent)
   hidetimeout = 500,          -- duration in ms until the OSC hides if no
   -- mouse movement. enforced non-negative for the
   -- user, but internally negative is "always-on".
   fadeduration = 200,         -- duration of fade out in ms, 0 = no fade
   deadzonesize = 0.5,         -- size of deadzone
   minmousemove = 0,           -- minimum amount of pixels the mouse has to
   -- move between ticks to make the OSC show up
   iamaprogrammer = false,     -- use native mpv values and disable OSC
   -- internal track list management (and some
   -- functions that depend on it)
   layout = "bottombar",
   seekbarstyle = "bar",       -- bar, diamond or knob
   seekbarhandlesize = 0.6,    -- size ratio of the diamond and knob handle
   seekrangestyle = "inverted",-- bar, line, slider, inverted or none
   seekrangeseparate = true,   -- whether the seekranges overlay on the bar-style seekbar
   seekrangealpha = 200,       -- transparency of seekranges
   seekbarkeyframes = true,    -- use keyframes when dragging the seekbar
   scrollcontrols = true,      -- allow scrolling when hovering certain OSC elements
   title = "${media-title}",   -- string compatible with property-expansion
   -- to be shown as OSC title
   tooltipborder = 1,          -- border of tooltip in bottom/topbar
   timetotal = false,          -- display total time instead of remaining time?
   remaining_playtime = true,  -- display the remaining time in playtime or video-time mode
   -- playtime takes speed into account, whereas video-time doesn't
   timems = false,             -- display timecodes with milliseconds?
   tcspace = 100,              -- timecode spacing (compensate font size estimation)
   visibility = "auto",        -- only used at init to set visibility_mode(...)
   boxmaxchars = 80,           -- title crop threshold for box layout
   boxvideo = false,           -- apply osc_param.video_margins to video
   windowcontrols = "auto",    -- whether to show window controls
   windowcontrols_alignment = "right", -- which side to show window controls on
   greenandgrumpy = false,     -- disable santa hat
   livemarkers = true,         -- update seekbar chapter markers on duration change
   chapters_osd = true,        -- whether to show chapters OSD on next/prev
   playlist_osd = true,        -- whether to show playlist OSD on next/prev
   chapter_fmt = "Chapter: %s", -- chapter print format for seekbar-hover. "no" to disable
   unicodeminus = false,       -- whether to use the Unicode minus sign character
}

-- read options from config and command-line
opt.read_options(user_opts, "osc", function(list) update_options(list) end)

local osc_param = { -- calculated by osc_init()
   playresy = 0,                           -- canvas size Y
   playresx = 0,                           -- canvas size X
   display_aspect = 1,
   unscaled_y = 0,
   areas = {},
   video_margins = {
      l = 0, r = 0, t = 0, b = 0,         -- left/right/top/bottom
   },
}

local osc_styles = {
   bigButtons = "{\\blur0\\bord0\\1c&HFFFFFF\\3c&HFFFFFF\\fs50\\fnmpv-osd-symbols}",
   smallButtonsL = "{\\blur0\\bord0\\1c&HFFFFFF\\3c&HFFFFFF\\fs19\\fnmpv-osd-symbols}",
   smallButtonsLlabel = "{\\fscx105\\fscy105\\fn" .. mp.get_property("options/osd-font") .. "}",
   smallButtonsR = "{\\blur0\\bord0\\1c&HFFFFFF\\3c&HFFFFFF\\fs30\\fnmpv-osd-symbols}",
   topButtons = "{\\blur0\\bord0\\1c&HFFFFFF\\3c&HFFFFFF\\fs12\\fnmpv-osd-symbols}",

   elementDown = "{\\1c&H999999}",
   timecodes = "{\\blur0\\bord0\\1c&HFFFFFF\\3c&HFFFFFF\\fs20}",
   vidtitle = "{\\blur0\\bord0\\1c&HFFFFFF\\3c&HFFFFFF\\fs12\\q2}",
   box = "{\\rDefault\\blur0\\bord1\\1c&H000000\\3c&HFFFFFF}",

   topButtonsBar = "{\\blur0\\bord0\\1c&HFFFFFF\\3c&HFFFFFF\\fs18\\fnmpv-osd-symbols}",
   smallButtonsBar = "{\\blur0\\bord0\\1c&HFFFFFF\\3c&HFFFFFF\\fs28\\fnmpv-osd-symbols}",
   timecodesBar = "{\\blur0\\bord0\\1c&HFFFFFF\\3c&HFFFFFF\\fs27}",
   timePosBar = "{\\blur0\\bord".. user_opts.tooltipborder .."\\1c&HFFFFFF\\3c&H000000\\fs30}",
   vidtitleBar = "{\\blur0\\bord0\\1c&HFFFFFF\\3c&HFFFFFF\\fs18\\q2}",

   wcButtons = "{\\1c&HFFFFFF\\fs24\\fnmpv-osd-symbols}",
   wcTitle = "{\\1c&HFFFFFF\\fs24\\q2}",
   wcBar = "{\\1c&H000000}",
}

local function create_osd_overlay(...)
   if not mp.create_osd_overlay then return end
   return mp.create_osd_overlay(...)
end

-- internal states, do not touch
local state = {
   showtime,                               -- time of last invocation (last mouse move)
   osc_visible = false,
   anistart,                               -- time when the animation started
   anitype,                                -- current type of animation
   animation,                              -- current animation alpha
   mouse_down_counter = 0,                 -- used for softrepeat
   active_element = nil,                   -- nil = none, 0 = background, 1+ = see elements[]
   active_event_source = nil,              -- the "button" that issued the current event
   rightTC_trem = not user_opts.timetotal, -- if the right timecode should display total or remaining time
   tc_ms = user_opts.timems,               -- Should the timecodes display their time with milliseconds
   mp_screen_sizeX, mp_screen_sizeY,       -- last screen-resolution, to detect resolution changes to issue reINITs
   initREQ = false,                        -- is a re-init request pending?
   marginsREQ = false,                     -- is a margins update pending?
   last_mouseX, last_mouseY,               -- last mouse position, to detect significant mouse movement
   mouse_in_window = false,
   message_text,
   message_hide_timer,
   fullscreen = false,
   tick_timer = nil,
   tick_last_time = 0,                     -- when the last tick() was run
   hide_timer = nil,
   cache_state = nil,
   idle = false,
   enabled = true,
   input_enabled = true,
   showhide_enabled = false,
   windowcontrols_buttons = false,
   dmx_cache = 0,
   using_video_margins = false,
   border = true,
   maximized = false,
   osd = create_osd_overlay("ass-events"),
   chapter_list = {},                      -- sorted by time
}

local thumbfast = {
   width = 0,
   height
