#!/usr/bin/env bash
# Run software calculations + RTL simulations on any Linux host (including EC2).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BENCH_DIR="$(cd "$(dirname "$0")" && pwd)"

RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  Cascade AWS calculation benchmark${NC}"
echo -e "${BLUE}========================================${NC}"
echo "Host: $(uname -n) ($(uname -m))"
echo ""

if ! command -v python3 >/dev/null; then
    echo -e "${RED}python3 not found${NC}"
    exit 1
fi

if ! python3 -c "import numpy" 2>/dev/null; then
    echo "Installing numpy..."
    python3 -m pip install --user numpy
fi

echo -e "${BLUE}[1/2] Software calculations (NumPy + reference model)${NC}"
python3 "$BENCH_DIR/compute_bench.py"
sw_result=$?

echo ""
echo -e "${BLUE}[2/2] RTL simulations (iverilog)${NC}"
if command -v iverilog >/dev/null; then
    (cd "$ROOT" && ./run.sh)
    rtl_result=$?
else
    echo -e "${RED}iverilog not found. Install with:${NC}"
    echo "  Ubuntu:        sudo apt install -y iverilog"
    echo "  Amazon Linux:  sudo yum install -y iverilog"
    rtl_result=1
fi

echo ""
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  Combined summary${NC}"
echo -e "${BLUE}========================================${NC}"
[ "$sw_result" -eq 0 ] && echo -e "Software calc:  ${GREEN}PASS${NC}" || echo -e "Software calc:  ${RED}FAIL${NC}"
[ "$rtl_result" -eq 0 ] && echo -e "RTL simulation: ${GREEN}PASS${NC}" || echo -e "RTL simulation: ${RED}FAIL${NC}"

if [ "$sw_result" -eq 0 ] && [ "$rtl_result" -eq 0 ]; then
    exit 0
fi
exit 1
