# OpenCode + local models (privacy-first hybrid)

**Status**: Approved design — 2026-07-14

## Goal

Run [OpenCode](https://opencode.ai) against **local models by default** (privacy),
with the **ability to route to cloud Claude for cost/quality tradeoffs** (hybrid).
Local by default — nothing leaves the machine unless explicitly routed out.

Hardware: M3 Max, 64GB, arm64. Comfortably runs 30B-class quantized coders with Metal.

## Architecture

OpenCode talks to **one** endpoint — a LiteLLM proxy. All local-vs-cloud policy lives
in the proxy's YAML, version-controlled and tunable. OpenCode config never changes again.

```
OpenCode  (nix pkg, ~/.config/opencode/opencode.json)
   │   one provider "router" → http://localhost:4000/v1
   ▼
LiteLLM proxy  (nix pkg, launchd user-agent :4000, ~/.config/litellm/config.yaml)
   ├─ "local"       → ollama/qwen3-coder:30b     (privacy default)
   ├─ "local-small" → ollama/qwen3:4b            (titles/summaries via small_model)
   ├─ "smart"       → anthropic/claude-…         (cloud, ANTHROPIC_API_KEY)
   └─ "auto"        → local, fall back to smart on context-overflow / error
   │
   ├──▶ Ollama  (nix pkg, launchd user-agent :11434) → ~/.local/share/ollama  (existing plumbing)
   └──▶ Anthropic API (cloud)
```

Rationale: routing policy is **data, not code**. Start privacy-only; dial in cost-mode
from observed spend. No difficulty-prediction — that signal doesn't exist; "auto" =
context-overflow + failure fallback only.

## Components

| Piece | Layer | File |
|-------|-------|------|
| `ollama`, `litellm`, `opencode` binaries | nix | `dot_config/nix/common/packages.nix` |
| ollama + litellm always-on services | nix (home-manager launchd agents) | new `dot_config/nix/common/local-ai.nix`, imported by home config |
| OpenCode config (points at router) | chezmoi | `dot_config/opencode/opencode.json` |
| LiteLLM routing rules | chezmoi | `dot_config/litellm/config.yaml` |
| Model pull helper (`ai-pull`) | chezmoi | `dot_local/bin/executable_ai-pull` |
| Model blobs / Spotlight excl / `OLLAMA_MODELS` | *already present* | `shell.nix`, `spotlight.nix` |

Services run as **home-manager launchd agents** (declarative, autostart on login) — the
imperative shell: nix supplies binaries, launchd wires up the side-effecting daemons.

## OpenCode config (`~/.config/opencode/opencode.json`)

- `$schema` = `https://opencode.ai/config.json`
- one `provider.router` → `@ai-sdk/openai-compatible`, `baseURL: http://localhost:4000/v1`,
  models: `auto`, `local`, `local-small`, `smart`
- `model` = `router/local` (privacy-first default)
- `small_model` = `router/local-small` (background chatter stays local)
- cloud reached only via `/models` → `router/smart` or `router/auto`

## LiteLLM config (`~/.config/litellm/config.yaml`) — the tunable core

- `model_list`: the four aliases above → their backends
- Ollama backend: OpenAI-compatible at `http://localhost:11434/v1`; bump `num_ctx` to
  16k–32k or tool calls silently fail
- Anthropic backend: `ANTHROPIC_API_KEY` from env (no change to secret storage)
- `router_settings`: `context_window_fallbacks` (overflow → smart) + `fallbacks`
  (local error → smart), wired but only reachable through the `auto` alias
- cost tracking on — see cloud spend before making routing aggressive

## Models (swap via `ai-pull` + one config line)

- **qwen3-coder:30b** — main coder, tool-capable, fits 64GB
- **qwen3:4b** — small/fast for titles/summaries
- Not pulled at apply-time (multi-GB, user-chosen); `ai-pull` fetches on demand

## Decisions (all reversible)

| Decision | Chose | Reversal |
|----------|-------|----------|
| Local runtime | Ollama from **nix** | Verify Metal GPU accel at first run; if CPU-only, escape hatch is Homebrew `ollama` formula — same config otherwise |
| Main model | qwen3-coder:30b | `ai-pull <model>` + edit alias |
| Small model | qwen3:4b | same |
| Default routing | local-only | flip OpenCode `model` to `router/auto` for cost-mode |
| Proxy | LiteLLM | lighter alt: Olla (weaker cost tooling) |

## Open risk to verify during implementation

**Metal acceleration under nixpkgs `ollama` on aarch64-darwin.** If first-run inference
is CPU-only (slow), switch the ollama binary to the Homebrew formula; everything
downstream (LiteLLM, OpenCode, launchd agent shape) is unaffected.

## Not in this pass

- No difficulty-based auto-routing (doesn't exist)
- No model pulls during `nix`/`chezmoi apply`
- No changes to Anthropic secret storage (stays env-var)
- No Olla/custom-plugin routing
