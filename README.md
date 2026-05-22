# keebs-nix

Self-contained Nix flake that builds [ZMK](https://zmk.dev) firmware for my
keyboards. Every keyboard's complete ZMK config is **vendored** into this repo
under `keyboards/`, so the flake has no dependency on any external config repo
and reproduces identical firmware to the upstream sources.

| Keyboard         | Board                          | Shield / notes           |
| ---------------- | ------------------------------ | ------------------------ |
| Ergonaut One     | `seeeduino_xiao_ble`           | `ergonaut_one_left/right`|
| Ergonaut One ↺   | `seeeduino_xiao_ble`           | `settings_reset`         |
| HolySwitch TK44  | `tk44` (custom)                | none                     |
| Mriya46          | `mriya_left` / `mriya_right`   | split, two custom boards |
| Mriya46 ↺        | `nice_nano_v2`                 | `settings_reset`         |

Built on top of [zmk-nix](https://github.com/lilyinstarlight/zmk-nix).

## Layout

```
keyboards/
  ergonaut-one/   config/ (+ build.yaml)   # board+shield split
  tk44/           config/ (+ build.yaml)   # single custom board
  mriya46/        config/ (+ build.yaml)   # split as two custom boards
flake.nix
```

Each `keyboards/<kb>/config/` is the keyboard's ZMK config dir (`west.yml`,
`boards/`, keymaps, `*.conf`) copied verbatim from upstream.

## Build

```sh
nix build               # all firmware → ./result (combined .uf2 dir)
nix build .#ergonaut-one
nix build .#ergonaut-one-reset
nix build .#tk44
nix build .#mriya46
nix build .#mriya46-reset
```

`nix build` produces a `result/` with stable names:

```
ergonaut_one_left.uf2
ergonaut_one_right.uf2
ergonaut_one_settings_reset.uf2
tk44.uf2
mriya46_left.uf2
mriya46_right.uf2
mriya46_settings_reset.uf2
```

## Flash

Double-tap reset on the keyboard, then:

```sh
nix run .#flash-ergonaut-one          # prompts for left, then right
nix run .#flash-ergonaut-one-reset
nix run .#flash-tk44
nix run .#flash-mriya46               # prompts for left, then right
nix run .#flash-mriya46-reset
```

## Dev shell

```sh
nix develop   # west + Zephyr ARM toolchain for manual `west build`
```

## Editing keymaps / configs

Everything lives here now — edit the files under `keyboards/<kb>/config/`
directly (e.g. `keyboards/tk44/config/tk44.keymap`) and rebuild. No external
repos are involved.

## Updating West deps

All three vendored configs pin ZMK at `revision: main` and ship a
byte-identical `west.yml`, so a **single** `zephyrDepsHash` in `flake.nix`
covers every keyboard (one West fetch is shared by all). The hash is tied to
whatever ZMK `main` resolved to when it was last computed.

To refresh (after editing a `west.yml`, or to pull a newer ZMK):

1. set `zephyrDepsHash` to `nixpkgs.lib.fakeHash` in `flake.nix`,
2. run `nix build .#tk44.westDeps` (or any target),
3. copy the reported `got:` hash back into `zephyrDepsHash`.

> The bundled `nix run .#update` from zmk-nix assumes a single `west.yml` at
> the repo root, which doesn't match this layout, so refresh manually as above.

## Notes

- **Self-contained:** no flake inputs other than `nixpkgs` and `zmk-nix`. The
  keyboard configs are vendored, not referenced.
- The `src` suffix filter adds `.c` and `.yaml` on top of the upstream zmk-nix
  template list because the custom boards ship those (e.g. `tk44.c`,
  `<board>.yaml`) and they'd otherwise be dropped from the build source.
- The shared West-deps fetch forces git to **HTTP/1.1** (via `GIT_CONFIG_*`
  env) to survive GitHub's flaky HTTP/2 stream resets during the large Zephyr
  clone. Env vars don't affect a fixed-output derivation's hash, so this stays
  reproducible.
- To re-vendor a config after upstream changes, recopy
  `keyboards/<kb>/config/` from the source repo/branch (the Mriya46 and TK44
  configs come from different branches of the holyswitch repo).
