#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")"&&pwd)";FLOW_DIR="$(cd "$SCRIPT_DIR/.."&&pwd)";REPO_ROOT="$(cd "$FLOW_DIR/../../.."&&pwd)";BUILD_DIR="$REPO_ROOT/build/formal/$(basename "$FLOW_DIR")";rm -rf "$BUILD_DIR";mkdir -p "$BUILD_DIR/prove" "$BUILD_DIR/cover" "$BUILD_DIR/generated"
