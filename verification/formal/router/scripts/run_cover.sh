#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FLOW_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
REPO_ROOT="$(cd "$FLOW_DIR/../../.." && pwd)"
BUILD_DIR="$REPO_ROOT/build/formal/$(basename "$FLOW_DIR")"

DMCTP_BUILD_DIR="$BUILD_DIR" \
    python3 "$REPO_ROOT/verification/uvm/isa/scripts/prepare_rtl.py"
cd "$FLOW_DIR"
exec "${SBY:-sby}" -d "$BUILD_DIR/cover/full" -f cover/full.sby
