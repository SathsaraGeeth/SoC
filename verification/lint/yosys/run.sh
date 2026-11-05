#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
cd "$ROOT"

TARGET="${1:-chip}"
OUTDIR="build/lint/yosys/${TARGET}"

# Try target-specific script first, then fall back to blocks/
if [ -f "verification/lint/yosys/${TARGET}.ys" ]; then
    SCRIPT="verification/lint/yosys/${TARGET}.ys"
elif [ -f "verification/lint/yosys/blocks/${TARGET}.ys" ]; then
    SCRIPT="verification/lint/yosys/blocks/${TARGET}.ys"
else
    echo "ERROR: No Yosys script found for target '${TARGET}'"
    echo "  Tried: verification/lint/yosys/${TARGET}.ys"
    echo "  Tried: verification/lint/yosys/blocks/${TARGET}.ys"
    exit 1
fi

mkdir -p "$OUTDIR"

yosys \
    -s "$SCRIPT" \
    2>&1 | tee "$OUTDIR/lint.log"
