#!/usr/bin/env bash
set -euo pipefail
S="$(cd "$(dirname "${BASH_SOURCE[0]}")"&&pwd)";F="$(cd "$S/.."&&pwd)";R="$(cd "$F/../../.."&&pwd)";DMCTP_BUILD_DIR="$R/build/formal/sys_core" python3 "$R/verification/uvm/isa/scripts/prepare_rtl.py";cd "$F";exec "${SBY:-sby}" -d "$R/build/formal/sys_core/cover/full" -f cover/full.sby

