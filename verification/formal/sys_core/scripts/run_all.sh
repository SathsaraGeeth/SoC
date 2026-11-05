#!/usr/bin/env bash
set -euo pipefail
R="$(cd "$(dirname "${BASH_SOURCE[0]}")/.."&&pwd)";"$R/scripts/run_prove.sh";"$R/scripts/run_cover.sh"

