# Contributing

Thanks for wanting to help!

- **Bugs:** open an issue with your Hyprland version, config style (conf/lua) and the output of `qs -c hypr-whichkey`.
- **Testing changes:** run the overlay straight from your clone, no install needed:
  ```sh
  pkill -f "qs -c hypr-whichkey"; qs -p ./quickshell/shell.qml
  # in another terminal, fake a held SUPER+SHIFT:
  echo "65 $(hyprctl -j monitors | jq -r '.[]|select(.focused).name')" > $XDG_RUNTIME_DIR/hypr-whichkey
  echo 0 > $XDG_RUNTIME_DIR/hypr-whichkey
  ```
- **Shell scripts** should pass `shellcheck`.
- Screenshots with other themes for the README are very welcome.
