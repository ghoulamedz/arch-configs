-- ~/.config/hypr/input.lua
--
-- Keyboard, mouse and touchpad. Full option reference:
-- https://wiki.hypr.land/Configuring/Basics/Variables/#input

hl.config({
  input = {
    -- French AZERTY first (this is an AZERTY keyboard), Arabic second.
    -- kb_layout is a comma-separated list, and grp:alt_shift_toggle switches
    -- between the entries with Left Alt + Right Alt.
    kb_layout  = "fr,ara",
    kb_variant = "",
    kb_model   = "",
    kb_options = "compose:caps,grp:alt_shift_toggle",
    kb_rules   = "",

    -- compose:caps in kb_options turns Caps Lock into the compose key. That is
    -- what makes the ~/.XCompose sequences reachable — the Arabic ligatures,
    -- the diacritics, the Arabic-Indic digits and the emoji. It also means Caps
    -- Lock no longer capitalises; that is the trade being made here.

    -- Keyboard focus follows the mouse pointer.
    follow_mouse = 1,

    -- 0 disables pointer acceleration; this is a trackpad-first laptop and the
    -- acceleration curve is more trouble than it is worth at this size.
    sensitivity = 0,

    touchpad = {
      -- Two-finger scroll moves content the way a touch screen does.
      natural_scroll = true,

      -- Tap to click, and tap-and-drag for selecting.
      --
      -- NOTE the underscores: Hyprland's option names are tap_to_click and
      -- tap_and_drag. The libinput documentation calls them tap-to-click and
      -- tap-and-drag, and writing those here would be a Lua syntax error as well
      -- as the wrong option name — a bare hyphen is not allowed in a Lua key.
      tap_to_click = true,
      tap_and_drag = true,

      -- Ignore taps while typing, so resting a palm mid-sentence does nothing.
      disable_while_typing = true,

      -- One-finger click is left, two-finger is right, three is middle.
      -- This is a string, not a boolean: "lrm" is the only accepted value and
      -- it disables click interpretation based on finger position.
      clickfinger_behavior = "lrm",
    },
  },
})

-- Three-finger horizontal swipe switches workspaces.
hl.gesture({
  fingers   = 3,
  direction = "horizontal",
  action    = "workspace",
})

-- ---------------------------------------------------------------------------
-- Per-device configuration
-- ---------------------------------------------------------------------------
-- Since Hyprland 0.55 this is done with hl.device(), not the old hyprlang
-- `device[...]` syntax. There is no runtime dispatcher for enabling or disabling
-- a touchpad, so a toggle keybinding is not possible; a device is configured
-- statically here instead.
--
-- Get the exact device name first:
--   hyprctl devices -j | jq -r '.mice[].name, .touch[].name'
--
-- Then, for example, to turn the touchpad off permanently:
--
--   hl.device({
--     name    = "asue120a:00-04f3:31d1-touchpad",
--     enabled = false,
--   })
--
-- Or to change one device's sensitivity without touching the others:
--
--   hl.device({
--     name        = "epic-mouse-v1",
--     sensitivity = -0.5,
--   })
