{ lib, vars, ... }:
let
  # SSH server with user + password login. Off by default; set to true and
  # rebuild when you need to reach this machine over SSH, then set it back to
  # false (and rebuild) to close the port again.
  # The password is the one set with `passwd` for the account (no key needed).
  enable = false;
in
{
  services.openssh = lib.mkIf enable {
    enable = true;
    openFirewall = true;
    settings = {
      PasswordAuthentication = true;
      KbdInteractiveAuthentication = false;
      PermitRootLogin = "no";
      # Only the regular user can log in.
      AllowUsers = [ vars.username ];
    };
  };
}
