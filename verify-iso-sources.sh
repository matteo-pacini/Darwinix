#!/usr/bin/env bash

# Verify that all ISO source URLs in iso-sources.json are still accessible
# Uses HTTP HEAD requests to check without downloading the files

set -eo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ISO_SOURCES_FILE="$SCRIPT_DIR/iso-sources.json"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

if [ ! -f "$ISO_SOURCES_FILE" ]; then
    echo -e "${RED}Error: iso-sources.json not found at $ISO_SOURCES_FILE${NC}"
    exit 1
fi

if ! command -v jq &> /dev/null; then
    echo -e "${RED}Error: jq is required but not installed${NC}"
    exit 1
fi

if ! command -v curl &> /dev/null; then
    echo -e "${RED}Error: curl is required but not installed${NC}"
    exit 1
fi

echo "Verifying ISO sources..."
echo

# Get all distribution names
distributions=$(jq -r 'keys[]' "$ISO_SOURCES_FILE")

failed=0
total=0

for distro in $distributions; do
    url=$(jq -r ".\"$distro\".url" "$ISO_SOURCES_FILE")
    total=$((total + 1))
    
    printf "Checking %-25s ... " "$distro"
    
    # Use HEAD request (-I) to check URL without downloading
    # -s: silent, -o /dev/null: discard output, -w: write out status code
    # -L: follow redirects, --connect-timeout: timeout for connection
    http_code=$(curl -s -o /dev/null -w "%{http_code}" -I -L --connect-timeout 10 "$url" 2>/dev/null || echo "000")
    
    if [ "$http_code" -ge 200 ] && [ "$http_code" -lt 400 ]; then
        echo -e "${GREEN}OK${NC} (HTTP $http_code)"
    elif [ "$http_code" = "000" ]; then
        echo -e "${RED}FAILED${NC} (Connection error)"
        failed=$((failed + 1))
    else
        echo -e "${RED}FAILED${NC} (HTTP $http_code)"
        failed=$((failed + 1))
    fi
done

echo
echo "---"
echo "Total: $total, Passed: $((total - failed)), Failed: $failed"

if [ "$failed" -gt 0 ]; then
    exit 1
fi

