# Mayhem Agent Contract

`docs/MAYHEM_CURRENT_SPEC_v1.2.md` is the authoritative execution contract. If
an older PRD, report, plan, README, ADR, or development log conflicts with it,
the current specification wins.

## Product boundary

- `mobile/` is the only production application target.
- Root web code is legacy reference material. Do not add product features to it.
- Kira and `.hatch-pets/` are personal tooling, not Mayhem. Never import, track,
  inspect for product direction, or delete the user's local files.
- Keep `.hatch-pets/` ignored. No companion work is authorized.

## Engineering rules

- Preserve local-first behavior and offline launch. Network availability must
  never be required to open the core application.
- Do not declare a software, CI, live-backend, simulator, device, or release
  gate complete without the evidence required by the specification.
- Implement one smallest complete vertical slice per branch/commit.
- Do not edit a migration already applied to any shared environment. Add a new
  forward-only migration for every subsequent fix.
- Do not silently add dependencies, install system software, alter SDKs, or
  change developer-machine configuration.
- Keep secrets, tokens, caches, builds, generated failures, signing material,
  and local environment overrides out of Git.
- Do not begin Production Composition Root, Season UX, visual redesign, or an
  invented phase until the current baseline PR and CI are green.
- Update `docs/CURRENT_STATUS.md` after every completed slice.

## Required workflow

Before implementation, read the authoritative specification and current
status. State the vertical outcome, run the relevant format/analyze/test and
contract checks, report exact evidence and unavailable gates, then commit with
a specific conventional message.

See [Current specification](docs/MAYHEM_CURRENT_SPEC_v1.2.md) and
[Current status](docs/CURRENT_STATUS.md).
