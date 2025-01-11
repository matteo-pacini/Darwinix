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

All VMS come with Internet and a CoreAudio-bound audio device.
Copy-paste between host and guest is also supported.

QEMU needs to be compiled for the first run for this to work, as a few macOS 11.0+ functionalities [are currently disabled](https://github.com/NixOS/nixpkgs/blob/nixos-unstable/pkgs/applications/virtualization/qemu/default.nix#L116-L137) in the official derivation.

`RAM` and `CORES` environment variables can be used to override the launch script defaults (half of the CPU cores, +1 if result is odd, and 1/4th of the available RAM.).

Example:

```
CORES=2 RAM=4 nix run "github:matteo-pacini/darwinix#nixos"
```

## Contributing

Contributions are welcome! Please open an issue or submit a pull request on GitHub.

## License

Darwinix is released under the [MIT License](LICENSE).
