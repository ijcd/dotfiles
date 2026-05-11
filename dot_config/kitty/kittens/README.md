# kittens — local kitty extensions

A small collection of kitty kittens that buff up the default terminal experience
for this dotfiles setup. Each kitten is a single Python file using kitty's
public kitten API.

Wired up via `map` lines in `../kitty.conf`. To reload after editing, hit
**Ctrl+Shift+F5** (kitty's default config-reload shortcut) or restart kitty.

## Kittens

### `smart_open.py`

Hints-kitten customization. Press the bound key to highlight every visible
path *or* bare filename-with-extension, type the letter for the one you want,
it opens in `emacsclient -n` (non-blocking; needs the emacs daemon running).

Extends the built-in `hints --type=path` two ways:

1. **Wider match** — recognizes bare filenames like `spec.md` even when the
   full path isn't on screen.
2. **Fragment resolution** — if the picked token isn't a real path, searches
   `cwd` + git toplevel for a matching file; first hit wins.

Binding (in `../kitty.conf`):
```
map kitty_mod+e kitten hints --type=regex --customize-processing kittens/smart_open.py
```

Tuning: the token regex lives at the top of the file. If you find it too
greedy or too sparse, edit `PATTERN`.

## Adding a new kitten

1. Drop a `.py` file in this directory.
2. For hints-style kittens, implement `mark()` and `handle_result()` per
   <https://sw.kovidgoyal.net/kitty/kittens/hints/#customizing-hints>.
3. For action kittens (no hint UI), implement `main(args)` and reference
   <https://sw.kovidgoyal.net/kitty/kittens/custom/>.
4. Add a `map` line in `../kitty.conf` and a section in this README.

## Ideas / TODO

- `find_open` — prompt for a filename fragment, search fs, present picker UI
  for ambiguous matches (versus smart_open's "first match wins").
- `claude_tabs` — jump between kitty tabs running active Claude Code sessions
  by reading `~/.claude/sessions/<pid>.json`.
- `freshness_popup` — `nixhome-rebuild`'s freshness summary as an on-demand
  overlay rather than scrolling output.
