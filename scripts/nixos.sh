#!/usr/bin/env bash

set -eo pipefail

PREFIX=@@prefix@@

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

info() {
    gum log --structured --level info "$1"
}

warn() {
    gum log --structured --level warn "$1"
}

if [[ "$*" == *"-h"* ]] || [[ "$*" == *"--help"* ]]; then
    echo "Usage: <environment> nix run \"github:matteo-pacini/darwinix#nixos\" -- [extra qemu options]"
    echo
    echo "Environment variables:"
    echo "  CORES: number of cores to use (default: $_CORES)"
    echo "  RAM: amount of RAM to use in GB (default: $_RAM)"
    echo "  GRAPHICS: enable graphics support (default: 1)"
    echo "  AUDIO: enable audio support (default: 1)"
    echo "  NETWORK: enable network support (default: 1)"
    echo "  COMPRESS: compress disk image after shutdown (default: 1)"
    exit 0
fi

clear

info "Starting NixOS VM..."
info "Using $CORES cores and $RAM GB of RAM"

sleep 1

if [ ! -f efi.img ]; then
    gum spin --title "EFI image not found, creating one..." -- \
    sleep 1 && \
    truncate -s 64m efi.img && \
    dd if=$PREFIX/share/RELEASEAARCH64_QEMU_EFI.fd of=efi.img conv=notrunc > /dev/null 2>&1
else 
    info "efi.img found, skipping creation..."
fi

if [ ! -f varstore.img ]; then
    gum spin --title "EFI vars image not found, creating one..." -- \
    sleep 1 && \
    truncate -s 64m varstore.img
else
    info "varstore.img found, skipping creation..."
fi

if [ ! -f disk.qcow2 ]; then
    gum spin --title "Disk image not found, creating one..." -- \
    qemu-img create -f qcow2 disk.qcow2 512G
else
    info "disk.qcow2 found, skipping creation..."
fi

# shellcheck disable=SC2054
args=(
    -M virt,accel=hvf,highmem=on
    --cpu max
    -smp "$CORES",cores="$CORES",threads=1,sockets=1
    -m "${RAM}G"
    -device qemu-xhci,id=usb-bus
    -device usb-tablet,bus=usb-bus.0
    -device usb-mouse,bus=usb-bus.0
    -device usb-kbd,bus=usb-bus.0
    -device virtio-rng-pci
    -device virtio-balloon-pci
    -drive if=pflash,format=raw,file=efi.img,readonly=on
    -drive if=pflash,format=raw,file=varstore.img
    -drive if=virtio,format=qcow2,file=disk.qcow2
    -cdrom "$PREFIX/share/nixos.iso"
)

if [ "$GRAPHICS" -eq 1 ]; then
    info "Enabling graphics and qemu-vdagent support..."
    # shellcheck disable=SC2054
    args+=(
        -device virtio-gpu-pci
        -display cocoa,show-cursor=on
        -device virtio-serial,packed=on,ioeventfd=on
        -device virtserialport,name=com.redhat.spice.0,chardev=vdagent0
        -chardev qemu-vdagent,id=vdagent0,name=vdagent,clipboard=on,mouse=off
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

qemu-system-aarch64 "${args[@]}" "$@"

if [ "$COMPRESS" -eq 1 ]; then
    gum spin --title "Compressing disk image (this may take a while)..." -- \
    qemu-img convert -O qcow2 -c disk.qcow2 disk.qcow2-compressed
    rm disk.qcow2
    mv disk.qcow2-compressed disk.qcow2 
fi
