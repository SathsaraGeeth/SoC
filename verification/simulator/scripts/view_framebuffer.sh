#!/usr/bin/env bash
set -eu
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR/../../.."
port="${1:-8088}"
echo "Framebuffer viewer: open the code-server forwarded port ${port}"
exec python3 -m http.server "$port" --bind 127.0.0.1
