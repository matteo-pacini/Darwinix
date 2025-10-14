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

### Building the ISO

The NixOS ISO is now built dynamically instead of being hardcoded. This allows for customization and ensures you always have the latest configuration.

**Important**: Building the ISO requires a Linux builder since ISOs can only be built on Linux systems. On macOS, you have several options:

#### Option 1: Using nix-darwin's built-in Linux builder

If you're using nix-darwin, you can enable the built-in Linux builder:

```nix
# In your nix-darwin configuration
nix.linux-builder.enable = true;
```

Then rebuild your system:
```bash
darwin-rebuild switch
```

#### Option 2: Using a remote Linux builder

Configure a remote Linux builder in your `~/.config/nix/nix.conf` or `/etc/nix/nix.conf`:

```
builders = ssh://user@linux-host aarch64-linux
```

```

## Contributing

Contributions are welcome! Please open an issue or submit a pull request on GitHub.

## License

Darwinix is released under the [MIT License](LICENSE).
