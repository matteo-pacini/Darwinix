{ pkgs, mkQemu }:
{
  nixos = pkgs.callPackage ./nixos {
    inherit mkQemu;
    aarch64-qemu-efi = pkgs.callPackage ../packages/aarch64-qemu-efi { };
  };
}
