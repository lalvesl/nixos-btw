# Password of the user and of root, taken from the environment at build time:
#
#   LAPTOP_PASSWORD='...' nix build .#laptop-intel-i5 --impure
#
# Only a yescrypt hash goes into the system (and so onto the laptop's disk); the
# plaintext stays in the installer ISO, which needs it to format the LUKS volume.
# --impure is what lets Nix see the variable.
#
# Left unset, nothing is configured here: the accounts keep whatever password
# they already have, so `nixos-rebuild switch` on the laptop works without it.
{
  lib,
  pkgs,
  vars,
  ...
}:
let
  password = builtins.getEnv "LAPTOP_PASSWORD";

  # yescrypt, like nix-wallet: PAM validates /etc/shadow through libxcrypt, which
  # implements yescrypt but not argon2. A random salt, so each build differs.
  hashFile =
    pkgs.runCommand "laptop-password-hash"
      {
        nativeBuildInputs = [ pkgs.mkpasswd ];
        inherit password;
        passAsFile = [ "password" ];
      }
      ''
        mkpasswd -m yescrypt -s < "$passwordPath" | tr -d '\n' > $out
      '';
in
{
  config = lib.mkIf (password != "") {
    users.users.${vars.username}.hashedPasswordFile = "${hashFile}";
    users.users.root.hashedPasswordFile = "${hashFile}";
  };
}
