#!/usr/bin/env bash
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ROOT="$(cd "$HERE/../../.." && pwd)"
DMCTP_FORMAL_OUTPUT="$ROOT/build/formal/sys_common/generated" \
    python3 "$HERE/scripts/prepare_rtl.py"
sby -f -d "$ROOT/build/formal/sys_common/cover/full" "$HERE/cover/full.sby"
