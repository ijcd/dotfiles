---
name: nix-search
description: Search NixOS packages at search.nixos.org before trying to build from source
---

# Nix Package Search

When you need a nix package, ALWAYS search for it first before building from source.

## How to Search

Use WebFetch to search search.nixos.org:

```
WebFetch url="https://search.nixos.org/packages?channel=unstable&query=PACKAGE_NAME" prompt="List all package names and versions that match"
```

## Common Patterns

- Package might have a different name (e.g., `asciinema_3` not `asciinema`)
- Check multiple package sets (python313Packages, nodePackages, etc.)
- Packages ending in numbers often indicate major versions

## Never Do This

- Don't build from source with `buildRustPackage`, `buildGoModule`, etc. until you've confirmed the package isn't already in nixpkgs
- Don't guess package names - search first

## Example

Looking for asciinema v3:
1. Search: `https://search.nixos.org/packages?channel=unstable&query=asciinema`
2. Find: `asciinema_3` (version 3.1.0)
3. Use: `pkgs.asciinema_3`
