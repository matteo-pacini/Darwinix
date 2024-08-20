{
  description = "Flake for quickly spawning VMs on aarch64-darwin";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
  };

  outputs =
    { self, nixpkgs }:
    let
      pkgs = import nixpkgs { system = "aarch64-darwin"; };
      lib = import ./lib { inherit pkgs; };
      vms = import ./vms {
        inherit pkgs;
        mkQemu = lib.mkQemu;
      };
    in
    {
      apps.aarch64-darwin = {
        nixos = {
          type = "app";
          program = "${vms.nixos}/bin/nixos.sh";
        };
        macos9 = {
          type = "app";
          program = "${vms.macos9}/bin/macos9.sh";
        };
      };

    };
}
