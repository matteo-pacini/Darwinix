#!/usr/bin/env bash

# Refresh the rolling entries in iso-sources.json:
# - nixos-*, opensuse-tumbleweed: URLs are stable but their content moves;
#   refresh sha256
# - gentoo, debian, alpine: old releases rotate off the mirrors; resolve the
#   latest release and refresh url, filename and sha256 together
# Pinned entries (Ubuntu, Fedora) are left untouched.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ISO_SOURCES_FILE="$SCRIPT_DIR/iso-sources.json"

die() {
    echo "Error: $1" >&2
    exit 1
}

command -v jq >/dev/null 2>&1 || die "jq is required but not installed"
command -v curl >/dev/null 2>&1 || die "curl is required but not installed"
[ -f "$ISO_SOURCES_FILE" ] || die "iso-sources.json not found at $ISO_SOURCES_FILE"

require_sha256() {
    [[ "$1" =~ ^[0-9a-f]{64}$ ]] || die "$2: expected a sha256 hash, got '$1'"
}

update_entry() {
    jq --arg key "$1" --arg url "$2" --arg file "$3" --arg sha "$4" \
        '.[$key].url = $url | .[$key].filename = $file | .[$key].sha256 = $sha' \
        "$ISO_SOURCES_FILE" > "$ISO_SOURCES_FILE.tmp"
    mv "$ISO_SOURCES_FILE.tmp" "$ISO_SOURCES_FILE"
}

# --- nixos channels (entry-key:channel-name) ---
for entry in "nixos-26-05:nixos-26.05" "nixos-unstable:nixos-unstable"; do
    key=${entry%%:*}
    channel=${entry#*:}
    sha_url="https://channels.nixos.org/$channel/latest-nixos-minimal-aarch64-linux.iso.sha256"
    sha=$(curl -fsSL "$sha_url" | awk '{print $1; exit}')
    require_sha256 "$sha" "$key"
    echo "$key: sha256 $sha"
    jq --arg key "$key" --arg sha "$sha" '.[$key].sha256 = $sha' \
        "$ISO_SOURCES_FILE" > "$ISO_SOURCES_FILE.tmp"
    mv "$ISO_SOURCES_FILE.tmp" "$ISO_SOURCES_FILE"
done

# --- gentoo ---
GENTOO_BASE="https://distfiles.gentoo.org/releases/arm64/autobuilds"
# latest-*.txt is PGP-clearsigned; the payload line is "<path>/<file>.iso <size>"
GENTOO_PATH=$(curl -fsSL "$GENTOO_BASE/latest-install-arm64-minimal.txt" \
    | grep -Eo '^[0-9TZ]+/install-arm64-minimal-[0-9TZ]+\.iso' | head -1)
[ -n "$GENTOO_PATH" ] || die "gentoo: could not parse latest-install-arm64-minimal.txt"

GENTOO_URL="$GENTOO_BASE/$GENTOO_PATH"
GENTOO_FILENAME=$(basename "$GENTOO_PATH")
GENTOO_SHA=$(curl -fsSL "$GENTOO_URL.sha256" \
    | grep -E "^[0-9a-f]{64}[[:space:]]+$GENTOO_FILENAME\$" | awk '{print $1; exit}')
require_sha256 "$GENTOO_SHA" "gentoo"
echo "gentoo: $GENTOO_FILENAME sha256 $GENTOO_SHA"

update_entry "gentoo" "$GENTOO_URL" "$GENTOO_FILENAME" "$GENTOO_SHA"

# --- debian (current point release; old ISOs rotate off the mirror) ---
DEBIAN_BASE="https://cdimage.debian.org/debian-cd/current/arm64/iso-cd"
DEBIAN_LINE=$(curl -fsSL "$DEBIAN_BASE/SHA256SUMS" \
    | grep -E 'debian-[0-9.]+-arm64-netinst\.iso$' | head -1)
DEBIAN_SHA=$(echo "$DEBIAN_LINE" | awk '{print $1}')
DEBIAN_FILENAME=$(echo "$DEBIAN_LINE" | awk '{print $2}')
require_sha256 "$DEBIAN_SHA" "debian"
[ -n "$DEBIAN_FILENAME" ] || die "debian: could not parse SHA256SUMS"
echo "debian: $DEBIAN_FILENAME sha256 $DEBIAN_SHA"
update_entry "debian" "$DEBIAN_BASE/$DEBIAN_FILENAME" "$DEBIAN_FILENAME" "$DEBIAN_SHA"

# --- opensuse-tumbleweed (stable Current URL, rolling content) ---
TW_URL="https://download.opensuse.org/ports/aarch64/tumbleweed/iso/openSUSE-Tumbleweed-DVD-aarch64-Current.iso"
TW_SHA=$(curl -fsSL "$TW_URL.sha256" | awk '{print $1; exit}')
require_sha256 "$TW_SHA" "opensuse-tumbleweed"
echo "opensuse-tumbleweed: sha256 $TW_SHA"
jq --arg sha "$TW_SHA" '."opensuse-tumbleweed".sha256 = $sha' \
    "$ISO_SOURCES_FILE" > "$ISO_SOURCES_FILE.tmp"
mv "$ISO_SOURCES_FILE.tmp" "$ISO_SOURCES_FILE"

# --- alpine (latest-stable, virt flavor) ---
ALPINE_BASE="https://dl-cdn.alpinelinux.org/alpine/latest-stable/releases/aarch64"
ALPINE_YAML=$(curl -fsSL "$ALPINE_BASE/latest-releases.yaml" | grep -A 8 'flavor: alpine-virt')
ALPINE_FILENAME=$(echo "$ALPINE_YAML" | awk '/file:/ {print $2; exit}')
ALPINE_SHA=$(echo "$ALPINE_YAML" | awk '/sha256:/ {print $2; exit}')
require_sha256 "$ALPINE_SHA" "alpine"
[ -n "$ALPINE_FILENAME" ] || die "alpine: could not parse latest-releases.yaml"
echo "alpine: $ALPINE_FILENAME sha256 $ALPINE_SHA"
update_entry "alpine" "$ALPINE_BASE/$ALPINE_FILENAME" "$ALPINE_FILENAME" "$ALPINE_SHA"

echo "iso-sources.json updated"
