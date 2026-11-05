#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

TARGET="${1:-chip}"

echo "=========================================="
echo " Running all lint tools for target: $TARGET"
echo "=========================================="

echo ""
echo "--- Slang ---"
verification/lint/slang/run.sh "$TARGET"
echo "Slang completed."

echo ""
echo "--- Verilator ---"
verification/lint/verilator/run.sh "$TARGET"
echo "Verilator completed."

echo ""
echo "--- Verible ---"
verification/lint/verible/run.sh "$TARGET"
echo "Verible completed."

echo ""
echo "--- Yosys ---"
verification/lint/yosys/run.sh "$TARGET"
echo "Yosys completed."

echo ""
echo "=========================================="
echo " All lint tools completed for target: $TARGET"
echo "=========================================="