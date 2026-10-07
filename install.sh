#!/usr/bin/env bash
# Symlink dotfiles into $HOME. Re-runnable; backs up anything it replaces.
set -euo pipefail

DOTFILES="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STAMP="$(date +%Y%m%d%H%M%S)"

LINKS=(
  ".aerospace.toml"
  ".config/sketchybar"
  ".config/borders"
)

for rel in "${LINKS[@]}"; do
  src="$DOTFILES/$rel"
  dst="$HOME/$rel"

  if [ -L "$dst" ] && [ "$(readlink "$dst")" = "$src" ]; then
    echo "ok        $rel"
    continue
  fi

  if [ -e "$dst" ] || [ -L "$dst" ]; then
    mv "$dst" "$dst.bak.$STAMP"
    echo "backed up $rel -> $rel.bak.$STAMP"
  fi

  mkdir -p "$(dirname "$dst")"
  ln -s "$src" "$dst"
  echo "linked    $rel"
done

echo
echo "Done. Reload with:"
echo "  aerospace reload-config && sketchybar --reload"
