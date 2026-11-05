#!/usr/bin/env bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SIMULATOR_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
REPO_ROOT="$(cd "$SIMULATOR_DIR/../.." && pwd)"
BUILD_DIR="$REPO_ROOT/build/simulator"
EXPERIMENTAL_LLVM_BIN="$REPO_ROOT/compiler/llvm-project/build-experimental/bin"

cd "$SIMULATOR_DIR"

# Setup directories and automatic logging
mkdir -p "$BUILD_DIR/checkpoints"
mkdir -p "$BUILD_DIR/logs"
if [ -f checkpoint.vls ] && [ ! -f "$BUILD_DIR/checkpoints/checkpoint.vls" ]; then
    mv checkpoint.vls "$BUILD_DIR/checkpoints/checkpoint.vls"
fi
if [ -f "$BUILD_DIR/checkpoint.vls" ] && [ ! -f "$BUILD_DIR/checkpoints/checkpoint.vls" ]; then
    mv "$BUILD_DIR/checkpoint.vls" "$BUILD_DIR/checkpoints/checkpoint.vls"
fi
LOG_TIME=$(date +%Y%m%d_%H%M%S)
LOG_FILE="$BUILD_DIR/logs/log_${LOG_TIME}.log"
exec > >(tee -i "$LOG_FILE") 2>&1

# Default ELF path to kernel if not provided
ELF_PATH=""
SIM_ARGS=()
GRAPHICS=0
GRAPHICS_PORT=8088
GRAPHICS_PID=""
BUILD_ONLY=0

for arg in "$@"; do
    if [[ "$arg" == "--distributed" ]]; then
        : # The distributed soc_multi topology is the only supported topology.
    elif [[ "$arg" == "--graphics" ]]; then
        GRAPHICS=1
    elif [[ "$arg" == "--build-only" ]]; then
        BUILD_ONLY=1
    elif [[ "$arg" == -* || "$arg" == +* ]]; then
        SIM_ARGS+=("$arg")
    elif [[ -z "$ELF_PATH" ]]; then
        ELF_PATH="$arg"
    else
        SIM_ARGS+=("$arg")
    fi
done

cleanup_graphics() {
    if [[ -n "$GRAPHICS_PID" ]]; then
        kill "$GRAPHICS_PID" 2>/dev/null || true
        wait "$GRAPHICS_PID" 2>/dev/null || true
    fi
}

if [[ -z "$ELF_PATH" ]]; then
    ELF_PATH=$(realpath -m ../../kernel/build/boot_rom.elf)
fi
export ELF_PATH
export BL2_PATH=$(realpath -m ../../kernel/build/bl2.elf)
export BL2A_PATH=$(realpath -m ../../kernel/build/bl2A.elf)
export KERNEL_PATH=$(realpath -m ../../kernel/build/kernel.elf)

# Extract configuration dynamically from regressions/truth/soc.yaml and rtl/isa/isa.yaml.
(cd ../.. && ./regressions/truth/sync.sh)
# shellcheck disable=SC1091
source ../../regressions/truth/sim.env

# The simulator requires native DMCTP objects from the experimental backend.
# Force recompilation after syncing so neither a stable-backend object nor an
# object built for an older topology can be reused accidentally.
echo "Building kernel with the experimental DMCTP backend..."
make -B -C "$REPO_ROOT/kernel" -j"${KERNEL_JOBS:-$(nproc)}" \
    LLVM_BIN="$EXPERIMENTAL_LLVM_BIN"

CLOCK_FREQ_HZ=$(awk -F: '/^[[:space:]]*clock_freq_hz[[:space:]]*:/ { gsub(/[[:space:]]/, "", $2); print $2; exit }' ../../regressions/truth/soc.yaml)
REGION_SIZE=$(grep -oE 'REGION_SIZE\s+0x[0-9a-fA-F]+' ../../kernel/dmtcp/include/soc.h | awk '{print $2}')
FLASH_SIZE=$(grep -E '#define[[:space:]]+FLASH_SIZE' ../../kernel/dmtcp/include/soc.h | awk '{print $3}')
BL1_BASE=$(grep -E '#define[[:space:]]+BL1_BASE[[:space:]]+0x[0-9a-fA-F]+' ../../kernel/dmtcp/include/soc.h | awk '{print $3}')
BL1_SIZE=$(grep -E '#define[[:space:]]+BL1_SIZE[[:space:]]+0x[0-9a-fA-F]+' ../../kernel/dmtcp/include/soc.h | awk '{print $3}')
BL2_SIZE=$(grep -E '#define[[:space:]]+BL2_SIZE[[:space:]]+0x[0-9a-fA-F]+' ../../kernel/dmtcp/include/soc.h | awk '{print $3}')
BL2A_SIZE=$(grep -E '#define[[:space:]]+BL2A_SIZE[[:space:]]+0x[0-9a-fA-F]+' ../../kernel/dmtcp/include/soc.h | awk '{print $3}')
BL2_BASE_BA=$(grep -E '#define[[:space:]]+BL2_BASE_BA[[:space:]]+0x[0-9a-fA-F]+' ../../kernel/dmtcp/include/soc.h | awk '{print $3}')
FS_BASE_BA=$(grep -E '#define[[:space:]]+FS_BASE_BA[[:space:]]+0x[0-9a-fA-F]+' ../../kernel/dmtcp/include/soc.h | awk '{print $3}')

# Fallbacks if grep failed
if [ -z "$REGION_SIZE" ]; then
    REGION_SIZE="0x00200000"
fi
if [ -z "$FLASH_SIZE" ]; then
    FLASH_SIZE="0x01000000"
fi
if [ -z "$CLOCK_FREQ_HZ" ]; then
    CLOCK_FREQ_HZ="1000000000"
fi
if [ -z "$BL2_BASE_BA" ]; then
    BL2_BASE_BA="0x20010000"
fi
if [ -z "$BL2_SIZE" ]; then
    BL2_SIZE="0x00008000"
fi
if [ -z "$BL2A_SIZE" ]; then
    BL2A_SIZE="0x00008000"
fi
if [ -z "$BL1_BASE" ]; then
    BL1_BASE="0x00004000"
fi
if [ -z "$BL1_SIZE" ]; then
    BL1_SIZE="0x00008000"
fi
BL2A_BASE_BA=$(printf "0x%x" $((BL2_BASE_BA + BL2_SIZE)))
KERNEL_BASE_BA=$(printf "0x%x" $((BL2A_BASE_BA + BL2A_SIZE)))
if [ -z "$FS_BASE_BA" ]; then
    FS_BASE_BA="0x20098000"
fi

echo "Compiling utilities..."
mkdir -p "$BUILD_DIR/tools"
g++ -O3 -Wall -std=c++17 tools/elf2hex.cpp -o "$BUILD_DIR/tools/elf2hex"
g++ -O3 -Wall -std=c++17 tools/elf2bin.cpp -o "$BUILD_DIR/tools/elf2bin"
g++ -O3 -Wall -std=c++17 tools/hostd.cpp tools/hostd_main.cpp -o "$BUILD_DIR/tools/hostd" -pthread
g++ -O3 -Wall -std=c++17 tools/mkfs.cpp -o "$BUILD_DIR/tools/mkfs"

echo "Converting ELF to Hex..."
mkdir -p "$BUILD_DIR/boot_rom"
"$BUILD_DIR/tools/elf2hex" "$ELF_PATH" -o "$BUILD_DIR/boot_rom" --region-size "$REGION_SIZE" --num-banks "$NUM_BANKS"

if [ -f "$BL2_PATH" ]; then
    echo "Converting BL2 ELF to Bin for Block Storage..."
    mkdir -p "$BUILD_DIR/block_storage"
    "$BUILD_DIR/tools/elf2bin" "$BL2_PATH" "$BUILD_DIR/block_storage/bl2.bin"
fi

if [ -f "$BL2A_PATH" ]; then
    echo "Converting BL2A ELF to Bin for Block Storage..."
    mkdir -p "$BUILD_DIR/block_storage"
    "$BUILD_DIR/tools/elf2bin" "$BL2A_PATH" "$BUILD_DIR/block_storage/bl2A.bin"
fi

if [ -f "$KERNEL_PATH" ]; then
    echo "Converting Kernel ELF to Bin for Block Storage..."
    mkdir -p "$BUILD_DIR/block_storage"
    "$BUILD_DIR/tools/elf2bin" "$KERNEL_PATH" "$BUILD_DIR/block_storage/kernel.bin"
fi

echo "Building DMCTP user space applications..."
(cd ../../user && make -B dmctp DMCTP_MODE=experimental \
    DMCTP_LLVM_BIN="$EXPERIMENTAL_LLVM_BIN")

USER_ELFS=(../../user/bin/*.elf)
if [ -e "${USER_ELFS[0]}" ]; then
    echo "Generating File System Image..."
    mkdir -p "$BUILD_DIR/block_storage"
    "$BUILD_DIR/tools/mkfs" "$BUILD_DIR/block_storage/fs.bin" "${USER_ELFS[@]}"
    
    # Update hostfs root copy so 'run host/*.elf' also runs the new binaries
    mkdir -p "$BUILD_DIR/hostroot"
    cp "${USER_ELFS[@]}" "$BUILD_DIR/hostroot/"
fi

echo "Starting SoC Simulation..."
# Verilator's generated Makefile does not reliably notice RTL timestamp
# changes.  Recreate only the generated model so a kernel/RTL width migration
# cannot accidentally run a stale simulator, while preserving the images above.
rm -rf "$BUILD_DIR/obj_dir"
cd sim

echo "Building Simulator..."
# A fresh Verilator directory can race PCH/dependency creation with parallel
# generated builds.  Keep model generation deterministic; simulation itself
# remains multi-threaded through VERILATOR_THREADS.
make VERILATOR_JOBS=1 TOP_MODULE=soc SYS_CORES_PER_CLUSTER="$SYS_CORES_PER_CLUSTER" \
    FLASH_SIZE="$FLASH_SIZE" BL2_BASE_BA="$BL2_BASE_BA" BL2A_BASE_BA="$BL2A_BASE_BA" \
    KERNEL_BASE_BA="$KERNEL_BASE_BA" FS_BASE_BA="$FS_BASE_BA" NUM_BANKS="$NUM_BANKS" \
    CLOCK_FREQ_HZ="$CLOCK_FREQ_HZ"

if [[ "$BUILD_ONLY" == "1" ]]; then
    echo "[SIM] build-only complete"
    exit 0
fi

if [[ "$GRAPHICS" == "1" ]]; then
    cd "$REPO_ROOT"
    python3 -m http.server "$GRAPHICS_PORT" --bind 127.0.0.1 >"$BUILD_DIR/framebuffer_viewer.log" 2>&1 &
    GRAPHICS_PID=$!
    trap cleanup_graphics EXIT INT TERM
    echo "Graphics viewer started on port $GRAPHICS_PORT"
    echo "Forward port $GRAPHICS_PORT in code-server, then open /verification/simulator/tools/framebuffer_viewer.html"
    cd sim
fi

echo "Running Simulation with host daemon..."
cd "$BUILD_DIR"
"$BUILD_DIR/tools/hostd" ./hostroot ./obj_dir/Vsoc "${SIM_ARGS[@]}"
