{ pkgs }:
let
  inherit (builtins)
    filter
    elem
    split
    baseNameOf
    ;
in
{
  mkQemu =
    { hostCpuTarget }:

    (pkgs.qemu.override { hostCpuTargets = [ hostCpuTarget ]; }).overrideAttrs (oldAttrs: {
      # Filter out patches that disable some advanced Cocoa features,
      # like copy-pasting between host and guest.
      # Min. OS required becomes macOS 11.0, which is the base SDK for `aaarch64-darwin`.
      # https://github.com/NixOS/nixpkgs/blob/nixos-unstable/pkgs/applications/virtualization/qemu/default.nix#L116-L137
      patches = filter (patch: !(elem "cocoa" (split "-" (baseNameOf patch)))) oldAttrs.patches;
      # Optimize for Apple M1 onwards
      NIX_CFLAGS_COMPILE =
        [ (oldAttrs.NIX_CFLAGS_COMPILE or "") ]
        ++ [
          "-O2"
          "-mcpu=apple-m1"
        ];
    });

}
