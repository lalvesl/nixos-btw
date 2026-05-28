{
  description = "NixOS configuration";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nixos-rk3588 = {
      url = "github:gnull/nixos-rk3588";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      home-manager,
      nixos-rk3588,
      ...
    }@inputs:
    let
      system = "x86_64-linux";

      # Cross-compilation toolchain: build on x86_64, target aarch64
      pkgsCross = import nixpkgs {
        localSystem = system;
        crossSystem = {
          config = "aarch64-unknown-linux-gnu";
        };
      };

      rk3588Path = nixos-rk3588;

      # specialArgs required by gnull/nixos-rk3588 board modules
      rk3588SpecialArgs = {
        rk3588 = {
          inherit nixpkgs;
          pkgsKernel = pkgsCross;
        };
        # dtb-install.nix lists this arg but never uses it
        nixos-generators = { };
      };

      walletIso = nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = { inherit inputs; };
        modules = [
          ./nix-wallet/configuration.nix
          home-manager.nixosModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.users.lalvesl = import ./nixos/modules/home/mod.nix;
          }
        ];
      };
    in
    {
      nixosConfigurations.lalvesl-nix = nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = { inherit inputs; };
        modules = [
          ./nixos/configuration.nix
          home-manager.nixosModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.backupFileExtension = "bak";
            home-manager.users.lalvesl = import ./nixos/modules/home/mod.nix;
          }
        ];
      };

      nixosConfigurations.wallet = walletIso;

      # Orange Pi 5 — cross-compiled from x86_64 to aarch64
      nixosConfigurations.orangepi = nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = {
          inherit inputs nixpkgs;
        }
        // rk3588SpecialArgs;
        modules = [
          { nixpkgs.crossSystem.config = "aarch64-unknown-linux-gnu"; }
          (import "${toString rk3588Path}/modules/boards/orangepi5.nix")
          ./cloud/orangepi/sdcard.nix
          ./cloud/orangepi/configuration.nix
          {
            image.baseName = "orangepi-sd-image";
          }
        ];
      };

      # Colmena deployment hive
      colmena = import ./cloud/colmena.nix {
        inherit
          nixpkgs
          inputs
          pkgsCross
          rk3588SpecialArgs
          rk3588Path
          ;
      };

      packages.${system} = {
        wallet = walletIso.config.system.build.isoImage;
        orangepi-sdimage = self.nixosConfigurations.orangepi.config.system.build.sdImage;
      };
    };
}
