#!/usr/bin/env bash
# Measured NumPy vs RTL vs Vivado comparison for 16x16 matmul.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BENCH="$(cd "$(dirname "$0")" && pwd)"
TIMING="$ROOT/synth/build/reports/timing.rpt"

ARGS=(--run-rtl)

if [ -f "$TIMING" ]; then
    ARGS+=(--timing-report "$TIMING")
    echo "Using Vivado timing: $TIMING"
else
    echo "No Vivado timing report yet (will use 250 MHz target only)."
    echo "For measured Fmax: make -C synth impl TARGET=matmul16 VIVADO_JOBS=2"
fi

python3 "$BENCH/compare.py" "${ARGS[@]}"
