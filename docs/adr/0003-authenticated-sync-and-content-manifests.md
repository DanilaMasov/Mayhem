# ADR 0003: Authenticated sync and versioned content manifests

- Status: accepted for repository implementation
- Date: 2026-07-13
- External validation: pending

## Context

The mobile product must remain useful before a remote account exists, while a
future Supabase session must provide authoritative cross-device projection,
remote content and Delete Everywhere. Local identity, private reflections and
optimistic rewards cannot be silently replaced by an auth implementation.

Content revisions are immutable, but remote publication and rollback require an
active set to change. Mutating an `active` field on an immutable revision would
make rollback internally contradictory.

## Decision

1. Local `local_user_id` and `installation_id` remain the offline identity.
   Supabase anonymous auth is a separate remote session. Registration binds the
   two identities and rejects later remote-user drift.
2. Access and refresh tokens live only behind `SecureSessionStore`. SQLite
   cannot implement that interface. Platform secure-storage selection remains
   an external/manual gate and does not add a package in this phase.
3. Local terminal events remain append-only and optimistic. The server returns
   a versioned authoritative projection; reconciliation reapplies only still
   pending events and never decreases longest Momentum history.
4. Event acknowledgements must exactly match the submitted batch. Event-level
   permanent failures are quarantined while attempts and private reflections
   remain local.
5. Content bodies remain immutable `content_item_revisions`. Publication uses
   versioned `content_manifests` and ordered `content_manifest_items`; switching
   the active manifest is the atomic activation and rollback boundary.
6. A remote feature flag can become true only when it names a valid capability
   revision supported by the client. Missing, unknown, malformed or duplicated
   records resolve to false.
7. Remote lifecycle work is protected by a separate local production gate.
   Repository implementation does not enable any remote operation by default.

## Consequences

- Offline onboarding, Feed fallback, attempts and progress remain available
  without Supabase.
- Server corrections are deterministic, revision-gated and exposed through an
  exactly-once local notice boundary.
- Content rollback does not rewrite or delete a published content revision.
- A real platform secure store, disposable Supabase deployment, RLS/RPC tests,
  anonymous-auth abuse controls and content-publisher transaction still require
  external validation before related flags can be enabled.
