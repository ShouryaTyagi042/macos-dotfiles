#!/usr/bin/env bash
# Route every open Cursor window to its repo's workspace.
#
# Why this exists: Cursor is Electron, and on-window-detected fires before the
# window has any title at all -- so the title-based rules in .aerospace.toml can
# never match on first open. Every new Cursor window therefore lands in the
# catch-all workspace (FALLBACK), and this script moves it on once the title
# resolves a moment later.
#
#   sort-cursor.sh          sort every Cursor window
#   sort-cursor.sh --dry    print what would move, change nothing
#   sort-cursor.sh --watch  daemon: poll, and only ever move windows that are
#                           still sitting in FALLBACK. A window you've parked
#                           somewhere by hand is left alone forever.
set -euo pipefail

CONF="${AEROSPACE_REPOS_CONF:-$HOME/.config/aerospace/repos.conf}"
DRY=0
WATCH=0
case "${1:-}" in
  --dry)   DRY=1 ;;
  --watch) WATCH=1 ;;
esac
INTERVAL="${AEROSPACE_SORT_INTERVAL:-2}"

[ -f "$CONF" ] || { echo "missing $CONF" >&2; exit 1; }

fallback=""
declare -a repos wss
while read -r ws repo; do
  case "$ws" in ''|'#'*) continue ;; esac
  [ -z "${repo:-}" ] && continue
  if [ "$repo" = FALLBACK ]; then fallback="$ws"; continue; fi
  repos+=("$repo"); wss+=("$ws")
done < "$CONF"

# Longest repo name first, so "superfone-api-working-hours" is tested before
# "superfone-api" and does not get swallowed by the shorter prefix.
order=$(for i in "${!repos[@]}"; do printf '%s\t%s\n' "${#repos[$i]}" "$i"; done | sort -rn | cut -f2)

sweep() {
moved=0
while IFS='|' read -r wid cur title; do
  if [ -z "$wid" ]; then continue; fi
  # title is "<file> — <repo>"; take the text after the last em-dash
  repo="${title##*— }"
  target=""
  for i in $order; do
    if [ "$repo" = "${repos[$i]}" ]; then target="${wss[$i]}"; break; fi
  done
  if [ -z "$target" ]; then target="$fallback"; fi
  if [ -z "$target" ]; then continue; fi
  if [ "$cur" = "$target" ]; then continue; fi
  # In watch mode, only rescue windows still parked in the catch-all. Anything
  # you moved by hand stays where you put it.
  if [ "$WATCH" = 1 ] && [ "$cur" != "$fallback" ]; then continue; fi

  if [ "$DRY" = 1 ]; then
    printf 'would move %-8s %-32s %s -> %s\n' "$wid" "$repo" "$cur" "$target"
  else
    aerospace move-node-to-workspace --window-id "$wid" "$target" < /dev/null
    printf 'moved %-8s %-32s %s -> %s\n' "$wid" "$repo" "$cur" "$target"
  fi
  moved=$((moved+1))
done < <(aerospace list-windows --monitor all --format '%{window-id}|%{workspace}|%{window-title}' --app-bundle-id com.todesktop.230313mzl4w4u92)
return 0
}

if [ "$WATCH" = 1 ]; then
  # Single instance: a second --watch replaces the first.
  LOCK="${TMPDIR:-/tmp}/aerospace-sort-cursor.pid"
  if [ -f "$LOCK" ] && kill -0 "$(cat "$LOCK")" 2>/dev/null; then
    kill "$(cat "$LOCK")" 2>/dev/null || true
  fi
  echo $$ > "$LOCK"
  trap 'rm -f "$LOCK"' EXIT
  while :; do
    sweep || true
    sleep "$INTERVAL"
  done
fi

sweep
if [ "$moved" = 0 ]; then echo "nothing to move"; fi
exit 0
