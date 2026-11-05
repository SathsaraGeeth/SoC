#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FLOW_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
REPO_ROOT="$(cd "$FLOW_DIR/../../.." && pwd)"
cd "$FLOW_DIR"
exec "${SBY:-sby}" -d "$REPO_ROOT/build/formal/$(basename "$FLOW_DIR")/prove/full" -f prove/full.sby

