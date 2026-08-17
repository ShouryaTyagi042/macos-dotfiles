#!/usr/bin/env bash
# Spotify state + control for the sketchybar media item.
#
# Uses Spotify's AppleScript dictionary rather than nowplaying-cli/MediaRemote,
# which macOS 15.4 restricted to first-party apps (returns null on 26.x).
#
# Every call is guarded on Spotify already running — a bare `tell application
# "Spotify"` would launch it, and this is polled on a timer.

set -u

osa() { osascript -e "$1" 2>/dev/null; }

running() { [ "$(osa 'application "Spotify" is running')" = "true" ]; }

case "${1:-get}" in
  get)
    running || { echo "stopped"; exit 0; }
    # Field order must match the parser in items/media.lua
    osa 'tell application "Spotify"
           set t to current track
           return (player state as text) & "\n" & name of t & "\n" & album of t ¬
             & "\n" & artist of t & "\n" & id of t & "\n" & artwork url of t ¬
             & "\n" & (player position as text) & "\n" & (duration of t as text) ¬
             & "\n" & (shuffling as text) & "\n" & (repeating as text) ¬
             & "\n" & (sound volume as text)
         end tell'
    ;;
  playpause) running && osa 'tell application "Spotify" to playpause' ;;
  next)      running && osa 'tell application "Spotify" to next track' ;;
  prev)
    # Spotify's `previous track` restarts the current track first, matching the
    # behaviour of the app itself. Two calls would skip back too far.
    running && osa 'tell application "Spotify" to previous track'
    ;;
  shuffle)   running && osa 'tell application "Spotify" to set shuffling to not shuffling' ;;
  loop)      running && osa 'tell application "Spotify" to set repeating to not repeating' ;;
  seek)
    # $2 = percentage (0-100) from sketchybar, $3 = track duration in seconds
    running || exit 0
    pos=$(awk "BEGIN { printf \"%.3f\", $3 * $2 / 100 }")
    osa "tell application \"Spotify\" to set player position to $pos"
    ;;
  volume)
    running || exit 0
    osa "tell application \"Spotify\" to set sound volume to ${2%.*}"
    ;;
  *) echo "usage: spotify.sh get|playpause|next|prev|shuffle|loop|seek <pct> <dur>|volume <pct>" >&2; exit 1 ;;
esac
