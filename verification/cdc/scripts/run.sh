#!/usr/bin/env bash
set -euo pipefail

target="${1:-soc}"
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
out="${root}/build/cdc/${target}"
filelist="verification/cdc/filelists/${target}.f"

cd "${root}"
test -f "${filelist}" || { echo "Unknown CDC target: ${target}" >&2; exit 2; }
mkdir -p "${out}"
python3 verification/cdc/scripts/discover_domains.py "${filelist}" \
  --output "${out}/domains.rpt"
python3 verification/cdc/scripts/discover_domains.py "${filelist}" --json \
  --output "${out}/domains.json"
python3 verification/cdc/scripts/check_sync_cells.py | tee "${out}/sync_cells.rpt"
if command -v yosys >/dev/null 2>&1; then
  yosys -ql "${out}/yosys_primitives.rpt" -p \
    "read_verilog -sv rtl/common/cdc/cdc_bit_sync.sv rtl/common/cdc/cdc_gray_sync.sv rtl/common/cdc/cdc_pulse_sync.sv rtl/common/cdc/cdc_handshake.sv rtl/common/cdc/async_fifo.sv rtl/common/reset/reset_sync.sv; hierarchy -check; stat"
else
  echo "Yosys not installed; primitive synthesis report skipped." \
    | tee "${out}/yosys_primitives.rpt"
fi
echo "CDC development reports: ${out}"
