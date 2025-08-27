{
  description = "Flake for quickly spawning VMs on aarch64-darwin";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/release-25.05";
  };

  outputs =
    { self, nixpkgs }:
    let
      pkgs = import nixpkgs { system = "aarch64-darwin"; };
      aarch64-qemu-efi = pkgs.callPackage ./packages/aarch64-qemu-efi/default.nix { };
      nixosVM = pkgs.callPackage ./vms/nixos.nix {
        inherit aarch64-qemu-efi;
      };
    in
    {
      apps.aarch64-darwin = {
        nixos = {
          type = "app";
          program = "${nixosVM}/bin/nixos.sh";
        };
      };

    };
}
