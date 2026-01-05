#!/usr/bin/env bash
#
# Dry-Run Test Runner for Codec Build Scripts
#
# Validates all codec scripts by running them in dry-run mode.
# This catches missing variables and argument errors before expensive builds.
#
# Usage:
#   ./build/dry-run.sh           # Test all codecs
#   ./build/dry-run.sh x264      # Test specific codec
#   ./build/dry-run.sh --list    # List available codecs
#   ./build/dry-run.sh -v        # Verbose mode (show validation output)
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
CODECS_DIR="$SCRIPT_DIR/codecs"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

VERBOSE=0

# Load all versions from versions.properties
load_versions() {
    local versions_file="$PROJECT_ROOT/versions.properties"
    if [[ ! -f "$versions_file" ]]; then
        echo "ERROR: versions.properties not found at $versions_file"
        exit 1
    fi

    while IFS='=' read -r key value; do
        # Skip comments and empty lines
        [[ "$key" =~ ^#.*$ || -z "$key" ]] && continue
        # Trim whitespace
        key="$(echo "$key" | xargs)"
        value="$(echo "$value" | xargs)"
        export "$key=$value"
    done < "$versions_file"
}

# List available codecs
list_codecs() {
    echo "Available codec scripts:"
    for script in "$CODECS_DIR"/*.sh; do
        [[ "$(basename "$script")" == "common.sh" ]] && continue
        echo "  $(basename "$script" .sh)"
    done
}

# Run dry-run for a single codec
test_codec() {
    local name="$1"
    local script="$CODECS_DIR/${name}.sh"

    if [[ ! -f "$script" ]]; then
        echo -e "${RED}FAIL${NC}: $name - script not found"
        return 1
    fi

    echo -n "Testing $name... "

    # Run script with dry-run mode
    if output=$(bash "$script" 2>&1); then
        echo -e "${GREEN}PASS${NC}"
        if [[ "$VERBOSE" == "1" ]]; then
            echo "$output" | sed 's/^/  /'
        fi
        return 0
    else
        echo -e "${RED}FAIL${NC}"
        echo "$output" | sed 's/^/  /'
        return 1
    fi
}

# Main
main() {
    # Parse options
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -v|--verbose)
                VERBOSE=1
                shift
                ;;
            --list)
                list_codecs
                exit 0
                ;;
            -*)
                echo "Unknown option: $1"
                exit 1
                ;;
            *)
                break
                ;;
        esac
    done

    echo "=========================================="
    echo "Codec Build Scripts - Dry Run Validation"
    echo "=========================================="
    echo ""

    # Load versions
    echo "Loading versions.properties..."
    load_versions
    echo ""

    # Set dry-run mode
    export DRY_RUN=1
    export PREFIX=/build
    export WORK_DIR=/tmp/codec-dry-run

    local passed=0
    local failed=0
    local failed_codecs=()

    # Test specific codec or all
    if [[ -n "${1:-}" ]]; then
        if test_codec "$1"; then
            passed=1
        else
            failed=1
            failed_codecs+=("$1")
        fi
    else
        # Test all codecs
        for script in "$CODECS_DIR"/*.sh; do
            [[ "$(basename "$script")" == "common.sh" ]] && continue

            local name
            name=$(basename "$script" .sh)

            if test_codec "$name"; then
                passed=$((passed + 1))
            else
                failed=$((failed + 1))
                failed_codecs+=("$name")
            fi
        done
    fi

    echo ""
    echo "=========================================="
    echo "Results"
    echo "=========================================="
    echo -e "Passed: ${GREEN}$passed${NC}"
    echo -e "Failed: ${RED}$failed${NC}"

    if [[ $failed -gt 0 ]]; then
        echo ""
        echo "Failed codecs:"
        for codec in "${failed_codecs[@]}"; do
            echo "  - $codec"
        done
        exit 1
    fi

    echo ""
    echo "All codec scripts validated successfully!"
}

main "$@"
