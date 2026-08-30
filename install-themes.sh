#!/bin/bash
# Re-clone the ~135 community themes into ~/.config/omarchy/themes.
# Reads themes.txt (one GitHub URL per line). Skips themes already present.
# Note: GitHub rate-limits unauthenticated clones — re-run if some fail.

set -uo pipefail
DOTFILES="$(cd "$(dirname "$0")" && pwd)"
T="$HOME/.config/omarchy/themes"
mkdir -p "$T"

ok=0; fail=0
while IFS= read -r url; do
  [ -n "$url" ] || continue
  clean="${url%/}"
  repo=$(basename "$clean" .git)
  slug=$(printf '%s' "$repo" | sed -E 's/^omarchy-//; s/-theme$//' | tr '[:upper:]' '[:lower:]')
  if [ -d "$T/$slug/.git" ]; then continue; fi
  if timeout 120 git clone --depth 1 --quiet "$url" "$T/$slug" 2>/dev/null; then
    ok=$((ok+1))
  else
    echo "FAIL $slug  $url"
    rm -rf "$T/$slug" 2>/dev/null
    fail=$((fail+1))
  fi
done < "$DOTFILES/themes.txt"

# Apply per-theme overrides (customized colors.toml, etc.) on top of the clones.
OVERRIDES="$DOTFILES/theme-overrides"
if [ -d "$OVERRIDES" ]; then
  for slug in "$OVERRIDES"/*/; do
    name=$(basename "$slug")
    [ -d "$T/$name" ] || continue
    cp -f "$slug"* "$T/$name/" 2>/dev/null
    echo "✓ Applied override: $name"
  done
fi

echo "✓ Cloned $ok themes, $fail failed (re-run to retry rate-limited ones)."
