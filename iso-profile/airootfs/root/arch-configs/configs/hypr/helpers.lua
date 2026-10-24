-- ~/.config/hypr/helpers.lua
--
-- One helper, and the reason it exists: Hyprland's own hl.bind() takes no
-- description, and ~/.config/hypr/keybindings.md (the cheatsheet shown by
-- SUPER+K) has to stay in step with what is actually bound. Recording the
-- description on the binding itself is what keeps the two from drifting apart.

-- bind(keys, description, command, options)
--
--   keys         chord, e.g. "SUPER + RETURN"
--   description  text for the cheatsheet; pass nil to bind without listing it
--   command      a shell string (wrapped in hl.dsp.exec_cmd) or an hl.dsp.* value
--   options      forwarded to hl.bind, e.g. { locked = true, repeating = true }
--
-- Returns whatever hl.bind returns, so a binding can be captured and toggled
-- later with :set_enabled(false).
function bind(keys, description, command, options)
  local opts = options or {}

  -- Hyprland stores this and reports it via `hyprctl binds`, so the description
  -- travels with the binding rather than living only in the cheatsheet.
  if description then
    opts.description = description
  end

  -- A string is a shell command; an hl.dsp.* value is already a dispatcher.
  if type(command) == "string" then
    command = hl.dsp.exec_cmd(command)
  end

  return hl.bind(keys, command, opts)
end
