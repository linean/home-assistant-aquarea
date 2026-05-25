# Changelog

All notable differences of this fork relative to [wpatrik14/home-assistant-aquarea](https://github.com/wpatrik14/home-assistant-aquarea).

Format loosely follows [Keep a Changelog](https://keepachangelog.com/). Versions use date-based scheme `YYYYMM.N`.

Upstream baseline: `wpatrik14/main @ 8d0e645` ("Refactoring").

---

## [202605.5] — 2026-05-25

### Changed
- Added this CHANGELOG.

---

## [202605.4] — 2026-05-25

### Changed
- README reduced to fork-specific information only (upstream description, installation steps, feature list, etc. dropped — see [upstream README](https://github.com/wpatrik14/home-assistant-aquarea) for that content).

---

## [202605.3] — 2026-05-25

### Changed
- README: added fork callout describing local fixes, upstream tracking branch, and HACS install path pointing at this repo.

---

## [202605.2] — 2026-05-25

### Added (cherry-picked from upstream)
- Fix today energy consumption sensors stuck at 0 (`ffcb6ae`).
- Bump aioaquarea 1.0.6 → 1.0.7 (`d2a74c5`).

---

## [202605.1] — 2026-05-25

### Fixed (fork-only)
- **Coordinator returning `None` on transient `AuthenticationError`.** `AquareaDataUpdateCoordinator._async_update_data` only re-raised `ConfigEntryAuthFailed` for `INVALID_USERNAME_OR_PASSWORD` and `INVALID_CREDENTIALS`. Any other auth error (expired session, server revoke, transient network issue during re-login) fell through silently. The coordinator returned `None`, and every entity dereferencing `coordinator.device` crashed with `AttributeError`. Now raises `UpdateFailed` for non-credential auth errors so HA handles it as a transient update failure. (`custom_components/aquarea/coordinator.py`)
- **Redundant double-refresh burst on HA startup/reload.** `async_setup_entry` called `async_config_entry_first_refresh()` per device, then immediately scheduled a second `async_refresh()` task per device. This doubled the Panasonic Cloud API load (device state + monthly consumption) on every HA boot — a real risk given documented IP-throttling behavior. The trailing loop has been removed. (`custom_components/aquarea/__init__.py`)

### Removed
- GitHub Actions workflows (`hassfest.yaml`, `hacs.yaml`, `release-drafter.yml`, `bump-aioaquarea.yml`). CI runs upstream only; this fork doesn't consume Actions minutes.

### Changed
- Versioning switched from SemVer (`1.0.x`) to date-based `YYYYMM.N`.
- HACS install metadata points at `linean/home-assistant-aquarea`.

---

## Branch layout in this fork

- `main` — personal releases (this changelog applies here).
- `upstream` — mirror of `wpatrik14/main` for syncing upstream changes before merging into `main`.

## Known outstanding bugs (not yet fixed in this fork)

The audit that produced 202605.1 also identified these — see commit history / TODO for context:

- Today energy sensor (`EnergyConsumptionSensor`) does not reset across midnight; can report yesterday's value briefly until the first new-day API entry arrives. (`sensor.py:362`)
- `EnergyAccumulatedConsumptionSensor` sets value to `None` when monthly fetch fails — causes a false positive delta in the HA Energy Dashboard on the next valid reading. (`sensor.py:256`)
- `_schedule_refresh` tasks created via `hass.async_create_task` are never stored or cancelled on entity removal/reload — accumulates on rapid commands; can wake into an unloaded coordinator. (`climate.py`, `water_heater.py`, `switch.py`, `select.py`)
- `climate.async_set_temperature` schedules a second delayed refresh even when `async_set_hvac_mode` already scheduled one (both called when HA sends combined `kwargs`). (`climate.py:239`)
- `WaterHeater.async_set_temperature` has no rollback on failed API command (optimistic value sticks until next poll). (`water_heater.py:142`)
- `AquareaForceDHWSwitch` / `ForceHeater` / `HolidayTimer` switches: no rollback on failed command, optimistic state can leak indefinitely. (`switch.py`)
