{ pkgs, vars, ... }:
{
  programs.zsh.enable = true;

  users = {
    defaultUserShell = pkgs.zsh;

    users.${vars.username} = {
      isNormalUser = true;
      description = vars.username;
      extraGroups = [
        "networkmanager"
        "wheel"
        "input"
        "video"
      ];
      packages = [ ];
    };
  };
}
