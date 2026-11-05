#!/usr/bin/env bash
set -euo pipefail

FLOW_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
"$FLOW_DIR/scripts/run_prove.sh"
"$FLOW_DIR/scripts/run_cover.sh"
