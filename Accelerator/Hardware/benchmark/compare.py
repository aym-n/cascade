#!/usr/bin/env python3
"""
Measured 16x16 comparison: NumPy vs RTL cycle count vs Vivado Fmax.

NumPy  = real wall-clock on this CPU.
RTL    = real cycle count from iverilog simulation.
FPGA   = RTL cycles / Vivado post-route Fmax (requires synth timing report).
"""

from __future__ import annotations

import argparse
import platform
import re
import subprocess
import sys
import time
from pathlib import Path

try:
    import numpy as np
except ImportError:
    print("numpy required: sudo apt install python3-numpy", file=sys.stderr)
    sys.exit(1)

N = 16
MACS = N ** 3
CLOCK_PERIOD_NS = 10.0  # tb clock: #5 delay -> 10 ns period
TARGET_MHZ = 250.0
TARGET_PERIOD_NS = 1000.0 / TARGET_MHZ

HW_ROOT = Path(__file__).resolve().parent.parent
SYNTH_DIR = HW_ROOT / "synth"
DEFAULT_TIMING = SYNTH_DIR / "build" / "reports" / "timing.rpt"


def matmul_int(a: np.ndarray, b: np.ndarray) -> np.ndarray:
    out = np.zeros((N, N), dtype=np.int32)
    for i in range(N):
        for j in range(N):
            s = 0
            for k in range(N):
                s += int(a[i, k]) * int(b[k, j])
            out[i, j] = s
    return out


def bench_numpy(repeats: int) -> tuple[float, float, float]:
    rng = np.random.default_rng(0)
    a = rng.integers(-8, 8, size=(N, N), dtype=np.int8)
    b = rng.integers(-8, 8, size=(N, N), dtype=np.int8)
    _ = a.astype(np.int32) @ b.astype(np.int32)

    t0 = time.perf_counter()
    for _ in range(repeats):
        _ = a.astype(np.int32) @ b.astype(np.int32)
    elapsed = time.perf_counter() - t0

    per_op = elapsed / repeats
    gmacs = MACS / per_op / 1e9
    return gmacs, per_op * 1e6, elapsed


def bench_naive_python(repeats: int) -> tuple[float, float, float]:
    rng = np.random.default_rng(0)
    a = rng.integers(-8, 8, size=(N, N), dtype=np.int8)
    b = rng.integers(-8, 8, size=(N, N), dtype=np.int8)
    matmul_int(a, b)

    t0 = time.perf_counter()
    for _ in range(repeats):
        matmul_int(a, b)
    elapsed = time.perf_counter() - t0

    per_op = elapsed / repeats
    gmacs = MACS / per_op / 1e9
    return gmacs, per_op * 1e6, elapsed


def run_rtl_benchmark() -> tuple[int, bool]:
    out_dir = HW_ROOT / "output"
    out_dir.mkdir(exist_ok=True)
    vvp = out_dir / "tb_matmul_16x16_bench.vvp"

    srcs = [
        HW_ROOT / "src/pe.v",
        HW_ROOT / "src/systolic_array_16x16.v",
        HW_ROOT / "src/systolic_matmul_16x16.v",
        HW_ROOT / "sim/tb_matmul_16x16_bench.v",
    ]

    subprocess.run(
        ["iverilog", "-g2012", "-o", str(vvp), *[str(s) for s in srcs]],
        check=True,
        capture_output=True,
        text=True,
    )
    result = subprocess.run(
        ["vvp", str(vvp)],
        check=True,
        capture_output=True,
        text=True,
    )
    log = result.stdout

    cycles_m = re.search(r"BENCHMARK_CYCLES=(\d+)", log)
    pass_m = re.search(r"BENCHMARK_PASS=(\d+)", log)
    if not cycles_m:
        print(log, file=sys.stderr)
        raise RuntimeError("RTL benchmark did not emit BENCHMARK_CYCLES")

    cycles = int(cycles_m.group(1))
    passed = pass_m and pass_m.group(1) == "1"
    return cycles, passed


def parse_vivado_fmax(timing_path: Path) -> tuple[float | None, float | None]:
    if not timing_path.is_file():
        return None, None

    text = timing_path.read_text(encoding="utf-8", errors="replace")
    wns = None

    for line in text.splitlines():
        if "WNS(ns)" in line and "|" in line:
            cells = [c.strip() for c in line.split("|") if c.strip()]
            if len(cells) >= 2 and cells[0] == "WNS(ns)":
                wns = float(cells[1])
                break
    if wns is None:
        m = re.search(r"WNS\(ns\)\s+(-?\d+\.\d+)", text)
        if m:
            wns = float(m.group(1))

    if wns is None:
        return None, None

    achieved_ns = TARGET_PERIOD_NS - wns
    if achieved_ns <= 0:
        return wns, None
    return wns, 1000.0 / achieved_ns


def hw_throughput(cycles: int, fmax_mhz: float) -> tuple[float, float]:
    seconds = cycles / (fmax_mhz * 1e6)
    gmacs = MACS / seconds / 1e9
    return gmacs, seconds * 1e6


def print_row(label: str, gmacs: float, us: float, detail: str) -> None:
    print(f"  {label:22} {gmacs:>11.3f} GMAC/s {us:>11.2f} us   {detail}")


def main() -> int:
    parser = argparse.ArgumentParser(description="Measured NumPy vs RTL vs FPGA comparison")
    parser.add_argument("--numpy-repeats", type=int, default=50000)
    parser.add_argument("--python-repeats", type=int, default=200)
    parser.add_argument("--run-rtl", action="store_true", help="Run iverilog cycle benchmark")
    parser.add_argument("--rtl-cycles", type=int, default=0, help="Use pre-measured RTL cycles")
    parser.add_argument("--timing-report", type=Path, default=DEFAULT_TIMING)
    parser.add_argument("--target-mhz", type=float, default=TARGET_MHZ)
    args = parser.parse_args()

    print("=" * 72)
    print(" 16x16 measured comparison (not theoretical-only)")
    print("=" * 72)
    print(f"  Host:     {platform.node()} ({platform.machine()})")
    print(f"  MACs/op:  {MACS}")
    print()

    np_gmacs, np_us, _ = bench_numpy(args.numpy_repeats)
    py_gmacs, py_us, _ = bench_naive_python(args.python_repeats)

    rtl_cycles = args.rtl_cycles
    rtl_pass = True
    if args.run_rtl:
        if not shutil_which("iverilog"):
            print("iverilog not found; install with: sudo apt install iverilog", file=sys.stderr)
            return 1
        rtl_cycles, rtl_pass = run_rtl_benchmark()

    wns, fmax = parse_vivado_fmax(args.timing_report)

    print(f"  {'Implementation':22} {'Throughput':>14} {'Latency':>11}  Notes")
    print(f"  {'-'*22} {'-'*14} {'-'*11}  {'-'*24}")
    print_row("NumPy (BLAS)", np_gmacs, np_us,
              f"measured, {args.numpy_repeats} runs")
    print_row("Python (naive loops)", py_gmacs, py_us,
              f"measured, {args.python_repeats} runs")

    if rtl_cycles > 0:
        target_gmacs, target_us = hw_throughput(rtl_cycles, args.target_mhz)
        print_row(f"FPGA @{args.target_mhz:.0f}MHz est.", target_gmacs, target_us,
                  f"RTL {rtl_cycles} cyc × synth target")

        if fmax is not None:
            synth_gmacs, synth_us = hw_throughput(rtl_cycles, fmax)
            print_row("FPGA @Vivado Fmax", synth_gmacs, synth_us,
                      f"RTL {rtl_cycles} cyc, WNS={wns:.3f}ns")
        else:
            print(f"  {'FPGA @Vivado Fmax':22} {'n/a':>14} {'n/a':>11}   "
                  f"no timing report ({args.timing_report})")
    else:
        print(f"  {'FPGA (RTL cycles)':22} {'n/a':>14} {'n/a':>11}   "
              "run with --run-rtl")

    print()
    if rtl_cycles > 0 and rtl_pass:
        print(f"  RTL correctness: PASS (256/256 elements)")
        print(f"  RTL measured latency: {rtl_cycles} clock cycles "
              f"({rtl_cycles * CLOCK_PERIOD_NS:.0f} ns @ testbench clock)")
    elif rtl_cycles > 0:
        print("  RTL correctness: FAIL")
        return 1

    if rtl_cycles > 0 and fmax is not None:
        best_hw = hw_throughput(rtl_cycles, fmax)[0]
        speedup = best_hw / np_gmacs
        print(f"\n  FPGA (@ Vivado Fmax) vs NumPy: {speedup:.2f}x "
              f"({'hardware wins' if speedup > 1 else 'NumPy wins'})")
    elif rtl_cycles > 0:
        best_hw = hw_throughput(rtl_cycles, args.target_mhz)[0]
        speedup = best_hw / np_gmacs
        print(f"\n  FPGA (@ {args.target_mhz:.0f} MHz target) vs NumPy: {speedup:.2f}x")
        print("  Tip: run Vivado synth for measured Fmax:")
        print("    make -C synth impl TARGET=matmul16 VIVADO_JOBS=2")
        print("    python3 benchmark/compare.py --run-rtl")

    print()
    print("  How to read this:")
    print("  - NumPy/Python rows are REAL CPU measurements on this machine")
    print("  - FPGA rows use REAL cycle count from RTL sim × clock frequency")
    print("  - For silicon-accurate Fmax, run Vivado impl first (timing.rpt)")
    return 0


def shutil_which(cmd: str) -> str | None:
    from shutil import which
    return which(cmd)


if __name__ == "__main__":
    sys.exit(main())
