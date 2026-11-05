#!/usr/bin/env bash
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ROOT="$(cd "$HERE/../../.." && pwd)"
target="$ROOT/build/formal/sys_common"
if [[ -d "$target" ]]; then find "$target" -mindepth 1 -maxdepth 1 -exec rm -rf -- {} +; fi

