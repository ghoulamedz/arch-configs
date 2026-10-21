-- ~/.config/hypr/envs.lua
--
-- hl.env() sets variables in the compositor's environment before it spawns any
-- child, so every application started from the session inherits them.

-- NVIDIA. Blackwell (the RTX 5050) drives through the GPU System Processor, and
-- `direct` is the buffer-allocation backend that works with GSP + nvidia-drm.
-- It only changes behaviour when the NVIDIA driver is already rendering; it does
-- not enable or offload anything by itself, which is why it is safe to set
-- globally.
hl.env("NVD_BACKEND", "direct")

-- Deliberately NOT set here:
--
--   LIBVA_DRIVER_NAME          the VA-API driver differs per process — iHD for
--                              the Intel iGPU, nvidia for offloaded apps. It is
--                              owned by ~/.config/environment.d/vaapi.conf and
--                              the vaapi-backend script. Setting it here would
--                              override that file and pin one driver on
--                              everything, including processes that render on the
--                              other GPU, where it fails.
--
--   __GLX_VENDOR_LIBRARY_NAME  globally these force every GL/Vulkan app onto the
--   __NV_PRIME_RENDER_OFFLOAD  discrete GPU and drain the battery on a hybrid
--   __VK_LAYER_NV_optimus      laptop. Use `vaapi-backend run <cmd>` to opt a
--                              single command into the dGPU instead.

-- fcitx5. GTK, Qt and XWayland applications only route key input through fcitx5
-- when these are set, and fcitx5 is where the Arabic input methods live.
hl.env("GTK_IM_MODULE", "fcitx")
hl.env("QT_IM_MODULE", "fcitx")
hl.env("XMODIFIERS", "@im=fcitx")

-- Custom characters. ~/.XCompose defines the Arabic ligatures, the diacritics,
-- Arabic-Indic digits and emoji reachable through the compose key. Caps Lock is
-- the compose key — see kb_options in input.lua.
hl.env("XCOMPOSEFILE", (os.getenv("HOME") or "") .. "/.XCompose")

-- Cursor size, for both the cursor theme and Hyprland's own cursor rendering.
hl.env("XCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_SIZE", "24")

-- Electron and Chromium applications: choose the Wayland backend automatically
-- instead of silently falling back to XWayland.
hl.env("ELECTRON_OZONE_PLATFORM_HINT", "auto")

-- ---------------------------------------------------------------------------
-- ~/.config/environment.d
-- ---------------------------------------------------------------------------
-- Load every KEY=VALUE from ~/.config/environment.d/*.conf into the session.
--
-- Why this is here at all: those files are normally read by systemd's *user*
-- manager at session start, which only happens when the session is started by
-- uwsm. SDDM has no setting to force a session, so if it launches plain
-- hyprland.desktop nothing reads them — and the two things that live there are
-- the VA-API driver chosen by the vaapi-backend script and the session PATH that
-- makes ~/.local/bin resolve for bindings and Waybar. Loading them here makes
-- both work however the session was started.
--
-- $HOME and $PATH are expanded by hand: Lua does not do it, and the files are
-- written with those placeholders so they are not machine-specific.
local function load_environment_d()
  local home = os.getenv("HOME") or ""

  -- io.popen rather than a directory read: Lua has no glob.
  local pipe = io.popen('cat "' .. home .. '/.config/environment.d/"*.conf 2>/dev/null')
  if not pipe then return end

  -- Lua 5.4 marks a generic-for control variable as const, so the raw line is
  -- copied into a local before being modified.
  for raw in pipe:lines() do
    local line = raw:gsub("^%s+", ""):gsub("%s+$", "")

    if line ~= "" and line:sub(1, 1) ~= "#" then
      local key, value = line:match("^([%w_]+)=(.*)$")

      if key then
        value = value:gsub("^[\"']", ""):gsub("[\"']$", "")
        value = value:gsub("%$HOME", home)
        value = value:gsub("%$PATH", os.getenv("PATH") or "")

        -- Deduplicate colon-separated values. `hyprctl reload` re-runs this
        -- file, and without this PATH would grow a little on every reload.
        if value:find(":", 1, true) then
          local seen, parts = {}, {}
          for part in value:gmatch("[^:]+") do
            if part ~= "" and not seen[part] then
              seen[part] = true
              parts[#parts + 1] = part
            end
          end
          value = table.concat(parts, ":")
        end

        hl.env(key, value)
      end
    end
  end

  pipe:close()
end

load_environment_d()
