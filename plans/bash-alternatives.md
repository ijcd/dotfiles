# Future: Explore Bash Script Alternatives

**Status**: Future consideration - bring up occasionally when working on shell scripts

## Problem

Bash scripts in `~/.local/bin/` are:
- Hard to test
- Easy to get wrong (quoting, error handling, portability)
- Verbose for simple logic
- No type safety

## Options to Explore

| Language | Compiles To | Notes |
|----------|-------------|-------|
| **Amber** | Bash | Modern syntax, type-safe, most polished. [amber-lang.com](https://amber-lang.com) |
| **Batsh** | Bash + Batch | Cross-platform (bash + Windows) |
| **Bunster** | Bash | Go-like syntax |
| **Bashly** | Bash | Ruby DSL for CLI apps, generates bash |
| **Oil Shell** | N/A | Better shell, bash-compatible (not a compiler) |

## Candidates for Migration

Scripts that would benefit most from rewriting:
- `pg` - complex control flow, error handling
- Other multi-function CLI tools in `dot_local/bin/`

## When to Consider

- When a bash script gets complex enough to have bugs
- When adding new CLI tools
- When refactoring existing scripts

## Next Steps (when ready)

1. Try Amber on a simple script
2. Evaluate: readability, debugging, generated output quality
3. If good, migrate complex scripts incrementally
