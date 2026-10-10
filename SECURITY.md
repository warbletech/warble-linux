# Security Policy

## Supported versions

| Version | Supported |
|---------|-----------|
| `main` (nightly / prerelease artifacts) | Yes — best effort |
| Tagged releases | Yes for the latest tag |

Warble Linux images are **ephemeral sandboxes**. Treat live sessions as untrusted
and do not store secrets on a running live system without full-disk encryption
you control.

## Reporting a vulnerability

Please **do not** open a public issue for security-sensitive reports.

1. Prefer [GitHub Security Advisories](https://github.com/warbletech/warble-linux/security/advisories/new) for this repository.
2. Include: impact, affected edition/build, reproduction steps, and any suggested fix.

We will acknowledge receipt as soon as practical and coordinate disclosure.

## Scope notes

- Mock ISO artifacts produced on Ubuntu CI are **not** bootable OS images; security
  review should focus on scripts, package selection, and real archiso profiles.
- Third-party software installed from Arch mirrors carries upstream risk; please
  report distro packaging issues that we introduced, and upstream issues to their
  respective projects when appropriate.
