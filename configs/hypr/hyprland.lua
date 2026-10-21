-- ~/.config/hypr/hyprland.lua — the file Hyprland loads.
--
-- Written against Hyprland's own upstream Lua API (hl.*), documented at
-- https://wiki.hypr.land/Configuring/ . There are no Omarchy helpers and no
-- Omarchy binaries anywhere in this config: every command a binding runs is
-- either an Arch package or a script in ~/.local/bin.

-- Make `require("hypr.bindings")` resolve to ~/.config/hypr/bindings.lua.
-- Hyprland does not add the config directory to Lua's search path itself.
package.path = (os.getenv("HOME") or "") .. "/.config/?.lua;" .. package.path

-- Hyprland re-executes this file on `hyprctl reload`. Without clearing Lua's
-- module cache, require() would hand back the previously loaded copy and edits
-- to the files below would only take effect after a full logout.
for name in pairs(package.loaded) do
  if name == "hypr" or name:sub(1, 5) == "hypr." then
    package.loaded[name] = nil
  end
end

-- Order matters: helpers defines bind(), which bindings uses.
require("hypr.helpers")    -- bind() wrapper that records descriptions
require("hypr.envs")       -- environment variables for the whole session
require("hypr.monitors")   -- outputs, modes, scale
require("hypr.input")      -- keyboard layouts, touchpad, gestures
require("hypr.looknfeel")  -- gaps, borders, blur, animations, colours
require("hypr.windows")    -- window and layer rules
require("hypr.bindings")   -- every keybinding
require("hypr.autostart")  -- session daemons
