# keebs-nix

Self-contained Nix flake that builds [ZMK](https://zmk.dev) firmware for my
keyboards. Every keyboard's complete ZMK config is **vendored** into this repo
under `keyboards/`, so the flake has no dependency on any external config repo
and reproduces identical firmware to the upstream sources.

Keyboards — each links to its own README (keymap diagram, board/shield details,
build & flash notes) and vendored `config/`:

- **[Ergonaut One](keyboards/ergonaut-one/)** — column-stagger split
- **[HolySwitch TK44](keyboards/tk44/)** — unibody monosplit
- **[Mriya46](keyboards/mriya46/)** — column-stagger split
- **[Dao](keyboards/dao/)** — 42-key column-stagger split (+ ZMK Studio)

Built on top of [zmk-nix](https://github.com/lilyinstarlight/zmk-nix).

## Layout

```
keyboards/
  ergonaut-one/   config/ (+ build.yaml)   # board+shield split
  tk44/           config/ (+ build.yaml)   # single custom board
  mriya46/        config/ (+ build.yaml)   # split as two custom boards
  dao/            config/ (+ build.yaml)   # split as two custom boards (+ studio)
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
nix build .#dao
nix build .#dao-studio        # left half built with ZMK Studio enabled
nix build .#dao-reset
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
dao_left.uf2
dao_right.uf2
dao_studio_left.uf2
dao_studio_right.uf2
dao_settings_reset.uf2
```

## Flash

Double-tap reset on the keyboard, then:

```sh
nix run .#flash-ergonaut-one          # prompts for left, then right
nix run .#flash-ergonaut-one-reset
nix run .#flash-tk44
nix run .#flash-mriya46               # prompts for left, then right
nix run .#flash-mriya46-reset
nix run .#flash-dao                   # prompts for left, then right
nix run .#flash-dao-studio            # left half with ZMK Studio
nix run .#flash-dao-reset
```

## Dev shell

```sh
nix develop   # west + Zephyr ARM toolchain for manual `west build`
```

## Editing keymaps / configs

Everything lives here now — edit the files under `keyboards/<kb>/config/`
directly (e.g. `keyboards/tk44/config/tk44.keymap`) and rebuild. No external
repos are involved.

## Keymap diagrams

Each keyboard's `README.md` embeds a layout diagram rendered by
[keymap-drawer](https://github.com/caksoylar/keymap-drawer) into
`keyboards/<kb>/keymap-drawer/<kb>.svg`. Regenerate them all after editing a
keymap:

```sh
nix run .#draw-keymaps
```

It parses each `config/<kb>.keymap` and draws it against that keyboard's local
physical-layout JSON (`config/*.json`), using the shared
`keymap-drawer/config.yaml`.

## ZMK version

Upstream the configs track `revision: main`, but ZMK `main` has migrated to
Zephyr's Hardware Model v2, which renamed the boards these (HWMv1) configs use
(`seeeduino_xiao_ble` → `xiao_ble`, `nice_nano_v2` → `nice_nano`) and would not
build them. So the vendored `west.yml`s pin ZMK to **`v0.3-branch`**
(`acfd8e5e…`) + **Zephyr 3.5** (`dacab487…`) — the same known-good, pre-HWMv2
revision zmk-nix's template uses. This keeps the HWMv1 board names and legacy
custom-board definitions valid, avoids the huge `hal_renesas` module (added in
later Zephyr), and is fully reproducible. To move to a newer ZMK you'd migrate
the boards to HWMv2 and bump the pin.

## Updating West deps

All four vendored configs ship a byte-identical `west.yml`, so a **single**
`zephyrDepsHash` in `flake.nix` covers every keyboard (one West fetch is shared
by all). Dao uses ZMK Studio and physical layouts, both already present on the
pinned `v0.3-branch`, so it needs no separate fetch.

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
  `<board>.yaml`) and they'd otherwise be dropped from the build source. It also
  keeps a board-level `Kconfig` (no suffix), which the Dao board ships for its
  DCDC option.
- **Dao** vendors its board from
  [ergonautkb/ergonautkb-zmk-module](https://github.com/ergonautkb/ergonautkb-zmk-module)
  (`boards/arm/dao` → `keyboards/dao/config/boards/arm/dao`) so the config is
  self-contained like the others, rather than pulling the module via `west.yml`.
- The shared West-deps fetch forces git to **HTTP/1.1** (via `GIT_CONFIG_*`
  env) to survive GitHub's flaky HTTP/2 stream resets during the large Zephyr
  clone. Env vars don't affect a fixed-output derivation's hash, so this stays
  reproducible.
- To re-vendor a config after upstream changes, recopy
  `keyboards/<kb>/config/` from the source repo/branch (the Mriya46 and TK44
  configs come from different branches of the holyswitch repo).
