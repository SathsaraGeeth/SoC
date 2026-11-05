#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

TARGET="${1:-core}"
TOOL="${2:-all}"

echo "=========================================="
echo " Running lint for block: $TARGET, tool: $TOOL"
echo "=========================================="

case "$TOOL" in
    slang)
        verification/lint/slang/run.sh "$TARGET"
        ;;
    verilator)
        verification/lint/verilator/run.sh "$TARGET"
        ;;
    verible)
        verification/lint/verible/run.sh "$TARGET"
        ;;
    yosys)
        verification/lint/yosys/run.sh "$TARGET"
        ;;
    all)
        verification/lint/slang/run.sh "$TARGET"
        verification/lint/verilator/run.sh "$TARGET"
        verification/lint/verible/run.sh "$TARGET"
        verification/lint/yosys/run.sh "$TARGET"
        ;;
    *)
        echo "Unknown tool: $TOOL"
        echo "Usage: $0 <target> <tool: slang|verilator|verible|yosys|all>"
        exit 1
        ;;
esac

echo ""
echo "Completed: block=$TARGET, tool=$TOOL"