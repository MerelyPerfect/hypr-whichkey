# Changelog

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
