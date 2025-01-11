{ pkgs, ... }: {
  services.flatpak.enable = true;
  users.users."alves" = {
    packages = with pkgs; [
      flatpak
    ];
  };
  systemd.services.flatpak-repo = {
    wantedBy = [ "multi-user.target" ];
    path = [ pkgs.flatpak ];
    script = ''
      flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
    '';
  };

}
