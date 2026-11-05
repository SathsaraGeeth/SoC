#!/usr/bin/env bash
set -euo pipefail

target="${1:-soc}"
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
out="${root}/build/rdc/${target}"
filelist="verification/rdc/filelists/${target}.f"

cd "${root}"
test -f "${filelist}" || { echo "Unknown RDC target: ${target}" >&2; exit 2; }
mkdir -p "${out}"
python3 verification/rdc/scripts/discover_resets.py "${filelist}" \
  "build/rdc/${target}/resets.json"
python3 verification/rdc/scripts/check_reset_sync.py "${out}/resets.json" \
  | tee "${out}/reset_sync.rpt"
if command -v yosys >/dev/null 2>&1; then
  yosys -ql "${out}/yosys_reset_sync.rpt" -p \
    "read_verilog -sv rtl/common/reset/reset_sync.sv; hierarchy -top reset_sync; proc; check; stat"
else
  echo "Yosys not installed; reset synchronizer report skipped." \
    | tee "${out}/yosys_reset_sync.rpt"
fi
echo "RDC development reports: ${out}"
