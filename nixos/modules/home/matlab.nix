# nix-matlab's wrappers source this file to find where MATLAB was installed
# imperatively. See ../matlab.nix for the one-time installation steps.
{ config, ... }:
{
  xdg.configFile."matlab/nix.sh".text = ''
    INSTALL_DIR=${config.home.homeDirectory}/.local/share/matlab/installation
  '';
}
