#!/usr/bin/env bash
# hypr-whichkey installer — copies files, never edits your Hyprland config without asking.
#   ./install.sh            install / update
#   ./install.sh --uninstall
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
qs_dir="${XDG_CONFIG_HOME:-$HOME/.config}/quickshell/hypr-whichkey"
cfg_dir="${XDG_CONFIG_HOME:-$HOME/.config}/hypr-whichkey"
bin="$HOME/.local/bin/hypr-whichkey"
hypr="${XDG_CONFIG_HOME:-$HOME/.config}/hypr"
b=$'\e[1m'; g=$'\e[32m'; y=$'\e[33m'; r=$'\e[31m'; n=$'\e[0m'

if [[ "${1:-}" == "--uninstall" ]]; then
  pkill -f "qs -c hypr-whichkey" 2>/dev/null || true
  rm -rf "$qs_dir" "$bin" "$cfg_dir/whichkey.lua" "$cfg_dir/whichkey.conf"
  echo "${g}Removed.${n} Delete the source/dofile line from your Hyprland config and the exec-once/autostart line."
  echo "Your config.json (if any) was kept in $cfg_dir."
  exit 0
fi

echo "${b}hypr-whichkey${n} installer"
missing=()
for c in hyprctl qs; do command -v "$c" >/dev/null || missing+=("$c"); done
if ((${#missing[@]})); then
  echo "${r}Missing:${n} ${missing[*]}"
  echo "  qs = Quickshell → Arch: pacman -S quickshell · Fedora: dnf copr enable errornointernet/quickshell && dnf install quickshell · Nix: pkgs.quickshell"
  exit 1
fi

mkdir -p "$qs_dir" "$cfg_dir" "$(dirname "$bin")"
install -m644 "$here/quickshell/shell.qml"   "$qs_dir/shell.qml"
install -m644 "$here/drivers/whichkey.lua"   "$cfg_dir/whichkey.lua"
install -m644 "$here/drivers/whichkey.conf"  "$cfg_dir/whichkey.conf"
install -m755 "$here/drivers/hypr-whichkey"  "$bin"
[[ -f "$cfg_dir/config.json" ]] || install -m644 "$here/examples/config.example.json" "$cfg_dir/config.example.json"
echo "${g}✓${n} files installed"

if [[ -f "$hypr/hyprland.lua" ]]; then
  mode=lua
  line='dofile(os.getenv("HOME") .. "/.config/hypr-whichkey/whichkey.lua")'
  start='hl.on("hyprland.start", function() hl.exec_cmd("qs -c hypr-whichkey -d") end)'
  target="$hypr/hyprland.lua"
else
  mode=conf
  line='source = ~/.config/hypr-whichkey/whichkey.conf'
  start='exec-once = qs -c hypr-whichkey -d'
  target="$hypr/hyprland.conf"
fi
echo "${g}✓${n} detected ${b}$mode${n} config ($target)"

if grep -qs "hypr-whichkey" "$target"; then
  echo "${g}✓${n} already wired into $target"
else
  echo
  echo "Add these two lines to ${b}$target${n}:"
  echo "    ${y}$line${n}"
  echo "    ${y}$start${n}"
  read -rp "Append them for you? [y/N] " a
  if [[ "${a,,}" == y* ]]; then
    cp "$target" "$target.bak-whichkey"
    c='--'; [[ $mode == conf ]] && c='#'
    printf '\n%s hypr-whichkey\n%s\n%s\n' "$c" "$line" "$start" >> "$target"
    echo "${g}✓${n} appended (backup: $target.bak-whichkey)"
  fi
fi

# (re)start now
pkill -f "qs -c hypr-whichkey" 2>/dev/null || true
if [[ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]]; then
  qs -c hypr-whichkey -d >/dev/null 2>&1 || true
  hyprctl reload >/dev/null 2>&1 || true
  echo "${g}✓${n} started — ${b}hold SUPER${n} to try it."
fi
echo
echo "Tip: give your binds descriptions (bindd / desc=) for the nicest labels. Config: $cfg_dir/config.json"
