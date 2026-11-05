#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
cd "$ROOT"

TARGET="${1:-chip}"
TOP="${2:-soc}"

FILELIST="verification/lint/filelists/${TARGET}.f"
OUTDIR="build/lint/verilator/${TARGET}"

mkdir -p "$OUTDIR"

verilator \
    --lint-only \
    --sv \
    --Wall \
    --top-module "$TOP" \
    -f "$FILELIST" \
    -Wno-fatal \
    2>&1 | tee "$OUTDIR/lint.log"