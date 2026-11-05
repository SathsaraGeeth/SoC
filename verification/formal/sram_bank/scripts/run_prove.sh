#!/usr/bin/env bash
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ROOT="$(cd "$HERE/../../.." && pwd)"
sby -f -d "$ROOT/build/formal/sram_bank/prove/full" "$HERE/prove/full.sby"

