{
  imports = [
    ./checks.nix
    ./ci.nix
    ./devshells.nix
    ./overlays.nix
    ./packages
  ];

  perSystem = {pkgs, ...}: {
    formatter = pkgs.alejandra;

    # Neovim uses lua 5.1 as it is the version which supports JIT
    _module.args = {
      lua = pkgs.lua5_1;
    };
  };
}
