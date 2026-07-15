// GENERATED CODE - DO NOT MODIFY BY HAND.
// Source: mobile/database/migrations/005_feed_vnext.sql

const v5FeedVNextStatements = <String>[
  r'''CREATE TABLE IF NOT EXISTS user_identity (
  local_user_id TEXT PRIMARY KEY,
  installation_id TEXT NOT NULL UNIQUE,
  remote_user_id TEXT,
  created_at TEXT NOT NULL,
  linked_at TEXT
)
''',
  r'''CREATE TABLE IF NOT EXISTS content_item_revisions (
  content_id TEXT NOT NULL,
  revision INTEGER NOT NULL CHECK (revision > 0),
  locale TEXT NOT NULL,
  type TEXT NOT NULL,
  payload_json TEXT NOT NULL,
  safety_json TEXT NOT NULL,
  media_json TEXT,
  published_at TEXT NOT NULL,
  starts_at TEXT,
  ends_at TEXT,
  source TEXT NOT NULL,
  checksum TEXT NOT NULL,
  PRIMARY KEY (content_id, revision, locale)
)
''',
  r'''CREATE TABLE IF NOT EXISTS feed_batches (
  batch_id TEXT PRIMARY KEY,
  created_at TEXT NOT NULL,
  expires_at TEXT,
  source TEXT NOT NULL,
  algorithm_revision TEXT NOT NULL,
  sync_state TEXT NOT NULL
)
''',
  r'''CREATE TABLE IF NOT EXISTS feed_assignments (
  assignment_id TEXT PRIMARY KEY,
  batch_id TEXT NOT NULL,
  content_id TEXT NOT NULL,
  content_revision INTEGER NOT NULL CHECK (content_revision > 0),
  locale TEXT NOT NULL,
  position INTEGER NOT NULL CHECK (position >= 0),
  assignment_reason TEXT NOT NULL,
  metadata_json TEXT NOT NULL,
  impressed_at TEXT,
  opened_at TEXT,
  skipped_at TEXT,
  FOREIGN KEY (batch_id) REFERENCES feed_batches(batch_id)
)
''',
  r'''CREATE UNIQUE INDEX IF NOT EXISTS feed_assignments_batch_position_idx
ON feed_assignments (batch_id, position)
''',
  r'''CREATE TABLE IF NOT EXISTS challenge_attempts (
  attempt_id TEXT PRIMARY KEY,
  assignment_id TEXT NOT NULL,
  content_id TEXT NOT NULL,
  content_revision INTEGER NOT NULL CHECK (content_revision > 0),
  status TEXT NOT NULL CHECK (status IN ('active', 'deferred', 'abandoned', 'attempted', 'completed')),
  selected_route TEXT NOT NULL CHECK (selected_route IN ('normal', 'low_pressure', 'advanced')),
  accepted_at TEXT NOT NULL,
  resolved_at TEXT,
  timezone_id TEXT NOT NULL,
  result_json TEXT,
  reward_applied_local INTEGER NOT NULL DEFAULT 0 CHECK (reward_applied_local IN (0, 1)),
  sync_state TEXT NOT NULL CHECK (sync_state IN ('pending', 'synced', 'rejected')),
  updated_at TEXT NOT NULL
)
''',
  r'''CREATE UNIQUE INDEX IF NOT EXISTS challenge_attempts_one_open_idx
ON challenge_attempts ((1))
WHERE status = 'active'
''',
  r'''CREATE INDEX IF NOT EXISTS challenge_attempts_history_idx
ON challenge_attempts (resolved_at DESC, accepted_at DESC)
''',
  r'''CREATE TABLE IF NOT EXISTS private_reflections (
  reflection_id TEXT PRIMARY KEY,
  attempt_id TEXT NOT NULL UNIQUE,
  fear_before INTEGER CHECK (fear_before BETWEEN 1 AND 10),
  feel_after INTEGER CHECK (feel_after BETWEEN 1 AND 10),
  want_repeat INTEGER CHECK (want_repeat IN (0, 1)),
  private_note TEXT,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  sync_preference TEXT NOT NULL DEFAULT 'signals_only' CHECK (sync_preference IN ('local_only', 'signals_only'))
)
''',
  r'''CREATE TABLE IF NOT EXISTS event_log_v2 (
  event_id TEXT PRIMARY KEY,
  local_user_id TEXT NOT NULL,
  installation_id TEXT NOT NULL,
  client_sequence INTEGER NOT NULL CHECK (client_sequence > 0),
  schema_version INTEGER NOT NULL CHECK (schema_version = 2),
  event_type TEXT NOT NULL,
  assignment_id TEXT,
  attempt_id TEXT,
  content_id TEXT,
  content_revision INTEGER,
  occurred_at_utc TEXT NOT NULL,
  timezone_id TEXT NOT NULL,
  timezone_offset_minutes INTEGER NOT NULL CHECK (timezone_offset_minutes BETWEEN -840 AND 840),
  payload_json TEXT NOT NULL,
  sync_status TEXT NOT NULL CHECK (sync_status IN ('pending', 'synced', 'rejected')),
  attempt_count INTEGER NOT NULL DEFAULT 0 CHECK (attempt_count >= 0),
  next_retry_at TEXT,
  last_error_code TEXT,
  received_server_at TEXT,
  UNIQUE (installation_id, client_sequence),
  CHECK ((content_id IS NULL AND content_revision IS NULL) OR (content_id IS NOT NULL AND content_revision > 0))
)
''',
  r'''CREATE INDEX IF NOT EXISTS event_log_v2_sync_idx
ON event_log_v2 (sync_status, next_retry_at)
''',
  r'''CREATE INDEX IF NOT EXISTS event_log_v2_attempt_idx
ON event_log_v2 (attempt_id, event_type)
''',
  r'''CREATE INDEX IF NOT EXISTS event_log_v2_occurred_idx
ON event_log_v2 (occurred_at_utc)
''',
  r'''CREATE TABLE IF NOT EXISTS projection_checkpoints (
  projection_name TEXT PRIMARY KEY,
  snapshot_json TEXT NOT NULL,
  last_applied_installation_id TEXT,
  last_applied_sequence INTEGER,
  updated_at TEXT NOT NULL,
  schema_version INTEGER NOT NULL
)
''',
  r'''CREATE TABLE IF NOT EXISTS event_quarantine (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  raw_row_json TEXT NOT NULL,
  reason TEXT NOT NULL,
  quarantined_at TEXT NOT NULL
)
''',
  r'''CREATE TABLE IF NOT EXISTS feature_flags_cache (
  flag_key TEXT PRIMARY KEY,
  value_json TEXT NOT NULL,
  fetched_at TEXT NOT NULL,
  expires_at TEXT
)
''',
  r'''CREATE TABLE IF NOT EXISTS media_cache_index (
  cache_key TEXT PRIMARY KEY,
  content_id TEXT NOT NULL,
  content_revision INTEGER NOT NULL,
  uri TEXT NOT NULL,
  checksum TEXT NOT NULL,
  byte_size INTEGER NOT NULL CHECK (byte_size >= 0),
  last_accessed_at TEXT NOT NULL,
  expires_at TEXT
)
''',
];
