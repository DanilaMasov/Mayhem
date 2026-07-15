-- MAYHEM local database v6: Phase 3 vertical-slice invariants.

-- statement
ALTER TABLE content_item_revisions
ADD COLUMN active INTEGER NOT NULL DEFAULT 1 CHECK (active IN (0, 1))

-- statement
CREATE UNIQUE INDEX IF NOT EXISTS challenge_attempts_assignment_idx
ON challenge_attempts (assignment_id)
