#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FLOW_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"; REPO_ROOT="$(cd "$FLOW_DIR/../../.." && pwd)"
DMCTP_BUILD_DIR="$REPO_ROOT/build/formal/memory" DMCTP_FORMAL_MEMORY=1 python3 "$REPO_ROOT/verification/uvm/isa/scripts/prepare_rtl.py"
cd "$FLOW_DIR"; exec "${SBY:-sby}" -d "$REPO_ROOT/build/formal/memory/prove/full" -f prove/full.sby
