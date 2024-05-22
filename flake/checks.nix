{inputs, ...}: {
  # TODO: not working
  perSystem = {pkgs, ...}: {
    checks = {
      shlint = pkgs.runCommand "shlint" {
        nativeBuildInputs = [pkgs.shellcheck];
        preferLocalBuild = true;
      } "make -C ${inputs.neovim-src} shlint > $out";
    };
  };
}
