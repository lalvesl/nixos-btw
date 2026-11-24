{ lib, vars, ... }:
let
  # SSH server with user + password login for this laptop. Off by default; set to
  # true and rebuild when you need to reach it over SSH, then set it back to false
  # (and rebuild) to close the port again. It is separate from the main machine's
  # nixos/modules/ssh.nix, so turning one on never turns the other on.
  # The password is the one the image was built with (LAPTOP_PASSWORD), or the
  # one set later with `passwd` for the account (no key needed).
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
