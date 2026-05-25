# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Is

A Home Assistant custom integration for Panasonic Aquarea heat pumps. It consists of two parts:
1. **`custom_components/aquarea/`** — the HA integration (editable)
2. **`aioaquarea/`** — the upstream library source that wraps the Panasonic Aquarea Smart Cloud API (**read-only** — do not modify; changes must go upstream)

## Documentation

- `docs/integration_overview.md` — architecture, data flow, and entity implementation details for the HA integration
- `docs/aioaquarea_library.md` — aioaquarea library internals: auth flow, data models, API endpoints, JSON examples
- `docs/improvements.md` — known bugs and planned architectural improvements
- `CHANGELOG.md` (on `main` branch only) — fork-vs-upstream diffs and known outstanding bugs from 2026-05 audit

## Fork operations (this checkout is a personal fork)

### Remotes
- `origin` → `wpatrik14/home-assistant-aquarea` (upstream, read-only)
- `linean` → personal fork (push target for everything)

### Branch layout on `linean`
- `main` — personal releases with local fixes (date-versioned `YYYYMM.N`, not SemVer)
- `upstream` — mirror of `wpatrik14/main` for syncing upstream changes

Sync upstream into fork:
```
git fetch origin
git push linean origin/main:upstream
git checkout main && git merge upstream && git push linean main
```

### Release workflow
**Only bump `custom_components/aquarea/manifest.json` `version` when there are actual addon code changes (anything under `custom_components/aquarea/`).** Docs-only changes (README, CHANGELOG) must NOT bump the version — users would re-download identical addon files via HACS.

When addon code changes:
1. Edit `custom_components/aquarea/manifest.json` → bump `version` to next `YYYYMM.N`
2. Update `CHANGELOG.md`
3. Commit
4. `git tag -a <version> -m "Release <version>"`
5. `git push linean main && git push linean <version>`
6. `gh release create <version> --repo linean/home-assistant-aquarea --title <version> --notes "..."`

### HACS
- Install URL: `https://github.com/linean/home-assistant-aquarea`
- HACS reads GitHub releases; both tag and release object required

### Fork divergence notes
- `.github/workflows/` deleted on `linean/main`; do NOT reintroduce
- `CHANGELOG.md` baseline: `wpatrik14/main @ 8d0e645`
- Non-`main` branches (`fix-*`) still carry original upstream README/manifest — fork-specific content lives on `main` only

## Commands

### CI Validation
The two GitHub Actions workflows validate:
- **hassfest** (`.github/workflows/hassfest.yaml`) — HA integration correctness
- **HACS** (`.github/workflows/hacs.yaml`) — HACS compatibility

There is no automated test suite.

### Installing the library for Development
```bash
# Install the bundled aioaquarea in editable mode (read-only source — do not modify)
cd aioaquarea && pip install -e .
```

## Architecture

### Data Flow

```
Config Flow (config_flow.py)
  → creates AquareaClient (aioaquarea)
  → discovers devices
  → creates one AquareaDataUpdateCoordinator per device (coordinator.py)
  → platforms create entities that subscribe to the coordinator
```

### Coordinator Polling Intervals
- **1 minute**: device state (`device.refresh_data()`)
- **15 minutes**: daily energy consumption
- **60 minutes**: monthly energy consumption

### Entity Pattern
All entities extend HA base classes and `CoordinatorEntity`. After sending a command, entities apply **optimistic state updates** and schedule a 5–10 second delayed refresh to confirm the change from the device.

### aioaquarea Library (key files)

| File | Role |
|------|------|
| `aioaquarea/core.py` | `AquareaClient` — main entry point |
| `aioaquarea/auth.py` | OAuth2/OIDC with PKCE; scrapes HTML for auth codes; handles app version headers |
| `aioaquarea/api_client.py` | HTTP wrapper with Panasonic-specific headers |
| `aioaquarea/device_manager.py` | Device discovery and status queries |
| `aioaquarea/device_control.py` | Command execution |
| `aioaquarea/consumption_manager.py` | Hourly/daily/monthly energy stats |
| `aioaquarea/data.py` | Data models and enums for device state |
| `aioaquarea/entities.py` | Zone, tank, and sensor entity models |

### Integration Platforms

| Platform | What it exposes |
|----------|----------------|
| `climate.py` | Heating/cooling zones (HVAC modes, temperature, ECO/COMFORT presets) |
| `water_heater.py` | DHW tank control |
| `sensor.py` | Temperature, energy consumption, direction, status |
| `binary_sensor.py` | Error flags, defrost status |
| `switch.py` | ECO/COMFORT, powerful mode toggles |
| `select.py` | Quiet mode, powerful time selection |
| `button.py` | One-shot actions (refresh, force DHW, defrost) |

### Minimum Requirements
- Home Assistant 2024.2.0+
- Python 3.9+

## Key Constraints

- **One Panasonic account per HA instance** — the API does not support concurrent sessions from multiple clients on the same account.
- The auth flow in `aioaquarea/auth.py` scrapes HTML pages; it is fragile to Panasonic server changes and includes app version strings that may need updating.
- Energy data from the API is often delayed or unstable; the coordinator handles this with tiered intervals and caching.
- Translations live in `custom_components/aquarea/translations/` (cs, en, es, it, lt, nl, pl, ru, sk).
