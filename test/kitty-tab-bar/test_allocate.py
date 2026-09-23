#!/usr/bin/env python3
"""Tests for the cell allocator — the replacement for kitty's tab_bar.py:762-788.

What kitty does and this must not: floor (columns // ntabs), subtract a phantom
separator cell per tab, floor again on extra // len(over_achievers), skip the
distribution entirely when that quotient rounds to zero, and never do a second
pass. The invariant below — allocations sum to exactly `total` — is the whole point.
"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "dot_config" / "kitty"))
from tab_bar import allocate  # noqa: E402

failures = []


def check(got, want, what):
    if got != want:
        failures.append(f"{what}\n    want: {want!r}\n    got:  {got!r}")


# --- the invariant kitty breaks ----------------------------------------------

check(sum(allocate([30] * 12, 172, floor=12, cap=24)), 172,
      "every cell is allocated — no floors, no remainder on the ground")

check(allocate([8, 10, 24, 24], 172, floor=12, cap=24), [24, 24, 24, 24],
      "with width going spare the cap binds and the rest is deliberately unspent")

check(sum(allocate([5] * 7, 100, floor=12, cap=24)), 100,
      "a remainder that does not divide evenly is still fully spent")

check(sum(allocate([30] * 13, 172, floor=12, cap=24)), 172,
      "an over-subscribed bar still spends exactly the width available")


# --- surplus goes to the neediest --------------------------------------------

check(allocate([8, 8, 20], 40, floor=8, cap=24), [10, 10, 20],
      "once every demand is met the remaining width pads the smallest tabs")

check(allocate([8, 20, 20], 48, floor=8, cap=24), [8, 20, 20],
      "each tab gets exactly what it asked for when the bar can afford it")

check(allocate([8, 22, 14], 44, floor=8, cap=24), [8, 22, 14],
      "demands under the cap are met before anyone is padded")

check(allocate([30, 30], 40, floor=8, cap=24), [20, 20],
      "when nobody can be satisfied the shortfall is shared, not dumped on one")

check(allocate([12, 30], 40, floor=8, cap=24), [16, 24],
      "the starving tab is filled to the cap, then the surplus pads the other")


# --- the floor and the cap ---------------------------------------------------

check(allocate([4, 4, 40], 36, floor=10, cap=24), [10, 10, 16],
      "every tab clears the floor before anyone is fed past it")

check(allocate([40, 40], 100, floor=10, cap=24), [24, 24],
      "nothing grows past the cap even when width is going spare")

check(min(allocate([2] * 14, 172, floor=12, cap=24)), 12,
      "a bar at its tab limit still holds the floor for every tab")

check(allocate([5, 5], 6, floor=12, cap=24), [3, 3],
      "a floor the bar cannot afford degrades evenly instead of starving a tab")


# --- max-min fairness --------------------------------------------------------

check(allocate([24, 24, 24], 40, floor=8, cap=24), [14, 13, 13],
      "equal demands split the shortfall evenly, odd cell to the leftmost")

check(allocate([9, 24, 24], 41, floor=8, cap=24), [9, 16, 16],
      "the neediest are levelled up together rather than one being filled first")


if failures:
    print(f"FAIL ({len(failures)})")
    for f in failures:
        print("  " + f)
    sys.exit(1)
print("ok: allocate")
