#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
cd "$ROOT"

TARGET="${1:-chip}"
FILELIST="verification/lint/filelists/${TARGET}.f"
OUTDIR="build/lint/verible/${TARGET}"

mkdir -p "$OUTDIR"

FILES="$(
    grep -vE '^[[:space:]]*(#|\+|-f|$)' "$FILELIST"
)"

verible-verilog-lint \
    --rules_config_search \
    --waiver_files=verification/lint/verible/waive.conf \
    $FILES \
    2>&1 | tee "$OUTDIR/lint.log"