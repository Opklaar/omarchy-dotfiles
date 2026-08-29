# Omarchy dotfiles

My personal Omarchy (Arch + Hyprland) configuration.

## What's in here

- **DeepSeek quick-access widget** (`home/.config/omarchy/plugins/fh.agents/`) — a bar icon whose dropdown answers questions inline using `deepseek-v4-flash-vision-exp`, with "Open app" for full OpenCode (v4-pro).
- **Keybindings** (`home/.config/hypr/bindings.lua`) — double-tap **Super** toggles the DeepSeek dropdown, plus unbinds for removed apps/services.
- **Double-tap script** (`home/.local/bin/omarchy-super-tap`).
- **Bar layout** (`home/.config/omarchy/shell.json`).
- **Shell cleanup** (`home/.bashrc`) — dropped aliases/functions for removed agents and tmux/herdr layouts.

## Install on a fresh machine

```bash
git clone https://github.com/Opklaar/omarchy-dotfiles.git ~/dotfiles
cd ~/dotfiles
./bootstrap.sh           # link configs + re-run app/agent removals
./install-themes.sh      # optional: re-clone ~135 community themes
```

`bootstrap.sh` is idempotent — re-run it after `git pull` to apply updates.

## Notes

- Only `~/.config/`, `~/.bashrc`, and `~/.local/bin/` are tracked — `omarchy update` never wipes these.
- The community theme list lives in `themes.txt` (not the themes themselves, which are re-cloneable from GitHub).
