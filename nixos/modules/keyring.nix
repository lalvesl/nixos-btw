{ pkgs, ... }:
{
  # GDM (xserver.nix) already wires PAM to unlock this on login via
  # security.pam.services.login.enableGnomeKeyring, so no spawn-at-startup
  # is needed in niri's config. Backs the Secret Service API used by
  # Chrome/Chromium/Brave for saved passwords, ssh-agent, etc.
  services.gnome.gnome-keyring.enable = true;

  environment.systemPackages = [ pkgs.seahorse ];
}
