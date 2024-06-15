{ pkgs }:
{
  nixos = pkgs.callPackage ./nixos {
    aarch64-qemu-efi = pkgs.callPackage ../packages/aarch64-qemu-efi { };
  };
}
