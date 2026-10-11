# Contributing to Warble Linux

Thanks for helping make an open sandbox OS better. This project is intentionally
small and script-first — clear diffs and reproducible builds matter more than
features.

## Development setup

```bash
git clone https://github.com/warbletech/warble-linux.git
cd warble-linux
make check          # lint + mock build (edition 1)
```

You do **not** need Arch or `mkarchiso` to contribute to package lists, docs,
or CI. Real ISO work needs an Arch host (see [docs/building.md](docs/building.md)).

## Workflow

1. Fork and branch from `main` (`feature/…` or `fix/…`).
2. Make focused changes.
3. Run `make lint` (and `make check` if you touch build scripts or editions).
4. Open a pull request with a short **why** and **how to test**.

## Package lists

- Edit files under [`editions/`](editions/) only.
- Do not hand-maintain long-lived `profile/packages.x86_64` (it is generated).
- **No AUR package names** in edition lists.
- Prefer official Arch package names that resolve on a stock Arch mirror.

## Scripts

- Entry point: `scripts/make-and-bake.sh`
- Root `make-and-bake.sh` is a thin compatibility wrapper
- Shebang: `#!/bin/bash`
- Prefer `[[ ]]` / `(( ))` and `set -euo pipefail` for new bash

## Commits

Use concise, present-tense messages:

- `feat: add ripgrep to developer edition`
- `fix: refuse empty release artifacts`
- `docs: clarify mock vs real ISO`

## Code of Conduct

Participation is governed by [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md).

## License

By contributing, you agree your contributions are licensed under the
**GNU GPL v2** (see [LICENSE](LICENSE)), matching this repository.
