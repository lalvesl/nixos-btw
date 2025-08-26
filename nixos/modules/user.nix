{ pkgs, ... }:
{
  programs.zsh.enable = true;

  users = {
    defaultUserShell = pkgs.zsh;

    users.lalvesl = {
      isNormalUser = true;
      description = "lalvesl";
      extraGroups = [
        "networkmanager"
        "wheel"
        "input"
      ];
      packages = [ ];
    };
  };
}
