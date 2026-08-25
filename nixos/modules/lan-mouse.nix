{ pkgs, ... }:
{
  environment.systemPackages = [ pkgs.lan-mouse ];

  systemd.user.services.lan-mouse = {
    description = "lan-mouse - share mouse and keyboard over LAN";
    serviceConfig = {
      ExecStart = "${pkgs.lan-mouse}/bin/lan-mouse";
      Restart = "on-failure";
    };
  };
}
