# Architecture

Warble Linux is a **sandbox-oriented live image** aimed at isolated testing,
learning, and cloud-native workflows. It is **not** a general-purpose desktop
distro like Omarchy; it is a rebuildable artifact pipeline plus an archiso
profile.

## Layout

```text
warble-linux/
├── editions/           # Human-edited package lists (source of truth)
├── profile/            # archiso profile (airootfs + generated packages.x86_64)
├── scripts/            # Build & publish tooling
├── docs/               # Design / build docs
├── assets/             # Branding
├── out/                # Build products (gitignored)
├── Makefile            # Contributor entry points
└── .github/workflows/  # CI bake + prereleases
```

## Build pipeline

```text
editions/*.packages
        │
        ▼
scripts/make-and-bake.sh  ──► profile/packages.x86_64
        │
        ├─► mkarchiso (Arch + complete profile) ──► bootable ISO
        │
        └─► mock path (Ubuntu CI / incomplete profile) ──► non-empty ISO-like artifact
        │
        └──► WSL tarball · OVF · Vagrant .box · MANIFEST · SHA256SUMS
```

## Editions

| ID | Name | Role |
|----|------|------|
| 1 | minimal | Smallest live GUI + terminal |
| 2 | developer | Languages and editor stack |
| 3 | cloud-native | Containers / K8s clients |
| 4 | full | Union of 2 + 3 |

Package policy: **Arch official repositories only** in edition files. AUR-only
names must not appear in `editions/` (they break pacman on real builds).

## Runtime (live image goals)

When a full ISO is baked:

- **Openbox** session with Firefox and Terminator
- **nftables** baseline firewall
- Helpers under `/usr/local/bin` (`mount-wsl.sh`, `mount-vagrant.sh`, `mount-filestorage.sh`)
- Optional welcome dialog via `profile.d`

## Relationship to Omarchy

Omarchy is a full opinionated Arch desktop. Warble Linux is a **separate
product**: ephemeral sandbox images and multi-format packaging. It may live as
a sibling checkout under a monorepo for convenience, but it has its own git
remote (`warbletech/warble-linux`) and release cycle.

## Status

| Component | Status |
|-----------|--------|
| Mock artifacts + CI prerelease | Working |
| Modular editions + Makefile | Working |
| Full releng-style bootloaders | WIP |
| Real rootfs for WSL / Vagrant | Stubs only |
| GCP Artifact Registry | Optional script (`DRY_RUN` default) |
