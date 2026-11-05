#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FLOW_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
REPO_ROOT="$(cd "$FLOW_DIR/../../.." && pwd)"
BUILD_DIR="$REPO_ROOT/build/uvm/$(basename "$FLOW_DIR")"

cd "$FLOW_DIR"

mkdir -p "$BUILD_DIR/logs" "$BUILD_DIR/tools" "$BUILD_DIR/images"
mkdir -p "$BUILD_DIR/generated"
LOG_TIME=$(date +%Y%m%d_%H%M%S)
exec > >(tee -i "$BUILD_DIR/logs/random_${LOG_TIME}.log") 2>&1

echo "Generating and compiling an RV64 random ISA program..."
python3 "$REPO_ROOT/rtl/isa/isa_gen.py"
make -C tests/random clean all SEED="${ISA_RANDOM_SEED:-1}"

echo "Creating the flat memory image..."
g++ -O3 -Wall -std=c++17 ../../simulator/tools/elf2bin.cpp \
    -o "$BUILD_DIR/tools/elf2bin"
"$BUILD_DIR/tools/elf2bin" tests/random/boot_rom.elf "$BUILD_DIR/images/random.bin"

DMCTP_BUILD_DIR="$BUILD_DIR" python3 scripts/prepare_rtl.py

awk -v prefix="$FLOW_DIR/" -v generated="$BUILD_DIR/generated/" '
  /^[ \t]*#/ || /^$/ { print; next }
  /^build\/generated\// { sub(/^build\/generated\//, generated); print; next }
  /^\+incdir\+/ { sub(/^\+incdir\+/, ""); print "+incdir+" prefix $0; next }
  { print prefix $0 }
' filelist.f > "$BUILD_DIR/tools/filelist_abs.f"

cd "$BUILD_DIR/tools"
export LD_LIBRARY_PATH="${HOME}/AltairDSim/2026/llvm_small/lib:${LD_LIBRARY_PATH:-}"
DEFAULT_DSIM_LICENSE="${HOME}/metrics-ca/dsim-license.json"
if [[ -n "${DSIM_LICENSE:-}" && ! -f "${DSIM_LICENSE}" ]]; then
    if [[ -f "${DEFAULT_DSIM_LICENSE}" ]]; then
        echo "Warning: DSIM_LICENSE does not exist: ${DSIM_LICENSE}"
        echo "Using ${DEFAULT_DSIM_LICENSE}"
        export DSIM_LICENSE="${DEFAULT_DSIM_LICENSE}"
    else
        echo "Error: DSIM_LICENSE does not exist: ${DSIM_LICENSE}" >&2
        exit 1
    fi
elif [[ -z "${DSIM_LICENSE:-}" && -f "${DEFAULT_DSIM_LICENSE}" ]]; then
    export DSIM_LICENSE="${DEFAULT_DSIM_LICENSE}"
fi

echo "Compiling and running the isolated core..."
DSIM_LOG="$BUILD_DIR/tools/dsim.log"
set +e
dsim -f filelist_abs.f \
    -top tb_top \
    -c-opts "-I${REPO_ROOT}/rtl/isa -I${FLOW_DIR}/models/iss/include -I${FLOW_DIR}/models/iss/src/include" \
    "+incdir+${HOME}/AltairDSim/2026/uvm/1.2/src" \
    -uvm 1.2 -sv \
    -suppress DefNetNone \
    -suppress MissingTimescale \
    -cov-db metrics.db \
    +UVM_TESTNAME=random_test \
    +UVM_VERBOSITY=UVM_NONE \
    +UVM_NO_RELNOTES \
    +ISA_BIN="$BUILD_DIR/images/random.bin" 2>&1 | tee "$DSIM_LOG"
DSIM_STATUS=${PIPESTATUS[0]}
set -e

if (( DSIM_STATUS != 0 )); then
    exit "$DSIM_STATUS"
fi

if grep -Eq '^=[FE]:|^UVM_(FATAL|ERROR)' "$DSIM_LOG"; then
    echo "Error: DSim reported an error despite returning success." >&2
    exit 1
fi
