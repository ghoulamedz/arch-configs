-- ~/.config/hypr/monitors.lua
--
-- List the outputs Hyprland can see, with every mode each supports:
--   hyprctl monitors all

-- Internal laptop panel. The mode is given explicitly rather than as
-- "preferred", so the panel's 144 Hz refresh is used instead of whatever rate
-- the EDID advertises first.
--
-- Specific rules must come before the wildcard below: Hyprland applies the first
-- matching rule.
hl.monitor({
  output   = "eDP-2",
  mode     = "1920x1080@144",
  position = "0x0",
  scale    = 1,
})

-- Anything else that gets plugged in: its preferred mode, placed automatically.
-- Without this an unknown output can come up with no mode set.
hl.monitor({
  output   = "",
  mode     = "preferred",
  position = "auto",
  scale    = "auto",
})

-- Adding an external monitor later — uncomment and adjust the output name:
--
--   hl.monitor({ output = "DP-1",     mode = "2560x1440@144", position = "1920x0", scale = 1 })
--   hl.monitor({ output = "HDMI-A-1", mode = "preferred",     position = "auto",   scale = 1 })
--
-- Per-monitor scaling is also switchable at runtime with the `display-scale`
-- script, which cycles the focused output through 1, 1.25, 1.6 and 2.
