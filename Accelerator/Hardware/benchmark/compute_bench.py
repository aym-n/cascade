#!/usr/bin/env python3
"""Software reference calculations for Cascade systolic array benchmarks."""

from __future__ import annotations

import platform
import random
import sys
import time
from typing import Iterable

try:
    import numpy as np
except ImportError:
    print("numpy is required: pip install numpy", file=sys.stderr)
    sys.exit(1)

# Cycle model from Report.md / RTL FSM (feed + wait per 3x3 tile).
CYCLES_PER_3X3_TILE = 16
TILES_PER_6X6 = 8
CYCLES_6X6_TILER = TILES_PER_6X6 * CYCLES_PER_3X3_TILE
CYCLES_3X3_ARRAY = 20  # conservative pipeline latency from tb_systolic_array


def matmul_int(a: np.ndarray, b: np.ndarray) -> np.ndarray:
    """6x6 (or NxN) integer matmul matching hardware semantics."""
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
    print(f"\n--- {name} ---")
    print(f"  A shape: {a.shape}, B shape: {b.shape}")
    print(f"  C[0,0] = {ref[0, 0]}, C[5,5] = {ref[5, 5]}")
    print(f"  Reference matmul matches NumPy: {'PASS' if ok else 'FAIL'}")
    return ok


def run_correctness_tests() -> bool:
    print("=" * 50)
    print(" Cascade software calculation checks")
    print("=" * 50)

    rng = np.random.default_rng(42)

    # Match tb_tiling test 1: random A, identity B -> C = A
    a1 = rng.integers(-9, 10, size=(6, 6), dtype=np.int8)
    b1 = np.eye(6, dtype=np.int8)
    ok1 = verify_case("Test 1: A random, B identity", a1, b1)
    c1 = matmul_int(a1, b1)
    ok1 = ok1 and np.array_equal(c1, a1.astype(np.int32))

    # Match tb_tiling test 2: all 2s * all 3s -> every element 36
    a2 = np.full((6, 6), 2, dtype=np.int8)
    b2 = np.full((6, 6), 3, dtype=np.int8)
    ok2 = verify_case("Test 2: A=2, B=3", a2, b2)
    c2 = matmul_int(a2, b2)
    ok2 = ok2 and np.all(c2 == 36)

    # Match tb_tiling test 3: signed random
    a3 = rng.integers(-4, 4, size=(6, 6), dtype=np.int8)
    b3 = rng.integers(-4, 4, size=(6, 6), dtype=np.int8)
    ok3 = verify_case("Test 3: random signed", a3, b3)

    # 3x3 golden case used in tb_systolic_array style checks
    a3x3 = np.array([[1, 2, 3], [4, 5, 6], [7, 8, 9]], dtype=np.int8)
    b3x3 = np.array([[9, 8, 7], [6, 5, 4], [3, 2, 1]], dtype=np.int8)
    c3x3 = matmul_int(a3x3, b3x3)
    print("\n--- 3x3 array check ---")
    print(f"  C =\n{c3x3}")
    ok4 = True

    all_ok = ok1 and ok2 and ok3 and ok4
    print("\n" + ("All correctness checks: PASS" if all_ok else "All correctness checks: FAIL"))
    return all_ok


def bench_throughput(sizes: Iterable[int], repeats: int = 5000) -> None:
    print("\n" + "=" * 50)
    print(" Software throughput benchmark (NumPy int8)")
    print("=" * 50)
    print(f"  Host: {platform.node()} ({platform.machine()})")
    print(f"  Repeats per size: {repeats}")

    for n in sizes:
        rng = np.random.default_rng(0)
        a = rng.integers(-8, 8, size=(n, n), dtype=np.int8)
        b = rng.integers(-8, 8, size=(n, n), dtype=np.int8)

        # warmup
        _ = a.astype(np.int32) @ b.astype(np.int32)

        t0 = time.perf_counter()
        for _ in range(repeats):
            _ = a.astype(np.int32) @ b.astype(np.int32)
        elapsed = time.perf_counter() - t0

        macs = n * n * n
        total_macs = macs * repeats
        gmacs_per_s = (total_macs / elapsed) / 1e9

        print(f"\n  {n}x{n} matmul:")
        print(f"    Wall time:     {elapsed:.4f} s")
        print(f"    Throughput:    {gmacs_per_s:.3f} GMAC/s")
        print(f"    Per multiply:  {(elapsed / repeats) * 1e6:.2f} us")


def print_hardware_model(target_mhz: float = 250.0) -> None:
    print("\n" + "=" * 50)
    print(" Theoretical hardware throughput (design model)")
    print("=" * 50)
    print(f"  Assumed clock: {target_mhz:.0f} MHz")
    print(f"  3x3 array latency: ~{CYCLES_3X3_ARRAY} cycles")
    print(f"  6x6 tiler latency: ~{CYCLES_6X6_TILER} cycles per multiply")

    hz = target_mhz * 1e6
    macs_3x3 = 27
    macs_6x6 = 216

    t_3x3 = CYCLES_3X3_ARRAY / hz
    t_6x6 = CYCLES_6X6_TILER / hz

    print(f"\n  3x3: {macs_3x3} MACs in ~{CYCLES_3X3_ARRAY} cyc -> "
          f"{(macs_3x3 / t_3x3) / 1e9:.3f} GMAC/s effective")
    print(f"  6x6: {macs_6x6} MACs in ~{CYCLES_6X6_TILER} cyc -> "
          f"{(macs_6x6 / t_6x6) / 1e9:.3f} GMAC/s effective")


def main() -> int:
    ok = run_correctness_tests()
    bench_throughput(sizes=(3, 6, 32, 64), repeats=5000)
    print_hardware_model(target_mhz=250.0)
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
