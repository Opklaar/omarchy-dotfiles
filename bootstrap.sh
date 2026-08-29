#!/bin/bash
# Apply Omarchy dotfiles to this machine.
# Symlinks tracked files into $HOME, then re-runs the app/agent removals.
# Idempotent — safe to run again after pulling new changes.

set -euo pipefail
DOTFILES="$(cd "$(dirname "$0")" && pwd)"

link() {
  local src="$1" dst="$2"
  mkdir -p "$(dirname "$dst")"
  if [ -e "$dst" ] && [ ! -L "$dst" ]; then
    mv "$dst" "$dst.bak.$(date +%s)"
  fi
  ln -sfn "$src" "$dst"
}

echo "→ Linking config files into $HOME"
while IFS= read -r -d '' f; do
  rel="${f#"$DOTFILES/home/"}"
  link "$DOTFILES/home/$rel" "$HOME/$rel"
done < <(cd "$DOTFILES/home" && find . -type f -print0)

echo "→ Removing unwanted preinstalled web apps"
for app in "X" "WhatsApp" "Google Photos" "Google Messages" "Zoom" "Discord"; do
  omarchy webapp remove "$app" >/dev/null 2>&1 || true
done

echo "→ Removing unwanted AI agent launchers"
rm -f "$HOME/.local/bin/claude" "$HOME/.local/bin/codex" "$HOME/.local/bin/gemini" \
  "$HOME/.local/bin/grok" "$HOME/.local/bin/copilot" "$HOME/.local/bin/crush" \
  "$HOME/.local/bin/pi" "$HOME/.local/bin/omp" "$HOME/.local/bin/hunk"

echo "→ Reloading Hyprland and shell"
hyprctl reload >/dev/null 2>&1 || true
omarchy restart shell >/dev/null 2>&1 || true

echo "✓ Done. Community themes are NOT installed by default — run ./install-themes.sh if you want them."
