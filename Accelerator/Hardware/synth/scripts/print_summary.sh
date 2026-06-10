#!/usr/bin/env bash
set -euo pipefail

BUILD_DIR="${1:-build}"
REPORT_DIR="$BUILD_DIR/reports"

pick_report() {
    local impl="$REPORT_DIR/utilization.rpt"
    local synth="$REPORT_DIR/utilization_synth.rpt"
    if [[ -f "$impl" ]]; then
        echo "$impl"
    else
        echo "$synth"
    fi
}

pick_timing() {
    local impl="$REPORT_DIR/timing.rpt"
    local synth="$REPORT_DIR/timing_synth.rpt"
    if [[ -f "$impl" ]]; then
        echo "$impl"
    else
        echo "$synth"
    fi
}

UTIL_REPORT="$(pick_report)"
TIME_REPORT="$(pick_timing)"

if [[ ! -f "$UTIL_REPORT" ]]; then
    echo "No utilization report found under $REPORT_DIR"
    exit 1
fi

echo "========================================"
echo " Cascade FPGA synthesis summary"
echo "========================================"
echo "Utilization: $UTIL_REPORT"
echo "Timing:      $TIME_REPORT"
echo

python3 - "$UTIL_REPORT" "$TIME_REPORT" <<'PY'
import re
import sys

util_path, time_path = sys.argv[1:3]

def parse_util_line(text, label):
    for line in text.splitlines():
        if label in line and "|" in line:
            cells = [c.strip() for c in line.split("|") if c.strip()]
            if len(cells) >= 4:
                return cells[1], cells[3], cells[4].rstrip("%")
    return None

with open(util_path, encoding="utf-8", errors="replace") as f:
    util = f.read()

labels = [
    ("CLB LUTs", "CLB LUTs"),
    ("CLB Registers", "CLB Registers"),
    ("DSP Blocks", "DSPs"),
    ("Block RAM", "Block RAM Tile"),
]

print("--- Resources ---")
for title, key in labels:
    row = parse_util_line(util, key)
    if row:
        used, avail, pct = row
        print(f"{title:14} {used} used / {avail} available ({pct}%)")
    else:
        print(f"{title:14} n/a")

if time_path:
    try:
        with open(time_path, encoding="utf-8", errors="replace") as f:
            timing = f.read()
    except FileNotFoundError:
        timing = ""

    if timing:
        print()
        print("--- Timing ---")
        for metric in ("WNS(ns)", "TNS(ns)", "WHS(ns)", "THS(ns)"):
            m = re.search(rf"^{re.escape(metric)}\s+(-?\d+\.\d+)", timing, re.M)
            if m:
                print(f"{metric:10} {m.group(1)}")

        wns_m = re.search(r"^WNS\(ns\)\s+(-?\d+\.\d+)", timing, re.M)
        if wns_m:
            wns = float(wns_m.group(1))
            period = 4.0
            achieved = period - wns
            fmax = (1000.0 / achieved) if achieved > 0 else float("nan")
            print()
            print("Target clock: 250 MHz (4.0 ns period)")
            if fmax == fmax:
                print(f"Estimated Fmax: {fmax:.2f} MHz")
            else:
                print("Estimated Fmax: n/a (timing not achievable at target)")

print()
print(f"Full reports: {util_path.rsplit('/', 1)[0]}")
PY
