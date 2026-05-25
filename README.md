# home-assistant-aquarea (personal fork)

![GitHub Release](https://img.shields.io/github/v/release/linean/home-assistant-aquarea?include_prereleases)

Personal fork of [wpatrik14/home-assistant-aquarea](https://github.com/wpatrik14/home-assistant-aquarea). Carries local additions on top of upstream until merged there. Release notes live in [GitHub Releases](https://github.com/linean/home-assistant-aquarea/releases).

## Local changes on top of upstream `main`

- Daily DHW heating and defrost cycle counter sensors (diagnostic; reset at local midnight). Upstream PR open.
- GitHub Actions workflows dropped (CI runs upstream only).
- Date-based release versions (e.g. `202605.3`) instead of SemVer.

## Branches

- `main` — personal releases.
- `upstream` — mirror of `wpatrik14/main` for syncing.

## Install via HACS

1. HACS → 3-dot menu → Custom repositories
2. Repository: `https://github.com/linean/home-assistant-aquarea`, Type: Integration
3. Download → pick latest release
4. Restart Home Assistant

For the original integration, docs, and feature list see [upstream](https://github.com/wpatrik14/home-assistant-aquarea).
