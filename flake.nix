{
  description = "Flake for quickly spawning VMs on aarch64-darwin";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/release-24.05";
  };

  outputs =
    { self, nixpkgs }:
    let
      pkgs = import nixpkgs { system = "aarch64-darwin"; };
      linuxPkgs = import nixpkgs { system = "aarch64-linux"; };
      vms = import ./vms { inherit pkgs; };
    in
    {
      apps.aarch64-darwin = {
        nixos = {
          type = "app";
          program = "${vms.nixos}/bin/nixos.sh";
        };
      };

      apps.aarch64-linux = {
        nixos-efi-format = {
          type = "app";
          program = toString (
            linuxPkgs.writeShellScript "efi-format" ''
              #!${linuxPkgs.bash}/bin/bash
              export PATH=${linuxPkgs.gptfdisk}/bin:$PATH
              sudo sgdisk \
                -og $1 \
                -n 1:0:+512M \
                -t 1:ef00 \
                -n 2:0:+4G \
                -t 2:8200 \
                -n 3:0:0 \
                -t 3:8300 \
                $1
              sudo partprobe
              sudo mkfs.vfat -F 32 ''${1}1
              sudo mkswap ''${1}2
              sudo swapon ''${1}2
              sudo mkfs.xfs ''${1}3
              sudo mount /dev/''${1}3 /mnt
              sudo mkdir /mnt/boot
              sudo mount /dev/''${1}1 /mnt/boot
              sudo nixos-generate-config --root /mnt
            ''
          );
        };
      };
    };
}
