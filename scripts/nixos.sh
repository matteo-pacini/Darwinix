#!/usr/bin/env bash

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

info() {
    gum log --structured --level info "$1"
}

warn() {
    gum log --structured --level warn "$1"
}

clear

info "Starting NixOS VM..."
info "Using $CORES cores and $RAM GB of RAM"

sleep 1

if [ ! -f efi.img ]; then
    warn "efi.img not found, creating one..."
    truncate -s 64m efi.img
    dd if=$PREFIX/share/RELEASEAARCH64_QEMU_EFI.fd of=efi.img conv=notrunc
else 
    info "efi.img found, skipping creation..."
fi

if [ ! -f varstore.img ]; then
    warn "varstore.img not found, creating one..."
    truncate -s 64m varstore.img
else
    info "varstore.img found, skipping creation..."
fi

if [ ! -f disk.qcow2 ]; then
    warn "disk.qcow2 not found, creating one..."
    qemu-img create -f qcow2 disk.qcow2 512G
else
    info "disk.qcow2 found, skipping creation..."
fi

qemu-system-aarch64 -M virt,accel=hvf,highmem=on \
                    --cpu max \
                    -smp "$CORES",cores="$CORES",threads=1,sockets=1 \
                    -m "${RAM}G" \
                    -device virtio-gpu-pci \
                    -display cocoa,show-cursor=on \
                    -device virtio-net-pci,netdev=net0 \
                    -netdev user,id=net0 \
                    -device qemu-xhci,id=usb-bus \
                    -device usb-tablet,bus=usb-bus.0 \
                    -device usb-mouse,bus=usb-bus.0 \
                    -device usb-kbd,bus=usb-bus.0 \
                    -device virtio-rng-pci \
                    -device virtio-balloon-pci \
                    -device intel-hda \
                    -device hda-output,audiodev=audiodev \
                    -audiodev driver=coreaudio,id=audiodev \
                    -device virtio-serial,packed=on,ioeventfd=on \
                    -device virtserialport,name=com.redhat.spice.0,chardev=vdagent0 \
                    -chardev qemu-vdagent,id=vdagent0,name=vdagent,clipboard=on,mouse=off \
                    -drive if=pflash,format=raw,file=efi.img,readonly=on \
                    -drive if=pflash,format=raw,file=varstore.img \
                    -drive if=virtio,format=qcow2,file=disk.qcow2 \
                    -cdrom "$PREFIX/share/nixos.iso" \
                    "$@"