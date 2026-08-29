# Omarchy Dotfiles — Installation Guide

My personal setup for [Omarchy](https://omarchy.org/) (Arch Linux + Hyprland).
This is a complete, step-by-step guide to reproduce this machine from a fresh install.

**The only secret you ever need to bring is your DeepSeek API key.** Everything else is in this repo.

---

## Overview of what you're installing

- **DeepSeek quick-access widget** — a robot icon in the top bar. Click it (or double-tap `Super`) to open a dropdown where you type a question and get an answer inline, powered by `deepseek-v4-flash-vision-exp`. "Open app" launches full OpenCode (on `deepseek-v4-pro`).
- **DeepSeek as the only AI** — every other agent (Claude Code, Codex, Gemini, Grok, Copilot, etc.) and AI web app (ChatGPT, Grok) is removed.
- **Clean base** — removed unwanted web apps (X, WhatsApp, Google Photos/Messages/Maps, Zoom, Discord), Spotify/Signal/1Password launchers, and tmux/herdr/rails shell aliases.
- **~135 community themes** (optional).

---

## Step 0 — Install Omarchy (the OS)

1. Download the ISO from <https://omarchy.org/>.
2. Write it to a USB stick (balenaEtcher on Mac/Windows, or `iso2sd` on Linux).
3. **Turn off Secure Boot and TPM in the BIOS** (required).
4. Boot from the USB and follow the installer. It wipes the target drive and uses full-disk encryption — back up anything on it first.
5. Finish the setup questions, log in.

Reference: <https://omarchy.org/manual/getting-started/>

## Step 1 — Update the system

```bash
omarchy update
```

## Step 2 — Install git + GitHub auth

Omarchy ships `git` and `gh`. Log in to GitHub (this sets up git credentials too):

```bash
gh auth login
# → GitHub.com → HTTPS → Login with a web browser → enter the one-time code
gh auth setup-git
```

## Step 3 — Clone this repo

```bash
git clone https://github.com/Opklaar/omarchy-dotfiles.git ~/dotfiles
cd ~/dotfiles
```

## Step 4 — Apply the dotfiles

```bash
./bootstrap.sh
```

This links all config files into `$HOME`, re-runs the app/agent removals, reloads
Hyprland + the shell, and enables the sync watchdog (below).

## Step 5 — Install community themes (optional)

```bash
./install-themes.sh
```

Clones ~135 community themes into `~/.config/omarchy/themes`. GitHub rate-limits
unauthenticated clones — if some fail, just re-run the script to retry.

## Step 6 — Bring your DeepSeek API key

This is the **only** thing you must supply.

```bash
opencode auth login
# → choose DeepSeek → paste your API key
```

The key is stored in `~/.local/share/opencode/auth.json` (never committed).
The model config (`v4-pro` main, `v4-flash` small, `v4-flash-vision-exp` vision)
is already in this repo.

## Step 7 — Verify it works

- **Double-tap `Super`** → the DeepSeek dropdown opens with the input focused.
- Type a question, press **Enter** → answer appears inline.
- **Right-click the robot icon** (or "Open app") → full OpenCode on `v4-pro`.
- `Super + Ctrl + Shift + Space` → theme picker (if you installed themes).
- `Super + K` → should NOT list ChatGPT/Grok/etc.

---

## How it works (so you never have to think about it)

### Everything survives updates

`omarchy update` only rewrites `/usr/share/omarchy/` (package-owned). Your configs
live in `~/.config/`, `~/.bashrc`, and `~/.local/bin/` — updates never touch them.

### Symlinks + a sync watchdog

Config files are **symlinked** into `$HOME` from this repo. The shell and opencode
sometimes rewrite configs atomically (which replaces the symlink with a plain
file). A **systemd timer** runs `sync.sh` every 5 minutes to detect that, capture
the new content back into the repo, and re-link — automatically.

Check it:
```bash
systemctl --user status omarchy-dotfiles-sync.timer
```

### The DeepSeek widget is a cloned plugin

It lives at `~/.config/omarchy/plugins/fh.agents/` — a user-owned clone of the
built-in `omarchy.agents` plugin, so it survives `omarchy update`.

---

## Daily maintenance

**Pull updates to another machine:**
```bash
cd ~/dotfiles && git pull && ./bootstrap.sh
```

**Commit changes you make:**
```bash
cd ~/dotfiles && git add -A && git commit -m "describe the change" && git push
```

**Reset something you broke:**
```bash
omarchy refresh <component>   # e.g. `omarchy refresh shell`, `omarchy refresh hyprland`
```

---

## Repo layout

```
home/.config/hypr/bindings.lua              # keybindings: double-Super + unbinds
home/.config/omarchy/plugins/fh.agents/     # DeepSeek quick-access widget
home/.config/omarchy/shell.json             # bar layout
home/.config/opencode/opencode.json         # DeepSeek model config (no keys)
home/.config/systemd/user/*                 # sync watchdog timer + service
home/.local/bin/omarchy-super-tap           # double-Super tap-detection script
home/.bashrc                                 # shell alias cleanup
themes.txt                                   # list of ~135 community theme URLs
bootstrap.sh                                 # apply everything (idempotent)
install-themes.sh                            # re-clone themes
sync.sh                                      # watchdog: heal symlinks
```
