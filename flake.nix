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
    # Secrets encrypted at rest in the repo, decrypted only at activation
    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # FHS wrappers for an imperatively installed native MATLAB (no docker/web)
    nix-matlab = {
      url = "gitlab:doronbehar/nix-matlab";
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
          ./cloud/orangepi/cross-fixes.nix
          # First-boot image: cleartext initial password and no sops secrets. The
          # board has no host key yet, so nothing here may depend on decrypting
          # anything. Colmena takes over from the next deploy on.
          ./cloud/orangepi/bootstrap.nix
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

      apps.${system}.send-orangepi-sdimage = {
        type = "app";
        program = "${self.packages.${system}.send-orangepi-sdimage}/bin/send-orangepi-sdimage";
      };

      packages.${system} = {
        wallet = walletIso.config.system.build.isoImage;
        orangepi-sdimage = self.nixosConfigurations.orangepi.config.system.build.sdImage;
        send-orangepi-sdimage = import ./cloud/orangepi/send-sdimage.nix {
          pkgs = import nixpkgs { inherit system; };
          sdImage = self.nixosConfigurations.orangepi.config.system.build.sdImage;
        };

        gamebox-image = import ./nixos/modules/gamebox-image.nix {
          pkgs = import nixpkgs {
            inherit system;
            config.allowUnfree = true;
          };
        };
      };

      # Secrets tooling. `nix develop` makes the commands in secrets/README.md
      # work without installing anything system-wide.
      devShells.${system}.default =
        let
          pkgs = import nixpkgs { inherit system; };
        in
        pkgs.mkShell {
          packages = with pkgs; [
            sops
            age
            ssh-to-age
            mkpasswd
            colmena
          ];

          # Where sops looks for the admin key when editing and decrypting. Set
          # in the shellHook rather than as a derivation variable because it
          # depends on $HOME, which does not exist during pure flake evaluation.
          shellHook = ''
            export SOPS_AGE_KEY_FILE="$HOME/.config/sops/age/keys.txt"
          '';
        };
    };
}
