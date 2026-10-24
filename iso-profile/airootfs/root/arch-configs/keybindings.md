# Keybindings

`SUPER` is the Windows/Super key. Shown in a terminal with `SUPER + K`, or
`less ~/.config/hypr/keybindings.md`.

Every binding is defined in `~/.config/hypr/bindings.lua` — this file is the
human-readable mirror of it. If you change one, change both.

## Applications

| Keys | Action |
|---|---|
| `SUPER + RETURN` | Terminal (ghostty) |
| `SUPER + SHIFT + RETURN` | Browser |
| `SUPER + SHIFT + B` | Browser |
| `SUPER + SHIFT + ALT + B` | Browser, private window |
| `SUPER + SHIFT + F` | File manager |
| `SUPER + ALT + SHIFT + F` | File manager, opened at `$HOME` |
| `SUPER + SHIFT + N` | Editor (VS Code) |
| `SUPER + SPACE` | **Application launcher** (fuzzel — type the first letters of anything) |
| `SUPER + ALT + RETURN` | Terminal with tmux (`tmux new -A -s main`) |
| `SUPER + CTRL + RETURN` | herdr |
| `SUPER + SHIFT + D` | lazydocker |
| `SUPER + SHIFT + O` | Obsidian |
| `SUPER + SHIFT + Q` | Calculator |
| `XF86Calculator` | Calculator |

## Pickers

Every one of these opens in a small floating window. They are also all in the
application launcher by name, so you never have to remember the keys.

| Keys | Action |
|---|---|
| `SUPER + K` | This cheatsheet |
| `SUPER + CTRL + V` | Clipboard history |
| `SUPER + CTRL + E` | Emoji picker |
| `SUPER + ESCAPE`, `XF86PowerOff` | Power menu (lock / suspend / logout / reboot / shutdown) |
| `SUPER + CTRL + SPACE` | Wallpaper picker |
| `SUPER + SHIFT + SPACE` | Next wallpaper |
| `SUPER + CTRL + D` | Display scale (cycles 1 → 1.25 → 1.6 → 2) |
| `SUPER + SHIFT + T` | Text size (GTK + terminal, in lockstep) |
| `SUPER + CTRL + G` | VA-API backend (iHD / nvidia, plus dGPU offload runner) |
| `SUPER + SHIFT + P` | Install a package (pacman) |
| `SUPER + SHIFT + A` | Install a package (AUR) |
| `SUPER + SHIFT + R` | Remove a package |
| `SUPER + CTRL + U` | Update system (`pacman -Syu` then `paru -Syu`) |

## Windows

| Keys | Action |
|---|---|
| `SUPER + W` | Close window |
| `CTRL + ALT + DELETE` | Close all windows |
| `SUPER + J` | Toggle split direction |
| `SUPER + P` | Pseudo-tile (dwindle) |
| `SUPER + T` | Toggle floating / tiling |
| `SUPER + F` | Full screen |
| `SUPER + ALT + F` | Full width (maximized) |
| `SUPER + O` | Pop out: float, pin and centre |
| `SUPER + L` | Toggle workspace layout (dwindle ⇄ master) |
| `SUPER + ← ↑ → ↓` | Move focus |
| `SUPER + SHIFT + ← ↑ → ↓` | Swap window with its neighbour |
| `SUPER + -` / `SUPER + =` | Shrink / grow the window horizontally |
| `SUPER + SHIFT + -` / `SUPER + SHIFT + =` | Shrink / grow vertically |
| `SUPER + CTRL + -` / `SUPER + CTRL + =` | Resize by a larger step |
| `ALT + TAB` / `ALT + SHIFT + TAB` | Next / previous window |
| `CTRL + ALT + TAB` / `CTRL + ALT + SHIFT + TAB` | Move focus to the next / previous monitor |
| `SUPER + LMB` / `SUPER + RMB` | Drag / resize a window with the mouse |

## Workspaces

| Keys | Action |
|---|---|
| `SUPER + 1` … `SUPER + 0` | Switch to workspace 1 … 10 |
| `SUPER + SHIFT + 1` … `0` | Move the focused window there |
| `SUPER + SHIFT + ALT + 1` … `0` | Move the window there without following it |
| `SUPER + TAB` / `SUPER + SHIFT + TAB` | Next / previous workspace |
| `SUPER + CTRL + TAB` | The workspace you were on before |
| `SUPER + scroll` | Cycle workspaces |
| `SUPER + S` | Toggle the scratchpad |
| `SUPER + ALT + S` | Send the window to the scratchpad |
| `SUPER + SHIFT + ALT + ← ↑ → ↓` | Send the whole workspace to another monitor |

## Window groups

Groups are tabbed stacks — several windows in the space of one.

| Keys | Action |
|---|---|
| `SUPER + G` | Toggle grouping for the focused window |
| `SUPER + ALT + G` | Take the window out of its group |
| `SUPER + ALT + ← ↑ → ↓` | Move the window into the group in that direction |
| `SUPER + ALT + TAB` / `SUPER + ALT + SHIFT + TAB` | Next / previous window in the group |
| `SUPER + ALT + scroll` | Next / previous window in the group |
| `SUPER + ALT + 1` … `5` | Jump to the Nth window in the group |

## Clipboard

| Keys | Action |
|---|---|
| `SUPER + C` | Copy — sends the right chord for terminals or GUI apps |
| `SUPER + V` | Paste — likewise |
| `SUPER + X` | Cut |
| `SUPER + CTRL + V` | Clipboard history |

## Audio

| Keys | Action |
|---|---|
| `XF86AudioRaiseVolume` / `XF86AudioLowerVolume` | Volume ±5%, with an on-screen display |
| `ALT + XF86AudioRaiseVolume` / `ALT + XF86AudioLowerVolume` | Volume ±1% |
| `XF86AudioMute` | Mute |
| `XF86AudioMicMute` | Mute the microphone |
| `SHIFT + XF86AudioMute` | Switch the default output |
| `XF86AudioPlay` / `XF86AudioPause` | Play / pause |
| `XF86AudioNext` / `XF86AudioPrev` / `XF86AudioStop` | Track control |

## Display and backlight

| Keys | Action |
|---|---|
| `XF86MonBrightnessUp` / `XF86MonBrightnessDown` | Brightness ±5%, with an on-screen display |
| `SHIFT + XF86MonBrightnessUp` / `SHIFT + XF86MonBrightnessDown` | Brightness to maximum / minimum |
| `XF86KbdBrightnessUp` / `XF86KbdBrightnessDown` | Keyboard backlight |
| `XF86KbdLightOnOff` | Keyboard backlight off |

## Capture and toggles

| Keys | Action |
|---|---|
| `PRINT` | Full screenshot |
| `SUPER + CTRL + C` | Region screenshot |
| `SUPER + SLASH` / `SUPER + ALT + SLASH` | Monitor scale up / down |
| `SUPER + CTRL + PRINT` | OCR — select a region, the text goes to the clipboard |
| `SUPER + PRINT` | Colour picker |
| `SUPER + CTRL + L` | Lock the screen |
| `SUPER + CTRL + I` | Keep awake — stops and starts the idle timer |
| `SUPER + CTRL + N` | Night light |
| `SUPER + CTRL + B` | Bluetooth |
| `SUPER + CTRL + A` | Audio mixer |
| `SUPER + CTRL + W` | Network (nmtui) |
| `SUPER + ,` / `SUPER + SHIFT + ,` | Dismiss the last / all notifications |
| `XF86TouchpadToggle` | Not bound — see below |

## Not carried over from Omarchy

These needed Omarchy's own binaries or its Quickshell panels, and have no
upstream equivalent here:

- `SUPER + CTRL + K` and `SUPER + ALT + K` — herdr / tmux keybinding cheatsheets
- `SUPER + CTRL + R`, `SUPER + SHIFT + CTRL + R` — reminders
- `SUPER + CTRL + X`, `F9` — dictation
- `SUPER + CTRL + PERIOD` — transcoding
- `SUPER + SHIFT + A/C/E/Y/X/…` — web-app launchers (ChatGPT, HEY, YouTube, X…)
- `SUPER + SHIFT + CTRL + SPACE` — theme switcher (this setup has no theme engine)
- `SUPER + CTRL + ALT + D/B/T/W` — clock, battery, time and weather notices
- `SUPER + BACKSPACE`, `SUPER + SHIFT + BACKSPACE`, `SUPER + CTRL + BACKSPACE` —
  runtime transparency, gap and aspect-ratio toggles
- `SUPER + ALT + Home`, `SUPER + Home` — save / restore window width
- `SUPER + CTRL + F` — "tiled fullscreen" (plain fullscreen and maximized remain)
- `SUPER + CTRL + Delete`, `SUPER + CTRL + ALT + Delete` — laptop panel toggles
  (single-panel machine, and the lid switch is handled in `bindings.lua`)
- `SUPER + SHIFT + M`, `SUPER + SHIFT + G`, `SUPER + SHIFT + W`, `SUPER + SHIFT + SLASH` —
  Spotify, Signal, omawrite, 1Password
- `XF86TouchpadOn/Off/Toggle` — touchpad toggle. The only runtime mechanism is the
  hyprlang `device[...]` selector, deprecated in Hyprland 0.55 in favour of the static
  `hl.device()`. Use the commented `hl.device` example in `~/.config/hypr/input.lua`.
- `SUPER + SHIFT + SPACE` as a top-bar toggle — the chord cycles the wallpaper here
