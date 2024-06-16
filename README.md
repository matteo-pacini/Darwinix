# Darwinix

Darwinix is a flake designed for quickly spawning VMs on `aarch64-darwin` systems. 

## Usage

### VMs

Currently, Darwinix supports creating a NixOS VM. You can spawn a NixOS VM using the following command:

```
nix run "github:matteo-pacini/darwinix#nixos"
```

This command will create the necessary VM files locally if they are not found (e.g., EFI, EFI varstore, disk, etc.) and then start the VM.

Futher arguments passed to the command invocation are sent to `qemu-system-aarch64` directly, i.e.:

```
nix run "github:matteo-pacini/darwinix#nixos" -- -cdrom "/path/to/image.iso"
```

All VMS come with NIC, USB support and CoreAudio-bound audio device.

### Commands

#### nixos-efi-format

The only command available in Darwinix at the moment is `nixos-efi-format`. This command formats the device passed as an argument with an EFI layout:

- 512MB for the EFI partition
- 4GB for swap
- The remaining space for the root partition (`/`)

To use `nixos-efi-format`, run the following command from within the VM, replacing `/dev/sdX` with your target device:

```
nix run "github:matteo-pacini/darwinix#nixos-efi-format" /dev/[sv]dX
```

This command will:

1. Create the partitions:
    - 512MB EFI partition (type `ef00`)
    - 4GB swap partition (type `8200`)
    - Remaining space as the root partition (type `8300`)
2. Format the partitions:
    - EFI partition as FAT32
    - Swap partition
    - Root partition as XFS
3. Mount the partitions and generate the initial NixOS configuration.

## Contributing

Contributions are welcome! Please open an issue or submit a pull request on GitHub.

## License

Darwinix is released under the [MIT License](LICENSE).
