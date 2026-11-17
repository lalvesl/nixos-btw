# Values shared by every desktop module. Reach them with the `vars` argument
# (passed through specialArgs and home-manager's extraSpecialArgs in flake.nix).
rec {
  # The one login account on this machine. Change it here and rebuild.
  username = "lalvesl";
  home = "/home/${username}";

  # Use the open-source nouveau driver for the NVIDIA GPU of the main desktop
  # instead of the proprietary one. Off for now. It affects the whole stack:
  # nixos/modules/nvidia.nix, xserver.nix and the niri render device.
  # The GTX 1050 (Pascal) cannot be reclocked by nouveau, so expect 3D to be slow,
  # and there is no CUDA, nvidia-settings or container toolkit.
  nouveau = false;

  # This machine has an NVIDIA GPU, so CUDA is built and `cudatoolkit` installed.
  # A machine without one (the i5 laptop) overrides it to false in flake.nix.
  nvidia = true;
}
