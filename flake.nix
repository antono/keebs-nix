{
  description = "ZMK firmware for antono's keyboards (Ergonaut One + HolySwitch TK44 + Mriya46 + Dao)";

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
  #   keyboards/dao           <- antono/dao-zmk-config @ antono-layout (config/) +
  #                              the dao board from ergonautkb/ergonautkb-zmk-module
  #                              (boards/arm/dao -> config/boards/arm/dao), vendored
  #                              so the config is self-contained like the others.

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

      # Like lib.sourceFilesBySuffices, but also keeps a board-level `Kconfig`
      # (no suffix). The dao board ships one for its BOARD_ENABLE_DCDC option;
      # the suffix list alone would silently drop it.
      keebSrc =
        input:
        lib.cleanSourceWith {
          src = input;
          filter =
            name: type:
            let
              base = baseNameOf (toString name);
            in
            type == "directory" || base == "Kconfig" || lib.any (suf: lib.hasSuffix suf base) srcSuffixes;
        };

      # West-dependency FOD hash. The FOD output is the fetched west projects,
      # determined solely by west.yml. All three vendored configs ship a
      # byte-identical west.yml (pinned to ZMK v0.3-branch + Zephyr 3.5, matching
      # zmk-nix's template — see "ZMK version" in the README), so one fetch and
      # hash serve every keyboard. To refresh after a west.yml change, set this
      # to nixpkgs.lib.fakeHash, rebuild, and copy back the reported `got:` hash.
      zephyrDepsHash = "sha256-lEMy05wxNd44gTh5JQiIvkmHkiwScMzw4T+kPrmr9qs=";

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

          # One West-deps fetch shared by every keyboard — otherwise each
          # keyboard gets its own multi-GiB clone. Every keyboard pins the same
          # zmk + zephyr revisions, so a single fetch serves them all; the only
          # divergence is that charybdis-mini additionally needs the PMW3610
          # trackball driver. We therefore source the shared fetch from
          # charybdis-mini's west.yml — the superset manifest (zmk + zephyr +
          # driver) — and every other keyboard's deps are a subset of it. The
          # driver is inert for builds that don't reference it in a shield.
          # (Invariant: if another keyboard ever needs an extra module, either
          # add it to this manifest or move the fetch source to a new superset.)
          #
          # The shallow + narrow `west update` fetches only the needed commits
          # instead of full history: far less data (minutes vs hours on a slow
          # link), and small enough transfers that GitHub's occasional HTTP/2
          # stream resets don't bite. The fetcher discards git history into a
          # stub, so the output (and FOD hash) is identical to a full clone.
          westDeps =
            (fetchZephyrDeps {
              name = "keebs-west-deps";
              src = keebSrc ./keyboards/charybdis-mini;
              westRoot = "config";
              hash = zephyrDepsHash;
            }).overrideAttrs
              (_: {
                buildPhase = ''
                  runHook preBuild
                  west update --narrow --fetch-opt=--depth=1
                  runHook postBuild
                '';
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

          # Dao: 42-key split, each half its own custom nRF52840 board
          # (dao_left / dao_right), left as the BLE central — same shape as
          # Mriya46. The keymap chooses the Corne physical layout and uses
          # ZMK Studio, both supported by the pinned v0.3-branch.
          dao = buildSplitKeyboard {
            name = "dao";
            src = keebSrc ./keyboards/dao;
            board = "dao_%PART%";
            parts = [
              "left"
              "right"
            ];
            inherit zephyrDepsHash westDeps;
            meta = mkMeta "ZMK firmware for the Dao (split, custom nRF52840 boards)";
          };

          # Same boards with ZMK Studio enabled on the central (left) half
          # (adds the studio-rpc-usb-uart snippet + CONFIG_ZMK_STUDIO=y); the
          # right peripheral is built plain, as Studio runs over the central.
          dao-studio = buildSplitKeyboard {
            name = "dao-studio";
            src = keebSrc ./keyboards/dao;
            board = "dao_%PART%";
            parts = [
              "left"
              "right"
            ];
            enableZmkStudio = true;
            inherit zephyrDepsHash westDeps;
            meta = mkMeta "ZMK firmware for the Dao with ZMK Studio (split, custom nRF52840 boards)";
          };

          # Dao settings reset is built on nice_nano_v2 per its build.yaml.
          dao-reset = buildKeyboard {
            name = "dao-reset";
            src = keebSrc ./keyboards/dao;
            board = "nice_nano_v2";
            shield = "settings_reset";
            inherit zephyrDepsHash westDeps;
            meta = mkMeta "ZMK settings-reset firmware for the Dao";
          };

          charybdis-mini = buildSplitKeyboard {
            name = "charybdis-mini";
            src = keebSrc ./keyboards/charybdis-mini;
            board = "nice_nano_v2";
            shield = "charybdis_%PART%";
            parts = [
              "left"
              "right"
            ];
            inherit zephyrDepsHash westDeps;
            meta = mkMeta "ZMK firmware for the Charybdis Mini (split, nice!nano v2)";
          };

          # Charybdis Mini settings reset is built on nice_nano_v2. The vendored
          # BastardKB charybdis shield wires its matrix through the &pro_micro
          # connector, which the nice!nano defines (the Seeeduino XIAO BLE does
          # not — it exposes &xiao_d instead).
          charybdis-mini-reset = buildKeyboard {
            name = "charybdis-mini-reset";
            src = keebSrc ./keyboards/charybdis-mini;
            board = "nice_nano_v2";
            shield = "settings_reset";
            inherit zephyrDepsHash westDeps;
            meta = mkMeta "ZMK settings-reset firmware for the Charybdis Mini";
          };

          # Collect every keyboard's firmware under one output with stable,
          # human-readable names. Each build is copied generically by globbing
          # its actual *.uf2 outputs and rewriting the leading "zmk" to the
          # keyboard's prefix, so a split (zmk_left.uf2 + zmk_right.uf2 ->
          # <prefix>_left.uf2 + <prefix>_right.uf2) and a single-firmware build
          # (zmk.uf2 -> <prefix>.uf2) both work without hardcoding filenames.
          # Adding a keyboard is one line in firmwareOutputs.
          firmwareOutputs = {
            ergonaut_one = ergonaut-one;
            ergonaut_one_settings_reset = ergonaut-one-reset;
            tk44 = tk44;
            mriya46 = mriya46;
            mriya46_settings_reset = mriya46-reset;
            dao = dao;
            dao_studio = dao-studio;
            dao_settings_reset = dao-reset;
            charybdis_mini = charybdis-mini;
            charybdis_mini_settings_reset = charybdis-mini-reset;
          };
          firmware = pkgs.runCommand "keebs-firmware" { } (
            ''
              mkdir -p "$out"
            ''
            + lib.concatStrings (
              lib.mapAttrsToList (prefix: drv: ''
                for f in ${drv}/*.uf2; do
                  name="$(basename "$f")"
                  cp "$f" "$out/${prefix}''${name#zmk}"
                done
              '') firmwareOutputs
            )
          );

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
            dao
            dao-studio
            dao-reset
            ;

          flash-ergonaut-one = flashFor ergonaut-one;
          flash-ergonaut-one-reset = flashFor ergonaut-one-reset;
          flash-tk44 = flashFor tk44;
          flash-mriya46 = flashFor mriya46;
          flash-mriya46-reset = flashFor mriya46-reset;
          flash-dao = flashFor dao;
          flash-dao-studio = flashFor dao-studio;
          flash-dao-reset = flashFor dao-reset;

          flash-charybdis-mini = flashFor charybdis-mini;
          flash-charybdis-mini-reset = flashFor charybdis-mini-reset;

          update = zmk-nix.packages.${system}.update;
        }
      );

      # `nix run .#draw-keymaps` (re)renders the per-keyboard layout SVGs under
      # keyboards/<kb>/keymap-drawer/ from the vendored keymaps + local physical
      # layout JSONs, using the shared keymap-drawer/config.yaml. Run from the
      # repo root.
      apps = forAllSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
          draw-keymaps = pkgs.writeShellApplication {
            name = "draw-keymaps";
            runtimeInputs = [ pkgs.keymap-drawer ];
            text = ''
              cfg="keymap-drawer/config.yaml"
              draw() { # <kb-dir> <keymap-file> <layout-json> <layout-name>
                local kb="$1" keymap="$2" json="$3" layout="$4"
                local d="keyboards/$kb/keymap-drawer"
                mkdir -p "$d"
                keymap -c "$cfg" parse -z "keyboards/$kb/config/$keymap" > "$d/$kb.yaml"
                keymap -c "$cfg" draw "$d/$kb.yaml" \
                  -j "keyboards/$kb/config/$json" -l "$layout" > "$d/$kb.svg"
                echo "drew keyboards/$kb/keymap-drawer/$kb.svg"
              }
              draw ergonaut-one ergonaut_one.keymap ergonaut_one.json LAYOUT
              draw tk44          tk44.keymap         tk44.json          default
              draw mriya46       mriya.keymap        mriya.json         default
              draw dao           dao.keymap          info.json          LAYOUT
              draw charybdis-mini charybdis.keymap charybdis.json default_transform
            '';
          };
        in
        {
          draw-keymaps = {
            type = "app";
            program = "${draw-keymaps}/bin/draw-keymaps";
          };
        }
      );

      devShells = forAllSystems (system: {
        default = zmk-nix.devShells.${system}.default;
      });
    };
}
