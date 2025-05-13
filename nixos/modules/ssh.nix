{ pkgs, lib, ... }:
{
  services.openssh = {
    enable = true;
    ports = [
      22
      8822
    ];
    settings = {
      PasswordAuthentication = true;
      AllowUsers = [ "alves" ]; # Allows all users by default. Can be [ "user1" "user2" ]
      UseDns = true;
      X11Forwarding = true;
      PermitRootLogin = "prohibit-password"; # "yes", "without-password", "prohibit-password", "forced-commands-only", "no"
    };
  };
  programs.ssh.startAgent = true;
  services.sshd.enable = true;
  systemd.services.sshd.wantedBy = lib.mkOverride 40 [ "multi-user.target" ];
  environment.systemPackages = with pkgs; [
    openssh
  ];

  networking.firewall.allowedTCPPorts = [
    22
    8822
  ];
}
