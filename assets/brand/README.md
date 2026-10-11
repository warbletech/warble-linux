# Warble Linux brand assets

All art in this directory belongs to **Warble Cloud** (Warble Tech / ChirpStack LLP) and is used here for Warble Linux.
It is **not** covered by the repository's code licence. Do not reuse it outside Warble projects without permission.
No third-party mascots or logos are included. In particular, **no Goose art**: goose is a third-party agent that Warble only links to upstream.

## What's here

| Path | What | Origin |
|------|------|--------|
| `source/warble-cloud-icon-512.png` | Warble Cloud bird-and-cloud icon, 512×385, transparent | Existing: `warbletech/warble-core` `apps/frontend/public/logo-512.png` |
| `source/warble-cloud-logo-276.png` | Warble Cloud logo with wordmark, 276×159, transparent | Existing: `warble-tech/warble-onboarding` `assets/brand/warble-logo.png` |
| `svg/mascot-{warble,starling,heron,murmuration}.svg` | Flat, geometric mascot marks, 1000×1000 | **New**, authored in `generate.py` |
| `svg/wallpaper-<edition>-{dark,light}.svg` | Wallpaper sources (1920×1080 viewBox; they reference the icon) | **New** |
| `png/mascots/mascot-*-1024.png` | Mascot exports, transparent | Rendered |
| `png/wallpapers/warble-linux-<edition>-<theme>-<W>x<H>.png` | 1920×1080, 2560×1440, 3840×2160 | Rendered |

Regenerate everything with `python3 assets/brand/generate.py` (needs `resvg-py` or `rsvg-convert`).
This also copies the 2560×1440 set to `profile/airootfs/usr/share/backgrounds/warble/`.
The live desktop sets the wallpaper there with `feh`, via Openbox autostart → `/usr/local/bin/warble-wallpaper`.
The edition is read from `/etc/warble-release`; set `WARBLE_THEME=light` for the light set.

## Edition → bird

Each bird's meaning comes from the Warble brand story (warble-tech `brand/index.html`) and the Heron Ops / ShrikeOps material:

| Edition | Bird | Why |
|---------|------|-----|
| minimal | **Warble** (songbird) | The brand: a clear, rich signal |
| developer | **Starling** | "Speaks the language of whatever flock it's in": a polyglot toolbox |
| cloud-native | **Heron** (Heron Ops) | Observes: the Kubernetes/container toolset |
| full | **Murmuration** | "The whole flock moving as one": every tool together |

## Palette and type

- **Warble Cloud logo** (sampled): navy `#102f5e`, `#12356a`; teal `#10a6b4`; sky `#99d0ea`, `#b6dbed`.
- **warble-tech brand page tokens:**
  - background `#0a0a0f` / `#13131f` / `#1a1a2e`
  - accent `#6c63ff`, `#4fc3f7`, `#a78bfa`, `#f472b6`
  - success `#34d399`, warning `#fbbf24`
  - text `#e8e8f0`, muted `#8888a0`
- **warbleoss.org:** `--heron #1e3a5f`, `--shrike #9b1b30`, accent `#0ea5e9`.
- **Fonts:** **Inter** (UI and headings) and **JetBrains Mono** (code), per the brand page.

## Bird family actually used across Warble (from the repos; nothing invented)

**Brand and company** (from the brand page):

| Name | Role |
|------|------|
| Warble | the brand |
| Chirp | ChirpStack LLP, the legal entity |
| Flock | the team philosophy |
| Shrike | ShrikeOps |
| Starling | Starling MCP / Starling EX |
| Murmuration | Murmuration Advisory |

**Products:**
- Heron (Heron Ops).
- Accipiter (Accipiter Striatus, the scaling agent).
- Kestrel: manifest scan, documented as a deprecated path.
- Merlin ("Merlin Suggest"): proposed only, in `warble-cms` docs.

**Mascots:**
- **Ruffle**, a neon owl, is the brand mascot and "product face" (`warble-murmurration` `frontend/public/ruffle_mascot.jpg`).
- The **Warble Army** roster (`reflexion-ai` `docs/marketing/WARBLE_ARMY_MASCOTS.md`) has a JPG for each bird in `frontend/public/army/`:

| Role | Bird |
|------|------|
| Observer | Starling |
| Actor | Hummingbird |
| Critic | Owl |
| Executor | Harrier Hawk |
| Knowledge | Raven |
| FinOps | Sparrow |
| Accipiter | Accipiter Hawk |

Existing raster logos for Heron Ops, ShrikeOps and Starling are opaque 1024² JPGs; the Starling one has a checkerboard baked in. They were not embedded here, and the flat marks in `svg/` are new.
