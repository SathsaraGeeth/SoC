#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FLOW_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"; REPO_ROOT="$(cd "$FLOW_DIR/../../.." && pwd)"
rm -rf "$REPO_ROOT/build/formal/memory"
mkdir -p "$REPO_ROOT/build/formal/memory/prove" "$REPO_ROOT/build/formal/memory/cover"

