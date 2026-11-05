#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
cd "$ROOT"

TARGET="${1:-chip}"
FILELIST="verification/lint/filelists/${TARGET}.f"
ARGS="verification/lint/slang/common.args"
OUTDIR="build/lint/slang/${TARGET}"

mkdir -p "$OUTDIR"

slang \
    -f "$FILELIST" \
    $(cat "$ARGS") \
    2>&1 | tee "$OUTDIR/lint.log"