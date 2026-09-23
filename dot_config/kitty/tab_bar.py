# tab_bar.py — display-only tab naming for kitty.
#
# Reached via `tab_title_template "{bell_symbol}{custom}"` (kitty.conf), which calls
# draw_title(data) once per tab per draw. Stored titles are never touched: `kitty @ ls`
# still reports the full `cc:lunar/test-doubles`, so jjflow-cleanup's title matcher and
# session restore keep working. Only the pixels get clever.
#
# WHY: runclaude names tabs <project>/<leaf> for disambiguation, but the project segment
# is dead weight whenever no other tab shares the leaf — and at font_size 16 with a dozen
# tabs there are ~13 cells to spend. So the prefix is decided against the tabs actually
# on the bar rather than against the path, and it costs the fewest characters that still
# distinguish. Every tab runs the same pure function over the same set, so when a new tab
# creates a collision the already-open tabs re-render with prefixes on that same redraw —
# no coordination, no mutation of anyone else's title.

VOWELS = frozenset("aeiouAEIOU")
MAX_SQUEEZE = 2  # chars a vowel-squeeze may remove before truncation takes over
BALLS = ("🔴", "🟡", "🔵", "🟢")
BALLS_CHARS = frozenset(BALLS)
MIN_SEG = 2  # never squeeze a hyphen-segment below this
MIN_CELLS = 12  # a tab never renders narrower than this — short names centre-pad
MAX_CELLS = 24  # ...nor wider, so one long name cannot hog the bar


# --- functional core ---------------------------------------------------------

def _split(title):
    """title -> (ball, segments) — segments is None for a tab we do not own."""
    ball, rest = "", title
    for b in BALLS:
        if rest.startswith(b + " "):
            ball, rest = b + " ", rest[len(b) + 1:]
            break
    if not rest.startswith("cc:"):
        return ball, rest, None
    segs = [s for s in rest[3:].split("/") if s]
    return ball, rest, segs or None


def _short_prefix(token, rivals):
    """Fewest leading chars of token that no rival shares."""
    for n in range(1, len(token) + 1):
        if not any(r.startswith(token[:n]) for r in rivals):
            return token[:n]
    return token


def _qualify(group):
    """group: list of segment-lists sharing a leaf. -> list of display names.

    Walks up from the nearest ancestor to the first depth where the members differ,
    and spends the shortest prefix of that ancestor which separates each from its
    rivals. Members identical the whole way up fall back to a counter.
    """
    leaf = group[0][-1]
    if len(group) == 1:
        return [leaf]
    for depth in range(2, max(len(s) for s in group) + 1):
        tokens = [s[-depth] if len(s) >= depth else "" for s in group]
        if len(set(tokens)) == len(tokens):
            return [f"{_short_prefix(t, tokens[:i] + tokens[i + 1:])}/{leaf}"
                    for i, t in enumerate(tokens)]
    return [f"{leaf}#{i + 1}" for i in range(len(group))]


def _squeeze_once(segs):
    """Remove one character from the longest eligible segment. -> True if it shrank."""
    order = sorted(range(len(segs)), key=lambda i: (-len(segs[i]), i))
    for i in order:
        s = segs[i]
        if len(s) <= MIN_SEG:
            continue
        for j in range(len(s) - 1, 0, -1):  # never the leading char
            if s[j] in VOWELS:
                segs[i] = s[:j] + s[j + 1:]
                return True
        segs[i] = s[:-1]
        return True
    return False


def _fit(name, budget):
    """Fit name to budget.

    A near-miss is vowel-squeezed — that is what keeps `dashboards` whole as
    `dashbords`. Anything further over is handed back untouched for kitty to clip.

    We never truncate here. budget is kitty's max_title_length, which is a HINT:
    the fade style passes max_tab_length - 8 and then lets the title overflow,
    clipping at the true extent (kitty/tab_bar.py:421). Truncating to the hint
    throws away cells kitty would have granted.
    """
    if len(name) <= budget:
        return name
    if len(name) - budget <= MAX_SQUEEZE:
        segs = name.split("-")
        while sum(len(s) for s in segs) + len(segs) - 1 > budget:
            if not _squeeze_once(segs):
                break  # hit the per-segment floor; truncation takes it from here
        squeezed = "-".join(segs)
        if len(squeezed) <= budget:
            return squeezed
    return name


def _cells(s):
    """Display width. Only the state balls are double-width here."""
    return len(s) + sum(1 for ch in s if ch in BALLS_CHARS)


def display_names(titles, width):
    """titles -> display names, positionally. Shortest name that stays unique here.

    A list, not a dict: two tabs may hold byte-identical titles, and they still need
    to render differently. Pure — same input always gives the same output, which is
    what lets every tab compute this independently and agree without coordinating.
    """
    parsed = [_split(t) for t in titles]

    groups = {}
    for idx, (_, _, segs) in enumerate(parsed):
        if segs is not None:
            groups.setdefault(segs[-1], []).append(idx)

    qualified = {}
    for members in groups.values():
        for idx, name in zip(members, _qualify([parsed[i][2] for i in members])):
            qualified[idx] = name

    budget = {idx: max(1, width - _cells(p[0])) for idx, p in enumerate(parsed)}
    squeezed = {idx: _fit(name, budget[idx]) for idx, name in qualified.items()}

    # Uniqueness outranks fitting. Where two tabs squeeze to the same string, both
    # revert to their full names and overflow — one tab reading long is a smaller
    # failure than two tabs reading identical.
    clashed = {v for v in squeezed.values() if list(squeezed.values()).count(v) > 1}

    out = []
    for idx, (ball, rest, segs) in enumerate(parsed):
        if segs is None:
            out.append(ball + rest)
        elif squeezed[idx] in clashed:
            out.append(ball + qualified[idx])
        else:
            out.append(ball + squeezed[idx])
    return out


def allocate(demands, total, floor=None, cap=None):
    """Cells per tab, summing to exactly `total`.

    Replaces kitty's own allocator (kitty/tab_bar.py:762-788), which floors
    `columns // ntabs`, subtracts a separator cell per tab that an empty
    tab_separator never draws, floors again on `extra // len(over_achievers)`,
    skips the hand-out entirely when that quotient rounds to zero, and never
    revisits the split. Between them those drop ~9% of the bar on the floor.

    Here: everyone clears the floor, then each spare cell goes to whichever tab
    is furthest from what it asked for. Raising the neediest until it ties the
    next is max-min fairness — the shortfall lands on the tabs that can best
    absorb it, and a bar that cannot even afford the floor degrades evenly
    instead of starving whoever sorts last.
    """
    floor = MIN_CELLS if floor is None else floor
    cap = MAX_CELLS if cap is None else cap
    n = len(demands)
    if n == 0:
        return []

    base = min(floor, total // n)
    alloc = [base] * n
    pool = total - base * n
    wants = [min(d, cap) for d in demands]

    # Phase 1: raise the SMALLEST allocation that still wants more, one cell at
    # a time. Smallest-first, not largest-gap-first: a tab one cell short of its
    # name would never be fed if a hungrier tab could always outbid it.
    while pool > 0:
        needy = [j for j in range(n) if alloc[j] < wants[j]]
        if not needy:
            break
        alloc[min(needy, key=lambda j: (alloc[j], j))] += 1
        pool -= 1

    # Phase 2: every demand met and width still spare — pad so the bar has no
    # holes, still respecting the cap. Leftover past that stays unspent; with a
    # handful of tabs the alternative is a few absurdly wide blocks.
    while pool > 0:
        room = [j for j in range(n) if alloc[j] < cap]
        if not room:
            break
        alloc[min(room, key=lambda j: (alloc[j], j))] += 1
        pool -= 1
    return alloc


def _clip(s, cells):
    """Longest prefix of s fitting `cells` columns, plus the columns it uses.

    Slicing by character overruns whenever the string holds a double-width glyph
    — the state ball is one character and two cells, so s[:n] can be n+1 wide.
    """
    out, used = "", 0
    for ch in s:
        w = 2 if ch in BALLS_CHARS else 1
        if used + w > cells:
            break
        out += ch
        used += w
    return out, used


def frame(s, width):
    """Centre s in exactly `width` cells, clipping if it does not fit.

    Padding to the allocation is what packs the bar: kitty hands each tab
    (columns // ntabs) - 1 cells and abandons whatever a tab does not draw
    (kitty/tab_bar.py:763), so a tab that renders only its text leaves holes.

    Cost of the minimum: a padded tab claims its whole slot, so it stops donating
    slack to longer neighbours (kitty/tab_bar.py:786), and past roughly
    columns // MIN_CELLS tabs kitty stops drawing altogether and marks the
    overflow with a red ellipsis rather than shrinking everything further.
    """
    target = max(1, width)
    n = _cells(s)
    if n > target:
        head, used = _clip(s, target - 1)
        return head + " " * (target - 1 - used) + "…"
    pad = target - n
    return " " * (pad // 2) + s + " " * (pad - pad // 2)


def render(titles, columns):
    """Every tab's final string, each exactly as wide as its allocation.

    Disambiguate with no width pressure, ask what each name would like, let
    allocate() divide the bar, then squeeze and centre each name into what it got.
    """
    names = display_names(titles, 10 ** 6)
    widths = allocate([_cells(n) for n in names], columns)
    out = []
    for name, w in zip(names, widths):
        ball = name[:2] if name[:1] in BALLS else ""
        out.append(frame(ball + _fit(name[len(ball):], w - _cells(ball)), w))
    return out


# --- kitty-facing shell ------------------------------------------------------

_cache = {}


def _rendered(os_window_id, columns):
    from kitty.fast_data_types import get_boss
    tabs = get_boss().os_window_map[os_window_id].tabs
    titles = tuple(t.effective_title for t in tabs)
    key = (titles, columns)
    if key not in _cache:
        _cache.clear()
        _cache[key] = render(list(titles), columns)
    return _cache[key]


def draw_tab(draw_data, screen, tab, before, max_tab_length, index, is_last, extra_data):
    """Paint one tab. Registered by `tab_bar_style custom`.

    The layout pass draws a single cell on purpose. kitty sizes tabs from what
    that pass reports (kitty/tab_bar.py:768-788) and we do our own sizing, so
    claiming one cell each leaves every tab an under-achiever: kitty allocates
    nothing above the minimum, redistributes nothing, and its overflow guard
    (`cursor.x > columns - max_tab_lengths[i+1]`, :750) can only fire once the
    bar is genuinely full. The real pass then draws our own width, which sums to
    `columns` exactly rather than kitty's (columns // ntabs) - 1 per tab.

    cursor.bg/fg arrive already set to this tab's colours, so the centring pad
    paints as a solid block in the tab's own colour.
    """
    if extra_data.for_layout:
        screen.draw(" ")
        return screen.cursor.x
    try:
        cells = _rendered(draw_data.os_window_id, screen.columns)[index - 1]
    except Exception:
        cells = frame(tab.title, max_tab_length)
    if tab.needs_attention and draw_data.bell_on_tab:
        # Re-frame rather than splice: bell_on_tab is "🔔 " — two characters,
        # three cells — so overwriting a character-prefix changes the width.
        cells = frame(draw_data.bell_on_tab + cells.strip(), _cells(cells))
    screen.draw(cells)
    return screen.cursor.x
