# OpenCode + Local Models Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Run OpenCode against local Ollama models by default (privacy), with a LiteLLM proxy that can route to cloud Claude for cost/overflow fallback.

**Architecture:** Three nix-installed binaries (`ollama`, `litellm`, `opencode`). Two Home-Manager launchd user-agents run `ollama serve` (:11434) and the LiteLLM proxy (:4000). OpenCode talks only to LiteLLM; all local-vs-cloud policy lives in `~/.config/litellm/config.yaml`. Config files are chezmoi-managed; the services + binaries are nix.

**Tech Stack:** nix-darwin + Home Manager, chezmoi, Ollama, LiteLLM (OpenAI-compatible proxy), OpenCode (`@ai-sdk/openai-compatible` provider).

## Global Constraints

- **Two config layers, do not cross them.** chezmoi = file content (`~/.config/**`, `~/.local/bin/**`). nix = binaries + launchd agents. Source-of-truth is this repo; never edit `~` destinations directly.
- **chezmoi source prefixes are load-bearing.** `dot_config/x` → `~/.config/x`; `executable_` → `+x`; `private_` → `0600`.
- **nix changes need `sudo darwin-rebuild switch --flake ~/.config/nix#bearcat`** to take effect (interactive sudo — run by the human via `! sudo ...`, NOT the agent). chezmoi changes need `chezmoi apply`.
- **Agent-runnable verification is `nix build .#darwinConfigurations.bearcat.system --no-link` (no sudo).** Runtime checks (curl endpoints, `opencode run`) happen AFTER the human runs the switch. Each service task separates the two.
- **No secrets in the nix store or git.** `ANTHROPIC_API_KEY` is sourced at launch from `~/.config/litellm/env` (0600, user-created, never committed). Local-only works without it.
- **Host is `bearcat`, user `ijcd`, arch aarch64-darwin, 64GB.** Home-Manager modules live in `dot_config/nix/common/`, imported by `common/default.nix`.
- **Model tags:** main `qwen3-coder:30b`, small `qwen3:4b`. Cloud smart tier `anthropic/claude-sonnet-5`. All three are swap-a-line changes.

---

### Task 1: Install ollama, litellm, opencode via nix

**Files:**
- Modify: `dot_config/nix/common/packages.nix` (add a new section in the `home.packages` list)

**Interfaces:**
- Produces: binaries `ollama`, `litellm`, `opencode` in the user profile; `pkgs.ollama`, `pkgs.litellm` referenced by Task 2/4.

- [ ] **Step 1: Add the three packages.** In `dot_config/nix/common/packages.nix`, inside the `home.packages` list, add a new section (place it after the `# Dev environment` block, before `# Cloud & infrastructure`):

```nix
      # ─────────────────────────────────────────────────────────────────────────
      # AI / local models  (see docs/superpowers/plans/2026-07-14-opencode-local-models.md)
      # Runtime + proxy are wired as launchd agents in common/local-ai.nix.
      # ─────────────────────────────────────────────────────────────────────────
      ollama             # local LLM runtime (Metal accel on arm64-darwin); serve on :11434
      litellm            # OpenAI-compatible routing proxy (local↔cloud) on :4000
      opencode           # terminal AI coding agent; talks only to the litellm proxy
```

- [ ] **Step 2: Materialize + eval-check.**

Run:
```bash
chezmoi apply ~/.config/nix/common/packages.nix
cd ~/.config/nix && nix eval .#darwinConfigurations.bearcat.system.outPath 2>&1 | tail -1
```
Expected: prints a `/nix/store/...-darwin-system-...` path (no eval error).

- [ ] **Step 3: Build the closure (proves the three packages resolve).**

Run: `cd ~/.config/nix && nix build .#darwinConfigurations.bearcat.system --no-link 2>&1 | tail -3; echo EXIT=$?`
Expected: `EXIT=0`.

- [ ] **Step 4: Commit.**

```bash
cd ~/.local/share/chezmoi
git add dot_config/nix/common/packages.nix
git commit -m "nix: add ollama, litellm, opencode for local-model coding"
```

- [ ] **Step 5: Human installs + verifies on PATH.** Ask the human to run:
```
! sudo darwin-rebuild switch --flake ~/.config/nix#bearcat
```
Then: `which ollama litellm opencode` — expected: three paths under `/etc/profiles/per-user/ijcd/bin` or the nix profile.

---

### Task 2: Ollama service (launchd agent)

**Files:**
- Create: `dot_config/nix/common/local-ai.nix`
- Modify: `dot_config/nix/common/default.nix` (add `./local-ai.nix` to `imports`)

**Interfaces:**
- Consumes: `pkgs.ollama` (Task 1).
- Produces: Ollama HTTP API at `http://127.0.0.1:11434` (native) + `/v1` (OpenAI-compat), used by Task 4. `OLLAMA_CONTEXT_LENGTH=32768` so tool calls don't truncate.

- [ ] **Step 1: Create `dot_config/nix/common/local-ai.nix`** with the ollama agent (litellm agent added in Task 4):

```nix
{ pkgs, config, ... }:
let
  homeDir = config.home.homeDirectory;
  logDir = "${homeDir}/.local/state/local-ai";
in
{
  # First launchd user-agents in this repo. Home Manager writes plists to
  # ~/Library/LaunchAgents and load/unloads them on activation.
  # Model blobs live at ~/.local/share/ollama (via the ~/.ollama symlink in
  # shell.nix); OLLAMA_MODELS is a shell-only var, so set the model path here
  # too — launchd agents do not source the login shell.
  home.activation.ensureLocalAiLogDir =
    config.lib.dag.entryAfter [ "writeBoundary" ] ''
      run mkdir -p "${logDir}"
    '';

  launchd.agents.ollama = {
    enable = true;
    config = {
      ProgramArguments = [ "${pkgs.ollama}/bin/ollama" "serve" ];
      EnvironmentVariables = {
        OLLAMA_MODELS = "${homeDir}/.local/share/ollama/models";
        OLLAMA_HOST = "127.0.0.1:11434";
        OLLAMA_CONTEXT_LENGTH = "32768"; # tool calls need headroom; docs bury this
      };
      RunAtLoad = true;
      KeepAlive = true;
      StandardOutPath = "${logDir}/ollama.out.log";
      StandardErrorPath = "${logDir}/ollama.err.log";
    };
  };
}
```

- [ ] **Step 2: Import it.** In `dot_config/nix/common/default.nix`, add `./local-ai.nix` to the `imports` list (after `./workspace.nix`):

```nix
  imports = [
    ./packages.nix
    ./git.nix
    ./shell.nix
    ./mise.nix
    ./direnv.nix
    ./emacs.nix
    ./workspace.nix
    ./local-ai.nix
  ];
```

- [ ] **Step 3: Materialize + build closure.**

Run:
```bash
chezmoi apply ~/.config/nix/common/local-ai.nix ~/.config/nix/common/default.nix
cd ~/.config/nix && nix build .#darwinConfigurations.bearcat.system --no-link 2>&1 | tail -3; echo EXIT=$?
```
Expected: `EXIT=0`.

- [ ] **Step 4: Commit.**

```bash
cd ~/.local/share/chezmoi
git add dot_config/nix/common/local-ai.nix dot_config/nix/common/default.nix
git commit -m "nix: ollama launchd agent (local model server, 32k ctx)"
```

- [ ] **Step 5: Human switches + verifies the server answers.** Human runs `! sudo darwin-rebuild switch --flake ~/.config/nix#bearcat`, then:

Run: `curl -sf http://127.0.0.1:11434/api/tags && echo " ← ollama UP"`
Expected: JSON (likely `{"models":[]}` before any pull) + `← ollama UP`.

- [ ] **Step 6: Verify Metal GPU acceleration (the spec's flagged risk).** After a model is pulled (Task 3), run a tiny prompt and inspect the runner. This is the one place nix's ollama could regress to CPU-only.

Run: `ollama run qwen3:4b "hi" --verbose 2>&1 | tail -3 && ollama ps`
Expected: `ollama ps` shows the model with a `100% GPU` (or mostly-GPU) PROCESSOR column. **If it shows `100% CPU`,** the nix build isn't using Metal — switch the ollama binary to the Homebrew formula (`brew install ollama`, point the agent's `ProgramArguments` at `/opt/homebrew/bin/ollama`); everything downstream is unchanged.

---

### Task 3: Model-pull helper (`ai-pull`)

**Files:**
- Create: `dot_local/bin/executable_ai-pull`

**Interfaces:**
- Consumes: running Ollama (Task 2).
- Produces: `ai-pull` on PATH; pulls the models LiteLLM (Task 4) references.

- [ ] **Step 1: Create `dot_local/bin/executable_ai-pull`:**

```bash
#!/usr/bin/env bash
# ai-pull — pull the local models OpenCode/LiteLLM expect. Idempotent (ollama
# skips already-present blobs). No args = pull the defaults; pass tags to override.
# Models are multi-GB and NOT pulled at nix/chezmoi apply time — run this once.
set -euo pipefail

if ! curl -sf http://127.0.0.1:11434/api/tags >/dev/null 2>&1; then
  echo "ollama not reachable on :11434 — is the launchd agent running?" >&2
  echo "  check: launchctl list | grep ollama ; tail ~/.local/state/local-ai/ollama.err.log" >&2
  exit 1
fi

models=("$@")
if [ "${#models[@]}" -eq 0 ]; then
  models=(qwen3-coder:30b qwen3:4b)
fi

for m in "${models[@]}"; do
  echo "==> ollama pull $m"
  ollama pull "$m"
done

echo "==> installed models:"
ollama list
```

- [ ] **Step 2: Materialize + confirm executable.**

Run:
```bash
chezmoi apply ~/.local/bin/ai-pull
test -x ~/.local/bin/ai-pull && echo "ai-pull is executable"
```
Expected: `ai-pull is executable`.

- [ ] **Step 3: Commit.**

```bash
cd ~/.local/share/chezmoi
git add dot_local/bin/executable_ai-pull
git commit -m "bin: ai-pull — pull local models for OpenCode/LiteLLM"
```

- [ ] **Step 4: Human pulls the models (multi-GB, one-time).** Requires Task 2 running.

Run: `ai-pull`
Expected: two `ollama pull` progress runs, then `ollama list` shows `qwen3-coder:30b` and `qwen3:4b`. (~20GB download; time depends on link.)

---

### Task 4: LiteLLM proxy — config + launcher + launchd agent

**Files:**
- Create: `dot_config/litellm/config.yaml`
- Modify: `dot_config/nix/common/local-ai.nix` (add `litellm` agent + launcher)

**Interfaces:**
- Consumes: `pkgs.litellm` (Task 1), Ollama on :11434 (Task 2), optional `~/.config/litellm/env` (`ANTHROPIC_API_KEY`).
- Produces: OpenAI-compatible endpoint `http://127.0.0.1:4000/v1` exposing model aliases `local`, `local-small`, `auto`, `smart`. Consumed by OpenCode (Task 5).

- [ ] **Step 1: Create `dot_config/litellm/config.yaml`** (the tunable routing core):

```yaml
# LiteLLM routing hub. OpenCode talks ONLY to this proxy; policy lives here.
# Aliases:
#   local        pure Ollama, never leaves the machine (privacy default)
#   local-small  small/fast Ollama, for OpenCode small_model (titles/summaries)
#   auto         Ollama first, fall back to cloud on context-overflow OR error
#   smart        cloud Claude (needs ANTHROPIC_API_KEY)
# NOTE: fallbacks are attached to `auto` ONLY — `local` stays pure on purpose.
model_list:
  - model_name: local
    litellm_params:
      model: openai/qwen3-coder:30b
      api_base: http://127.0.0.1:11434/v1
      api_key: "none"
  - model_name: local-small
    litellm_params:
      model: openai/qwen3:4b
      api_base: http://127.0.0.1:11434/v1
      api_key: "none"
  - model_name: auto
    litellm_params:
      model: openai/qwen3-coder:30b
      api_base: http://127.0.0.1:11434/v1
      api_key: "none"
  - model_name: smart
    litellm_params:
      model: anthropic/claude-sonnet-5
      api_key: os.environ/ANTHROPIC_API_KEY

router_settings:
  fallbacks: [{ "auto": ["smart"] }]
  context_window_fallbacks: [{ "auto": ["smart"] }]

litellm_settings:
  drop_params: true          # ignore params a local model doesn't understand
  # set_verbose: false
```

- [ ] **Step 2: Add the litellm launcher + agent to `local-ai.nix`.** Insert the launcher in the `let` block and the agent after the `ollama` agent:

In the `let` block (after `logDir = ...;`):
```nix
  # Wrapper: source the (optional, 0600, user-created) key file, then exec the
  # proxy. Keeps ANTHROPIC_API_KEY out of the nix store and out of git. Absent
  # key file → local aliases still work; only `smart`/`auto`-fallback need it.
  litellmLauncher = pkgs.writeShellScript "litellm-launch" ''
    set -a
    [ -f "${homeDir}/.config/litellm/env" ] && . "${homeDir}/.config/litellm/env"
    set +a
    exec ${pkgs.litellm}/bin/litellm \
      --config "${homeDir}/.config/litellm/config.yaml" \
      --host 127.0.0.1 --port 4000
  '';
```

After the `launchd.agents.ollama` block (still inside the module's attrset):
```nix
  launchd.agents.litellm = {
    enable = true;
    config = {
      ProgramArguments = [ "${litellmLauncher}" ];
      RunAtLoad = true;
      KeepAlive = true;
      StandardOutPath = "${logDir}/litellm.out.log";
      StandardErrorPath = "${logDir}/litellm.err.log";
    };
  };
```

- [ ] **Step 3: Materialize + build closure.**

Run:
```bash
chezmoi apply ~/.config/litellm/config.yaml ~/.config/nix/common/local-ai.nix
cd ~/.config/nix && nix build .#darwinConfigurations.bearcat.system --no-link 2>&1 | tail -3; echo EXIT=$?
```
Expected: `EXIT=0`.

- [ ] **Step 4: (Optional) create the cloud key file** so `smart`/`auto` fallback works. Local-only works without it.

Run: `install -m 600 /dev/null ~/.config/litellm/env && echo 'ANTHROPIC_API_KEY=sk-ant-REPLACE' >> ~/.config/litellm/env`
Then edit `~/.config/litellm/env` and paste the real key. (This file is NOT in chezmoi/git.)

- [ ] **Step 5: Commit.**

```bash
cd ~/.local/share/chezmoi
git add dot_config/litellm/config.yaml dot_config/nix/common/local-ai.nix
git commit -m "litellm: routing proxy (local default, auto→cloud fallback) + launchd agent"
```

- [ ] **Step 6: Human switches + verifies the proxy + a real local completion.** Human runs the switch, then:

```bash
curl -sf http://127.0.0.1:4000/health/liveliness && echo " ← litellm UP"
curl -sf http://127.0.0.1:4000/v1/models | grep -o '"id":"[^"]*"'
curl -sf http://127.0.0.1:4000/v1/chat/completions \
  -H 'Content-Type: application/json' \
  -d '{"model":"local","messages":[{"role":"user","content":"reply with the single word: ok"}]}' \
  | grep -o '"content":"[^"]*"'
```
Expected: `← litellm UP`; the four alias ids (`local`, `local-small`, `auto`, `smart`); and a completion containing `ok` (routed through Ollama — proves the full local path). Requires Task 3 models present.

---

### Task 5: OpenCode config → point at the router

**Files:**
- Create: `dot_config/opencode/opencode.json`

**Interfaces:**
- Consumes: LiteLLM `:4000/v1` aliases (Task 4).
- Produces: OpenCode defaulting to `router/local`, small tasks to `router/local-small`, cloud reachable via `/models`.

- [ ] **Step 1: Create `dot_config/opencode/opencode.json`:**

```json
{
  "$schema": "https://opencode.ai/config.json",
  "provider": {
    "router": {
      "npm": "@ai-sdk/openai-compatible",
      "name": "LiteLLM Router (local-first)",
      "options": {
        "baseURL": "http://127.0.0.1:4000/v1",
        "apiKey": "sk-local-noauth"
      },
      "models": {
        "local": { "name": "Local — qwen3-coder:30b (private)" },
        "local-small": { "name": "Local small — qwen3:4b" },
        "auto": { "name": "Auto — local, cloud on overflow/error" },
        "smart": { "name": "Cloud — Claude (Anthropic)" }
      }
    }
  },
  "model": "router/local",
  "small_model": "router/local-small"
}
```

- [ ] **Step 2: Materialize + validate JSON.**

Run:
```bash
chezmoi apply ~/.config/opencode/opencode.json
python3 -c "import json;json.load(open('$HOME/.config/opencode/opencode.json'));print('opencode.json valid')"
```
Expected: `opencode.json valid`.

- [ ] **Step 3: Commit.**

```bash
cd ~/.local/share/chezmoi
git add dot_config/opencode/opencode.json
git commit -m "opencode: default to local model via litellm router; cloud on demand"
```

- [ ] **Step 4: Human end-to-end check (requires Tasks 2–4 up + models pulled).**

Run: `opencode run "reply with the single word: ok"`
Expected: OpenCode responds `ok`, served by the local model through the router — nothing hit the cloud. Then, interactively, `opencode` → `/models` should list the four `router/*` aliases and let you switch to `smart`/`auto`.

---

### Task 6: Document the subsystem (ADR + README pointer)

**Files:**
- Create: `dot_config/nix/docs/decisions/0001-local-ai-launchd-services.md` (create `docs/decisions/` if absent)
- Modify: `dot_config/nix/README.md` (add a short "Local AI" pointer) — skip if no README section fits

**Interfaces:** none (docs only).

- [ ] **Step 1: Write the ADR** at `dot_config/nix/docs/decisions/0001-local-ai-launchd-services.md`:

```markdown
# 1. Local AI: Ollama + LiteLLM as launchd user-agents, OpenCode via a router

**Status**: Accepted (2026-07-14)

## Context
Wanted OpenCode coding with local models for privacy, plus an opt-in path to
cloud Claude for cost/overflow. Ollama plumbing (XDG symlink, OLLAMA_MODELS,
Spotlight exclusion) already existed but nothing was installed.

## Decision
Install ollama, litellm, opencode from nixpkgs. Run `ollama serve` (:11434) and
a LiteLLM proxy (:4000) as Home-Manager launchd user-agents (first in this repo).
OpenCode talks ONLY to LiteLLM; all local-vs-cloud policy is data in
`~/.config/litellm/config.yaml`. Default alias `local` never leaves the machine;
`auto` adds context-overflow + error fallback to `smart` (cloud). Cloud key is
sourced at launch from `~/.config/litellm/env` (0600, uncommitted).

## Alternatives considered
- Ollama from Homebrew — kept as escape hatch if nix Metal accel regresses.
- OpenCode → providers directly (no proxy) — loses central, tunable routing.
- Difficulty-based auto-routing — no such signal exists; auto = overflow+error only.
- npm/pip installs — rejected; breaks the declarative nix model.

## Consequences
- First launchd agents in the repo; future services follow this shape.
- Model blobs are runtime state (`ai-pull`), never nix/chezmoi-managed.
- Routing evolves by editing one YAML — no code changes to OpenCode.
```

- [ ] **Step 2: Commit.**

```bash
cd ~/.local/share/chezmoi
git add dot_config/nix/docs/decisions/0001-local-ai-launchd-services.md
git commit -m "docs: ADR-0001 local AI launchd services + router"
```

---

## Verification Summary (end state)

- `which ollama litellm opencode` → all on PATH
- `curl :11434/api/tags` → ollama up; `ollama list` → both models
- `curl :4000/health/liveliness` → "I'm alive!"; `curl :4000/v1/models` → 4 aliases
- `curl :4000/v1/chat/completions {model:"local"}` → local completion
- `opencode run "…"` → answered locally; `/models` lists `router/*`
- Cloud only engages when you pick `smart`/`auto` (and the key file exists)

## Not in this plan
- Difficulty-based routing (doesn't exist)
- Model pulls at apply time (multi-GB; `ai-pull` on demand)
- Changes to Anthropic secret storage beyond the optional env file
- Olla / custom-plugin routing
