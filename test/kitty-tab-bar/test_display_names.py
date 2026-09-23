#!/usr/bin/env python3
"""Tests for the pure core of dot_config/kitty/tab_bar.py.

Imports the core directly — no kitty, no terminal. Everything under test is
str -> str; the kitty-facing shell (get_boss, draw_title) is not exercised here.
"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "dot_config" / "kitty"))
from tab_bar import display_names, frame, render  # noqa: E402

WIDE = 100  # no width pressure — isolates disambiguation from fitting

failures = []


def check(got, want, what):
    if got != want:
        failures.append(f"{what}\n    want: {want!r}\n    got:  {got!r}")


def _cells_of(s):
    return len(s) + sum(1 for ch in s if ch in "🔴🟡🔵🟢")


def names(titles, width=WIDE):
    return display_names(titles, width)


# --- parsing -----------------------------------------------------------------

check(names(["🔴 cc:lunar/test-doubles"]), ["🔴 test-doubles"],
      "strips cc:, keeps the state ball, drops a non-distinguishing project")

check(names(["cc:lunar/test-doubles"]), ["test-doubles"],
      "a title with no ball renders without one")

check(names(["🟡 cc:.local/share/chezmoi"]), ["🟡 chezmoi"],
      "the $HOME-fallback form keeps only its leaf")

check(names(["zsh", "🔴 cc:lunar/test-doubles"]), ["zsh", "🔴 test-doubles"],
      "a non-cc tab passes through untouched")

check(names(["🔴 cc:lunar"]), ["🔴 lunar"],
      "a single-segment name is its own leaf")


# --- disambiguation ----------------------------------------------------------

check(names(["cc:lunar/main", "cc:gracenote/main"]), ["l/main", "g/main"],
      "colliding leaves take the shortest distinguishing project prefix")

check(names(["cc:lunar/main", "cc:liberties/main"]), ["lu/main", "li/main"],
      "prefix grows only as far as the competing projects force it")

check(names(["cc:lunar/main", "cc:liberties/main", "cc:gracenote/main"]),
      ["lu/main", "li/main", "g/main"],
      "each tab's prefix is minimal for itself, not a shared width")

check(names(["cc:lunar/main", "cc:gracenote/deploy"]), ["main", "deploy"],
      "non-colliding leaves keep no prefix even when projects differ")

check(names(["cc:lunar/test-doubles", "cc:lunar", "cc:erx-split"]),
      ["test-doubles", "lunar", "erx-split"],
      "a project used as its own leaf does not collide with its children")

check(names(["cc:theliberties/www/main", "cc:theliberties/api/main"]),
      ["w/main", "a/main"],
      "same project and leaf: walk up for the next distinguishing segment, still minimal")

check(names(["cc:lunar/main", "cc:lunar/main"]), ["main#1", "main#2"],
      "genuinely identical paths fall back to a counter")


# --- fitting -----------------------------------------------------------------
#
# Rule: a name over budget by at most MAX_SQUEEZE chars is vowel-squeezed — longest
# hyphen-segment first, vowels from the right, never a segment's leading char.
# Anything else is returned WHOLE and kitty clips it.
#
# WHY no truncation here: max_title_length is a hint, not the real extent. Under the
# fade style kitty passes max_tab_length - 8 and then lets the title overflow and
# clips at the true width (kitty/tab_bar.py:421). Truncating to the hint discards
# cells kitty would have given — that is what made the bar show LESS than before.

check(names(["cc:pubsub-stage1"], 13), ["pubsub-stage1"],
      "a name that already fits is left alone")

check(names(["cc:test-generation"], 13), ["test-generatn"],
      "vowels come out of the longest segment, rightmost first, and stop once it fits")

check(names(["cc:dashboards"], 9), ["dashbords"],
      "a one-char overage is squeezed, not truncated")

check(names(["cc:boundaries"], 9), ["boundaris"],
      "a squeeze rescue keeps the name whole and recognizable")

check(names(["cc:graphql-tracing-obs"], 13), ["graphql-tracing-obs"],
      "too far over to squeeze: hand it over whole and let kitty clip it")

check(names(["cc:controlled-substance-mfa"], 13), ["controlled-substance-mfa"],
      "never truncate against a hint — kitty knows the real extent, we do not")

check(names(["\U0001f534 cc:controlled-substance-mfa"], 16)[0].startswith("\U0001f534 "),
      True, "the ball is not squeezed away")

check(names(["cc:abcdefghijklmnop"], 6), ["abcdefghijklmnop"],
      "a name far over budget is left whole for kitty to clip")

check(names(["cc:ab-cd"], 3), ["ab-cd"],
      "a budget too small for any squeeze changes nothing")


# --- uniqueness outranks fitting ---------------------------------------------

check(names(["cc:a/reporting", "cc:b/reportng"], 8), ["reporting", "reportng"],
      "names that would squeeze to the same string stay unsqueezed and distinct")


# --- framing: centre inside the allocation, clamped to a min/max band --------
#
# frame() pads to the width kitty allocated, so tabs abut and fill the bar
# instead of leaving the remainder pooled at one edge. The padding inherits the
# tab's background (cursor.bg is the tab colour throughout draw_title), so every
# tab is a solid colour block — what fade gave, without fade's 8-cell gradient.
#
# The band clamps both ends: below MIN_CELLS a tab stays legible (and kitty drops
# overflow tabs past ~columns//MIN_CELLS rather than shrinking everything), above
# MAX_CELLS no single name can hog the bar. Under the separator style `width` is
# the true allocation — kitty passes max_tab_length straight through
# (kitty/tab_bar.py:389) — unlike fade, which lies to you by 8 cells.

check(frame("lunar", 15), "     lunar     ",
      "a short name is centred across its full allocation")

check(frame("erx-split", 12), " erx-split  ",
      "odd padding puts the extra cell on the right")

check(frame("pubsub-stage1", 13), "pubsub-stage1",
      "a name that exactly fills its allocation is untouched")

check(frame("controlled-substance-mfa", 15), "controlled-sub…",
      "a name past its allocation is clipped to it")

check(len(frame("lunar", 20)), 20,
      "frame renders exactly the width it is given — the band is allocate's job")

check(frame("lunar", 5), "lunar",
      "a name that exactly fills a narrow allocation is not padded")

check(_cells_of(frame("\U0001f534 lunar", 12)), 12,
      "the ball counts as two cells when centring")

check(frame("\U0001f534 lunar", 12), "  \U0001f534 lunar  ",
      "a ball-bearing tab centres on display width, not character count")


check(_cells_of(frame("\U0001f534 controlled-substance-mfa", 15)), 15,
      "clipping counts display cells, not characters — the ball is two cells wide")

check(frame("\U0001f534 controlled-substance-mfa", 15), "\U0001f534 controlled-…",
      "a clipped ball-bearing name still fills its allocation exactly")


# --- render: names and widths together, filling the bar ----------------------

_BAR = ["🔴 cc:lunar", "🔴 cc:graphql-tracing-obs", "🟡 cc:chezmoi", "🔴 cc:erx-split"]

check(sum(_cells_of(c) for c in render(_BAR, 37)), 37,
      "a bar whose names must be clipped still spends exactly its width")

check(sum(_cells_of(c) for c in render(_BAR, 60)), 60,
      "the rendered bar spends every column it was given")

check(all(_cells_of(c) >= 12 for c in render(_BAR, 60)), True,
      "no tab renders below the floor when the bar can afford it")

check(render(["🔴 cc:lunar"], 12), ["  🔴 lunar  "],
      "a lone tab is centred in its allocation")


if failures:
    print(f"FAIL ({len(failures)})")
    for f in failures:
        print("  " + f)
    sys.exit(1)
print("ok: display_names")
