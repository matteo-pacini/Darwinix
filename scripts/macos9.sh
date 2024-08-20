#!/usr/bin/env bash

set -eo pipefail

_CORES=1
_RAM=1

CORES=${CORES:-$_CORES}
RAM=${RAM:-$_RAM}
GRAPHICS=${GRAPHICS:-1}
AUDIO=${AUDIO:-1}
NETWORK=${NETWORK:-1}
COMPRESS=${COMPRESS:-1}

info() {
    gum log --structured --level info "$1"
}

warn() {
    gum log --structured --level warn "$1"
}

if [[ "$*" == *"-h"* ]] || [[ "$*" == *"--help"* ]]; then
    echo "Usage: <environment> nix run \"github:matteo-pacini/darwinix#macos9\" -- [extra qemu options]"
    echo
    echo "Environment variables:"
    echo "  COMPRESS: compress disk image after shutdown (default: 1)"
    exit 0
fi

clear

info "Starting MacOS 9.2.2 VM..."
info "Using $CORES cores and $RAM GB of RAM"

sleep 1

if [ ! -f disk.qcow2 ]; then
    gum spin --title "Disk image not found, creating one..." -- \
    qemu-img create -f qcow2 disk.qcow2 2G
else
    info "disk.qcow2 found, skipping creation..."
fi

# shellcheck disable=SC2054
args=(
    -L pc-bios
    -M mac99
    -m "${RAM}G"
    -hda disk.qcow2
)

info "Enabling graphics..."
# shellcheck disable=SC2054
args+=(
    -device VGA,edid=on
    -display cocoa,show-cursor=on
)

qemu-system-ppc "${args[@]}" "$@"

if [ "$COMPRESS" -eq 1 ]; then
    gum spin --title "Compressing disk image (this may take a while)..." -- \
    qemu-img convert -O qcow2 -c disk.qcow2 disk.qcow2-compressed
    rm disk.qcow2
    mv disk.qcow2-compressed disk.qcow2 
fi
