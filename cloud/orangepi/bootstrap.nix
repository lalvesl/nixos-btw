# First boot of the board, and only that.
#
# This module goes into the SD image (nixosConfigurations.orangepi) and never
# into a colmena deploy. It exists to break the sops chicken-and-egg: the board
# only gets an SSH host key -- and therefore an age identity -- once it has
# booted, so the image that boots it cannot depend on decrypting anything.
#
# Everything here is public and deliberately in cleartext in the repository.
# Once the board is up and secrets/add-host-key.sh has run, the first
# `colmena apply` replaces this with cloud/orangepi/secrets.nix and the
# cleartext password stops being valid.
{ lib, ... }:
{
  users.users.lalvesl.initialPassword = "changeme";
  users.users.root.initialPassword = "changeme";

  # Only needed for the very first login, in case the public key does not get
  # you in. secrets.nix turns this off on the first deploy.
  services.openssh.settings.PasswordAuthentication = lib.mkForce true;
}
