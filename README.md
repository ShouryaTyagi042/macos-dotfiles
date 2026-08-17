# dotfiles

macOS window-manager setup: [AeroSpace](https://github.com/nikitabobko/AeroSpace) for tiling,
[SketchyBar](https://github.com/FelixKratz/SketchyBar) (Lua config) for the status bar, and
[JankyBorders](https://github.com/FelixKratz/JankyBorders) for the focused-window outline.

## Contents

| Path | Installs to | What it is |
| --- | --- | --- |
| `.aerospace.toml` | `~/.aerospace.toml` | Tiling WM: layouts, keybinds, gaps, per-app workspace rules |
| `.config/sketchybar/` | `~/.config/sketchybar/` | Status bar, Lua config via [SbarLua](https://github.com/FelixKratz/SbarLua) |
| `.config/borders/bordersrc` | `~/.config/borders/bordersrc` | Border width + colours |

Compiled helper binaries (`helpers/*/bin/`) are gitignored — SketchyBar rebuilds them on
startup via `helpers/init.lua`, which shells out to `make`.

## Install

```bash
git clone https://github.com/ShouryaTyagi042/macos-dotfiles.git ~/dotfiles
cd ~/dotfiles && ./install.sh
```

`install.sh` symlinks each path into `$HOME` and backs up anything already there to
`<file>.bak.<timestamp>`. Re-runnable.

### Dependencies

```bash
brew install --cask nikitabobko/tap/aerospace
brew tap FelixKratz/formulae
brew install sketchybar borders lua

# SbarLua — the Lua bindings sketchybarrc requires
git clone https://github.com/FelixKratz/SbarLua.git /tmp/SbarLua \
  && cd /tmp/SbarLua && make install && rm -rf /tmp/SbarLua

# Notchy — Spotify player (not part of this repo, but the bar assumes it)
brew install --cask vishvavariya/notchy/notchy
```

Fonts: SF Pro / SF Mono (`helpers/default_font.lua`) plus `sketchybar-app-font`. To use
JetBrainsMono Nerd Font instead, swap the commented `font` block in
`.config/sketchybar/settings.lua`.

## AeroSpace cheat sheet

Modifier is `alt`. Layout root is `tiles`, orientation `auto` (horizontal on a wide monitor),
with both normalizations on — the tree stays shallow and auto-alternates H/V.

| Keys | Action |
| --- | --- |
| `alt-h/j/k/l` | Focus left / down / up / right |
| `alt-shift-h/j/k/l` | Move window |
| `alt-shift-minus` / `alt-shift-equal` | Resize `smart ∓50` |
| `alt-slash` / `alt-comma` | Cycle tiles / accordion layout (each press flips orientation) |
| `alt-f` | Fullscreen |
| `alt-1`…`alt-0` | Switch workspace · add `shift` to move the window there |
| `alt-tab` | Cycle focus through windows in the current workspace |
| `alt-backtick` | Toggle between current and previous workspace |
| `alt-shift-tab` | Move workspace to next monitor |
| `alt-shift-c` | Reload config |
| `alt-shift-;` | Enter service mode |

Service mode (`esc` to leave): `r` reset layout · `f` toggle floating/tiling ·
`backspace` close all but current · `alt-shift-<arrow>` join with neighbour.

App launchers: `alt-enter` Warp · `alt-a` Arc · `alt-c` Cursor · `alt-s` Slack ·
`alt-n` Notion · `alt-p` Postman · `alt-m` Spotify · `alt-d` pgAdmin 4.

Auto-placement: wezterm + Warp → 1, Arc → 2, Cursor → 3, Telegram + WhatsApp → 9,
Loom → floating.

## SketchyBar

Tokyo Night palette, defined once in `colors.lua`. Left side: Apple menu, workspace
indicator (click the toggle to swap between workspaces and the focused app's menu bar).
Right side: CPU graph, wifi, volume, battery, clock.

Media is deliberately **not** in the bar — [Notchy](https://notchy.dev) handles Spotify as
a floating pill (this machine runs clamshell on an external display, so there is no notch
and Notchy falls back to pill mode). `items/media.lua` and `helpers/spotify.sh` drove it
over Spotify's AppleScript dictionary before that; they are in git history if Notchy is
ever dropped. Note that the upstream `media_change` event and `nowplaying-cli` do *not*
work here at all: macOS 15.4 restricted Apple's private MediaRemote framework to
first-party apps, and on 26.x it returns null even with a track playing.

One item is deliberately not built the way upstream builds it:

- **`items/spaces.lua` is driven by AeroSpace, not yabai.** It registers the custom
  `aerospace_workspace_change` event that `.aerospace.toml` fires, and clicks run
  `aerospace workspace N`. A single `aerospace list-windows --all` call feeds all ten
  workspaces per update. All ten stay visible so the row never shifts; empty ones
  are dimmed rather than hidden.
  Items keep the `space.N` name because `menus.lua` toggles the `/space\..*/` group.

## Conventions

- **Border styling lives only in `bordersrc`.** AeroSpace starts `borders` with no arguments,
  because inline flags override the config file wholesale — passing both makes the winning
  config depend on which process happened to start first. Change colours in one place.
- **Per-monitor gap rules key off the exact `aerospace list-monitors` name.** A pattern that
  matches nothing fails silently and falls through to the list's trailing default, so verify
  the name after swapping displays.
