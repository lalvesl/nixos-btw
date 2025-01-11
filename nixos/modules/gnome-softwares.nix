{ pkgs, ... }: {
  users.users."alves" = {
    packages = with pkgs; [
      gnome-software
      gnome-system-monitor
      gnome-disk-utility
    ];
  };

}
