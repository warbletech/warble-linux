# Editions

Warble Linux ships four sandbox variants. Package lists live here so they are
reviewable in pull requests without scanning a generated `profile/packages.x86_64`.

| ID | Name | Package file | Intent |
|----|------|--------------|--------|
| 1 | **minimal** | `minimal.packages` (+ `base.packages`) | Live desktop + terminal only |
| 2 | **developer** | `developer.packages` | Languages, editors, CLI tooling |
| 3 | **cloud-native** | `cloud-native.packages` | Containers & Kubernetes clients |
| 4 | **full** | `full.packages` | Developer + cloud-native |

## Rules

1. **Official Arch repos only** in these lists (no AUR package names).
2. Comments start with `#` and are stripped by the bake script.
3. `scripts/make-and-bake.sh` merges `base.packages` + the edition file into
   `profile/packages.x86_64` before calling `mkarchiso` or writing mock artifacts.

## Build

```bash
make bake EDITION=1     # minimal
make bake EDITION=4     # full
make all-editions       # 1 through 4
```
