{
  description = "Flake for quickly spawning VMs on aarch64-darwin";

  nixConfig = {
    extra-substituters = [
      "https://zpnixcache.fly.dev/darwinix"
    ];
    extra-trusted-public-keys = [
      "darwinix:QwQIkpmFbPbRjN78oG0sSZX7QghoT8IN5sVXT2OvxJw="
    ];
  };

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      disko,
    }:
    let
      pkgs = import nixpkgs { system = "aarch64-darwin"; };
      optimizedForAppleSilicon =
        pkg:
        pkg.overrideAttrs (oldAttrs: {
          env = (oldAttrs.env or { }) // {
            NIX_CFLAGS_COMPILE = (oldAttrs.env.NIX_CFLAGS_COMPILE or "") + " -O2 -mcpu=apple-m1";
            NIX_CXXFLAGS_COMPILE = (oldAttrs.env.NIX_CFLAGS_COMPILE or "") + " -O2 -mcpu=apple-m1";
          };
        });

      # NixOS ISO configuration
      # This builds a minimal NixOS ISO for aarch64-linux
      # Note: This requires a Linux builder to build from macOS
      nixosIsoSystem = nixpkgs.lib.nixosSystem {
        system = "aarch64-linux";
        modules = [
          ./iso/nixos-minimal.nix
          disko.nixosModules.disko
        ];
      };

      # Build the ISO image
      nixosIso = nixosIsoSystem.config.system.build.isoImage;

      qemu = (
        optimizedForAppleSilicon (
          pkgs.qemu.override {
            hostCpuOnly = true;
          }
        )
      );

      # Read ISO sources configuration
      isoSources = builtins.fromJSON (builtins.readFile ./iso-sources.json);

      # Generic Linux VM package that supports multiple distributions
      nixosVM = pkgs.callPackage ./vms/linux.nix {
        inherit nixosIso qemu;
        distribution = "nixos";
      };

      # Dynamically generate VM packages for each distribution in iso-sources.json
      distributionVMs = nixpkgs.lib.mapAttrs (
        distribution: _config:
        pkgs.callPackage ./vms/linux.nix {
          inherit qemu;
          inherit distribution;
        }
      ) isoSources;
    in
    {
      packages.aarch64-linux = {
        nixos-iso = nixosIso;
      };

      packages.aarch64-darwin = {
        nixos = nixosVM;
      }
      // distributionVMs;

      apps.aarch64-darwin = {
        nixos = {
          type = "app";
          program = "${nixosVM}/bin/linux.sh";
        };
      }
      // (nixpkgs.lib.mapAttrs (distribution: vm: {
        type = "app";
        program = "${vm}/bin/linux.sh";
      }) distributionVMs);

    };
}
