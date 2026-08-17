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
Right side: Spotify, CPU graph, wifi, volume, battery, clock.

Two items are deliberately not built the way upstream builds them:

- **`items/spaces.lua` is driven by AeroSpace, not yabai.** It registers the custom
  `aerospace_workspace_change` event that `.aerospace.toml` fires, and clicks run
  `aerospace workspace N`. A single `aerospace list-windows --all` call feeds all ten
  workspaces per update. All ten stay visible so the row never shifts; empty ones
  are dimmed rather than hidden.
  Items keep the `space.N` name because `menus.lua` toggles the `/space\..*/` group.
- **`items/media.lua` drives Spotify over AppleScript**, through `helpers/spotify.sh`.
  The upstream `media_change` event and `nowplaying-cli` both read Apple's private
  MediaRemote framework, which was restricted to first-party apps in macOS 15.4 — on
  26.x it returns null for everything, so the item never drew. AppleScript still works,
  at the cost of being Spotify-only. The `if application "Spotify" is running` guard is
  load-bearing: a bare `tell application "Spotify"` would launch Spotify on every poll.

  The cover sits in the bar; clicking it opens a mini-player with album art, title,
  album, artist, shuffle / prev / play-pause / next / repeat, a seekable scrubber with
  elapsed and remaining times, and a volume slider. Polling drops from 2s to 1s while
  the popup is open so the scrubber tracks smoothly.

  Two shape constraints worth knowing before editing it:
  - **A popup is one row or one column**, never a grid — `popup.horizontal` is a single
    flag for the whole popup. Hence the wide single row. The three text lines are
    stacked by giving those items zero width and offsetting their labels vertically,
    with a spacer item reserving the space they overflow into.
  - **Image `scale` multiplies source pixels, not a target size.** Spotify serves
    640x640, so art is resized on disk with `sips` to a known size and always rendered
    at a fixed scale. Files are cached per track id *and* size under
    `/tmp/sketchybar-spotify-art/`; SketchyBar caches images by path, so a fixed
    filename would keep showing the first cover it ever loaded.

## Conventions

- **Border styling lives only in `bordersrc`.** AeroSpace starts `borders` with no arguments,
  because inline flags override the config file wholesale — passing both makes the winning
  config depend on which process happened to start first. Change colours in one place.
- **Per-monitor gap rules key off the exact `aerospace list-monitors` name.** A pattern that
  matches nothing fails silently and falls through to the list's trailing default, so verify
  the name after swapping displays.
