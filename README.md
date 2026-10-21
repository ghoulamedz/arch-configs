# arch-configs

Vanilla Arch Linux with the *look and feel* of Omarchy, built from **official Arch
packages plus 7 AUR packages**. No Omarchy package, binary, script, or pacman repo is
used or installed. Nothing here is compiled from an Omarchy fork — the Hyprland Lua
config is written against Hyprland's own upstream API (`hl.*`).

Target machine: `medo@medo-box`, hybrid Intel iGPU + NVIDIA RTX 5050 Max-Q (Blackwell),
UEFI, 1 NVMe for Arch + 1 NVMe holding NTFS data, no LUKS, no swap file (zram only).

Install contract: run `./install.sh` from the Arch ISO, after partitioning, formatting
and mounting. The script never touches partitions.

---

## 1. Repository structure

```
arch-configs/
├── install.sh                  Phase 1 + 3. Entry point, run from the live ISO as root.
├── install-chroot.sh           Phase 2. Invoked by install.sh inside arch-chroot.
├── lib/common.sh               Shared helpers: log, die, need_root, ensure_pkg,
│                               write_file (content-aware, idempotent), append_once,
│                               backup_once, copy_tree, enable_service, guard checks.
├── packages/
│   ├── official.txt            One package name per line, blank lines group related
│   │                           packages, no comments. Fed to pacstrap. Includes
│   │                           base-devel + rust, which paru and the AUR packages
│   │                           need to build.
│   └── aur.txt                 AUR packages, built as user `medo` via paru.
├── system/                     Files destined for /etc. Copied by phase 2, then owned
│   │                           root:root; 0644, except 0440 for sudoers.d. The PAM
│   │                           snippet is appended to /etc/pam.d/sddm, not copied.
│   ├── mkinitcpio.conf.d/10-system.conf
│   ├── mkinitcpio.conf.d/20-nvidia.conf
│   ├── modprobe.d/nvidia.conf
│   ├── zram-generator.conf
│   ├── default-grub
│   ├── sddm.conf.d/10-theme.conf
│   ├── pam.d/sddm.keyring.snippet
│   ├── sudoers.d/10-wheel
│   └── vconsole.conf
├── configs/                    Mirror of ~/.config. Copied to /home/medo/.config,
│   │                           then chown -R medo:medo, dirs 0755, files 0644.
│   ├── hypr/
│   ├── waybar/
│   ├── mako/
│   ├── fuzzel/
│   ├── foot/
│   ├── ghostty/
│   ├── fontconfig/
│   ├── fcitx5/
│   ├── gtk-3.0/
│   ├── gtk-4.0/
│   ├── tmux/
│   ├── btop/
│   ├── lazygit/
│   ├── fastfetch/
│   ├── imv/
│   ├── herdr/
│   ├── Code/
│   ├── starship.toml
│   ├── chromium-flags.conf
│   ├── xdg-terminals.list
│   └── mise/
├── home/                       Files copied directly into /home/medo/.
│   ├── bashrc
│   ├── bash_profile
│   ├── nanorc
│   ├── XCompose
│   └── gitconfig.tpl           Templated with git name/email at install time.
├── bin/                        Copied to ~/.local/bin, chmod 0755.
│   └── <24 scripts, see §4>
├── applications/               Copied to ~/.local/share/applications, one .desktop
│   │                           file per script, then update-desktop-database. This is
│   │                           what makes every tool reachable from the fuzzel
│   │                           launcher (SUPER + SPACE) by typing its first letters.
│   └── <27 .desktop files>
├── data/
│   └── emoji.tsv               emoji picker source: glyph, name.
├── wallpapers/                 4 images, 1920x1080, Tokyo Night palette.
└── keybindings.md              Copied to ~/.config/hypr/keybindings.md. Cheatsheet
                                shown by the SUPER+K binding. Single source of truth.
```

Directories the script creates that are **not** in the repo:
`/home/medo/Bin` (your own binaries, on PATH, empty), `~/Pictures/wallpapers`,
`~/.local/bin`, `~/.local/share/applications`.

---

## 2. What `install.sh` does

### Phase 1 — live ISO, outside the chroot

1. **Preflight, abort on any failure.** Must be root. Must be on the Arch ISO
   (`/etc/arch-release`). `findmnt` must show `/mnt` as btrfs with `subvol=/@` and
   `/mnt/boot` mounted. Network must be up. `packages/official.txt` must be readable.
2. `pacstrap -K /mnt $(packages/official.txt)` — installs the base system plus every
   official package in one transaction, initialising the keyring.
3. `genfstab -U /mnt >> /mnt/etc/fstab` — generates fstab from the *live* mount table.
   Not hand-edited afterwards: `grub-btrfs` parses these exact flags to build the
   `rootflags=` for snapshot boot entries.
4. `cp -a` the repo to `/mnt/root/arch-configs` so phase 2 can reach it.
5. `arch-chroot /mnt /root/arch-configs/install-chroot.sh` (arch-chroot bind-mounts
   `/etc/resolv.conf`, so the chroot has working DNS).
6. Prints the remaining steps: `umount -R /mnt` then `reboot`.

### Phase 2 — inside `arch-chroot /mnt`

Ordered, each step idempotent and re-runnable.

1. **Locale / time / identity.** Writes `/etc/locale.conf` (`LANG=en_US.UTF-8`),
   `/etc/locale.gen` (uncomment `en_US.UTF-8`, `fr_FR.UTF-8` and `ar_EG.UTF-8` — the
   Arabic and French data are preconditions for the font stack below), then runs
   `locale-gen`.
   `ln -sf /usr/share/zoneinfo/Africa/Tunis /etc/localtime`, `hwclock --systohc`.
   Writes `/etc/hostname` (`medo-box`), `/etc/hosts`, `/etc/vconsole.conf`
   (`KEYMAP=fr-pc`).
2. **User.** `useradd -m -G wheel,docker,video,render,audio,input,lp medo`, sets the
   password interactively (you type it), creates `/home/medo/Bin`,
   installs `/etc/sudoers.d/10-wheel` with `%wheel ALL=(ALL:ALL) NOPASSWD: ALL`.
3. **System files.** Copies everything in `system/` to `/etc`, sets owner `root:root`,
   mode `0644` — except `/etc/sudoers.d/10-wheel`, which gets `0440` because sudo
   ignores a group- or world-writable sudoers file. The PAM snippet is not copied:
   its lines are appended to `/etc/pam.d/sddm`, which belongs to the sddm package.
   Then uncomments the pacman tweaks in `/etc/pacman.conf`.
4. **Initramfs.** `mkinitcpio -P`. Generates both kernels' images if more than one
   kernel is installed.
5. **Bootloader.** `grub-install --target=x86_64-efi --efi-directory=/boot
   --bootloader-id=GRUB`, then asserts that no `GRUB_CMDLINE_LINUX*` variable sets
   `rootflags`, then runs `grub-mkconfig -o /boot/grub/grub.cfg`. The assertion
   targets the *assignment*, not the file's text: `/etc/default/grub` mentions
   `rootflags` in its own comments, and `grub.cfg` legitimately contains it inside
   grub-btrfs's snapshot entries. A naive `grep rootflags /etc/default/grub` would
   match the documentation and abort every install.
6. **Snapshots.** `snapper -c root create-config /` (creates `/.snapshots` as its own
   subvolume inside `@`), then patches the keys it cares about in
   `/etc/snapper/configs/root` in place — the file snapper generated is kept, only
   specific values are changed, so nothing snapper needs can be lost. No manual
   `/.snapshots` creation beforehand — doing that
   makes `create-config` fail.
7. **Services.** `systemctl enable` only, never `start` (there is no PID 1 in a
   chroot): `NetworkManager`, `systemd-timesyncd`, `bluetooth`, `sddm`, `thermald`,
   `power-profiles-daemon`, `docker`, `cups`, `ufw`, `plocate-updatedb.timer`,
   `paccache.timer`, `snapper-timeline.timer`, `snapper-cleanup.timer`,
   `grub-btrfsd`. Each short name is normalised to `<name>.service` before the
   existence check — unit *files* always carry a suffix, so testing the bare name
   would silently skip nine of the thirteen and leave the machine with no sddm.
8. **Firewall.** `ufw default deny incoming`, `ufw default allow outgoing`,
   `ufw --force enable`. Enabling the unit alone applies no policy; without this the
   machine would carry a firewall package and no rules.
9. **Dotfiles.** Copies `configs/*` → `/home/medo/.config/`, `home/*` →
   `/home/medo/`, `bin/*` → `/home/medo/.local/bin` (0755), `applications/*` →
   `/home/medo/.local/share/applications` (0644), `data/*` →
   `/home/medo/.local/share/arch-configs/data`, `wallpapers/*` →
   `/home/medo/Pictures/wallpapers/`, `keybindings.md` →
   `/home/medo/.config/hypr/keybindings.md`, plus
   `~/.config/environment.d/10-path.conf` (the session PATH — see §7). Renders
   `gitconfig.tpl` → `~/.gitconfig`. Then `chown -R medo:medo /home/medo`, and only
   *after* that runs `fc-cache -f`, `update-desktop-database` and
   `xdg-user-dirs-update` **as medo** via `runuser` — as root, `fc-cache` would build
   `/root/.cache/fontconfig` and leave the Arabic stack uncached for the user, and
   `update-desktop-database` would leave a root-owned `mimeinfo.cache` in their home.
10. **First rollback point.** `snapper -c root create -d "post-install"`, then
   `grub-mkconfig` again so the "Arch Linux snapshots" submenu is populated on the
   very first boot. Without the regeneration the menu entry would not appear until
   the first pacman transaction, which is exactly when a rollback is most wanted.
11. **AUR.** `su - medo -c 'paru -S --needed --noconfirm --skipreview …'` for
    `packages/aur.txt`, after bootstrapping `paru` itself from the AUR with
    `makepkg -si`. **No temporary sudoers file is needed** — `%wheel` already has
    `NOPASSWD`, so the user switch can sudo freely. `makepkg` refuses to run as root,
    hence the switch; `--skipreview` is passed because there is no interactive editor
    inside the chroot.

### Phase 3 — live ISO again

Prints the post-reboot checklist (set printer at `http://localhost:631`, `gh auth
login`, verify the SDDM session, first wallpaper). Does not unmount; you run
`umount -R /mnt` yourself so you can inspect before rebooting.

### What the script deliberately does not do

- Partition, format, or create subvolumes. You do that by hand (§5 of the reply).
- Touch `/dev/nvme0n1` (your NTFS data disk).
- Start services, or run anything requiring a live systemd.
- Configure **your** firewall rules. `configure_firewall()` applies `default deny
  incoming`, `default allow outgoing` and `ufw --force enable`, so the firewall is
  filtering from first boot; the per-application rules are yours to add in `gufw`.
  Docker bypasses ufw by design — accepted.
- Add a printer, log into GitHub, or authenticate anything.

---

## 3. `system/` — every file, and what it does

| File | Destination | Format | What it does |
|---|---|---|---|
| `mkinitcpio.conf.d/10-system.conf` | `/etc/mkinitcpio.conf.d/` | shell | `MODULES=(btrfs)` and `HOOKS=(base systemd autodetect microcode modconf kms keyboard sd-vconsole block filesystems fsck)`. systemd-based initramfs; `sd-vconsole` pairs with the `systemd` hook. |
| `mkinitcpio.conf.d/20-nvidia.conf` | same | shell | `MODULES+=(nvidia nvidia_modeset nvidia_uvm nvidia_drm)` — early KMS so the NVIDIA modeset happens before SDDM. Pairs with `nvidia-open` (the prebuilt module), not `nvidia-open-dkms`. |
| `modprobe.d/nvidia.conf` | `/etc/modprobe.d/` | modprobe | `options nvidia_drm modeset=1`. |
| `zram-generator.conf` | `/etc/systemd/` | INI | `zram-size = ram / 2`, `compression-algorithm = zstd`. Replaces a swap partition. |
| `default-grub` | `/etc/default/grub` | shell | `GRUB_TIMEOUT=3`, `GRUB_PRELOAD_MODULES="part_gpt btrfs"`, `GRUB_DISABLE_OS_PROBER=true` (no second OS exists). **No `rootflags=`** — `@` is the btrfs default subvolume instead. |
| — (patched in place) | `/etc/snapper/configs/root` | INI | Not a repo file. `snapper create-config` generates it; `install-chroot.sh` then patches individual keys: `TIMELINE_CREATE=yes`, `TIMELINE_LIMIT_{HOURLY,DAILY,WEEKLY,MONTHLY}`, `TIMELINE_CLEANUP=yes`, `NUMBER_LIMIT=20`, `NUMBER_LIMIT_IMPORTANT=10`, `NUMBER_CLEANUP=yes`, `EMPTY_PRE_POST_CLEANUP=yes`, `ALLOW_USERS=medo`, `BACKGROUND_COMPARISON=yes`. |
| `sddm.conf.d/10-theme.conf` | `/etc/sddm.conf.d/` | INI | Cursor theme and size so SDDM matches the session. |
| `pam.d/sddm.keyring.snippet` | appended to `/etc/pam.d/sddm` | pam | `pam_gnome_keyring.so` `auth`/`session` lines, so the login password also unlocks the keyring. |
| `sudoers.d/10-wheel` | `/etc/sudoers.d/` | sudoers | `%wheel ALL=(ALL:ALL) NOPASSWD: ALL`. |
| — (patched in place) | `/etc/pacman.conf` | INI | Not a repo file. `install-chroot.sh` uncomments or adds: `Color`, `ILoveCandy`, `VerbosePkgLists`, `ParallelDownloads = 8`. Uncommenting the existing line rather than appending avoids duplicate keys. |
| `vconsole.conf` | `/etc/` | INI | `KEYMAP=fr-pc` — French AZERTY at the TTY and at the LUKS-less early console. |

---

## 4. `bin/` — every script

All bash, `set -euo pipefail`, no dependencies beyond the packages in
`packages/*.txt`. Most are 20–60 lines; `vaapi-backend`, `display-scale` and
`text-size` are longer because each reads the state back rather than assuming a
change took effect: `display-scale` parses `hyprctl monitors -j`, `vaapi-backend`
probes with `vainfo`, and `text-size` reads `gsettings` and rewrites two terminal
configs.

Anything that needs a UI opens in a floating `foot` window
(`foot --app-id=float-<name> -e <script>`); `windows.lua` floats and centres each one
by that app-id.

| Script | What it does |
|---|---|
| `pkg-install` | omarchy's pacman TUI, de-omarchy'd: `pacman -Slq \| fzf --multi --preview 'pacman -Sii {1}'` → `sudo pacman -S`. |
| `pkg-aur-install` | Same over `paru -Slqa`, with the AUR binds: `alt-b` previews the PKGBUILD via `paru -Gpa`, `alt-B` the package info. |
| `pkg-remove` | fzf over installed packages → `sudo pacman -Rns`. |
| `menu-keybindings` | `foot -e less ~/.config/hypr/keybindings.md`. |
| `clipboard-history` | `cliphist list \| fzf --delimiter='\t' --with-nth=2.. --preview 'cliphist decode {1}'` → `cliphist decode \| wl-copy`; `ctrl-x` deletes an entry and reloads. |
| `clipboard-send` | Sends the right copy/paste/cut chord to the focused window: terminals get `CTRL+Insert` / `SHIFT+Insert`, GUI apps get `CTRL+C` / `CTRL+V`. Uses `hyprctl dispatch sendshortcut`, which reaches layer-shell surfaces too. |
| `emoji-picker` | fzf over `data/emoji.tsv`, copies the glyph with `wl-copy`. |
| `power-menu` | fzf: lock / suspend / logout / reboot / shutdown → `hyprlock`, `systemctl suspend`, `hyprctl dispatch exit`, `systemctl reboot`, `systemctl poweroff`. |
| `wallpaper-picker` | fzf over `~/Pictures/wallpapers`, applies via `hyprctl hyprpaper wallpaper`. |
| `wallpaper-cycle` | Next/previous wallpaper in the directory; `hyprpaper` keeps the last one. |
| `system-update` | `sudo pacman -Syu` then `paru -Syu` in a floating terminal, with a `checkupdates` pre-flight count first. This is the entire update story — no other updater exists on the system. Launcher entry: **Update System**. |
| `screenshot-region` | `grim -g "$(slurp)"` → save to `~/Pictures/Screenshots` + `wl-copy`. |
| `screenshot-full` | `grim` of the focused output → same destinations. |
| `screenshot-annotate` | region screenshot piped into `satty`. |
| `extract-text` | region screenshot → `tesseract - -` → `wl-copy` (OCR, replaces `omarchy-capture-text`). |
| `toggle-idle` | Starts/stops `hypridle` — your keep-awake switch. Exposes state for Waybar's `custom/keepawake` module. |
| `display-scale` | `menu` picks a scale, `show` prints it for Waybar, `cycle`/`up`/`down` step through `1, 1.25, 1.6, 2`. Rebuilds the whole monitor rule from `hyprctl monitors -j` and applies it with `hyprctl keyword monitor`. |
| `text-size` | `menu` picks a size, `show` prints it. Sets `org.gnome.desktop.interface text-scaling-factor` for GTK (live) and rewrites the ghostty and foot font size (new terminals), in lockstep from a 12px baseline. |
| `toggle-layout` | Flips `general:layout` between `dwindle` and `master` with `hyprctl keyword`, reading the current value first. |
| `toggle-nightlight` | Starts/stops `hyprsunset`; state for Waybar. |
| `osd-volume` | `pamixer` change + a transient `mako` notification with a 10-block bar — the OSD replacement. |
| `osd-brightness` | Same for `brightnessctl`. |
| `audio-output` | `switch` opens a picker over the audio sinks parsed out of `wpctl status`, then `wpctl set-default`. Says so instead of opening a menu when there is only one sink. |
| `vaapi-backend` | VA-API driver control, see §7. `status` probes every installed driver with `vainfo`; `set iHD\|nvidia` persists the session default to `~/.config/environment.d/vaapi.conf`; `run <cmd>` executes one command on the dGPU with NVDEC; `menu` is the fzf front end. |

`applications/` holds 27 `.desktop` files, installed to `~/.local/share/applications/`
and registered with `update-desktop-database`. Twenty-one cover the user-facing scripts
in `bin/`; the other six exist because their packages ship no entry of their own and the
operator needs to reach them by typing — btop, lazygit, lazydocker, herdr, nano, tmux.

Two shapes of `Exec`:
- pickers use `Exec=foot --app-id=float-<name> -e <script>` with `Terminal=false`, so the
tool opens in a floating window that `windows.lua` sizes and centres by app-id
- TUIs and anything that acts immediately (`btop`, `tmux`, `wallpaper-cycle`,
  `screenshot-*`, `toggle-*`) launch with no floating app-id at all, so they tile
  normally

`Name`, `Comment`, `Keywords` and `Icon` are set on every entry, which is what makes
fuzzel match on partial words — type `vaa`, `clip`, `wall`, `emo`, `upd`, `btop` and get
the right thing. Packages ship their own `.desktop` files, so nautilus, code, obsidian,
gufw, qalculate-qt, kdenlive and the rest need nothing from us.

---

## 5. `configs/` — every file, and what it does

### 5.1 `hypr/` — the compositor

Written against upstream Hyprland's Lua API only. `helpers.lua` is our own ~12-line
wrapper that adds a `description` field to `hl.bind` so the cheatsheet can be
generated from the same source that binds the keys.

| File | What it does |
|---|---|
| `hyprland.lua` | Entry point. `require`s the modules below in order. Nothing else. |
| `helpers.lua` | `bind(keys, description, command, opts)` → `hl.bind`, wrapping string commands in `hl.dsp.exec_cmd` and recording the description the cheatsheet lists. That is the only function it defines. |
| `envs.lua` | `hl.env`: `NVD_BACKEND=direct` (Blackwell runs through GSP); `GTK_IM_MODULE=fcitx`, `QT_IM_MODULE=fcitx`, `XMODIFIERS=@im=fcitx`; `XCOMPOSEFILE=$HOME/.XCompose`; `XCURSOR_SIZE=24`, `HYPRCURSOR_SIZE=24`; `ELECTRON_OZONE_PLATFORM_HINT=auto`. **Deliberately does not set `LIBVA_DRIVER_NAME`, `__GLX_VENDOR_LIBRARY_NAME`, or `__NV_PRIME_RENDER_OFFLOAD`** — on a hybrid laptop those force every app onto the dGPU and drain the battery. VA-API is owned by `vaapi-backend` (§7); the dGPU is opt-in per command. |
| `looknfeel.lua` | `hl.config` for general/decoration/blur/shadow/animations, plus `hl.curve` and `hl.animation` sets. Tokyo Night colours: background `#1a1b26`, foreground `#a9b1d6`, accents `#7aa2f7`/`#bb9af7`. Gaps 5/10, border 2, rounding 8. |
| `windows.lua` | Window and layer rules. A loop floats and centres every picker window by its `float-*` class (the list is coupled to the `picker()` helper in `bindings.lua`); then rules that suppress maximise requests, fix XWayland drags, float dialogs and transient tools, and dim the terminal slightly. |
| `input.lua` | `kb_layout = "fr,ara"`, `kb_options = "grp:alt_shift_toggle"` — AZERTY default, Arabic second. Touchpad: `natural_scroll = true`, `tap-to-click`. Mouse sensitivity neutral. |
| `monitors.lua` | `hl.monitor` for the internal panel: 1920x1080@144, scale 1, `position = auto`. A commented block shows how to add an external monitor. |
| `bindings.lua` | Every keybinding, §6. |
| `autostart.lua` | `hl.on("hyprland.start", …)`: `hyprpaper`, `hypridle`, `mako`, `waybar`, `fcitx5 -d`, `wl-paste --watch cliphist store`, `systemctl --user start hyprpolkitagent`. |
| `keybindings.md` | The cheatsheet. Generated by hand alongside `bindings.lua`; `menu-keybindings` displays it. |
| `hyprlock.conf` | Lock screen: blurred wallpaper background, clock, date, password field, Tokyo Night colours. |
| `hypridle.conf` | `listener`s: 300s → `loginctl lock-session` (which starts `hyprlock`); 600s → `hyprctl dispatch dpms off`, restored on resume; 1800s → `systemctl suspend`. `before_sleep_cmd` locks first. |
| `hyprpaper.conf` | `preload` + `wallpaper = ,<path>` — an empty monitor field applies the image to every output. `ipc = on` is what lets `wallpaper-picker` and `wallpaper-cycle` change it at runtime. |
| `hyprsunset.conf` | Night-light temperature (4000K) and gamma, toggled by `toggle-nightlight`. |

### 5.2 `waybar/` — the top bar

Reproduces Omarchy's bar layout with Waybar instead of Quickshell. Same three zones,
same widgets, same Tokyo Night colours.

| File | What it does |
|---|---|
| `config.jsonc` | `height: 28`, `position: top`, `spacing: 4`, `fixed-center: true`. **Left:** `custom/launcher` (click → fuzzel), `hyprland/workspaces`. **Center:** `clock` (`{:%A %H:%M}`, tooltip `{:%d %B %Y}`), `custom/scale` (display scale, click cycles), `custom/keepawake` (idle toggle), `custom/nightlight`, `custom/pkg` (pending-update count from `checkupdates`, hidden when zero). **Right:** `tray`, `bluetooth`, `network` (click → `nmtui`), `pulseaudio` (scroll = volume, click = mute, right-click → `pavucontrol`), `battery`, `custom/power`. Every click/scroll action calls one of the `bin/` scripts or a `pamixer`/`wpctl` one-liner. |
| `style.css` | Tokyo Night palette, transparent bar background, per-module padding, rounded module backgrounds, `#7aa2f7` accent on active workspace, red `#f7768e` for battery critical. |

### 5.3 The rest of `~/.config`

| File | Format | What it does |
|---|---|---|
| `mako/config` | INI | Notification daemon, anchored top-right, 8px radius, 5s default timeout, Tokyo Night colours. **Also the OSD target**: `osd-volume`/`osd-brightness` send transient notifications here. |
| `fuzzel/fuzzel.ini` | INI | App launcher: font size 11, 8px radius, `#1a1b26` background, `#7aa2f7` selection, icons on, 10 lines tall. Bound to `SUPER + SPACE`. |
| `foot/foot.ini` | INI | Terminal. Frozen from your current config, colours inlined (Tokyo Night, JetBrains Mono Nerd Font 9). Used for all floating picker windows. |
| `ghostty/config` | INI | Your daily terminal, frozen from your current config. |
| `fontconfig/fonts.conf` | XML | The font stack, §5.4. |
| `fcitx5/profile` | INI | Two input methods: `keyboard-us` (pass-through, the default) and `ar-translit` (m17n phonetic Arabic). No `ar-kbd` — add it in `fcitx5-configtool` if you want a table-based Arabic layout instead. `grp:alt_shift_toggle` is handled by Hyprland, not fcitx5. **Verify on first boot:** because `GTK_IM_MODULE=fcitx` routes keys through fcitx5, which carries its own xkb layout, check that `Default Layout=us` does not override Hyprland's `fr` in GTK apps — if it does, change this to `Default Layout=fr`. |
| `fcitx5/conf/xcb.conf` | INI | `Allow Overriding System XKB Settings=False` — fcitx5 leaves the XKB layout to Hyprland. |
| `gtk-3.0/settings.ini`, `gtk-4.0/settings.ini` | INI | `gtk-theme-name=Adwaita` + `gtk-application-prefer-dark-theme=1`, `gtk-font-name=Inter 11`, `gtk-icon-theme-name=Adwaita`, cursor `Adwaita`. Adwaita is compiled into GTK3 and GTK4, so the dark variant is selected by the prefer-dark flag — asking for a theme literally named `Adwaita-dark` would need `gnome-themes-extra` installed for that file to exist. |
| `tmux/tmux.conf` | tmux | Frozen from your current config. |
| `btop/btop.conf` | btop | Frozen; colours already resolved to Tokyo Night. |
| `lazygit/config.yml` | YAML | Frozen from omarchy's shipped config. |
| `fastfetch/config.jsonc` | JSONC | Minimal: OS, kernel, WM, terminal, shell, packages. |
| `imv/config` | INI | Frozen from omarchy's shipped config. |
| `herdr/config.toml` | TOML | Frozen from your current config. |
| `Code/User/settings.json` | JSONC | Frozen from your current VS Code settings. |
| `xdg-terminals.list` | text | `ghostty.desktop` then `foot.desktop` — makes `xdg-terminal-exec` deterministic for the picker scripts. |
| `mise/config.toml` | TOML | Minimal mise config, empty `[tools]` table, for when you try it. |

**The frozen copies are not verbatim.** Several of them referenced Omarchy paths that
do not exist here, which would have silently broken things — worth knowing because
these are the files you are most likely to assume are untouched:

| File | What had to change |
|---|---|
| `ghostty/config` | `config-file = ?"~/.local/state/omarchy/current/theme/ghostty.conf"` replaced with the 18 Tokyo Night colour values inlined. The `?` made the missing include silent, so without this the terminal would have quietly run on Ghostty's default colours. |
| `foot/foot.ini` | Same problem, same fix: the `include=` line was replaced with a `[colors-dark]` section carrying the palette. |
| `chromium-flags.conf` | The `--load-extension=` line pointed at three extensions under `/usr/share/omarchy/default/chromium/extensions/`. Removed — Chromium errors on a missing extension path. |
| `tmux/tmux.conf` | One binding called `omarchy-menu-tmux-keybindings --print`; replaced with `tmux list-keys -N`, which is the upstream equivalent of what that command did. |

Everything else in that table is byte-identical to what you run today.

### 5.4 The font stack

| Role | Family | Package |
|---|---|---|
| Latin UI | **Inter** | `inter-font` (official) |
| Latin monospace | **JetBrains Mono Nerd** | `ttf-jetbrains-mono-nerd-basic` (official) |
| Arabic UI | **Vazirmatn** | `vazirmatn-fonts` (AUR) |
| Arabic reading / Quranic | **Scheherazade New** | `ttf-scheherazade-new` (official) |
| Arabic serif / documents | **Amiri** | `ttf-amiri` (AUR) |
| Emoji | **Noto Color Emoji** | `noto-fonts-emoji` (official) |
| Fallback (everything else) | **Noto Sans** | `noto-fonts` (official) |

`fontconfig/fonts.conf` binds them by language so you never see a fallback surprise:
`lang="ar"` prefers Scheherazade New for serif and Vazirmatn for sans; `lang="ar"` with
`family="monospace"` falls back to Vazirmatn then Noto Sans Arabic; the generic sans
family is Inter with Vazirmatn and Noto Sans behind it; `emoji` is Noto Color Emoji
with `hintstyle` disabled; and `disable_lcdfilter` is set for Inter's stems. Arabic
digits are *not* forced — Western digits stay Western unless you enable the
`lang="ar"` digit rule, which is present but commented.

### 5.5 `home/`

| File | What it does |
|---|---|
| `bashrc` | `~/.local/bin` and `~/Bin` prepended to `PATH`; `starship init bash`; `zoxide init bash`; fzf key-bindings and completion sourced from `/usr/share/fzf`; `mise activate` (guarded); history settings (`HISTSIZE=50000`, `HISTCONTROL=ignoreboth:erasedups`, `shopt -s histappend`); aliases `ls`→`eza --icons`, `ll`, `cat`→`bat`, `g`→`git`, `lg`→`lazygit`, `t`→`tmux attach`; `EDITOR=nano`, `PAGER=less -R`. |
| `bash_profile` | Sources `~/.bashrc` for login shells. |
| `nanorc` | Line numbers, `set tabsize 4`, `set autoindent`, syntax highlighting from `/usr/share/nano/*.nanorc`, and a soft-wrap-aware `set breaklonglines`. |
| `XCompose` | Custom characters, §5.6. |
| `gitconfig.tpl` | Rendered to `~/.gitconfig` with `@GIT_NAME@` → `ghoulamedz` and `@GIT_EMAIL@` → `mluke4120@gmail.com`. Carries over your existing settings: `init.defaultBranch = master`, `core.editor = nano`, `pull.rebase = true`, `push.autoSetupRemote = true`, `diff.algorithm = histogram` with `colorMoved`/`mnemonicPrefix`, `commit.verbose`, `column.ui`, `branch.sort`, `tag.sort`, `rerere.enabled`/`autoupdate`, and the `co`/`br`/`ci`/`st` aliases. Two changes from what you had: aliases `lg`, `last` and `unstage` were added, and the GitHub credential helper is now `!gh auth git-credential` instead of an absolute path into a mise install, so it survives gh upgrades. |

### 5.6 `~/.XCompose` — custom characters

`XCOMPOSEFILE` is exported from `envs.lua`. Prefix is the compose key
(`Multi_key`), set in `input.lua` as `compose:caps` — i.e. **Caps Lock**.
`include "%L"` keeps the system defaults.

| Input | Output |
|---|---|
| `Caps` `a` `l` `l` `a` `h` | الله |
| `Caps` `s` `a` `w` | ﷺ |
| `Caps` `b` `s` `m` | ﷽ |
| `Caps` `j` `a` `l` | ﷻ |
| `Caps` `,` `a` | َ fatha |
| `Caps` `,` `u` | ُ damma |
| `Caps` `,` `i` | ِ kasra |
| `Caps` `,` `s` | ْ sukun |
| `Caps` `,` `d` | ّ shadda |
| `Caps` `,` `-` | ٰ superscript alef |
| `Caps` `,` `t` | ـ tatweel |
| `Caps` `0` … `Caps` `9` | ٠ ١ ٢ ٣ ٤ ٥ ٦ ٧ ٨ ٩ Arabic-Indic digits |
| `Caps` `m` `s` / `m` `c` / `m` `h` / `m` `y` / `m` `n` / `m` `x` / `m` `1` / `m` `p` / `m` `g` / `m` `a` | 😄 😂 ❤️ 👍 👎 🎉 💯 🙏 👋 💪 |
| `Caps` `-` `-` / `-` `>` / `<` `-` | — → ← |

(Full list is in the file; this is the shape of it.)

### 5.7 `wallpapers/` and `data/`

| Path | Contents |
|---|---|
| `wallpapers/` | 4 images downscaled to 1920x1080, taken from the Tokyo Night theme set already on your machine: `winding-road`, `quattro`, `sunset-lake`, `oma-cityscape`. Copied to `~/Pictures/wallpapers/`; `wallpaper-picker` and `wallpaper-cycle` read that directory. |
| `data/emoji.tsv` | 1923 emoji, tab-separated `glyph<TAB>name`, sorted by name. Generated from Unicode's `emoji-test.txt` (version 18.0, from unicode.org) by keeping every `fully-qualified` entry and dropping skin-tone and hair variants — those are the same emoji with a modifier appended, and they would have tripled the list. Installed to `~/.local/share/arch-configs/data/emoji.tsv`, so the list can be edited without touching `emoji-picker`. |

There is deliberately no TUI list file: TUIs (btop, lazygit, lazydocker, herdr, nano, tmux)
get their own `.desktop` entries instead, so they are found by typing in fuzzel rather
than through a second hand-maintained list.

---

## 6. Keybindings

Reproduced from Omarchy's `bindings/{tiling,clipboard,utilities,applications}.lua`
with every `omarchy-*` command replaced by an upstream tool or one of our scripts.
Two deliberate differences: `SUPER + SPACE` opens **fuzzel** (Omarchy opens a
Quickshell menu) and `SUPER + CTRL + V` opens the **fzf clipboard picker** (Omarchy
opens a Quickshell panel).

### Applications

| Keys | Action | Replaces |
|---|---|---|
| `SUPER + RETURN` | Terminal (ghostty) | `omarchy-launch-terminal` |
| `SUPER + SHIFT + RETURN` | Browser | `omarchy-launch-browser` |
| `SUPER + SHIFT + F` | File manager (nautilus) | `omarchy-launch-nautilus` |
| `SUPER + ALT + SHIFT + F` | File manager at cwd | `nautilus-cwd` |
| `SUPER + SHIFT + N` | Editor (VS Code) | `omarchy-launch-editor` |
| `SUPER + SPACE` | App launcher (fuzzel) | `omarchy-menu` |
| `SUPER + ALT + RETURN` | Tmux | `terminal-tmux` |
| `SUPER + CTRL + RETURN` | herdr | `terminal-herdr` |
| `SUPER + SHIFT + D` | lazydocker | `omarchy-launch-docker-tui` |
| `SUPER + SHIFT + O` | Obsidian | same |

### Windows and workspaces

| Keys | Action |
|---|---|
| `SUPER + W` | Close window |
| `CTRL + ALT + DELETE` | Close all windows |
| `SUPER + J` | Toggle window split |
| `SUPER + P` | Pseudo window |
| `SUPER + T` | Toggle floating/tiling |
| `SUPER + F` | Full screen |
| `SUPER + ALT + F` | Full width (maximized) |
| `SUPER + O` | Pop window out (float and pin) |
| `SUPER + L` | Toggle workspace layout |
| `SUPER + LEFT/RIGHT/UP/DOWN` | Focus in direction |
| `SUPER + 1..0` | Switch to workspace 1..10 |
| `SUPER + SHIFT + 1..0` | Move window to workspace |
| `SUPER + SHIFT + ALT + 1..0` | Move window silently |
| `SUPER + S` | Toggle scratchpad |
| `SUPER + ALT + S` | Move window to scratchpad |
| `SUPER + TAB` / `SHIFT + TAB` / `CTRL + TAB` | Next / previous / former workspace |
| `SUPER + SHIFT + LEFT..DOWN` | Swap window in direction |
| `SUPER + SHIFT + ALT + LEFT..DOWN` | Move workspace to monitor |
| `ALT + TAB` / `ALT + SHIFT + TAB` | Cycle windows |
| `CTRL + ALT + TAB` | Next monitor |
| `SUPER + G` / `ALT + G` | Toggle grouping / leave group |
| `SUPER + ALT + TAB` | Next window in group |
| `SUPER + mouse:272` / `:273` | Drag / resize window |
| `SUPER + mouse_up` / `down` | Scroll workspaces |
| `SUPER + SLASH` / `SUPER + ALT + SLASH` | Monitor scale up / down |
| `SUPER + SHIFT + ALT + LEFT..DOWN` | (reserved: monitor moves) |

### Clipboard

| Keys | Action |
|---|---|
| `SUPER + C` / `V` / `X` | Universal copy / paste / cut (sends the right chord to terminals vs GUI apps) |
| `SUPER + CTRL + V` | Clipboard history (fzf over `cliphist`) |

### Utilities

| Keys | Action | Replaces |
|---|---|---|
| `SUPER + K` | Keybindings cheatsheet | `omarchy-menu-keybindings` |
| `SUPER + CTRL + E` | Emoji picker | `omarchy-shell shell toggle omarchy.emojis` |
| `SUPER + CTRL + V` | Clipboard manager | `omarchy-shell shell toggle omarchy.clipboard` |
| `SUPER + CTRL + C` | Screenshot region | capture menu |
| `PRINT` | Full screenshot | `omarchy-capture-screenshot` |
| `SUPER + CTRL + PRINT` | OCR text extraction | `omarchy-capture-text` |
| `SUPER + PRINT` | Colour picker | `hyprpicker` |
| `SUPER + ESCAPE`, `XF86PowerOff` | Power menu (fzf) | `omarchy-menu system` |
| `SUPER + CTRL + SPACE` | Wallpaper picker | background menu |
| `SUPER + CTRL + L` | Lock | `omarchy-system-lock` |
| `SUPER + CTRL + I` | Toggle lock-on-idle (keep awake) | `omarchy-toggle-idle` |
| `SUPER + CTRL + N` | Toggle night light | `omarchy-toggle-nightlight` |
| `SUPER + SHIFT + SPACE` | Next wallpaper | background menu |
| `SUPER + SHIFT + Q`, `XF86Calculator` | Calculator (`qalculate-qt`) | `omacalc` |
| `SUPER + CTRL + D` | Display scale picker | display panel |
| `SUPER + comma` / `SHIFT + comma` | Dismiss last / all notifications | `omarchy-shell notifications` |
| `SUPER + CTRL + B` | Bluetooth panel | bluetooth panel |
| `SUPER + CTRL + W` | Network panel (`nmtui`) | network panel |
| `SUPER + CTRL + A` | Audio panel | audio panel |
| `XF86AudioRaiseVolume/LowerVolume/Mute` | Volume, with OSD | `omarchy-audio-output-volume` |
| `XF86AudioMicMute` | Mute microphone | `omarchy-audio-input-mute` |
| `SHIFT + XF86AudioMute` | Switch audio output | `omarchy-audio-output-switch` |
| `XF86MonBrightnessUp/Down` | Brightness, with OSD | `omarchy-brightness-display` |
| `XF86KbdBrightnessUp/Down` | Keyboard backlight | `omarchy-brightness-keyboard` |
| `XF86AudioPlay/Pause/Next/Prev` | Media control (`playerctl`) | `omarchy-shell media` |
| `switch:on/off:Lid Switch` | Lid close/open | `omarchy-system-lid-close` |

Not carried over, because they were Omarchy-specific, Quickshell-specific, or have no
upstream mechanism on Hyprland 0.55+:

| Omarchy binding | Why it is absent here |
|---|---|
| `XF86TouchpadOn` / `Off` / `Toggle` | The only runtime mechanism is the hyprlang `device[...]` selector, deprecated in 0.55 in favour of the static `hl.device()`. Use the commented `hl.device` example in `input.lua`. |
| `SUPER + SHIFT + SPACE` as a top-bar toggle | The chord now cycles the wallpaper. Hiding the bar would need a `pkill -x waybar` binding; none is installed. |
| `SUPER + BACKSPACE`, `SUPER + SHIFT + BACKSPACE`, `SUPER + CTRL + BACKSPACE` | Runtime transparency, gap and aspect-ratio toggles. Omarchy implemented these as generated Lua state; nothing here does. |
| `SUPER + CTRL + F` | "Tiled fullscreen". Plain fullscreen (`SUPER + F`) and maximized (`SUPER + ALT + F`) remain. |
| `SUPER + CTRL + K`, `SUPER + ALT + K` | herdr / tmux keybinding cheatsheets. Use `tmux list-keys -N` (bound to `?` in `tmux.conf`) and `herdr --help`. |
| `SUPER + CTRL + R`, `SUPER + SHIFT + CTRL + R` | Reminders. |
| `SUPER + CTRL + X`, `F9` | Dictation. |
| `SUPER + CTRL + PERIOD` | Transcoding. |
| `SUPER + SHIFT + A/C/E/Y/X/…` | Web-app launchers (ChatGPT, HEY, YouTube, X…). |
| `SUPER + SHIFT + CTRL + SPACE` | Theme switcher — this setup has no theme engine. |
| `SUPER + CTRL + ALT + D/B/T/W` | Clock, battery, time and weather notices. |
| `SUPER + ALT + code:34/35` | Webcam overlay resize. |
| `SUPER + CTRL + Delete`, `SUPER + CTRL + ALT + Delete` | Laptop panel toggles. Single-panel machine; the lid switch is handled in `bindings.lua`. |
| `SUPER + SHIFT + M`, `G`, `W`, `SLASH` | Spotify, Signal, omawrite, 1Password — none installed. |

---

## 7. `vaapi-backend` — VA-API driver strategy

**VA-API is not a system setting.** It is a client-side API: `libva` loads one driver
shared object, chosen by the environment variable `LIBVA_DRIVER_NAME`.

| Value | Driver package | `.so` | Used for |
|---|---|---|---|
| `iHD` | `intel-media-driver` | `/usr/lib/dri/iHD_drv_video.so` | Intel Gen8+ (your Raptor Lake iGPU) |
| `nvidia` | `libva-nvidia-driver` | `/usr/lib/dri/nvidia_drv_video.so` | NVDEC on the RTX 5050 |
| `i965` | `libva-intel-driver` | `/usr/lib/dri/i965_drv_video.so` | legacy Intel Gen4–Gen7 (not installed here) |

**The catch that makes a GUI impossible:** VA-API follows the GPU the client is
*actually rendering on*. On a hybrid laptop that is decided per process, at launch,
by the PRIME offload environment — not by a global preference. Point `libva` at
`nvidia` while the app renders on the iGPU (or the reverse) and you get a driver that
initialises and then fails to decode. So there is one correct value per process, and
no single correct value for the system. That is why no control panel exists.

**The strategy, therefore:**

1. **Default to `iHD`.** The compositor and almost every app render on the iGPU, so
the session-wide default is the Intel driver. This is also the battery-friendly
choice.
2. **Persist it where it belongs.** `~/.config/environment.d/vaapi.conf`.
   Two things read that file. systemd's *user* manager reads it at session start
   when the session is started by `uwsm`. Because SDDM has no setting that forces
   the uwsm session, and will usually launch plain `hyprland.desktop`, `envs.lua`
   also reads every file in `~/.config/environment.d` itself and calls `hl.env` for
   each `KEY=VALUE` — so the choice reaches every app Hyprland spawns however the
   session started. `$HOME` and `$PATH` are expanded by that loader and
   colon-separated values are deduplicated, so a `hyprctl reload` cannot grow PATH.
   Nothing in `envs.lua` sets `LIBVA_DRIVER_NAME` directly, so this one file remains
   the single source of truth and switching it never means editing a config by hand.
   The same file is also where the session PATH lives (`10-path.conf`), which is what
   makes the bare script names in the bindings and in Waybar resolve.
3. **Make the dGPU opt-in per command.** `vaapi-backend run <cmd>` sets all four
   variables that have to move together — `__NV_PRIME_RENDER_OFFLOAD=1`,
   `__VK_LAYER_NV_optimus=NVIDIA_only`, `__GLX_VENDOR_LIBRARY_NAME=nvidia`, and
   `LIBVA_DRIVER_NAME=nvidia` — then `exec`s your command. Offload and driver must be
   set together; setting one without the other is the usual reason NVDEC "does not
   work".
4. **Verify, don't assume.** `vaapi-backend status` runs `vainfo` once per installed
   driver with the variable overridden, and prints the `VAProfile*` entrypoints, so
   you can see which driver actually initialised and whether it exposes H.264, HEVC
   or AV1 decode.

```
$ vaapi-backend status
persisted  : iHD
this shell : (unset)
installed  : iHD nvidia

== iHD ==
vainfo: Driver version: Intel iHD driver for Intel(R) Gen Graphics
VAProfileH264High : VAEntrypointVLD
VAProfileHEVCMain : VAEntrypointVLD
VAProfileAV1Profile0 : VAEntrypointVLD

== nvidia ==
vainfo: Driver version: VA-API NVDEC driver
VAProfileH264High : VAEntrypointVLD
VAProfileHEVCMain : VAEntrypointVLD
```

Note on encode: the **NVIDIA VA-API shim is decode-only** — `nvidia_drv_video.so` wraps
NVDEC and exposes `VAEntrypointVLD` only. **`iHD` does advertise encode**
(`VAEntrypointEncSlice` / `VAEntrypointEncSliceLP`, the low-power VDENC path) for H.264,
HEVC and VP9 on Raptor Lake. **AV1 encode is not available on this iGPU** — hardware AV1
encoding starts with Arc / Meteor Lake and later. So for encoding: use `iHD` via VA-API,
or `vpl-gpu-rt` (oneVPL) for Intel, or NVENC directly on the dGPU. `vaapi-backend
status` prints the ground truth for this exact machine rather than trusting this table.

---

## 8. Third-party binary audit

Every package here is from the official Arch repositories or the AUR. Nothing is built
from an Omarchy fork. The entries below are **not** open-source-community projects, or
ship prebuilt code. They are all deliberate choices — this table exists so the choice
is visible.

| Package | Source | Issue | Status |
|---|---|---|---|
| `pantum-universal-driver` (AUR) | Pantum | **Proprietary closed-source blob.** Precompiled binaries, no source available, no public audit. | Accepted — needed for the printer. The only genuinely opaque package in the set. |
| `herdr-bin` (AUR) | `herdrdev/herdr` GitHub releases | **Prebuilt binary** fetched from a vendor release, not built by an Arch packager. Apache-2.0 licensed, so source *exists* (`herdr` in AUR builds it). | Accepted as `herdr-bin`. |
| `code` (official `extra`) | Microsoft | Open-source build (MIT), packaged by Arch from source — but it is a **Microsoft** product, and the extension Marketplace it talks to is proprietary. | Accepted. `vscodium` (AUR) is the community build with Open VSX if this is ever revisited. |
| `github-cli` (official) | GitHub / Microsoft | MIT, packaged by Arch, but owned by a large corporation. | Accepted. |
| `docker`, `docker-compose`, `docker-buildx` (official) | Docker Inc. | Apache-2.0 and packaged by Arch, but corporate upstream. **Also bypasses `ufw` entirely** — published container ports are reachable from the LAN regardless of firewall rules. | Accepted, including the firewall bypass. `podman` is the rootless community alternative. |
| `obsidian` (official) | Obsidian.md | **Proprietary freeware.** Arch repackages the vendor's binary. | Accepted. |
| `nvidia-open` (official) | NVIDIA | Corporate, but the **open** kernel modules (MIT/GPL dual), built by Arch from source. No alternative exists for Blackwell (GB207). | Unavoidable. Chosen over `nvidia-open-dkms` to avoid DKMS entirely. |
| `noto-fonts`, `noto-fonts-emoji` (official) | Google | Corporate origin, but **SIL OFL** licensed and packaged by Arch. | Fine. |
| `mise` (official) | mise | MIT. Downloads prebuilt language runtimes at runtime, outside pacman. | Accepted; not yet in use. |
| `paru`, `ufw`, `gufw`, `hyprland`, `uwsm`, `waybar`, `mako`, `fuzzel`, `foot`, `grim`, `slurp`, `satty`, `cliphist`, `fzf`, `btop`, `eza`, `bat`, `lazygit`, `lazydocker`, `fcitx5*`, `tesseract`, `mpv`, `imv`, `qbittorrent`, `localsend`, `kdenlive`, `libreoffice-fresh`, all fonts | various | GPL / MIT / BSD / OFL, community-maintained, packaged by Arch or by AUR packagers from source. | Clean. |

**No Omarchy package, binary, script, or pacman repository is installed by this repo.**

### Why `nvidia-open` and not `nvidia-open-dkms`

| | `nvidia-open` | `nvidia-open-dkms` |
|---|---|---|
| Depends on | `linux`, `nvidia-utils`, `libglvnd` | `dkms`, `nvidia-utils` |
| Needs `linux-headers` | no | **yes** |
| Rebuild on kernel update | Arch does it (package rebuild) | your machine does it, every time |
| Reboot needed after kernel bump | yes | yes |
| Works with other kernels | no — one package per kernel (`nvidia-open-lts` for `linux-lts`) | any kernel |

Since this machine boots only `linux` and no custom kernels are planned, `nvidia-open`
is strictly simpler: no `dkms`, no `linux-headers`, no `kernel-modules-hook`, no local
compilation, and nothing to break when a kernel lands before NVIDIA's module builds.
If `linux-lts` is ever added, add `nvidia-open-lts` alongside it.

---

## 9. Install reminder — run from the Arch ISO

```bash
# ---------- 1. verify the live environment ---------------------------------
cat /sys/firmware/efi/fw_platform_size     # must print 64 -> we are UEFI
cat /proc/cmdline                          # sanity check
timedatectl                                # confirm NTP is active
ping -c1 archlinux.org || iwctl            # network; iwctl -> station wlan0 connect SSID
lsblk -o NAME,SIZE,TYPE,FSTYPE,LABEL,MOUNTPOINT   # nvme0n1 = NTFS data, do not touch

# ---------- 2. partition /dev/nvme1n1 --------------------------------------
fdisk /dev/nvme1n1
#   g                create a new empty GPT
#   n 1 Enter +2G    partition 1, 2 GiB (the ESP)
#   t 1 1            set its type to EFI System
#   n 2 Enter Enter  partition 2, all remaining space (Linux filesystem)
#   p                review the table
#   w                write and exit

# ---------- 3. filesystems ------------------------------------------------
mkfs.fat -F32 -n ESP /dev/nvme1n1p1        # ESP must be FAT32
mkfs.btrfs -L arch -f /dev/nvme1n1p2       # one btrfs filesystem, -f to skip the prompt

# ---------- 4. subvolumes, created from the top level (subvolid=5) --------
mount /dev/nvme1n1p2 /mnt                  # a fresh btrfs mounts the top level
btrfs subvolume create /mnt/@              # root; this is what snapper snapshots
btrfs subvolume create /mnt/@home          # your data, excluded from rollbacks
btrfs subvolume create /mnt/@var_log       # grub-btrfs needs this for read-only snapshot boots
btrfs subvolume create /mnt/@pkg           # keeps the pacman cache out of snapshots
btrfs subvolume create /mnt/@docker        # keeps docker image layers out of snapshots
btrfs subvolume list /mnt                  # verify: 5 subvolumes, all top level 5

# make @ the filesystem default subvolume, so GRUB boots it with no rootflags
# (grub-btrfs builds its own rootflags from fstab; a second one would conflict)
btrfs subvolume set-default "$(btrfs subvolume list /mnt | awk '$NF=="@"{print $2}')" /mnt
umount /mnt

# ---------- 5. mount the real layout -------------------------------------
OPT=noatime,compress=zstd:3,ssd,space_cache=v2
mount -o "$OPT,subvol=/@"        /dev/nvme1n1p2 /mnt
mount -o "$OPT,subvol=/@home"    --mkdir /dev/nvme1n1p2 /mnt/home
mount -o "$OPT,subvol=/@var_log" --mkdir /dev/nvme1n1p2 /mnt/var/log
mount -o "$OPT,subvol=/@pkg"     --mkdir /dev/nvme1n1p2 /mnt/var/cache/pacman/pkg
mount -o "$OPT,subvol=/@docker"  --mkdir /dev/nvme1n1p2 /mnt/var/lib/docker
mount --mkdir /dev/nvme1n1p1 /mnt/boot     # ESP last, into the empty root
findmnt -R /mnt                            # must show 6 mounts before continuing

# ---------- 6. install ----------------------------------------------------
git clone https://github.com/ghoulamedz/arch-configs /root/arch-configs
cd /root/arch-configs
./install.sh                               # pacstrap, chroot, configs, AUR; asks for the medo password once

# ---------- 7. finish -----------------------------------------------------
umount -R /mnt
reboot                                     # remove the USB stick
```

After the reboot: log in at SDDM, and the only manual steps left are the ones the
script cannot do — add the printer at `http://localhost:631`, run `gh auth login`, and
drop your own files into `~/Bin`.

