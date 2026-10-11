# Editions guide

See also [editions/README.md](../editions/README.md).

## 1 — Minimal

Target: fastest boot, smallest package set for demos and browser/terminal
sandboxing.

Includes base desktop stack (Openbox, Firefox, Terminator) and core system
tools. No language toolchains or container runtimes.

## 2 — Developer

Adds:

- Go, Rust, Python, Node.js
- Neovim, tmux, ripgrep, fd, jq
- base-devel

GenAI / third-party CLIs that only exist in the AUR are intentionally omitted
from the package lists; document post-boot installers in issues/PRs instead of
adding AUR names to `editions/`.

## 3 — Cloud-Native

Adds:

- Docker + docker-compose
- kubectl, helm
- jq, yq

k3s is **not** included (it is not in the official Arch repositories). Install
it manually inside a running sandbox if you need a local cluster.

## 4 — Full

Union of developer and cloud-native. Default for CI “nightly” style prereleases.
