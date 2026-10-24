-- ~/.config/hypr/monitors.lua
--
-- Internal panel name varies by hardware (eDP-1, eDP-2, eDP-3, LVDS-1, etc.).
-- Configure via HYPR_INTERNAL_PANEL env var, or it will be auto-detected at
-- runtime by the display-scale script which persists to monitors.conf.
-- Falls back to "eDP-2" (common on this hardware).
local internal_panel = os.getenv("HYPR_INTERNAL_PANEL") or "eDP-2"

-- Internal laptop panel. The mode is given explicitly rather than as
-- "preferred", so the panel's 144 Hz refresh is used instead of whatever rate
-- the EDID advertises first.
--
-- Specific rules must come before the wildcard below: Hyprland applies the first
-- matching rule.
hl.monitor({
  output   = internal_panel,
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
