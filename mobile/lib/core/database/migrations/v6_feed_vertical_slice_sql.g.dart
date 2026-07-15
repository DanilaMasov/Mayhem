// GENERATED CODE - DO NOT MODIFY BY HAND.
// Source: mobile/database/migrations/006_feed_vertical_slice.sql

const v6FeedVerticalSliceStatements = <String>[
  r'''ALTER TABLE content_item_revisions
ADD COLUMN active INTEGER NOT NULL DEFAULT 1 CHECK (active IN (0, 1))
''',
  r'''CREATE UNIQUE INDEX IF NOT EXISTS challenge_attempts_assignment_idx
ON challenge_attempts (assignment_id)
''',
];
