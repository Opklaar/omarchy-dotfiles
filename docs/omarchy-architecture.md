# Omarchy Architecture — How It Differs From Stock Arch

Omarchy is an "omakase" (chef's-choice) distribution: **Arch Linux + Hyprland +
Quickshell**, assembled by DHH / 37signals. It is not a fork of Arch — it is a
*layer on top of Arch* that swaps out most of the conventional plumbing for its
own, and automates everything. This document maps the whole system against a
stock Arch install.

---

## 1. Executive summary

| Layer | Stock Arch | Omarchy |
|---|---|---|
| Base | Arch (pacman, systemd) | Same, but pointed at Omarchy's own mirror + `[omarchy]` repo + AUR via yay |
| WM | (your choice) | Hyprland (Wayland tiling), configured in **Lua** |
| Desktop shell | waybar / mako / wofi / swayosd / hyprlock (separate tools) | **One Quickshell process** that draws bar, notifications, menus, panels, OSD, lock screen |
| Bootloader | GRUB or systemd-boot (you set it up) | **Limine** (pre-configured) |
| Disk | ext4, no encryption (typical) | **LUKS full-disk encryption + btrfs** (subvolumes, zstd:3, snapper snapshots) |
| Initramfs | mkinitcpio + `udev` hook | mkinitcpio + **`systemd` hook** |
| Display manager | (your choice) | **SDDM** |
| Session | (manual) | **uwsm** (Universal Wayland Session Manager) wraps Hyprland |
| Config | dotfiles you write yourself | **`omarchy` CLI** + `/usr/share/omarchy` defaults + `~/.config` overrides |
| Updates | `pacman -Syu` | **`omarchy update`** (pacman + migrations + AUR), 4 channels |
| App tooling | (manual) | **mise** with lazy-loading wrappers in `~/.local/bin` |

The key idea: Omarchy **ships a complete, opinionated system**, then gives you a
huge self-documenting CLI (`omarchy ...`) to control it. Almost nothing is "stock
Arch default."

---

## 2. Boot & disk stack

### Disk layout (btrfs + LUKS)

```
nvme0n1p1   2G    vfat        /boot            (ESP, Limine)
nvme0n1p2   ~952G crypto_LUKS ── root (btrfs)
                              ├─ @           → /
                              ├─ @home       → /home
                              ├─ @pkg        → /var/cache/pacman/pkg
                              └─ @log        → /var/log
```

- **Full-disk encryption** via LUKS; unlock at boot with a passphrase
  (`cryptdevice=...` in the kernel cmdline).
- **btrfs** with `compress=zstd:3`, `space_cache=v2`.
- `/var/cache/pacman/pkg` and `/var/log` are *separate subvolumes* so snapshots of
  `/` don't bloat with package tarballs or logs.

### Bootloader: Limine

Stock Arch defaults to GRUB or systemd-boot; Omarchy uses **Limine**
(`limine`, `limine-mkinitcpio-hook`). Kernel cmdline (from `/etc/default/limine`):

```
cryptdevice=PARTUUID=...:root root=/dev/mapper/root zswap.enabled=0
rootflags=subvol=@ rw rootfstype=btrfs
```

### Snapshots: snapper + Limine

- **snapper** (btrfs snapshots) with a `root` config; `snapper-cleanup.timer` is
  enabled.
- **`limine-snapper-sync`** + a boot-time watcher regenerate a Limine boot entry
  for each snapshot, so you can boot *into* a previous snapshot from the boot
  menu. This is Omarchy's answer to "rollback if an update breaks things."
- `limine-snapper-notify.desktop` autostarts a desktop notification when a
  snapshot is taken.

### Initramfs, swap, kernel

- mkinitcpio `HOOKS=(base systemd autodetect microcode modconf kms keyboard
  sd-vconsole block filesystems fsck)` — note **`systemd`** instead of `udev`.
- Swap = **zram** (compressed RAM, via `zram-generator`) *plus* a **btrfs
  swapfile** at `/swap/swapfile` for hibernation.
- Ships **two kernels**: `linux` and `linux-ptl` (an alternative
  performance-tuned kernel), selected via the boot menu.

### Display manager + session

- **SDDM** starts the login screen.
- **uwsm** (`uwsm start ... Hyprland`) launches Hyprland as a properly-scoped
  systemd *user session*, which is how Omarchy's user services (see §8) run
  cleanly.

---

## 3. Package management

### Repositories

`/etc/pacman.conf`:
```
[core]      Include = /etc/pacman.d/mirrorlist
[extra]     Include = /etc/pacman.d/mirrorlist
[multilib]  Include = /etc/pacman.d/mirrorlist
[omarchy]   SigLevel = Optional TrustAll
```

`/etc/pacman.d/mirrorlist` contains a **single line**:
```
Server = https://stable-mirror.omarchy.org/$repo/os/$arch
```

So the ordinary Arch repos (`core`, `extra`, `multilib`) are served through
**Omarchy's own mirror** (a snapshot/pin of Arch), and `[omarchy]` is Omarchy's
private package repo (ships `omarchy`, `omarchy-keyring`, `omarchy-nvim`,
`omarchy-settings`, `aether`, `cliamp`, `omawrite`, `omacalc`, `omacut`, etc.).

### AUR

AUR is accessed through **yay** (not manually). `omarchy pkg aur add <pkg>`
wraps it, and `omarchy update` also updates AUR packages.

### `omarchy pkg`

- `omarchy pkg add <pkg...>` — install from the repos (interactive fuzzy picker
  in the menu).
- `omarchy pkg drop <pkg>` — remove (removes config + deps).
- `omarchy pkg aur add/drop` — AUR equivalents.

### Shipped package lists

- `/usr/share/omarchy/install/omarchy-base.packages` — the pacstrapped core
  (Chromium, LibreOffice, Obsidian, btop, docker, fzf, eza, herdr, foot,
  hyprland, etc.).
- `/usr/share/omarchy/install/omarchy-other.packages` — drivers & kernels
  (multiple `nvidia-*` variants, `vulkan-*` auto-detected, `linux-ptl`,
  `macbook12-spi-driver-dkms`, `tuxedo-drivers-*`, `yt6801-dkms`, etc.).

---

## 4. The `omarchy` CLI (the control plane)

This is the heart of Omarchy and its biggest departure from stock Arch.

- **422 binaries** live in `/usr/share/omarchy/bin/`, each named `omarchy-*`
  and each a small bash script with **metadata comments** in its header:
  ```bash
  # omarchy:summary=Apply an Omarchy theme
  # omarchy:args=<theme-name>
  # omarchy:group=theme
  ```
- The top-level `omarchy` command scans every `omarchy-*` binary, reads those
  comments, and builds a **routing table** (`ROUTE_TO_KEY`). So:
  - `omarchy theme set catppuccin` → routes to `omarchy-theme-set catppuccin`
  - `omarchy commands` / `omarchy commands --json` → the self-generated catalog
  - `omarchy <group> --help` → grouped help
- Adding a command = adding a `omarchy-foo-bar` script with the right comments;
  it is discovered automatically. There is no hardcoded command registry.

### Command groups (~90)

`theme`, `bar`, `toggle`, `capture`, `pkg`, `install`, `remove`, `hook`,
`plugin`, `launch`, `refresh`, `restart`, `reinstall`, `update`, `migrate`,
`channel`, `snapshot`, `system`, `menu`, `shell`, `hyprland`, `audio`,
`bluetooth`, `network`, `brightness`, `display`, `power`, `battery`, `dns`,
`drive`, `font`, `branding`, `screensaver`, `plymouth`, `reminder`,
`notification`, `osd`, `tailscale`, `webapp`, `windows` (VM), `games`,
`transcode`, `tui`, `agent`, `mise`, `dev`, … and more.

This is why Omarchy "does everything with bash": every feature is one of these
scripts, and the menu + hotkeys are thin wrappers over the same scripts.

---

## 5. The shell: Quickshell (one process does everything)

Stock Arch users assemble a bar (waybar/polybar), a notification daemon
(mako/dunst), an app launcher (wofi/rofi), an OSD (swayosd), and a lock screen
(hyprlock) as separate programs. **Omarchy replaces all of them with one
long-running Quickshell process** (`omarchy-shell`), so everything shares one
theme and one IPC surface.

Source: `/usr/share/omarchy/shell/` (`shell.qml`, `Commons/`, `Ui/`, `services/`,
`plugins/`).

What it draws:
- **Top bar** (widgets: menu, workspaces, clock, weather, indicators, audio,
  network, bluetooth, display, power, agents, tray, …).
- **Panels** (audio, network, bluetooth, display, power, calendar, wifi-QR,
  speed test, …) — opened by clicking a bar widget or a hotkey.
- **Notifications** (with DND + history).
- **Overlays** (emoji picker, clipboard history, image picker, reminders).
- **OSD** (volume/brightness popups).
- **The Omarchy menu** (the `Super + Space` everything-menu) and the **lock
  screen**.

### Plugins

Plugins are directories with a `manifest.json` (`kinds`: `bar-widget`,
`service`, `panel`, `overlay`, `menu`, `bar`, `lock`, …) plus QML entry points.
First-party plugins live in `/usr/share/omarchy/shell/plugins/`; user plugins in
`~/.config/omarchy/plugins/` (`omarchy plugin clone` copies a first-party plugin
there so you can edit it safely — e.g. our `fh.agents` DeepSeek widget).

### IPC

The shell exposes methods over IPC: `omarchy-shell <target> <method> [args]`.
This is how the bar panels, hotkeys (`omarchy-shell shell toggle fh.agents`), and
theme application talk to the running shell.

### Bar layout

`~/.config/omarchy/shell.json` → `bar.layout.left/center/right`, each an array of
widget entries `{ "id": "omarchy.clock", "format": "..." }`. Managed by
`omarchy bar ...` commands or by dragging in the UI.

---

## 6. The theme system

- A theme is a directory of files, centered on **`colors.toml`** (semantic
  colors: `accent`, `background`, `foreground`, `red`…`magenta`, `dark_background`,
  shades, `bright_*`, `selection`, `muted`, `mode`).
- **`omarchy-theme-color`** is the central resolver: it reads `colors.toml` and
  normalizes *legacy* formats (v3 ANSI `color0–15`, short names `bg`/`fg`) into
  the current semantic palette, deriving missing shades/brights by mixing.
- **`omarchy-theme-set-templates`** renders a set of templates in
  `/usr/share/omarchy/default/themed/*.tpl` (and user overrides in
  `~/.config/omarchy/themed/`) into per-app config files: alacritty, foot,
  kitty, ghostty, btop, chromium, hyprland, hyprlock, mako→shell, neovim,
  vscode, obsidian, helix, claude/pi, etc. Each template uses `{{ key }}` and
  `{{ mix a b 50% }}` placeholders.
- `omarchy theme set <name>` builds a staging dir
  (`~/.local/state/omarchy/current/next-theme`), atomically swaps it in, tells the
  shell the new palette over IPC, restarts the affected apps, and runs the
  `theme-set` hook.
- Themes live in `/usr/share/omarchy/themes/` (22 stock) and
  `~/.config/omarchy/themes/` (community + user). User themes win on top of stock.

This is a big divergence from stock Arch: the *entire system* re-skins at once
from one color file.

---

## 7. Hyprland config (Lua, not .conf)

Stock Hyprland uses `hyprland.conf`. Omarchy uses **Lua**:

```
~/.config/hypr/hyprland.lua      # loads Omarchy defaults, then user modules
~/.config/hypr/bindings.lua      # keybindings (user)
~/.config/hypr/monitors.lua      # displays
~/.config/hypr/input.lua         # keyboard/mouse
~/.config/hypr/looknfeel.lua     # gaps/borders/animations
~/.config/hypr/autostart.lua     # startup apps
```

Defaults live in `/usr/share/omarchy/default/hypr/` (modules like
`bindings/*.lua`, `apps/*.lua`, `helpers.lua`). Helpers:
- `o.bind(keys, description, dispatcher, options)` — wraps `hl.bind` and turns
  `"SUPER + SHIFT + Y"` into the right key string.
- `o.launch(command)`, `o.launch_webapp(url)`, `o.launch_tui`, `o.window(...)`,
  `o.bind_toggle(...)`.
- `hl.unbind("SUPER + X")` removes a default binding.

Keybindings are documented via `omarchy menu keybindings --print` / `Super + K`.

---

## 8. Automation layers

### Hooks

User scripts that run on system events, in `~/.config/omarchy/hooks/`:

```
battery-low.d/        # low battery ($1 = percentage)
font-set.d/           # after font change ($1 = font)
post-boot.d/          # after desktop starts
post-update.d/        # during `omarchy update`
pre-refresh-pacman.d/ # before `omarchy refresh pacman`
theme-set.d/          # after theme change ($1 = theme slug)
```

Install with `omarchy hook install <name> <script>`.

### Migrations

Timestamped shell scripts in `/usr/share/omarchy/migrations/` (e.g.
`1778623107.sh`). `omarchy migrate` runs any whose timestamp is newer than the
last-applied marker in `~/.local/state/omarchy/migrations/`. These are how
Omarchy evolves users' *installed* systems in place (moving config, renaming
things) as the distro changes — the equivalent of a package post-upgrade hook
but for the whole desktop.

### Toggles

Flag files in `~/.local/state/omarchy/toggles/` named for the *off* state
(`bar-off`, `screensaver-off`, `suspend-off`, …). `omarchy toggle <thing>`
creates/removes them; `omarchy-toggle-enabled <flag>` reports via exit code.
Examples: night light, DND, stay-awake, touchpad, suspend, hybrid GPU, bar.

### System snapshots

snapper + Limine (§2) give bootable rollback points; `omarchy snapshot` group
and `limine-snapper-sync` tie them into the boot menu.

---

## 9. Updates & release channels

- `omarchy update` = `omarchy-migrate` (run pending migrations) → pacman against
  the Omarchy mirror + `[omarchy]` repo → AUR via yay.
- **Four channels**: `stable`, `rc`, `edge`, `dev`. New installs start on
  `stable`. `omarchy channel set <channel>` switches the mirror/repo.
- The bar shows an **update badge** when updates are pending; clicking it runs
  the update.

---

## 10. Tool management: mise

Runtime/tool versioning is delegated to **mise** (`~/.local/share/mise`). Many
tools aren't installed as packages at all — they're **lazy-loading stubs** in
`~/.local/bin/`:

```bash
#!/bin/bash
export MISE_MINIMUM_RELEASE_AGE=0
mise use -g "github:basecamp/hey-cli" || exit 1
exec mise x "github:basecamp/hey-cli" -- "hey" "$@"
```

On first invocation the stub fetches the tool via mise; nothing is downloaded
until you actually run it. This is how `opencode`, `hey`, and the (removed) AI
agents are delivered. Global tool pins live in `~/.config/mise/config.toml`
(`[tools]`).

---

## 11. Session & environment

- **uwsm** manages the Wayland session as a systemd user unit, so user services
  are first-class.
- **`/usr/share/omarchy/default/environment.d/`** sets session env (fcitx5 input
  method here). `/usr/share/omarchy/default/bash/env-bootstrap` sets
  `OMARCHY_PATH` and `PATH` for every shell.
- **`/etc-overrides/`** (`/usr/share/omarchy/etc-overrides/`) holds files that
  are copied over stock `/etc/` during install/update: `os-release` (branding),
  `nsswitch.conf` (mDNS/avahi), `plymouthd.conf`, `security-faillock.conf`,
  `cups-cups-browsed.conf`.

---

## 12. Config layering (the "never edit /usr" rule)

Three layers, each overriding the previous:

1. **`/usr/share/omarchy/`** — package-owned defaults (read-only; overwritten on
   update). Never edit.
   - `bin/` (CLI), `config/` (app config templates), `default/` (system
     defaults: hypr, bash, themed, pacman, sddm, snapper, systemd, uwsm, …),
     `shell/` (Quickshell source), `themes/`, `migrations/`, `install/`.
2. **`~/.config/`** — *your* files (`~/.config/hypr`, `~/.config/omarchy/`,
   `~/.config/<app>`). Survive updates. This is where all user customization
   goes.
3. **`~/.local/state/omarchy/`** — runtime state (current theme, toggles,
   migrations markers, agents usage). Not config; regenerated.

`omarchy refresh <component>` resets a component's config to default (backing up
yours first). `omarchy refresh config <path>` refreshes one file.

---

## 13. Consolidated map of the Omarchy-specific surface

```
/usr/share/omarchy/                 (package-owned, READ-ONLY)
├── bin/omarchy-*                   (422 CLI scripts + the `omarchy` dispatcher)
├── config/                         (app config templates → copied to ~/.config)
├── default/
│   ├── bash/                       (env-bootstrap, aliases, functions, fns/*)
│   ├── hypr/                       (Lua modules: bindings, apps, helpers, …)
│   ├── themed/*.tpl                (theme templates → rendered per-app configs)
│   ├── environment.d/  sddm/  snapper/  systemd/  uwsm/  pacman/  limine/
│   └── agents/skills/              (agent skills: omarchy, diagnose-crash)
├── etc-overrides/                  (os-release, nsswitch, plymouthd, faillock)
├── install/                        (package lists + provisioning + post-install)
├── migrations/                     (timestamped .sh migration scripts)
├── shell/                          (Quickshell: shell.qml, Commons/, Ui/,
│                                   services/, plugins/)
└── themes/                         (22 stock themes)

~/.config/                          (YOUR files — survive updates)
├── hypr/*.lua                      (user Hyprland overrides)
├── omarchy/
│   ├── shell.json                  (bar layout, idle timings)
│   ├── plugins/                    (user shell plugins / bar widgets)
│   ├── themes/                     (community + user themes)
│   ├── themed/                     (user theme-template overrides)
│   └── hooks/*.d/                  (event hooks)
├── <app>/                          (foot, kitty, alacritty, btop, lazygit, …)
├── mise/config.toml                (mise global tools)
└── systemd/user/                   (user services, e.g. dotfiles sync watchdog)

~/.local/state/omarchy/             (runtime state — regenerated)
├── current/theme/                  (the *rendered* active theme + generated configs)
├── toggles/                        (bar-off, screensaver-off, …)
├── migrations/                     (applied-migration markers)
└── agents/usage/                   (AI agent usage records)

~/.local/bin/                       (lazy mise wrappers: opencode, hey, …)
~/.local/share/mise/                (mise installs + shims)
```

---

## 14. Quick "how does Omarchy do X" cheat-sheet

| Want to… | Omarchy way | Stock-Arch way |
|---|---|---|
| Update everything | `omarchy update` | `pacman -Syu` |
| Install a package | `omarchy pkg add <pkg>` | `pacman -S <pkg>` |
| Install AUR | `omarchy pkg aur add <pkg>` | `yay -S <pkg>` |
| Change theme | `omarchy theme set <name>` | manually edit ~10 config files |
| Change font | `omarchy font set <name>` | edit fontconfig + terminal config |
| Take a screenshot | `Print` (or `omarchy screenshot`) | `grim`/`spectacle` (manual) |
| Night light | `omarchy toggle nightlight` / `Super+Ctrl+N` | `hyprsunset` (manual) |
| Reminder | `omarchy reminder 15 "…"` | cron/at + notify-send |
| Add keybinding | edit `~/.config/hypr/bindings.lua` | edit `hyprland.conf` |
| Customize a widget | `omarchy plugin clone <id>` then edit | edit waybar config |
| Reset a config | `omarchy refresh <component>` | restore from backup |
| Roll back an update | boot a snapper snapshot from Limine | btrfs rollback (manual) |
| Run a script on theme change | `omarchy hook install theme-set <script>` | (nothing built-in) |
| Change update channel | `omarchy channel set <channel>` | edit mirrorlist |

This document is a living reference. It was produced by inspecting a running
Omarchy 4.0.0 system; verify details against `omarchy <group> --help` and the
`/usr/share/omarchy` source if something drifts across releases.
