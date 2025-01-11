{ pkgs }:
{
  mkQemu =
    { hostCpuTarget }:

    (pkgs.qemu.override { hostCpuTargets = [ hostCpuTarget ]; }).overrideAttrs (oldAttrs: {
      # Optimize for Apple M1 onwards
      NIX_CFLAGS_COMPILE =
        [ (oldAttrs.NIX_CFLAGS_COMPILE or "") ]
        ++ [
          "-O2"
          "-mcpu=apple-m1"
        ];
    });

}
