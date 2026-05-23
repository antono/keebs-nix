# Ergonaut One

42-key column-staggered **split** keyboard. Each half is a
[Seeeduino XIAO BLE](https://wiki.seeedstudio.com/XIAO_BLE/); ZMK builds it as
board `seeeduino_xiao_ble` + shield `ergonaut_one_left` / `ergonaut_one_right`,
with the **left** half as the BLE central.

## Keymap

![Ergonaut One keymap](./keymap-drawer/ergonaut-one.svg)

## Build & flash

From the repo root:

```sh
nix build .#ergonaut-one            # -> result/{zmk_left,zmk_right}.uf2
nix run  .#flash-ergonaut-one       # prompts for left, then right
nix run  .#flash-ergonaut-one-reset # wipe BLE/settings if pairing breaks
```

Config lives in [`config/`](./config). The diagram is generated with
[keymap-drawer](https://github.com/caksoylar/keymap-drawer) from
`config/ergonaut_one.keymap` + the `config/ergonaut_one.json` physical layout —
regenerate it with `nix run .#draw-keymaps` from the repo root.
