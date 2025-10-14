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
  };

  outputs =
    { self, nixpkgs }:
    let
      pkgs = import nixpkgs { system = "aarch64-darwin"; };
      aarch64-qemu-efi = pkgs.callPackage ./packages/aarch64-qemu-efi/default.nix { };
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
        modules = [ ./iso/nixos-minimal.nix ];
      };

      # Build the ISO image
      nixosIso = nixosIsoSystem.config.system.build.isoImage;

      # VM package that uses the dynamically built ISO
      nixosVM = pkgs.callPackage ./vms/nixos.nix {
        inherit aarch64-qemu-efi nixosIso;
        qemu = (
          optimizedForAppleSilicon (
            pkgs.qemu.override {
              hostCpuOnly = true;
            }
          )
        );
      };
    in
    {
      packages.aarch64-linux = {
        nixos-iso = nixosIso;
      };

      packages.aarch64-darwin = {
        nixos-vm = nixosVM;
      };

      apps.aarch64-darwin = {
        nixos = {
          type = "app";
          program = "${nixosVM}/bin/nixos.sh";
        };
      };

    };
}
