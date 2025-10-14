# Minimal NixOS ISO configuration for aarch64
# This configuration is used to build a custom ISO image on the fly
{
  config,
  pkgs,
  lib,
  modulesPath,
  ...
}:
{
  imports = [
    "${modulesPath}/installer/cd-dvd/installation-cd-minimal.nix"
    "${modulesPath}/installer/cd-dvd/channel.nix"
  ];

  # Set the NixOS version to match the flake
  system.stateVersion = "25.05";

  # Ensure we're building for aarch64
  nixpkgs.hostPlatform = "aarch64-linux";

}
