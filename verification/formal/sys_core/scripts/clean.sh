#!/usr/bin/env bash
set -euo pipefail
S="$(cd "$(dirname "${BASH_SOURCE[0]}")"&&pwd)";F="$(cd "$S/.."&&pwd)";R="$(cd "$F/../../.."&&pwd)";rm -rf "$R/build/formal/sys_core";mkdir -p "$R/build/formal/sys_core/prove" "$R/build/formal/sys_core/cover"

