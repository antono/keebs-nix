# keebs-nix

Nix flake that builds [ZMK](https://zmk.dev) firmware for my keyboards from
their sibling config repos:

| Keyboard         | Board                          | Shield / notes                  | Source                                          |
| ---------------- | ------------------------------ | ------------------------------- | ----------------------------------------------- |
| Ergonaut One     | `seeeduino_xiao_ble`           | `ergonaut_one_left` / `_right`  | `../ergonaut-one-zmk-config` (working copy)      |
| Ergonaut One ↺   | `seeeduino_xiao_ble`           | `settings_reset`                | `../ergonaut-one-zmk-config` (working copy)      |
| HolySwitch TK44  | `tk44` (custom)                | none                            | `../holyswitch-zmk-config` (working copy)        |
| Mriya46          | `mriya_left` / `mriya_right`   | split, two custom boards        | `../holyswitch-zmk-config` @ `antono-mriya46`    |
| Mriya46 ↺        | `nice_nano_v2`                 | `settings_reset`                | `../holyswitch-zmk-config` @ `antono-mriya46`    |

Built on top of [zmk-nix](https://github.com/lilyinstarlight/zmk-nix).

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

## Updating West deps

The config repos pin ZMK at `revision: main`, so the West-deps hashes in
`flake.nix` are tied to whatever `main` was when last computed. After a
config's `west.yml` changes (or to pull a newer ZMK), set the relevant hash to
`nixpkgs.lib.fakeHash`, run a build, and copy the reported `got:` hash back.

Because the FOD output is just the fetched West projects (determined only by
`west.yml`), configs with identical manifests share one hash:

- `ergonautDepsHash` — ergonaut-one + ergonaut-one-reset
- `holyswitchDepsHash` — tk44 + mriya46 (+ its reset); both are branches of the
  holyswitch repo with identical `west.yml`

> Note: the bundled `nix run .#update` from zmk-nix assumes a single `west.yml`
> at the repo root; here the manifests live in the sibling config repos, so
> update hashes manually as above.

## Notes

- The `src` suffix filter adds `.c` and `.yaml` on top of the upstream zmk-nix
  template list because the TK44 ships a custom board (`tk44.c`, `tk44.yaml`).
- Ergonaut One and TK44 build from the **local working copies** of their repos
  (so the holyswitch working tree must be on its `antono-tk44` branch for the
  `tk44` package). **Mriya46** instead builds from the committed
  `antono-mriya46` branch via the local git object store, so it builds
  regardless of which branch is checked out. To rebuild after pushing new mriya
  commits: `git fetch` in the holyswitch repo, then
  `nix flake update holyswitch-mriya46`.
