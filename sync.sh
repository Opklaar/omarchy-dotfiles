#!/bin/bash
# Watchdog: keep tracked dotfiles symlinked into $HOME.
#
# The shell and opencode write some configs atomically (write temp + rename),
# which replaces the symlink with a plain file. This script detects that,
# captures the system's new content back into the repo (so your changes are
# never lost), and re-establishes the symlink. Idempotent; safe to run often.

set -uo pipefail
DOTFILES="$(cd "$(dirname "$0")" && pwd)"

while IFS= read -r -d '' f; do
  rel="${f#./}"
  src="$DOTFILES/home/$rel"
  dst="$HOME/$rel"

  [ -L "$dst" ] && continue            # still a symlink — nothing to do

  if [ -f "$dst" ]; then
    cp -f "$dst" "$src"                # capture the system's newer content
  fi

  mkdir -p "$(dirname "$dst")"
  ln -sfn "$src" "$dst"                # re-link
done < <(cd "$DOTFILES/home" && find . -type f -print0)
