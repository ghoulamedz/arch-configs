-- ~/.config/hypr/autostart.lua
--
-- Session daemons, started once when the compositor comes up. Everything here
-- has to be running before the first window appears, or the bar, the
-- notifications, the lock screen or the input method will simply be missing.

hl.on("hyprland.start", function()
  -- Wallpaper. Started first so the desktop is never briefly bare.
  hl.exec_cmd("hyprpaper")

  -- Notification daemon. Hyprland has none of its own, so without this nothing
  -- can post a notification — including the volume and brightness OSD popups.
  hl.exec_cmd("mako")

  -- The top bar.
  hl.exec_cmd("waybar")

  -- Idle handling: dim, then lock, then suspend. Also the thing the keep-awake
  -- toggle starts and stops.
  hl.exec_cmd("hypridle")

  -- Polkit agent: the GUI prompt for privileged actions (mounting a disk,
  -- restarting a service, adding a printer). Started as a systemd user unit so
  -- uwsm supervises it rather than leaving an orphan process.
  hl.exec_cmd("systemctl --user start hyprpolkitagent.service")

  -- Input method daemon, for the Arabic input methods defined in
  -- ~/.config/fcitx5/profile. The layout switching itself is done by Hyprland
  -- (grp:alt_shift_toggle in input.lua); fcitx5 is here for ar-translit.
  hl.exec_cmd("fcitx5 -d")

  -- Clipboard history. Every wl-paste event is handed to cliphist, which stores
  -- it; the SUPER + CTRL + V picker reads back from that store.
  hl.exec_cmd("wl-paste --watch cliphist store")
end)
