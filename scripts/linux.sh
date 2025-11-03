#!/usr/bin/env bash

set -eo pipefail

PREFIX=@@prefix@@

# Get distribution from first argument, default to nixos
DISTRIBUTION="${1:-nixos}"

# Shift arguments so remaining args are passed to QEMU
if [ $# -gt 0 ]; then
    shift
fi

# Half of the cores, + 1 if odd
_CORES=$(
    sysctl -n hw.logicalcpu_max | \
    perl -nle 'my $half = $_ / 2; print $half % 2 != 0 ? $half + 1 : $half'
)
# 1/4 of the RAM
_RAM=$(sysctl -n hw.memsize | perl -nle 'print ($_ / (1024 ** 3) / 4)')

CORES=${CORES:-$_CORES}
RAM=${RAM:-$_RAM}
GRAPHICS=${GRAPHICS:-1}
AUDIO=${AUDIO:-1}
NETWORK=${NETWORK:-1}
COMPRESS=${COMPRESS:-0}
SNAPSHOT=${SNAPSHOT:-0}
DEBUG=${DEBUG:-0}
DISK_SIZE=${DISK_SIZE:-512G}

info() {
    gum log --structured --level info "$1"
}

warn() {
    gum log --structured --level warn "$1"
}

debug() {
    if [ "$DEBUG" -eq 1 ]; then
        gum log --structured --level debug "$1"
    fi
}

error() {
    gum log --structured --level error "$1"
}

# Cleanup function for temporary files
cleanup_temp_files() {
    debug "Cleaning up temporary files..."
    rm -f /tmp/RELEASEAARCH64_QEMU_EFI.fd /tmp/RELEASEAARCH64_QEMU_VARS.fd
}

# Set up trap to cleanup on exit
trap cleanup_temp_files EXIT

if [[ "$*" == *"-h"* ]] || [[ "$*" == *"--help"* ]] || [[ "${DISTRIBUTION}" == "-h" ]] || [[ "${DISTRIBUTION}" == "--help" ]]; then
    echo "Usage: nix run \"github:matteo-pacini/darwinix#linux-vm\" -- <distribution> [extra qemu options]"
    echo
    echo "Available distributions:"
    echo "  nixos                   - NixOS (pre-built ISO)"
    echo "  ubuntu-25-10            - Ubuntu 25.10 Desktop"
    echo "  fedora-workstation-42   - Fedora Workstation 42"
    echo
    echo "Environment variables:"
    echo "  CORES: number of cores to use (default: $_CORES)"
    echo "  RAM: amount of RAM to use in GB (default: $_RAM)"
    echo "  GRAPHICS: enable graphics support (default: 1)"
    echo "  AUDIO: enable audio support (default: 1)"
    echo "  NETWORK: enable network support (default: 1)"
    echo "  COMPRESS: compress disk image after shutdown (default: 0)"
    echo "  SNAPSHOT: run without committing disk changes (default: 0)"
    echo "  DEBUG: enable debug logging (default: 0)"
    echo "  DISK_SIZE: initial disk size (default: 512G, only used when disk is first created)"
    exit 0
fi

clear

info "Starting ${DISTRIBUTION} VM..."
info "Using $CORES cores and $RAM GB of RAM"

sleep 1

# Download EFI firmware if needed
if [ ! -f efi.img ]; then
    info "EFI image not found, creating one..."

    EFI_URL="https://retrage.github.io/edk2-nightly/bin/RELEASEAARCH64_QEMU_EFI.fd"
    EFI_TEMP="/tmp/RELEASEAARCH64_QEMU_EFI.fd"

    debug "Downloading EFI firmware from $EFI_URL..."
    if ! curl -fsSL -o "$EFI_TEMP" "$EFI_URL"; then
        error "Failed to download EFI firmware from $EFI_URL. Please check your internet connection."
        exit 1
    fi
    debug "EFI firmware downloaded successfully"

    debug "Creating efi.img..."
    truncate -s 64m efi.img
    dd if="$EFI_TEMP" of=efi.img conv=notrunc > /dev/null 2>&1
    debug "efi.img created successfully"
else
    debug "efi.img found, skipping creation..."
fi

# Download EFI vars firmware if needed
if [ ! -f varstore.img ]; then
    info "EFI vars image not found, creating one..."

    VARS_URL="https://retrage.github.io/edk2-nightly/bin/RELEASEAARCH64_QEMU_VARS.fd"
    VARS_TEMP="/tmp/RELEASEAARCH64_QEMU_VARS.fd"

    debug "Downloading EFI vars firmware from $VARS_URL..."
    if ! curl -fsSL -o "$VARS_TEMP" "$VARS_URL"; then
        error "Failed to download EFI vars firmware from $VARS_URL. Please check your internet connection."
        exit 1
    fi
    debug "EFI vars firmware downloaded successfully"

    debug "Creating varstore.img..."
    truncate -s 64m varstore.img
    dd if="$VARS_TEMP" of=varstore.img conv=notrunc > /dev/null 2>&1
    debug "varstore.img created successfully"
else
    debug "varstore.img found, skipping creation..."
fi

# Handle ISO based on distribution
ISO_PATH=""

if [ "${DISTRIBUTION}" = "nixos" ]; then
    # NixOS uses pre-built ISO from Nix store
    ISO_PATH="$PREFIX/share/nixos.iso"
    if [ ! -f "$ISO_PATH" ]; then
        error "NixOS ISO not found at $ISO_PATH"
        exit 1
    fi
    debug "Using NixOS ISO from Nix store: $ISO_PATH"
else
    # For other distributions, fetch ISO at runtime using configuration from iso-sources.json
    ISO_CONFIG_FILE="$PREFIX/share/iso-sources.json"

    if [ ! -f "$ISO_CONFIG_FILE" ]; then
        error "ISO sources configuration file not found at $ISO_CONFIG_FILE"
        exit 1
    fi

    # Look up distribution in JSON configuration
    ISO_ENTRY=$(jq -r ".\"${DISTRIBUTION}\"" "$ISO_CONFIG_FILE" 2>/dev/null)

    if [ "$ISO_ENTRY" = "null" ] || [ -z "$ISO_ENTRY" ]; then
        error "Distribution '${DISTRIBUTION}' not found in ISO sources configuration"
        error "Available distributions: $(jq -r 'keys | join(", ")' "$ISO_CONFIG_FILE")"
        exit 1
    fi

    # Extract ISO metadata from JSON
    ISO_FILENAME=$(echo "$ISO_ENTRY" | jq -r '.filename')
    ISO_URL=$(echo "$ISO_ENTRY" | jq -r '.url')

    if [ -z "$ISO_FILENAME" ] || [ -z "$ISO_URL" ]; then
        error "Invalid ISO configuration for distribution '${DISTRIBUTION}'"
        exit 1
    fi

    ISO_PATH="$ISO_FILENAME"

    if [ ! -f "$ISO_PATH" ]; then
        info "ISO not found, downloading ${DISTRIBUTION}..."
        debug "Downloading from: $ISO_URL"

        # Use aria2c with multiple connections for faster downloads
        # -x 16: max 16 connections per server
        # -k 1M: minimum split size of 1MB
        # -s 16: max 16 simultaneous connections
        # --allow-overwrite=true: allow overwriting existing files
        # --auto-file-renaming=false: don't rename files
        if ! aria2c -x 16 -k 1M -s 16 --allow-overwrite=true --auto-file-renaming=false "$ISO_URL"; then
            error "Failed to download ISO from $ISO_URL. Please check your internet connection."
            rm -f "$ISO_PATH"
            exit 1
        fi
        info "ISO downloaded successfully: $ISO_PATH"
    else
        debug "ISO found, skipping download: $ISO_PATH"
    fi
fi

# Create disk image if needed
if [ ! -f disk.qcow2 ]; then
    info "Disk image not found, creating one ($DISK_SIZE)..."
    debug "Creating disk.qcow2 ($DISK_SIZE)..."
    qemu-img create -f qcow2 disk.qcow2 "$DISK_SIZE"
    debug "disk.qcow2 created successfully"
else
    debug "disk.qcow2 found, skipping creation..."
fi

# shellcheck disable=SC2054
args=(
    -nodefaults
    -M virt,accel=hvf,highmem=on
    --cpu max
    -smp "$CORES",cores="$CORES",threads=1,sockets=1
    -m "${RAM}G"
    -rtc base=utc,clock=host
    -device qemu-xhci,id=usb-bus
    -device usb-kbd,bus=usb-bus.0
    -device virtio-rng-pci
    -device virtio-balloon-pci
    -drive if=pflash,format=raw,file=efi.img,readonly=on
    -drive if=pflash,format=raw,file=varstore.img
    -drive if=virtio,format=qcow2,file=disk.qcow2
    -cdrom "$ISO_PATH"
)

if [ "$GRAPHICS" -eq 1 ]; then
    info "Enabling graphics and qemu-vdagent support..."
    # shellcheck disable=SC2054
    args+=(
        -device usb-tablet,bus=usb-bus.0
        -device virtio-gpu-pci
        -display cocoa,show-cursor=on
        -device virtio-serial,packed=on,ioeventfd=on
        -device virtserialport,name=com.redhat.spice.0,chardev=vdagent0
        -chardev qemu-vdagent,id=vdagent0,name=vdagent,clipboard=on,mouse=on
    )
else
    warn "Disabling graphics..."
    warn "To exit, press Ctrl + A, then X"
    sleep 3
    # shellcheck disable=SC2054
    args+=(
        -nographic
    )
fi

if [ "$AUDIO" -eq 1 ]; then
    info "Enabling audio support (CoreAudio)..."
    # shellcheck disable=SC2054
    args+=(
        -device intel-hda
        -device hda-output,audiodev=audiodev
        -audiodev driver=coreaudio,id=audiodev
    )
else
    warn "Running without audio support..."
fi

if [ "$NETWORK" -eq 1 ]; then
    info "Enabling network support..."
    # shellcheck disable=SC2054
    args+=(
        -device virtio-net-pci,netdev=net0
        -netdev user,id=net0
    )
else
    warn "Running without network support..."
fi

if [ "$SNAPSHOT" -eq 1 ]; then
    info "Running in snapshot mode (disk changes will not be saved)..."
    args+=(-snapshot)
fi

info "QEMU command: qemu-system-aarch64 ${args[*]} $*"

qemu-system-aarch64 "${args[@]}" "$@"

if [ "$COMPRESS" -eq 1 ]; then
    gum spin --title "Compressing disk image (this may take a while)..." -- \
    qemu-img convert -O qcow2 -c disk.qcow2 disk.qcow2-compressed
    rm disk.qcow2
    mv disk.qcow2-compressed disk.qcow2 
fi

