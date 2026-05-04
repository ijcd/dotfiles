# Future Tools

Things to look into when there's time.

## atuin (shell history replacement)

https://atuin.sh — replaces `~/.zsh_history` with a SQLite database storing
per-command: command, cwd, exit code, duration, hostname, session ID, timestamp.

Replaces Ctrl-R with fuzzy/contextual searcher. Filter by cwd ("what did I run
in this directory") is the killer feature. Optionally syncs across machines via
self-hosted or hosted server.

Adds Rust binary dependency. Custom keybindings. Slight learning curve for
search UX.

Setup notes when ready:
- `brew install atuin` or via nix `programs.atuin.enable` (Home Manager)
- `atuin import auto` imports existing `~/.zsh_history`
- zsh init hook handles Ctrl-R rebinding

## Workspace launcher (terminal- and frontend-agnostic CLI)

Declarative workspace definitions in JSON/TOML, launched via a small Python
CLI (single file, stdlib only, ~300 LOC) that drives any terminal/multiplexer.

### Architecture

```
data: ~/.config/workspace/projects.json   (source of truth, terminal-neutral)
   │
   ▼
~/.local/bin/workspace                    (Python 3 stdlib, single file)
   │
   └── drivers: kitty | wezterm | tmux | iTerm | (none for leaf cmds)
```

### Per-level driver model

Each container (project/tab/pane) declares its own `driver` — the answer to
"what spawns my children?" Children inherit driver from parent if unset.
A leaf (`cmd` with no children) needs no driver.

| Level | Driver answers | Common values |
|---|---|---|
| Project | what spawns tabs | `kitty`, `wezterm`, `tmux` |
| Tab | what spawns panes within this tab | `kitty` (splits), `tmux`, `wezterm` |
| Pane (rare) | what spawns sub-panes | `tmux` usually |

The user's typical preference: project-level `kitty` (tab UI in kitty) +
selected tabs use `tmux` for explicit panes. Other tabs are leaf commands or
self-multiplexing tools (`devenv up`, `overmind start`) that need no driver.

### Data shape

```json
{
  "projects": {
    "liberties_www": {
      "driver": "kitty",
      "cwd": "~/work/theliberties/liberties_www",
      "tabs": [
        {
          "title": "claude",
          "cmd": "claude --dangerously-skip-permissions --continue"
        },
        {
          "title": "dev",
          "driver": "tmux",
          "session": "liberties-dev",
          "layout": "main-vertical",
          "panes": [
            { "cmd": "overmind start", "size": 0.6 },
            { "cmd": "psql liberties_www_dev" },
            { "cmd": "tail -f log/dev.log" }
          ]
        },
        { "title": "shell" }
      ]
    },
    "treehouse": {
      "driver": "kitty",
      "cwd": "~/work/treehouse",
      "tabs": [
        { "title": "claude", "cmd": "claude --dangerously-skip-permissions --continue" },
        { "title": "devenv", "cmd": "devenv up" },
        { "title": "shell" }
      ]
    }
  }
}
```

Tabs with just `cmd` are leaves — no inner driver needed. Tabs with `panes`
must declare a `driver` (or inherit one from their project) that knows how to
arrange them.

**Self-multiplexing commands** (`devenv up`, `overmind start`, `mprocs` etc.)
are leaf commands. They handle their own internal multiplexing — your
workspace tool doesn't need to know or care. Just `cmd: 'devenv up'`.

### Driver validity (containment rule)

**Inner driver must be containable by outer driver**: terminal emulators
(kitty, wezterm) host any process including multiplexers; multiplexers (tmux)
host only processes, not terminal-emulator UIs.

| Project driver | Tab driver | Valid |
|---|---|---|
| kitty | kitty (splits) | ✓ |
| kitty | tmux | ✓ user's preference |
| kitty | leaf cmd | ✓ |
| kitty | wezterm | ✗ |
| wezterm | wezterm | ✓ |
| wezterm | tmux | ✓ |
| wezterm | leaf cmd | ✓ |
| wezterm | kitty | ✗ |
| tmux | tmux (tmuxinator-style) | ✓ |
| tmux | leaf cmd | ✓ |
| tmux | kitty | ✗ |
| tmux | wezterm | ✗ |

The three practical patterns: `(kitty, kitty)`, `(kitty, tmux)`, `(tmux, tmux)`.
Tool should validate at config-load time and reject invalid pairings with
clear error.

### CLI surface

```
workspace up <name>           # launch (auto-detects outer if not specified)
workspace ls                  # list configured projects
workspace ls --running        # list workspaces currently up
workspace down <name>         # close all tabs/panes belonging to workspace
workspace edit                # open projects.json in $EDITOR
workspace capture <name>      # snapshot current terminal → draft project
workspace move-tab            # interactive helper
```

### Implementation details

- **Language**: Python 3 stdlib only. Apple-shipped 3.9 is the floor; nix
  install is 3.13. No pip, no PyYAML — JSON config side-steps deps.
- **Drivers**: Python classes implementing a small interface (spawn, list,
  set_title, move_tab). Composable — outer driver gets the inner driver as
  an argument when handling multi-pane tabs.
- **Distribution**: chezmoi-managed initially at `dot_local/bin/executable_workspace`.
  Extract to standalone repo if it stabilizes and others would use it.
- **Belongs in this repo** because the data and engine are personal; only
  emacs-specific binding lives in dotemacs (e.g., `(defun my/workspace-up
  (name) (shell-command (format "workspace up %s" name)))`).

### Replaces

The homemade `save-workspace`/`restore-workspace` scripts in `dot_local/bin/`
become recovery insurance via auto-snapshots, not the primary workflow. Once
this tool is built, the per-OS-window snapshot files can be deleted; the data
of "what projects exist" lives in `projects.json`.

### Templates (deferred)

Not needed for v1. Project configs are short enough to copy-paste. Revisit
if/when a fleet of >10 projects shows real repetition that would benefit from
templating + variable substitution.

### Capture flow

`workspace capture <name>` reads the current outer terminal's state via its
list API, normalizes captured cmdlines (e.g. `tmux -L overmind-XXX...` →
`overmind start`), produces a draft project entry, prints to stdout for the
user to paste/edit. Capture suggests, never commits.

### Tab indicator hooks (claude `cc:foo` + `⏳`/`…`)

Same terminal-agnostic dispatch: a small `tab-indicator` script reads
`$KITTY_LISTEN_ON` or `$WEZTERM_PANE` or `$TMUX` and uses the appropriate
CLI to set/strip the prefix. ~30 lines bash. Replaces current
`claude-start.sh`/`claude-stop.sh`.

## emacs desktop-save robustness

Per agent research, the canonical pattern for "survive an unexpected reboot
without losing buffers":

```elisp
(setq desktop-save t                    ; save without asking
      desktop-load-locked-desktop t     ; recover from crash (stale lock)
      desktop-auto-save-timeout 30)     ; flush every 30s idle
;; Read first; only enable save-mode if read succeeded — avoids clobbering
;; a good desktop with a fresh empty session on startup.
(when (file-exists-p (expand-file-name desktop-base-file-name desktop-dirname))
  (desktop-read))
(desktop-save-mode 1)
```

Upgrade path if named workspaces wanted: alphapapa's `activities.el` package.

## wezterm (terminal swap candidate, declarative workspaces native)

https://wezfurlong.org/wezterm/ — GPU-accelerated terminal by Wez Furlong with
**workspaces as a first-class concept** and Lua config. Solves the "no
declarative workspace tool for kitty" gap by being a different terminal that
ships the abstraction.

Why it's interesting:
- `wezterm cli spawn --workspace <name>` puts you in a named workspace
- Built-in mux server keeps state across UI restarts
- Lua config = real programmable launcher; one keybind prompts for project name,
  spawns it via `mux.spawn_window { workspace = name, cwd = ..., args = ... }`
- No tmux mental layer
- Active maintainer, cross-platform

Migration cost from kitty (~half day):
- Reimplement tab title hooks (⏳/…) via `format-tab-title` event in Lua
- Translate `kitten @ ...` calls (runclaude, etc.) to `wezterm cli ...`
- Redefine keybinds (defaults differ)
- Lose kitty-specific kittens (icat, clipboard) — wezterm has its own equivalents
- Reconfigure shell integration (direnv, fzf, zoxide should still work)

Suggested trial path: `brew install wezterm`, minimal Lua config, run side-by-
side with kitty for one project. Decide based on whether the workspace flow
feels right before committing to migration.

If adopted: replaces the elisp workspace launcher (above) and the homemade
`save-workspace`/`restore-workspace` scripts. Lua config in dotfiles becomes
the source of truth.
