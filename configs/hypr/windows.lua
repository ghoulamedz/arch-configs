-- ~/.config/hypr/windows.lua
--
-- Window and layer rules. Reference:
-- https://wiki.hypr.land/Configuring/Basics/Window-Rules/

-- ---------------------------------------------------------------------------
-- The picker windows
-- ---------------------------------------------------------------------------
-- Every ~/.local/bin picker is launched as
--   foot --app-id=float-<script> -e <script>
-- which gives each one its own window class. These rules turn that class into a
-- small centred floating window, so a picker never takes over the tiling layout.
--
-- Keep this list in step with the `picker` helper in bindings.lua.
local pickers = {
  "float-pkg-install",
  "float-pkg-aur-install",
  "float-pkg-remove",
  "float-menu-keybindings",
  "float-clipboard-history",
  "float-emoji-picker",
  "float-power-menu",
  "float-wallpaper-picker",
  "float-vaapi-backend",
  "float-system-update",
  "float-display-scale",
  "float-text-size",
  "float-audio-output",
  "float-clock",
  "float-nmtui",
}

for _, class in ipairs(pickers) do
  hl.window_rule({
    name  = class,
    -- For a native Wayland client, `class` is the app_id set by --app-id.
    match = { class = "^" .. class .. "$" },

    float  = true,
    center = true,
    size   = "60% 55%",
  })
end

-- ---------------------------------------------------------------------------
-- General behaviour
-- ---------------------------------------------------------------------------

-- Ignore maximise requests from every application. In a tiling layout a
-- maximise request usually means an application is trying to work around a
-- window manager, and honouring it breaks the layout.
hl.window_rule({
  name           = "suppress-maximize",
  match          = { class = ".*" },
  suppress_event = "maximize",
})

-- Fix dragging in XWayland applications: their untitled, floating windows would
-- otherwise steal focus on click.
hl.window_rule({
  name  = "fix-xwayland-drag",
  match = {
    class      = "^$",
    title      = "^$",
    xwayland   = true,
    float      = true,
    fullscreen = false,
    pin        = false,
  },
  no_focus = true,
})

-- ---------------------------------------------------------------------------
-- Applications that should float by default
-- ---------------------------------------------------------------------------

-- Screenshot annotation (satty) and the calculator are transient tools, not
-- documents to tile.
hl.window_rule({ name = "float-satty",     match = { class = "^(com.github.Satty|satty)$" }, float = true, center = true })
hl.window_rule({ name = "float-qalc",      match = { class = "^(qalculate-qt|Qalculate-qt)$" }, float = true, size = "40% 50%" })
hl.window_rule({ name = "float-pavu",      match = { class = "^(org.pulseaudio.pavucontrol|pavucontrol)$" }, float = true, size = "45% 55%" })
hl.window_rule({ name = "float-blueman",   match = { class = "^blueman-manager$" }, float = true, size = "50% 55%" })
hl.window_rule({ name = "float-print",     match = { class = "^system-config-printer$" }, float = true })

-- File choosers and authentication prompts are dialogs; they must float or they
-- get tiled next to the application that opened them.
hl.window_rule({ name = "float-dialogs",   match = { title = "^(Open|Save|Save As|Choose|File Upload|Authentication Required|Authentication)$" }, float = true, center = true })
hl.window_rule({ name = "float-portal",    match = { class = "^(xdg-desktop-portal-gtk|xdg-desktop-portal-hyprland)$" }, float = true, center = true })

-- ---------------------------------------------------------------------------
-- Opacity
-- ---------------------------------------------------------------------------

-- A little transparency on the terminal and the bar-adjacent tools, none on
-- anything where reading accuracy matters.
hl.window_rule({ name = "opacity-terminal", match = { class = "^(ghostty|foot)$" }, opacity = "0.97 0.92" })
