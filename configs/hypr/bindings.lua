-- ~/.config/hypr/bindings.lua
--
-- Every keybinding. Reference: https://wiki.hypr.land/Configuring/Binds/
--
-- The set is Omarchy's, with every omarchy-* command replaced by an Arch package
-- or a script in ~/.local/bin. The deliberate differences are marked "DIFFERS"
-- below. bind() comes from helpers.lua and records the description that
-- keybindings.md lists.

-- ---------------------------------------------------------------------------
-- Programs
-- ---------------------------------------------------------------------------
-- Change these to change which application a binding opens.
local TERMINAL = "ghostty"
local BROWSER  = "chromium"
local FILES    = "nautilus"
local EDITOR   = "code"
local LAUNCHER = "fuzzel"

-- Pickers always open in foot rather than in $TERMINAL: foot's --app-id is what
-- gives each picker its own window class, and windows.lua matches on that class
-- to float and centre it. The naming convention `float-<script>` couples the two
-- files — keep them in step.
local function picker(script)
  return "foot --app-id=float-" .. script .. " -e " .. script
end

-- ---------------------------------------------------------------------------
-- Applications
-- ---------------------------------------------------------------------------

bind("SUPER + RETURN",             "Terminal",            TERMINAL)
bind("SUPER + SHIFT + RETURN",     "Browser",             BROWSER)
bind("SUPER + SHIFT + B",          "Browser",             BROWSER)
bind("SUPER + SHIFT + ALT + B",    "Browser (private)",   BROWSER .. " --incognito")
bind("SUPER + SHIFT + F",          "File manager",        FILES)
bind("SUPER + ALT + SHIFT + F",    "File manager (home)", FILES .. " " .. (os.getenv("HOME") or ""))
bind("SUPER + SHIFT + N",          "Editor",              EDITOR)
bind("SUPER + SPACE",              "Application launcher", LAUNCHER)

-- Terminals and TUIs. -A attaches to the existing session if there is one, so
-- this does not accumulate tmux servers.
bind("SUPER + ALT + RETURN",       "Terminal with tmux",  TERMINAL .. " -e tmux new-session -A -s main")
bind("SUPER + CTRL + RETURN",      "herdr",               TERMINAL .. " -e herdr")
bind("SUPER + SHIFT + D",          "lazydocker",          TERMINAL .. " -e lazydocker")
bind("SUPER + SHIFT + O",          "Obsidian",            "obsidian")
bind("SUPER + SHIFT + Q",          "Calculator",          "qalculate-qt")
bind("XF86Calculator",             "Calculator",          "qalculate-qt", { locked = true })

-- ---------------------------------------------------------------------------
-- The pickers (see ~/.local/bin and keybindings.md)
-- ---------------------------------------------------------------------------

bind("SUPER + K",                  "Keybindings cheatsheet", picker("menu-keybindings"))
bind("SUPER + CTRL + E",           "Emoji picker",           picker("emoji-picker"))
bind("SUPER + CTRL + V",           "Clipboard history",      picker("clipboard-history"))
bind("SUPER + ESCAPE",             "Power menu",             picker("power-menu"))
bind("XF86PowerOff",               "Power menu",             picker("power-menu"), { locked = true })
bind("SUPER + CTRL + SPACE",       "Wallpaper picker",       picker("wallpaper-picker"))
bind("SUPER + SHIFT + SPACE",      "Next wallpaper",         "wallpaper-cycle next")
bind("SUPER + CTRL + G",           "VA-API backend",         picker("vaapi-backend"))
bind("SUPER + SHIFT + P",          "Install package",        picker("pkg-install"))
bind("SUPER + SHIFT + A",          "Install AUR package",    picker("pkg-aur-install"))
bind("SUPER + SHIFT + R",          "Remove package",         picker("pkg-remove"))
bind("SUPER + CTRL + U",           "Update system",          picker("system-update"))
bind("SUPER + CTRL + D",           "Display scale",          picker("display-scale"))
bind("SUPER + SHIFT + T",          "Text size",              picker("text-size"))

-- ---------------------------------------------------------------------------
-- Windows
-- ---------------------------------------------------------------------------

bind("SUPER + W",                  "Close window",        hl.dsp.window.close())

-- Close every window on every workspace. hyprctl clients returns one JSON object
-- per window; jq pulls out the addresses and each is closed by address.
bind("CTRL + ALT + DELETE",        "Close all windows",
  [[hyprctl clients -j | jq -r '.[].address' | xargs -r -I{} hyprctl dispatch closewindow address:{}]])

bind("SUPER + J",                  "Toggle window split", hl.dsp.layout("togglesplit"))
bind("SUPER + P",                  "Pseudo window",       hl.dsp.window.pseudo())
bind("SUPER + T",                  "Toggle floating",     hl.dsp.window.float({ action = "toggle" }))
bind("SUPER + F",                  "Full screen",         hl.dsp.window.fullscreen({ mode = "fullscreen" }))
bind("SUPER + ALT + F",            "Full width (maximized)", hl.dsp.window.fullscreen({ mode = "maximized" }))

-- Float, pin and centre in one step: a "pop the window out of the layout"
-- gesture. --batch runs the dispatchers in one round trip.
bind("SUPER + O",                  "Pop window out (float and pin)",
  [[hyprctl --batch 'dispatch togglefloating; dispatch pin; dispatch centerwindow']])

-- DIFFERS: Omarchy switches workspace layouts with a generated Lua toggle. This
-- calls ~/.local/bin/toggle-layout, which flips general:layout between dwindle
-- and master.
bind("SUPER + L",                  "Toggle workspace layout", "toggle-layout")

-- Focus
bind("SUPER + LEFT",               "Focus left",          hl.dsp.focus({ direction = "l" }))
bind("SUPER + RIGHT",              "Focus right",         hl.dsp.focus({ direction = "r" }))
bind("SUPER + UP",                 "Focus up",            hl.dsp.focus({ direction = "u" }))
bind("SUPER + DOWN",               "Focus down",          hl.dsp.focus({ direction = "d" }))

-- Swap the focused window with its neighbour.
bind("SUPER + SHIFT + LEFT",       "Swap window left",    hl.dsp.window.swap({ direction = "l" }))
bind("SUPER + SHIFT + RIGHT",      "Swap window right",   hl.dsp.window.swap({ direction = "r" }))
bind("SUPER + SHIFT + UP",         "Swap window up",      hl.dsp.window.swap({ direction = "u" }))
bind("SUPER + SHIFT + DOWN",       "Swap window down",    hl.dsp.window.swap({ direction = "d" }))

-- Resize the focused window. code:20 and code:21 are the minus and equals keys
-- on the number row, which avoids clashing with the arrow-key bindings above.
bind("SUPER + code:20",            "Shrink window left",  hl.dsp.window.resize({ x = -100, y = 0, relative = true }))
bind("SUPER + code:21",            "Grow window right",   hl.dsp.window.resize({ x = 100,  y = 0, relative = true }))
bind("SUPER + SHIFT + code:20",    "Shrink window up",    hl.dsp.window.resize({ x = 0, y = -100, relative = true }))
bind("SUPER + SHIFT + code:21",    "Grow window down",    hl.dsp.window.resize({ x = 0, y = 100,  relative = true }))
bind("SUPER + CTRL + code:20",     "Shrink window a lot", hl.dsp.window.resize({ x = -300, y = 0, relative = true }))
bind("SUPER + CTRL + code:21",     "Grow window a lot",   hl.dsp.window.resize({ x = 300,  y = 0, relative = true }))

-- Cycle windows and monitors.
bind("ALT + TAB",                  "Next window",         hl.dsp.window.cycle_next())
bind("ALT + SHIFT + TAB",          "Previous window",     hl.dsp.window.cycle_next({ next = false }))
bind("CTRL + ALT + TAB",           "Next monitor",        hl.dsp.focus({ monitor = "+1" }))
bind("CTRL + ALT + SHIFT + TAB",   "Previous monitor",    hl.dsp.focus({ monitor = "-1" }))

-- Drag and resize with the mouse.
bind("SUPER + mouse:272",          "Move window",         hl.dsp.window.drag(),   { mouse = true })
bind("SUPER + mouse:273",          "Resize window",       hl.dsp.window.resize(), { mouse = true })

-- ---------------------------------------------------------------------------
-- Workspaces
-- ---------------------------------------------------------------------------
-- code:10 through code:19 are the 1..0 keys on the number row. Using key codes
-- rather than key names keeps the bindings working on the AZERTY layout, where
-- the number row requires Shift for some symbols.
for ws = 1, 10 do
  local key = "code:" .. tostring(ws + 9)
  bind("SUPER + " .. key,             "Workspace " .. ws, hl.dsp.focus({ workspace = tostring(ws) }))
  bind("SUPER + SHIFT + " .. key,     "Move window to workspace " .. ws,
    hl.dsp.window.move({ workspace = tostring(ws) }))
  -- follow = false moves the window without switching to that workspace.
  bind("SUPER + SHIFT + ALT + " .. key, "Move window silently to workspace " .. ws,
    hl.dsp.window.move({ workspace = tostring(ws), follow = false }))
end

-- Scroll through workspaces with the wheel.
bind("SUPER + mouse_down",         "Workspace forward",   hl.dsp.focus({ workspace = "e+1" }))
bind("SUPER + mouse_up",           "Workspace back",      hl.dsp.focus({ workspace = "e-1" }))

bind("SUPER + TAB",                "Next workspace",      hl.dsp.focus({ workspace = "e+1" }))
bind("SUPER + SHIFT + TAB",        "Previous workspace",  hl.dsp.focus({ workspace = "e-1" }))
bind("SUPER + CTRL + TAB",         "Former workspace",    hl.dsp.focus({ workspace = "previous" }))

-- Scratchpad: a hidden workspace for a window you want on hand everywhere.
bind("SUPER + S",                  "Toggle scratchpad",   hl.dsp.workspace.toggle_special("scratchpad"))
bind("SUPER + ALT + S",            "Move window to scratchpad",
  hl.dsp.window.move({ workspace = "special:scratchpad", follow = false }))

-- Send a whole workspace to another monitor.
bind("SUPER + SHIFT + ALT + LEFT",  "Move workspace to left monitor",  hl.dsp.workspace.move({ monitor = "l" }))
bind("SUPER + SHIFT + ALT + RIGHT", "Move workspace to right monitor", hl.dsp.workspace.move({ monitor = "r" }))
bind("SUPER + SHIFT + ALT + UP",    "Move workspace to up monitor",    hl.dsp.workspace.move({ monitor = "u" }))
bind("SUPER + SHIFT + ALT + DOWN",  "Move workspace to down monitor",  hl.dsp.workspace.move({ monitor = "d" }))

-- ---------------------------------------------------------------------------
-- Window groups (tabbed stacks of windows)
-- ---------------------------------------------------------------------------

bind("SUPER + G",                  "Toggle window group",  hl.dsp.group.toggle())
bind("SUPER + ALT + G",            "Leave group",          hl.dsp.window.move({ out_of_group = true }))
bind("SUPER + ALT + LEFT",         "Move into group left", hl.dsp.window.move({ into_group = "l" }))
bind("SUPER + ALT + RIGHT",        "Move into group right", hl.dsp.window.move({ into_group = "r" }))
bind("SUPER + ALT + UP",           "Move into group up",   hl.dsp.window.move({ into_group = "u" }))
bind("SUPER + ALT + DOWN",         "Move into group down", hl.dsp.window.move({ into_group = "d" }))
bind("SUPER + ALT + TAB",          "Next window in group", hl.dsp.group.next())
bind("SUPER + ALT + SHIFT + TAB",  "Previous in group",    hl.dsp.group.prev())
bind("SUPER + ALT + mouse_down",   "Next window in group", hl.dsp.group.next())
bind("SUPER + ALT + mouse_up",     "Previous in group",    hl.dsp.group.prev())

-- Jump straight to the Nth window in the current group.
for i = 1, 5 do
  bind("SUPER + ALT + code:" .. tostring(i + 9), "Group window " .. i,
    hl.dsp.group.active({ index = i }))
end

-- ---------------------------------------------------------------------------
-- Clipboard
-- ---------------------------------------------------------------------------
-- Universal copy/paste: terminals use different chords than GUI applications,
-- so clipboard-send inspects the focused window's class and sends the right one.
bind("SUPER + C",                  "Copy (universal)",     "clipboard-send copy")
bind("SUPER + V",                  "Paste (universal)",    "clipboard-send paste")
bind("SUPER + X",                  "Cut (universal)",      "clipboard-send cut")

-- ---------------------------------------------------------------------------
-- Audio
-- ---------------------------------------------------------------------------
-- osd-volume wraps pamixer and posts a transient mako notification, which is the
-- replacement for Omarchy's on-screen display.
bind("XF86AudioRaiseVolume",       "Volume up",           "osd-volume +5%", { locked = true, repeating = true })
bind("XF86AudioLowerVolume",       "Volume down",         "osd-volume 5%-", { locked = true, repeating = true })
bind("XF86AudioMute",              "Mute",                "osd-volume toggle", { locked = true })
bind("ALT + XF86AudioRaiseVolume", "Volume up (fine)",    "osd-volume +1",  { locked = true, repeating = true })
bind("ALT + XF86AudioLowerVolume", "Volume down (fine)",  "osd-volume -1",  { locked = true, repeating = true })
bind("XF86AudioMicMute",           "Mute microphone",     "pamixer --default-source -t", { locked = true })
bind("SHIFT + XF86AudioMute",      "Switch audio output", "audio-output switch", { locked = true })

bind("XF86AudioPlay",              "Play / pause",        "playerctl play-pause", { locked = true })
bind("XF86AudioPause",             "Play / pause",        "playerctl play-pause", { locked = true })
bind("XF86AudioNext",              "Next track",          "playerctl next",       { locked = true })
bind("XF86AudioPrev",              "Previous track",      "playerctl previous",   { locked = true })
bind("XF86AudioStop",              "Stop",                "playerctl stop",       { locked = true })

-- ---------------------------------------------------------------------------
-- Display and keyboard backlight
-- ---------------------------------------------------------------------------
bind("XF86MonBrightnessUp",        "Brightness up",       "osd-brightness +5%", { locked = true, repeating = true })
bind("XF86MonBrightnessDown",      "Brightness down",     "osd-brightness 5%-", { locked = true, repeating = true })
bind("SHIFT + XF86MonBrightnessUp",   "Brightness maximum", "osd-brightness 100%", { locked = true, repeating = true })
bind("SHIFT + XF86MonBrightnessDown", "Brightness minimum", "osd-brightness 1%",   { locked = true, repeating = true })

-- The keyboard backlight device may not exist on this laptop; brightnessctl
-- exits non-zero and nothing happens, which is the intended behaviour.
bind("XF86KbdBrightnessUp",        "Keyboard backlight up",
  "brightnessctl -d '*::kbd_backlight' set +10%", { locked = true, repeating = true })
bind("XF86KbdBrightnessDown",      "Keyboard backlight down",
  "brightnessctl -d '*::kbd_backlight' set 10%-", { locked = true, repeating = true })
bind("XF86KbdLightOnOff",          "Keyboard backlight off",
  "brightnessctl -d '*::kbd_backlight' set 0", { locked = true })

-- ---------------------------------------------------------------------------
-- Screenshots, capture and toggles
-- ---------------------------------------------------------------------------

bind("PRINT",                      "Screenshot (full)",   "screenshot-full")
bind("SUPER + CTRL + C",           "Screenshot region",   "screenshot-region")
bind("SUPER + CTRL + PRINT",       "Extract text (OCR)",  "extract-text")
bind("SUPER + PRINT",              "Colour picker",       "pkill hyprpicker || hyprpicker -a")

-- Monitor scaling, the two-step form. SUPER + CTRL + D above opens a picker over
-- the same values.
bind("SUPER + SLASH",              "Monitor scale up",    "display-scale up")
bind("SUPER + ALT + SLASH",        "Monitor scale down",  "display-scale down")

bind("SUPER + CTRL + L",           "Lock screen",         "hyprlock")
bind("SUPER + CTRL + I",           "Toggle keep-awake",   "toggle-idle")
bind("SUPER + CTRL + N",           "Toggle night light",  "toggle-nightlight")

-- Panels that would be Quickshell surfaces in Omarchy. Each opens the
-- corresponding standalone application instead.
bind("SUPER + CTRL + B",           "Bluetooth",           "blueman-manager")
bind("SUPER + CTRL + A",           "Audio",               "pavucontrol")
bind("SUPER + CTRL + W",           "Network",             "foot --app-id=float-nmtui -e nmtui")

bind("SUPER + comma",              "Dismiss last notification", "makoctl dismiss")
bind("SUPER + SHIFT + comma",      "Dismiss all notifications", "makoctl dismiss --all")

-- ---------------------------------------------------------------------------
-- Touchpad
-- ---------------------------------------------------------------------------
-- XF86TouchpadOn / Off / Toggle are NOT carried over from Omarchy.
--
-- They can only work by flipping a device property at runtime, and the runtime
-- form is the hyprlang `device[...]` selector — which Hyprland deprecated in
-- favour of Lua in 0.55, and whose exact separator could not be verified against
-- this build. Shipping three bindings that error on every keypress would be
-- worse than shipping none.
--
-- The supported way to disable a device is a static declaration in input.lua
-- using hl.device(); see the commented example there.

-- Lid switch. Closing the lid turns the internal panel off; opening it brings it
-- back. `locked = true` means these fire even while the screen is locked.
bind("switch:on:Lid Switch",       "Lid closed",  "hyprctl keyword monitor eDP-2,disable", { locked = true })
bind("switch:off:Lid Switch",      "Lid opened",  "hyprctl keyword monitor eDP-2,1920x1080@144,0x0,1", { locked = true })
