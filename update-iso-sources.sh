#!/usr/bin/env bash

# Refresh the rolling entries in iso-sources.json:
# - nixos-*: channel URLs are stable but their content moves; refresh sha256
# - gentoo: autobuild snapshots disappear; resolve the latest build and
#   refresh url, filename and sha256 together
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

jq --arg gurl "$GENTOO_URL" \
   --arg gfile "$GENTOO_FILENAME" \
   --arg gsha "$GENTOO_SHA" \
   '.gentoo.url = $gurl
    | .gentoo.filename = $gfile
    | .gentoo.sha256 = $gsha' \
   "$ISO_SOURCES_FILE" > "$ISO_SOURCES_FILE.tmp"
mv "$ISO_SOURCES_FILE.tmp" "$ISO_SOURCES_FILE"

echo "iso-sources.json updated"
