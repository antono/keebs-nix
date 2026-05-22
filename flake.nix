{
  description = "ZMK firmware for antono's keyboards (Ergonaut One + HolySwitch TK44 + Mriya46)";

  inputs = {
    # Pinned to the same revision zmk-nix locks (and shared via follows below)
    # for a single, reproducible nixpkgs. Bump with `nix flake update`.
    nixpkgs.url = "github:NixOS/nixpkgs/d233902339c02a9c334e7e593de68855ad26c4cb";

    zmk-nix = {
      url = "github:lilyinstarlight/zmk-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  # This flake is fully self-contained: every keyboard's complete ZMK config
  # (west.yml + boards/shields + keymaps + conf) is vendored under ./keyboards,
  # copied verbatim from the upstream repos so it reproduces identical firmware.
  # Provenance of the vendored trees:
  #   keyboards/ergonaut-one  <- antono/ergonaut-one-zmk-config (config/)
  #   keyboards/tk44          <- antono/holyswitch-zmk-config @ antono-tk44 (config/)
  #   keyboards/mriya46       <- antono/holyswitch-zmk-config @ antono-mriya46 (config/)

  outputs =
    {
      self,
      nixpkgs,
      zmk-nix,
    }:
    let
      inherit (nixpkgs) lib;

      forAllSystems = lib.genAttrs (lib.attrNames zmk-nix.packages);

      # Suffixes that make up a ZMK config / custom board definition. Extends the
      # upstream template list with ".c" and ".yaml", required by the tk44 board
      # (tk44.c board init, tk44.yaml hardware description). The ".board",
      # ".defconfig" and ".shield" entries also match Kconfig.board /
      # Kconfig.defconfig / Kconfig.shield.
      srcSuffixes = [
        ".board"
        ".c"
        ".cmake"
        ".conf"
        ".defconfig"
        ".dts"
        ".dtsi"
        ".json"
        ".keymap"
        ".overlay"
        ".shield"
        ".yaml"
        ".yml"
        "_defconfig"
      ];

      keebSrc = input: lib.sourceFilesBySuffices input srcSuffixes;

      # West-dependency FOD hash. The FOD output is the fetched west projects
      # (ZMK@main + Zephyr + modules), determined solely by west.yml. All three
      # vendored configs ship a byte-identical west.yml, so a single fetch (and
      # hash) serves every keyboard. To refresh after a west.yml change, set
      # this to nixpkgs.lib.fakeHash, rebuild, and copy back the `got:` hash.
      zephyrDepsHash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";

      mkMeta = description: {
        inherit description;
        license = lib.licenses.mit;
        platforms = lib.platforms.all;
      };
    in
    {
      packages = forAllSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
          inherit (zmk-nix.legacyPackages.${system})
            buildKeyboard
            buildSplitKeyboard
            fetchZephyrDeps
            ;

          # One West-deps fetch shared by every keyboard (identical west.yml).
          # The GIT_CONFIG_* env forces git to HTTP/1.1 with a large post buffer
          # and no low-speed abort, which survives GitHub's flaky HTTP/2 stream
          # resets during the large Zephyr clone. Env does not affect an FOD's
          # output hash, so this stays reproducible.
          westDeps =
            (fetchZephyrDeps {
              name = "keebs-west-deps";
              src = keebSrc ./keyboards/tk44;
              westRoot = "config";
              hash = zephyrDepsHash;
            }).overrideAttrs
              (old: {
                env = (old.env or { }) // {
                  GIT_CONFIG_COUNT = "3";
                  GIT_CONFIG_KEY_0 = "http.version";
                  GIT_CONFIG_VALUE_0 = "HTTP/1.1";
                  GIT_CONFIG_KEY_1 = "http.postBuffer";
                  GIT_CONFIG_VALUE_1 = "1048576000";
                  GIT_CONFIG_KEY_2 = "http.lowSpeedLimit";
                  GIT_CONFIG_VALUE_2 = "0";
                };
              });

          ergonaut-one = buildSplitKeyboard {
            name = "ergonaut-one";
            src = keebSrc ./keyboards/ergonaut-one;
            board = "seeeduino_xiao_ble";
            shield = "ergonaut_one_%PART%";
            parts = [
              "left"
              "right"
            ];
            inherit zephyrDepsHash westDeps;
            meta = mkMeta "ZMK firmware for the Ergonaut One (split, Seeeduino XIAO BLE)";
          };

          # settings_reset is a stock ZMK shield; built on the same board so its
          # west deps (and hash) are identical to ergonaut-one.
          ergonaut-one-reset = buildKeyboard {
            name = "ergonaut-one-reset";
            src = keebSrc ./keyboards/ergonaut-one;
            board = "seeeduino_xiao_ble";
            shield = "settings_reset";
            inherit zephyrDepsHash westDeps;
            meta = mkMeta "ZMK settings-reset firmware for the Ergonaut One";
          };

          tk44 = buildKeyboard {
            name = "tk44";
            src = keebSrc ./keyboards/tk44;
            board = "tk44";
            inherit zephyrDepsHash westDeps;
            meta = mkMeta "ZMK firmware for the HolySwitch TK44";
          };

          # Mriya46: split keyboard where each half is its own custom board
          # (mriya_left / mriya_right), so %PART% is substituted into `board`
          # and there is no shield. Left is the BLE central.
          mriya46 = buildSplitKeyboard {
            name = "mriya46";
            src = keebSrc ./keyboards/mriya46;
            board = "mriya_%PART%";
            parts = [
              "left"
              "right"
            ];
            inherit zephyrDepsHash westDeps;
            meta = mkMeta "ZMK firmware for the Mriya46 (split, custom nRF52840 boards)";
          };

          # Mriya46 settings reset is built on nice_nano_v2 per its build.yaml.
          mriya46-reset = buildKeyboard {
            name = "mriya46-reset";
            src = keebSrc ./keyboards/mriya46;
            board = "nice_nano_v2";
            shield = "settings_reset";
            inherit zephyrDepsHash westDeps;
            meta = mkMeta "ZMK settings-reset firmware for the Mriya46";
          };

          # Collect every .uf2 under one output with stable, human-readable names.
          firmware = pkgs.runCommand "keebs-firmware" { } ''
            mkdir -p "$out"
            cp ${ergonaut-one}/zmk_left.uf2        "$out/ergonaut_one_left.uf2"
            cp ${ergonaut-one}/zmk_right.uf2       "$out/ergonaut_one_right.uf2"
            cp ${ergonaut-one-reset}/zmk.uf2       "$out/ergonaut_one_settings_reset.uf2"
            cp ${tk44}/zmk.uf2                     "$out/tk44.uf2"
            cp ${mriya46}/zmk_left.uf2             "$out/mriya46_left.uf2"
            cp ${mriya46}/zmk_right.uf2            "$out/mriya46_right.uf2"
            cp ${mriya46-reset}/zmk.uf2            "$out/mriya46_settings_reset.uf2"
          '';

          flashFor = firmware: zmk-nix.packages.${system}.flash.override { inherit firmware; };
        in
        {
          default = firmware;
          inherit
            firmware
            ergonaut-one
            ergonaut-one-reset
            tk44
            mriya46
            mriya46-reset
            ;

          flash-ergonaut-one = flashFor ergonaut-one;
          flash-ergonaut-one-reset = flashFor ergonaut-one-reset;
          flash-tk44 = flashFor tk44;
          flash-mriya46 = flashFor mriya46;
          flash-mriya46-reset = flashFor mriya46-reset;

          update = zmk-nix.packages.${system}.update;
        }
      );

      devShells = forAllSystems (system: {
        default = zmk-nix.devShells.${system}.default;
      });
    };
}
