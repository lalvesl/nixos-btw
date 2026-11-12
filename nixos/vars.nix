# Values shared by every desktop module. Reach them with the `vars` argument
# (passed through specialArgs and home-manager's extraSpecialArgs in flake.nix).
rec {
  # The one login account on this machine. Change it here and rebuild.
  username = "lalvesl";
  home = "/home/${username}";
}
