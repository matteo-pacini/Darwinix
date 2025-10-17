# Darwinix

Darwinix is a flake designed for quickly spawning VMs on `aarch64-darwin` systems. 

## Supported Operating Systems

Darwinix supports the following Linux distributions:

| OS | Version | Command | ISO Source |
|---|---|---|---|
| **NixOS** | Latest (unstable) | `nix run "github:matteo-pacini/darwinix#nixos"` | Pre-built during flake evaluation |
| **Ubuntu** | 25.10 (Desktop) | `nix run "github:matteo-pacini/darwinix#ubuntu-25-10"` | Downloaded at runtime from CDImage |

## Usage

### VMs

You can spawn a VM using one of the commands listed above. For example, to create a NixOS VM:

```
nix run "github:matteo-pacini/darwinix#nixos"
```

This command will create the necessary VM files locally if they are not found (e.g., EFI, EFI varstore, disk, etc.) and then start the VM.

**Note**: On first run, the EFI firmware files will be automatically downloaded from [edk2-nightly](https://retrage.github.io/edk2-nightly/). For distributions like Ubuntu that fetch ISOs at runtime, the ISO will also be downloaded on first run. An internet connection is required for the initial setup.

**Faster Downloads**: For non-NixOS distributions like Ubuntu, ISOs are downloaded using `aria2c` with multiple concurrent connections, which significantly speeds up the download process.

You can pass additional arguments directly to QEMU. For example:

```
nix run "github:matteo-pacini/darwinix#nixos" -- -cdrom "/path/to/image.iso"
```

VMs come with internet access, audio support, and clipboard sharing between your Mac and the VM.

You can customize the VM configuration using environment variables. To see all available options, run:

```
nix run "github:matteo-pacini/darwinix#nixos" -- --help
```

Example:

```
CORES=2 RAM=4 nix run "github:matteo-pacini/darwinix#nixos"
```

#### Disk Size Configuration

Use the `DISK_SIZE` environment variable to set the initial disk size (default: `512G`). This only applies when creating the disk for the first time:

```
DISK_SIZE=1T nix run "github:matteo-pacini/darwinix#nixos"
```

**Note**: Once the disk is created, changing `DISK_SIZE` won't affect it. If you want a different size, delete the `disk.qcow2` file and run the command again.

### Building the NixOS ISO

The NixOS ISO is built dynamically with:
- Flakes and nix-command enabled
- Disko for disk partitioning

**Note**: ISOs can only be built on Linux, so you'll need a Linux builder. Here are your options:

#### Option 1: nix-darwin's Linux builder

If you use nix-darwin, enable the built-in Linux builder:

```nix
nix.linux-builder.enable = true;
```

Then run:
```bash
darwin-rebuild switch
```

#### Option 2: Remote Linux builder

Point to a remote Linux machine in your Nix config (`~/.config/nix/nix.conf` or `/etc/nix/nix.conf`):

```
builders = ssh://user@linux-host aarch64-linux
```

## Contributing

Contributions are welcome! Please open an issue or submit a pull request on GitHub.

## License

Darwinix is released under the [MIT License](LICENSE).
