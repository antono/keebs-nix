# Ladniy/TK44

|  |  |
|---|---|
| **MCU / board** | Holyiot-18010 module (nRF52840) — single custom ZMK board `tk44`, no shield |
| **Layout** | 44 keys · **unibody** (mono), angled/rotated columns |
| **Switches** | MX-compatible · hot-swap sockets |
| **Designer** | [Ladniy](https://github.com/Ladniy) |
| **Hardware / PCB** | [Ladniy/TK44](https://github.com/Ladniy/TK44) (KiCad) · [kbd.news](https://kbd.news/TK44-1683.html) |
| **Features** | BLE · USB · deep sleep |

44-key unibody keyboard with angled/rotated columns. Single custom **`tk44`**
board built around an nRF52840 (QIAA) — no shield, no split. Designed by
[Ladniy/TK44](https://github.com/Ladniy/TK44).

## Keymap

![TK44 keymap](./keymap-drawer/tk44.svg)

## Build & flash

From the repo root:

```sh
nix build .#tk44        # -> result/zmk.uf2
nix run  .#flash-tk44
```

Config lives in [`config/`](./config), with the board definition under
`config/boards/arm/tk44/`. The diagram is generated with
[keymap-drawer](https://github.com/caksoylar/keymap-drawer) from
`config/tk44.keymap` + the `config/tk44.json` physical layout — regenerate it
with `nix run .#draw-keymaps` from the repo root.
