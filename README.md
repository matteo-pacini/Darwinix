# Darwinix

Darwinix is a flake designed for quickly spawning VMs on `aarch64-darwin` systems. 

## Supported Operating Systems

Darwinix supports the following Linux distributions:

| OS | Version | Command | ISO Source |
|---|---|---|---|
| **NixOS** | 25.11 (Minimal) | `nix run "github:matteo-pacini/darwinix#linux-vm" -- nixos-25-11` | Downloaded at runtime from NixOS |
| **Ubuntu** | 25.10 (Desktop) | `nix run "github:matteo-pacini/darwinix#linux-vm" -- ubuntu-25-10` | Downloaded at runtime from CDImage |
| **Fedora** | Workstation 42 | `nix run "github:matteo-pacini/darwinix#linux-vm" -- fedora-workstation-42` | Downloaded at runtime from Fedora |
| **Fedora** | Workstation 43 | `nix run "github:matteo-pacini/darwinix#linux-vm" -- fedora-workstation-43` | Downloaded at runtime from Fedora |
| **Gentoo** | Minimal (latest autobuild) | `nix run "github:matteo-pacini/darwinix#linux-vm" -- gentoo` | Downloaded at runtime from Gentoo |

ISO downloads are verified against SHA-256 checksums pinned in `iso-sources.json`. Rolling sources (NixOS channel, Gentoo autobuilds) are refreshed weekly by CI.

## Usage

### VMs

You can spawn a VM by specifying the distribution name as an argument. For example, to create a NixOS VM:

```
nix run "github:matteo-pacini/darwinix#linux-vm" -- nixos-25-11
```

This command will create the necessary VM files locally if they are not found (e.g., EFI, EFI varstore, disk, etc.) and then start the VM.

**Note**: EFI firmware comes bundled with the packaged QEMU — no separate download. All distribution ISOs (including NixOS) are downloaded at runtime on first use. An internet connection is required for the initial setup.

**Faster Downloads**: ISOs are downloaded using `aria2c` with multiple concurrent connections, which significantly speeds up the download process.

You can pass additional arguments directly to QEMU after the distribution name. For example:

```
nix run "github:matteo-pacini/darwinix#linux-vm" -- nixos-25-11 -cdrom "/path/to/image.iso"
```

VMs come with internet access and audio support.

#### SSH access

Guest port 22 is forwarded to host port 2222 by default (once an SSH server is running in the guest):

```
ssh -p 2222 <user>@127.0.0.1
```

Customize or disable with the `HOSTFWD` environment variable:

```
HOSTFWD="hostfwd=tcp::2222-:22,hostfwd=tcp::8080-:80" nix run "github:matteo-pacini/darwinix#linux-vm" -- nixos-25-11
HOSTFWD="" nix run "github:matteo-pacini/darwinix#linux-vm" -- nixos-25-11   # disable
```

**Note**: each forwarded host port can only be bound by one VM at a time — for a second concurrent VM, pick different ports or set `HOSTFWD=""`.

You can customize the VM configuration using environment variables. To see all available options, run:

```
nix run "github:matteo-pacini/darwinix#linux-vm" -- --help
```

Example:

```
CORES=2 RAM=4 nix run "github:matteo-pacini/darwinix#linux-vm" -- nixos-25-11
```

#### Disk Size Configuration

Use the `DISK_SIZE` environment variable to set the initial disk size (default: `512G`). This only applies when creating the disk for the first time:

```
DISK_SIZE=1T nix run "github:matteo-pacini/darwinix#linux-vm" -- nixos-25-11
```

**Note**: Once the disk is created, changing `DISK_SIZE` won't affect it. If you want a different size, delete the `disk.qcow2` file and run the command again.

## Contributing

Contributions are welcome! Please open an issue or submit a pull request on GitHub.

## License

Darwinix is released under the [MIT License](LICENSE).
