# Changelog

## 0.3.1 — 2026-11-24

- Submap binds are ordered plain keys first, then by label
- Fixed the Lua submap example in the README (`hl.dsp.window.resize`)

## 0.3.0 — 2026-11-24

- Submap support: entering a submap shows its binds right away (modifiers shown on the keycaps) and hides them on reset
- Uses Hyprland's event socket, so it works with both conf and Lua configs and needs no driver changes
- New `submaps` config option (default `true`)

## 0.2.1 — 2026-11-24

- More compact default layout: smaller text, tighter keycaps and spacing (about 30% less height)

## 0.2.0 — 2026-11-24

- Binds are grouped into categories (Workspaces, Windows, Layout, Apps, Media, Screenshots, System, Other)
- Choose a category with a `Category: label` or `[Category] label` description prefix
- Custom categories via `categories` in config.json; `"group": false` for a flat list
- Default `maxColumns` is now 5

## 0.1.0 — 2026-11-24

First release.

- Overlay appears after holding SUPER and narrows live with SHIFT / CTRL / ALT
- Reads binds from `hyprctl binds`, with readable labels for binds without a description
- Theme picked up from pywal/wallust or Hyprland's active border colour
- Drivers for both `hyprland.conf` and `hyprland.lua`
- Installer with uninstall option
