{
  description = "Neovim flake";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-compat = {
      url = "github:edolstra/flake-compat";
      flake = false;
    };
    flake-parts.url = "github:hercules-ci/flake-parts";
    hercules-ci-effects.url = "github:hercules-ci/hercules-ci-effects";
    neovim-src = {
      url = "github:neovim/neovim";
      flake = false;
    };
  };

  outputs = {
    self,
    nixpkgs,
    neovim-src,
    flake-parts,
    ...
  } @ inputs:
    flake-parts.lib.mkFlake {inherit inputs;} {
      imports = [
        inputs.flake-parts.flakeModules.easyOverlay
        inputs.hercules-ci-effects.flakeModule
        ./package.nix
      ];

      systems = ["x86_64-linux"];
      perSystem = {
        config,
        lib,
        pkgs,
        ...
      }: let
        lua = pkgs.lua5_1;
      in {
        checks = {
          shlint = pkgs.runCommand "shlint" {
            nativeBuildInputs = [pkgs.shellcheck];
            preferLocalBuild = true;
          } "make -C ${neovim-src} shlint > $out";
        };

        devShells = {
          default = pkgs.mkShell {
            name = "neovim-developer-shell";
            inputsFrom = [
              config.devShells.minimal
              config.packages.neovim-developer
            ];
            shellHook = ''
              ${config.packages.neovim-developer.shellHook or ""}
              export ASAN_SYMBOLIZER_PATH=${pkgs.llvm_18}/bin/llvm-symbolizer
              export NVIM_PYTHON_LOG_LEVEL=DEBUG
              export NVIM_LOG_FILE=/tmp/nvim.log

              # ASAN_OPTIONS=detect_leaks=1
              export ASAN_OPTIONS="log_path=./test.log:abort_on_error=1"

              # for treesitter functionaltests
              mkdir -p runtime/parser
              cp -f ${pkgs.vimPlugins.nvim-treesitter.builtGrammars.c}/parser runtime/parser/c.so
            '';
          };
          # Provide a devshell that can be used strictly for developing this flake.
          minimal = pkgs.mkShell.override {inherit (pkgs.llvmPackages_latest) stdenv;} {
            name = "neovim-minimal-shell";
            inputsFrom = [
              config.packages.default
            ];
            packages = with pkgs; [
              (python3.withPackages (ps: [ps.msgpack]))
              include-what-you-use
              jq
              lua-language-server
              lua.pkgs.luacheck
              shellcheck
            ];
            shellHook = ''
              export VIMRUNTIME=
            '';
          };
        };

        overlayAttrs = {
          inherit (config.packages) neovim neovim-debug neovim-developer;
        };

        packages = {
          default = config.packages.neovim;
          neovim-debug =
            (config.packages.neovim.override {
              stdenv =
                if pkgs.stdenv.isLinux
                then pkgs.llvmPackages_latest.stdenv
                else pkgs.stdenv;
              lua = pkgs.luajit;
            })
            .overrideAttrs (oa: {
              dontStrip = true;
              NIX_CFLAGES_COMPILE = " -ggdb -Og";
              cmakeBuildType = "Debug";
              disallowedReferences = [];
            });
          neovim-developer = config.packages.neovim-debug.overrideAttrs (oa: {
            cmakeFlagsArray =
              oa.cmakeFlagsArray
              ++ [
                "-DLUACHECK_PRG=${lua.pkgs.luacheck}/bin/luacheck"
                "-DENABLE_LTO=OFF"
              ]
              ++ lib.optionals pkgs.stdenv.isLinux [
                # https://github.com/google/sanitizers/wiki/AddressSanitizerFlags
                # https://clang.llvm.org/docs/AddressSanitizer.html#symbolizing-the-reports
                "-DENABLE_ASAN_UBSAN=ON"
              ];
            doCheck = pkgs.stdenv.isLinux;
            shellHook = ''
              export VIMRUNTIME=${neovim-src}/runtime
            '';
          });
        };
      };

      hercules-ci.flake-update = {
        enable = true;
        baseMerge.enable = true;
        baseMerge.method = "rebase";
        autoMergeMethod = "rebase";
        # Update everynight at midnight
        when = {
          hour = [0];
          minute = 0;
        };
      };
    };
}
