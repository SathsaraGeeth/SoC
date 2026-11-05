#!/usr/bin/env bash
set -euo pipefail
"$(dirname "$0")/run_prove.sh"
"$(dirname "$0")/run_cover.sh"

