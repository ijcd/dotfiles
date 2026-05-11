# smart_open.py — kitty hints kitten customization.
#
# Extends the built-in hints kitten to:
#   - match a wider set of path/filename tokens on screen
#   - resolve bare filenames against cwd + git root
#   - open the picked target in emacsclient (-n; non-blocking, daemon-aware)
#
# Wired up in kitty.conf via:
#   map kitty_mod+e kitten hints --type=regex --customize-processing kittens/smart_open.py
#
# The Mark/handle_result API is documented at:
# https://sw.kovidgoyal.net/kitty/kittens/hints/#customizing-hints

import os
import re
import subprocess
from pathlib import Path

# Token patterns we want to highlight. Three alternatives:
#   1. absolute or tilde paths:  ~/foo, /etc/hosts, $HOME/x
#   2. relative paths:           ./foo, ../bar/baz
#   3. bare filenames w/ ext:    spec.md, package.json, tsconfig.tsx
# Extension cap of 8 chars keeps things like tar.gz working without matching
# version strings or random word.word noise.
PATTERN = re.compile(
    r"""(
        (?:~|/|\$\w+/)[\w./~+\-$]+        # absolute / tilde / $VAR-rooted
      | \.{1,2}/[\w./+\-]+                # relative
      | \b[\w][\w+\-.]*\.\w{1,8}\b        # bare filename with extension
    )""",
    re.VERBOSE,
)


def mark(text, args, Mark, extra_cli_args, *a):
    """Called by hints kitten to find tokens worth labeling. Yields Mark."""
    for idx, m in enumerate(PATTERN.finditer(text)):
        yield Mark(idx, m.start(), m.end(), m.group(1), {})


def handle_result(args, data, target_window_id, boss):
    """Called after the user picks a label. Resolves each match and opens it."""
    for token in data.get('match', ()):
        target = _resolve(token)
        if target:
            # emacsclient -n is non-blocking; returns immediately, daemon opens
            # the buffer asynchronously. We don't wait or check exit.
            subprocess.Popen(['emacsclient', '-n', target])
        else:
            # Surface the miss in the kitty notifications/log; the kitten window
            # already closed by the time this runs.
            print(f"smart_open: no file resolved for '{token}'", flush=True)


def _resolve(token):
    """Resolve a token to a filesystem path, or None if no match.

    Tries direct (absolute / tilde / relative / env-var expanded) first; if the
    result isn't a real file, treats the token as a filename fragment and
    searches the cwd and git toplevel recursively.
    """
    # 1. Direct path resolution: expand ~ and $VARS, then try as-is.
    expanded = os.path.expandvars(os.path.expanduser(token))
    direct = Path(expanded)
    if direct.is_file():
        return str(direct.resolve())

    # 2. Fragment search: cwd, then git root (de-duped).
    roots = [Path.cwd()]
    try:
        gitroot = subprocess.check_output(
            ['git', 'rev-parse', '--show-toplevel'],
            stderr=subprocess.DEVNULL,
        ).decode().strip()
        gitroot_path = Path(gitroot)
        if gitroot and gitroot_path not in roots:
            roots.append(gitroot_path)
    except (subprocess.CalledProcessError, FileNotFoundError):
        pass

    # Use rglob with substring match; first hit wins. For multiple-match
    # disambiguation, we'd want a picker UI — future kitten.
    for root in roots:
        try:
            for found in root.rglob(f"*{token}*"):
                if found.is_file():
                    return str(found.resolve())
        except (PermissionError, OSError):
            continue

    return None
