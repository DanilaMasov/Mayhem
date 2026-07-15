# ADR 0002: v1.1 development policy baseline

- Status: Accepted
- Date: 2026-07-13
- Specification: `MAYHEM_MASTER_PRODUCT_DESIGN_TECH_SPEC_v1.1.md`
- Reviewed specification SHA-256: `c88764bc26af6be96654f566f6498cdd4f0e6236ab77f6143e9d3c803c49cdc3`

## Context

Phases 0-3 were implemented against the previous master specification. The
v1.1 delta freezes development revisions for reward, difficulty, rank and
Momentum, clarifies local identity reset, and allows later phases to continue
while physical-device and external-service gates remain open behind disabled
production flags.

The audit found working typed policies and repositories, so replacing the
existing state model or SQLite schema would add migration risk without product
value. The corrections therefore remain inside existing domain and repository
boundaries.

## Decision

1. `reward_policy_dev_v1` uses 60% XP for Attempted, 100% for Completed, a
   single 10% reflection bonus, and a 10% advanced-route bonus only when the
   route is explicitly safety approved. Same content revision terminal rewards
   within a rolling seven-day window use 100%, 75%, then 50%. The final result
   uses integer half-up rounding and remains idempotent per attempt.
2. The already implemented difficulty formula is frozen as
   `difficulty_model_dev_v1`. It observes the primary trait only until context
   clusters exist. Completed deltas for easier/about/harder/stopped-early are
   `+0.30/+0.15/+0.05/-0.10`; Attempted deltas are
   `+0.15/+0.05/-0.15/-0.30`; explicit too-easy/too-intense skips are
   `+0.25/-0.40`; situation, interest and safety skips are zero. Rating clamps
   to `1.0..5.0`, confidence adds `0.08` and clamps to `0.0..1.0`.
3. The fallback coefficients printed in v1.1 section 18.4.1 are not applied,
   because a tested local model already existed at audit time. Any coefficient
   change requires a new revision, fixtures and an explicit reprojection
   decision.
   Legacy checkpoints without difficulty fields restore at neutral rating `2.0`
   and recommended intensity `2`, never outside the valid model range.
4. `rank_config_dev_v1` is the only development ladder used by the vNext flow.
   Thresholds live in domain configuration; widgets receive only resolved rank
   and progress. All-trait minimums prevent one-trait farming, and progress to
   the next rank is the lower of total-XP progress and the weakest required
   trait progress.
5. `momentum_policy_dev_v1` persists the accepted local date, UTC timestamp,
   IANA timezone and optional pending timezone-review record. A different local
   date less than 20 hours after the last accepted day remains pending and does
   not permanently increment the local streak.
6. Full local reset deletes local history and cached configuration, then creates
   a new `installation_id`, `local_user_id` and zeroed client sequence in the
   same transaction. All feature flags are reinserted as `false`.
7. Through Phase 4, local identity is not Supabase anonymous auth. No remote
   session, cloud deletion claim or authenticated sync is created by these
   changes.

## Data and compatibility

- No SQLite schema or database version change is required.
- New Momentum fields are additive checkpoint JSON. Missing fields restore to
  null and `momentum_policy_dev_v1`, preserving existing checkpoints.
- Existing terminal attempts remain immutable. Diminishing returns count only
  earlier rewarded attempts of the same content revision in the rolling window.
- Reset deliberately rotates both local identifiers. Normal upgrades preserve
  them.

## Verification contract

- Reward fixtures cover first, second and third-or-later rewards, half-up
  rounding, safety-approved and unapproved advanced routes.
- Difficulty golden vectors cover every frozen signal plus rating and confidence
  clamps.
- Rank fixtures assert every threshold and revision.
- Momentum fixtures cover duplicate local date, 19:59 pending, 20:00 acceptance
  and legacy JSON restoration.
- Identity reset fixtures assert immediate rotation and atomic failure on an
  invalid generated ID.

## Deferred gates

- Server authority and legitimate travel correction remain Phase 5 work.
- Physical-device performance acceptance remains open and cannot be closed by a
  simulator or emulator.
- OS backup exclusion for private note bodies requires platform verification
  before production launch.
- Production flags remain disabled until their phase-specific gates close.
