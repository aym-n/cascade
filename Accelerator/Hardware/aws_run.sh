#!/usr/bin/env bash
# One-shot AWS benchmark: calculations + optional FPGA synthesis.
#
# On a cheap EC2 (t3.small):
#   sudo yum install -y git iverilog python3-pip
#   git clone https://github.com/aym-n/cascade
#   cd cascade/Accelerator/Hardware && ./aws_run.sh
#
# On FPGA Developer AMI (adds Vivado synthesis):
#   source /opt/Xilinx/Vivado/*/settings64.sh
#   ./aws_run.sh --synth
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
RUN_SYNTH=0

for arg in "$@"; do
    case "$arg" in
        --synth) RUN_SYNTH=1 ;;
        -h|--help)
            echo "Usage: $0 [--synth]"
            echo "  default  run software + RTL calculation benchmarks"
            echo "  --synth  also run Vivado impl (requires FPGA Developer AMI)"
            exit 0
            ;;
        *)
            echo "Unknown option: $arg"
            exit 1
            ;;
    esac
done

echo "========================================"
echo " Cascade full AWS benchmark"
echo "========================================"
echo "Started: $(date -u '+%Y-%m-%d %H:%M:%S UTC')"
echo ""

"$ROOT/benchmark/run.sh"

if [ "$RUN_SYNTH" -eq 1 ]; then
    echo ""
    echo "========================================"
    echo " FPGA synthesis (Vivado)"
    echo "========================================"
    if command -v vivado >/dev/null; then
        make -C "$ROOT/synth" impl TARGET=tiler
        make -C "$ROOT/synth" report
    else
        echo "vivado not in PATH; skip synthesis or run:"
        echo "  source /opt/Xilinx/Vivado/<version>/settings64.sh"
        exit 1
    fi
fi

echo ""
echo "Finished: $(date -u '+%Y-%m-%d %H:%M:%S UTC')"
