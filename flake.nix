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
    # Long-term memory server shared by AI coding agents. No `follows`: its
    # build relies on its own pinned nixpkgs + rust-overlay toolchain.
    ai-memory.url = "github:akitaonrails/ai-memory";
    # The home-lab (the Orange Pi and its services), kept off GitHub on the
    # private git server at home: it names every service, disk and device in
    # the house. Only reachable from the home LAN or the tailnet, so a clone of
    # this repository from anywhere else builds everything but the home-lab.
    homelab = {
      url = "git+ssh://forgejo@git.h.lalvesl.com/lalvesl/homelab.git";
      flake = false;
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      home-manager,
      nixos-rk3588,
      homelab,
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

      # Native aarch64 package set. The colmena hive builds with this rather
      # than pkgsCross so that cache.nixos.org actually matches -- see the
      # measurement in the homelab input's colmena.nix.
      pkgsNative = import nixpkgs {
        system = "aarch64-linux";
      };

      vars = import ./nixos/vars.nix;

      # The i5 laptop has no NVIDIA GPU: same shared modules, without CUDA.
      laptopVars = vars // { nvidia = false; };

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
            home-manager.extraSpecialArgs = {
              inherit vars;
              hasNvidia = true;
            };
            home-manager.users.${vars.username} = import ./nixos/modules/home/mod.nix;
          }
        ];
      };
    in
    {
      nixosConfigurations.lalvesl-nix = nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = { inherit inputs vars; };
        modules = [
          ./nixos/configuration.nix
          # The home lab's domain, DNS and cache, kept in the private homelab repo.
          "${homelab}/network.nix"
          home-manager.nixosModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.extraSpecialArgs = {
              inherit vars;
              hasNvidia = true;
            };
            home-manager.backupFileExtension = "bak";
            home-manager.users.${vars.username} = import ./nixos/modules/home/mod.nix;
          }
        ];
      };

      nixosConfigurations.wallet = walletIso;

      # Live ISO that installs the laptop system onto its HDD (LUKS2 + bcachefs).
      nixosConfigurations.laptop-i5-installer = nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = {
          inherit inputs;
          laptop = self.nixosConfigurations.laptop-i5;
        };
        modules = [ ./cloud/laptop-i5/installer.nix ];
      };

      # Second computer: Intel i5-3210M/3230M laptop on an HDD. Same desktop,
      # minus the NVIDIA and heavy parts; see cloud/laptop-i5/README.md.
      nixosConfigurations.laptop-i5 = nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = {
          inherit inputs;
          vars = laptopVars;
        };
        modules = [
          ./cloud/laptop-i5/configuration.nix
          "${homelab}/network.nix"
          ./cloud/laptop-i5/image.nix
          home-manager.nixosModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.backupFileExtension = "bak";
            # No NVIDIA here: niri keeps its monitor and render-device block off.
            home-manager.extraSpecialArgs = {
              vars = laptopVars;
              hasNvidia = false;
            };
            home-manager.users.${vars.username} = import ./nixos/modules/home/mod.nix;
          }
        ];
      };

      # Orange Pi 5B — cross-compiled from x86_64 to aarch64
      nixosConfigurations.orangepi = nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = {
          inherit inputs nixpkgs;
        }
        // rk3588SpecialArgs;
        modules = [
          { nixpkgs.crossSystem.config = "aarch64-unknown-linux-gnu"; }
          (import "${toString rk3588Path}/modules/boards/orangepi5b.nix")
          "${homelab}/orangepi/sdcard.nix"
          "${homelab}/orangepi/configuration.nix"
          "${homelab}/orangepi/cross-fixes.nix"
          # First-boot image: cleartext initial password and no sops secrets. The
          # board has no host key yet, so nothing here may depend on decrypting
          # anything. Colmena takes over from the next deploy on.
          "${homelab}/orangepi/bootstrap.nix"
          {
            image.baseName = "orangepi-sd-image";
          }
        ];
      };

      # Colmena deployment hive
      colmena = import "${homelab}/colmena.nix" {
        inherit
          nixpkgs
          inputs
          pkgsNative
          rk3588Path
          ;
      };

      apps.${system}.send-orangepi-sdimage = {
        type = "app";
        program = "${self.packages.${system}.send-orangepi-sdimage}/bin/send-orangepi-sdimage";
      };

      packages.${system} =
        let
          # What the Orange Pi pipeline leaves out of a system build, because building
          # it there is not worth it: the sbx base images (a VM under emulation starves
          # the board), the gamebox image (proot needs ptrace, which the emulation
          # lacks) and ai-memory (a Rust build that takes hours under emulation).
          # The machines build them themselves; the rest is fetched from the board.
          ciModule =
            {
              lib,
              options,
              pkgs,
              ...
            }:
            {
              config = lib.mkMerge [
                {
                  sbx.bakeImage = false;
                  services.ai-memory.package = lib.mkForce pkgs.emptyDirectory;
                }
                # Only the desktop has the gamebox module.
                (lib.optionalAttrs (options ? gamebox) { gamebox.bakeImage = false; })
              ];
            };
          ci = name: (self.nixosConfigurations.${name}.extendModules { modules = [ ciModule ]; }).config.system.build.toplevel;
        in
        {
        wallet = walletIso.config.system.build.isoImage;
        # The systems as the Orange Pi pipeline builds them (see ciModule).
        ci-laptop-i5 = ci "laptop-i5";
        ci-desktop = ci "lalvesl-nix";
        # The image to write to the HDD, and the installer ISO as the alternative.
        laptop-intel-i5 = self.nixosConfigurations.laptop-i5.config.system.build.diskImage;
        laptop-intel-i5-installer = self.nixosConfigurations.laptop-i5-installer.config.system.build.isoImage;
        orangepi-sdimage = self.nixosConfigurations.orangepi.config.system.build.sdImage;
        send-orangepi-sdimage = import "${homelab}/orangepi/send-sdimage.nix" {
          pkgs = import nixpkgs { inherit system; };
          sdImage = self.nixosConfigurations.orangepi.config.system.build.sdImage;
        };

        # The Pingora gateway. Exposed mainly so it can be built and tested on
        # its own; the board gets it through the homelab input's services/proxy.nix.
        homelab-gateway = (import nixpkgs { inherit system; }).callPackage "${homelab}/orangepi/pingora" { };

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
