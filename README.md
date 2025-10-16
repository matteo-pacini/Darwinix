# Darwinix

Darwinix is a flake designed for quickly spawning VMs on `aarch64-darwin` systems. 

## Usage

### VMs

Currently, Darwinix supports creating a NixOS VM. You can spawn a NixOS VM using the following command:

```
nix run "github:matteo-pacini/darwinix#nixos"
```

This command will create the necessary VM files locally if they are not found (e.g., EFI, EFI varstore, disk, etc.) and then start the VM.

**Note**: On first run, the EFI firmware files will be automatically downloaded from [edk2-nightly](https://retrage.github.io/edk2-nightly/). An internet connection is required for the initial setup.

Futher arguments passed to the command invocation are sent to `qemu-system-aarch64` directly, i.e.:

```
nix run "github:matteo-pacini/darwinix#nixos" -- -cdrom "/path/to/image.iso"
```

All VMS come with Internet and a CoreAudio-bound audio device.
Copy-paste between host and guest is also supported.

You can customize the VM configuration using environment variables. To see all available options, run:

```
nix run "github:matteo-pacini/darwinix#nixos" -- --help
```

Example:

```
CORES=2 RAM=4 nix run "github:matteo-pacini/darwinix#nixos"
```

#### Disk Size Configuration

The `DISK_SIZE` environment variable controls the initial size of the VM disk image (default: `512G`). This setting **only applies when the disk image is first created**.

```
DISK_SIZE=1T nix run "github:matteo-pacini/darwinix#nixos"
```

**Important**: Once the disk image (`disk.qcow2`) has been created, changing the `DISK_SIZE` variable will have no effect. The existing disk retains its current size. To create a new disk with a different size, you must first delete the existing `disk.qcow2` file.

### Building the ISO

The NixOS ISO is now built dynamically instead of being hardcoded. The ISO includes:
- Flakes and nix-command experimental features enabled
- Disko for disk partitioning and formatting

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
