-- ~/.config/hypr/looknfeel.lua
--
-- Gaps, borders, blur, shadows, animations and the colour palette. Full option
-- reference: https://wiki.hypr.land/Configuring/Basics/Variables/

-- Tokyo Night. Defined once here and reused below, so changing a colour in one
-- place is enough.
local bg      = "rgba(1a1b26ff)"   -- window background
local fg      = "rgba(a9b1d6ff)"   -- foreground text
local blue    = "rgba(7aa2f7ee)"   -- primary accent
local purple  = "rgba(bb9af7ee)"   -- secondary accent
local comment = "rgba(565f89aa)"   -- inactive borders

hl.config({
  general = {
    -- Space between tiled windows (in) and between windows and the screen edge (out).
    gaps_in  = 5,
    gaps_out = 10,

    border_size = 2,

    -- Active borders are a gradient between the two accents; inactive windows get
    -- a muted grey so the focused window is obvious at a glance.
    col = {
      active_border   = { colors = { blue, purple }, angle = 45 },
      inactive_border = comment,
    },

    -- Resize by dragging a window's border or the gaps between windows. Useful
    -- while learning a tiling layout.
    resize_on_border = true,

    -- Tearing is left off: it only benefits fullscreen games and can cause
    -- visible tearing in everything else.
    allow_tearing = false,

    layout = "dwindle",
  },

  decoration = {
    rounding       = 8,
    rounding_power = 2,

    -- Focused windows are fully opaque; unfocused ones are very slightly
    -- transparent, which reads as depth without hurting readability.
    active_opacity   = 1.0,
    inactive_opacity = 0.97,

    shadow = {
      enabled      = true,
      range        = 12,
      render_power = 3,
      color        = "rgba(16161eee)",
    },

    blur = {
      enabled          = true,
      size             = 6,
      passes           = 2,
      vibrancy         = 0.1696,
      -- Reuse the already-blurred background instead of blurring behind every
      -- window separately. Much cheaper on a laptop.
      new_optimizations = true,
      xray             = true,
    },
  },

  animations = {
    enabled = true,
  },

  dwindle = {
    -- New windows split the focused window rather than the whole workspace.
    preserve_split = true,
  },

  master = {
    new_status = "master",
  },

  misc = {
    -- No Hyprland logo or anime wallpaper on an empty workspace; hyprpaper
    -- provides the background.
    force_default_wallpaper = 0,
    disable_hyprland_logo   = true,
    disable_splash_rendering = true,

    -- Raise a window when an application asks for focus, instead of only
    -- flashing its border.
    focus_on_activate = true,

    -- Variable refresh rate: render only when something changed. Saves power.
    vfr = true,
  },

  ecosystem = {
    -- Do not print the "new version available" notice on startup.
    no_update_news = true,
  },
})

-- Animation curves. Bezier points follow CSS cubic-bezier(x1, y1, x2, y2).
hl.curve("easeOutQuint",   { type = "bezier", points = { { 0.23, 1 },    { 0.32, 1 } } })
hl.curve("easeInOutCubic", { type = "bezier", points = { { 0.65, 0.05 }, { 0.36, 1 } } })
hl.curve("linear",         { type = "bezier", points = { { 0, 0 },       { 1, 1 } } })
hl.curve("almostLinear",   { type = "bezier", points = { { 0.5, 0.5 },   { 0.75, 1 } } })
hl.curve("quick",          { type = "bezier", points = { { 0.15, 0 },    { 0.1, 1 } } })

-- A spring, used for window open/close: slightly bouncier than a bezier, which
-- makes new windows feel physical rather than mechanical.
hl.curve("easy", { type = "spring", mass = 1, stiffness = 238.1191, damping = 24.21279333 })

-- Each animation targets one "leaf" of the render tree.
hl.animation({ leaf = "global",         enabled = true, speed = 10,   bezier = "default" })
hl.animation({ leaf = "border",         enabled = true, speed = 5.39, bezier = "easeOutQuint" })
hl.animation({ leaf = "windows",        enabled = true, speed = 4.79, spring = "easy" })
hl.animation({ leaf = "windowsIn",      enabled = true, speed = 4.1,  spring = "easy",  style = "popin 87%" })
hl.animation({ leaf = "windowsOut",     enabled = true, speed = 1.49, bezier = "linear", style = "popin 87%" })
hl.animation({ leaf = "fadeIn",         enabled = true, speed = 1.73, bezier = "almostLinear" })
hl.animation({ leaf = "fadeOut",        enabled = true, speed = 1.46, bezier = "almostLinear" })
hl.animation({ leaf = "fade",           enabled = true, speed = 3.03, bezier = "quick" })
hl.animation({ leaf = "layers",         enabled = true, speed = 3.81, bezier = "easeOutQuint" })
hl.animation({ leaf = "layersIn",       enabled = true, speed = 4,    bezier = "easeOutQuint", style = "fade" })
hl.animation({ leaf = "layersOut",      enabled = true, speed = 1.5,  bezier = "linear", style = "fade" })
hl.animation({ leaf = "fadeLayersIn",   enabled = true, speed = 1.79, bezier = "almostLinear" })
hl.animation({ leaf = "fadeLayersOut",  enabled = true, speed = 1.39, bezier = "almostLinear" })
hl.animation({ leaf = "workspaces",     enabled = true, speed = 1.94, bezier = "almostLinear", style = "fade" })
hl.animation({ leaf = "workspacesIn",   enabled = true, speed = 1.21, bezier = "almostLinear", style = "fade" })
hl.animation({ leaf = "workspacesOut",  enabled = true, speed = 1.94, bezier = "almostLinear", style = "fade" })
hl.animation({ leaf = "zoomFactor",     enabled = true, speed = 7,    bezier = "quick" })
