#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FLOW_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
REPO_ROOT="$(cd "$FLOW_DIR/../../.." && pwd)"
BUILD_ROOT="$REPO_ROOT/build/formal/$(basename "$FLOW_DIR")"
OUTDIR="$BUILD_ROOT/prove/full"

DMCTP_BUILD_DIR="$BUILD_ROOT" python3 "$REPO_ROOT/verification/uvm/isa/scripts/prepare_rtl.py"
cd "$FLOW_DIR"
exec "${SBY:-sby}" -d "$OUTDIR" -f prove/full.sby

