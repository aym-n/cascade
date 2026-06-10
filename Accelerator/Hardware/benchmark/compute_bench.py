#!/usr/bin/env python3
"""Software reference calculations for Cascade systolic array benchmarks."""

from __future__ import annotations

import platform
import sys
import time
from typing import Iterable

try:
    import numpy as np
except ImportError:
    print("numpy is required: pip install numpy", file=sys.stderr)
    sys.exit(1)

N16 = 16
MACS_16X16 = N16 ** 3
CYCLES_16X16 = (2 * N16 - 1) + (2 * N16 - 1) + 5  # feed + drain + overhead

CYCLES_PER_3X3_TILE = 16
TILES_PER_6X6 = 8
CYCLES_6X6_TILER = TILES_PER_6X6 * CYCLES_PER_3X3_TILE
CYCLES_3X3_ARRAY = 20


def matmul_int(a: np.ndarray, b: np.ndarray) -> np.ndarray:
    n = a.shape[0]
    c = np.zeros((n, n), dtype=np.int32)
    for i in range(n):
        for j in range(n):
            for k in range(n):
                c[i, j] += int(a[i, k]) * int(b[k, j])
    return c


def verify_case(name: str, a: np.ndarray, b: np.ndarray) -> bool:
    ref = matmul_int(a, b)
    fast = a.astype(np.int32) @ b.astype(np.int32)
    ok = np.array_equal(ref, fast)
    n = a.shape[0]
    print(f"\n--- {name} ---")
    print(f"  A shape: {a.shape}, B shape: {b.shape}")
    print(f"  C[0,0] = {ref[0, 0]}, C[{n-1},{n-1}] = {ref[n-1, n-1]}")
    print(f"  Reference matmul matches NumPy: {'PASS' if ok else 'FAIL'}")
    return ok


def run_correctness_tests() -> bool:
    print("=" * 50)
    print(" Cascade software calculation checks")
    print("=" * 50)

    rng = np.random.default_rng(42)

    a1 = rng.integers(-9, 10, size=(6, 6), dtype=np.int8)
    b1 = np.eye(6, dtype=np.int8)
    ok1 = verify_case("6x6 Test 1: A random, B identity", a1, b1)
    ok1 = ok1 and np.array_equal(matmul_int(a1, b1), a1.astype(np.int32))

    a2 = np.full((6, 6), 2, dtype=np.int8)
    b2 = np.full((6, 6), 3, dtype=np.int8)
    ok2 = verify_case("6x6 Test 2: A=2, B=3", a2, b2)
    ok2 = ok2 and np.all(matmul_int(a2, b2) == 36)

    a3 = rng.integers(-4, 4, size=(6, 6), dtype=np.int8)
    b3 = rng.integers(-4, 4, size=(6, 6), dtype=np.int8)
    ok3 = verify_case("6x6 Test 3: random signed", a3, b3)

    # 16x16 core (matches tb_matmul_16x16 cases)
    a16_id = rng.integers(-9, 10, size=(N16, N16), dtype=np.int8)
    b16_id = np.eye(N16, dtype=np.int8)
    ok4 = verify_case("16x16 Test 1: A random, B identity", a16_id, b16_id)

    a16_const = np.full((N16, N16), 2, dtype=np.int8)
    b16_const = np.full((N16, N16), 3, dtype=np.int8)
    ok5 = verify_case("16x16 Test 2: A=2, B=3", a16_const, b16_const)
    ok5 = ok5 and np.all(matmul_int(a16_const, b16_const) == 96)  # 16*2*3

    a16_rand = rng.integers(-4, 4, size=(N16, N16), dtype=np.int8)
    b16_rand = rng.integers(-4, 4, size=(N16, N16), dtype=np.int8)
    ok6 = verify_case("16x16 Test 3: random signed", a16_rand, b16_rand)

    all_ok = ok1 and ok2 and ok3 and ok4 and ok5 and ok6
    print("\n" + ("All correctness checks: PASS" if all_ok else "All correctness checks: FAIL"))
    return all_ok


def bench_numpy_throughput(n: int, repeats: int) -> tuple[float, float]:
    rng = np.random.default_rng(0)
    a = rng.integers(-8, 8, size=(n, n), dtype=np.int8)
    b = rng.integers(-8, 8, size=(n, n), dtype=np.int8)

    _ = a.astype(np.int32) @ b.astype(np.int32)

    t0 = time.perf_counter()
    for _ in range(repeats):
        _ = a.astype(np.int32) @ b.astype(np.int32)
    elapsed = time.perf_counter() - t0

    macs = n * n * n
    gmacs = (macs * repeats / elapsed) / 1e9
    us_per = (elapsed / repeats) * 1e6
    return gmacs, us_per


def bench_hardware_model_16x16(target_mhz: float = 250.0) -> tuple[float, float]:
    hz = target_mhz * 1e6
    seconds = CYCLES_16X16 / hz
    gmacs = MACS_16X16 / seconds / 1e9
    us_per = seconds * 1e6
    return gmacs, us_per


def bench_16x16_comparison(repeats: int = 50000, target_mhz: float = 250.0) -> None:
    print("\n" + "=" * 50)
    print(" 16x16 head-to-head: NumPy vs systolic core")
    print("=" * 50)
    print(f"  Host: {platform.node()} ({platform.machine()})")
    print(f"  NumPy repeats: {repeats}")
    print(f"  Hardware model: {target_mhz:.0f} MHz, {CYCLES_16X16} cycles/op, {MACS_16X16} MACs")

    np_gmacs, np_us = bench_numpy_throughput(N16, repeats)
    hw_gmacs, hw_us = bench_hardware_model_16x16(target_mhz)

    print(f"\n  {'':18} {'Throughput':>14} {'Latency/op':>14}")
    print(f"  {'-'*18} {'-'*14} {'-'*14}")
    print(f"  {'NumPy (CPU)':18} {np_gmacs:>11.3f} GMAC/s {np_us:>11.2f} us")
    print(f"  {'Systolic 16x16':18} {hw_gmacs:>11.3f} GMAC/s {hw_us:>11.2f} us")

    if hw_gmacs > np_gmacs:
        print(f"\n  Hardware model is {hw_gmacs/np_gmacs:.2f}x faster than NumPy at 16x16")
    else:
        print(f"\n  NumPy is {np_gmacs/hw_gmacs:.2f}x faster than hardware model at 16x16")
    print("  (Hardware number is theoretical; run RTL sim or FPGA synth for measured cycles)")


def bench_throughput(sizes: Iterable[int], repeats: int = 5000) -> None:
    print("\n" + "=" * 50)
    print(" Software throughput sweep (NumPy int8)")
    print("=" * 50)
    print(f"  Repeats per size: {repeats}")

    for n in sizes:
        gmacs, us_per = bench_numpy_throughput(n, repeats)
        print(f"\n  {n}x{n} matmul:")
        print(f"    Throughput:    {gmacs:.3f} GMAC/s")
        print(f"    Per multiply:  {us_per:.2f} us")


def print_hardware_model(target_mhz: float = 250.0) -> None:
    print("\n" + "=" * 50)
    print(" Theoretical hardware throughput (design model)")
    print("=" * 50)
    print(f"  Assumed clock: {target_mhz:.0f} MHz")

    hz = target_mhz * 1e6

    hw16_gmacs, hw16_us = bench_hardware_model_16x16(target_mhz)
    print(f"\n  16x16 core: {MACS_16X16} MACs in ~{CYCLES_16X16} cyc -> "
          f"{hw16_gmacs:.3f} GMAC/s ({hw16_us:.2f} us/op)")

    t_3x3 = CYCLES_3X3_ARRAY / hz
    t_6x6 = CYCLES_6X6_TILER / hz
    print(f"  3x3 array:   27 MACs in ~{CYCLES_3X3_ARRAY} cyc -> "
          f"{(27 / t_3x3) / 1e9:.3f} GMAC/s")
    print(f"  6x6 tiler:  216 MACs in ~{CYCLES_6X6_TILER} cyc -> "
          f"{(216 / t_6x6) / 1e9:.3f} GMAC/s")


def main() -> int:
    ok = run_correctness_tests()
    bench_16x16_comparison(repeats=50000, target_mhz=250.0)
    bench_throughput(sizes=(3, 6, 16, 32, 64), repeats=5000)
    print_hardware_model(target_mhz=250.0)
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
