{
  description = "NixOS Wallet ISO Flake";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
  };

  outputs =
    { self, nixpkgs }:
    {
      nixosConfigurations.wallet-iso = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          # Import our custom configuration which handles the ISO base
          ./configuration.nix
        ];
      };
    };
}
