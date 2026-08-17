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
git clone https://github.com/ShouryaTyagi042/dotfiles.git ~/dotfiles
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
| `alt-tab` | Focus right, wrapping around the workspace |
| `alt-shift-tab` | Move workspace to next monitor |
| `alt-shift-c` | Reload config |
| `alt-shift-;` | Enter service mode |

Service mode (`esc` to leave): `r` reset layout · `f` toggle floating/tiling ·
`backspace` close all but current · `alt-shift-<arrow>` join with neighbour.

App launchers: `alt-enter` Warp · `alt-a` Arc · `alt-c` Cursor · `alt-s` Slack ·
`alt-n` Notion · `alt-p` Postman · `alt-m` Spotify · `alt-d` pgAdmin 4.

Auto-placement: wezterm → 1, Arc → 2, Cursor → 3, Telegram + WhatsApp → 9, Loom → floating.

## Known quirks

- **`bordersrc` is not actually read.** AeroSpace's `after-startup-command` launches `borders`
  with inline flags (`active_color=0xffe1e3e4 inactive_color=0xff494d64 width=5.0
  blacklist="Loom"`), which take precedence over the config file. The TokyoNight colours in
  `bordersrc` are therefore dead unless you drop those flags from `.aerospace.toml`.
- **`gaps.outer.top` matches no monitor.** The per-monitor list targets `MSI MP275Q` and
  `Apple TV 4k`; the actual display is `MSI MD272QXP`, so the `45` fallback always wins.
- **`alt-enter` opens Warp, but the workspace-1 rule matches `wezterm-gui`** — the terminal
  never gets auto-assigned.
- **`alt-tab` is `focus right`,** not `workspace-back-and-forth`, despite the comment above it.
