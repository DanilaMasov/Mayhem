import json
import pathlib
import sqlite3


ROOT = pathlib.Path(__file__).resolve().parents[1]
SOURCES = [
    ROOT / "mobile/database/migrations/005_feed_vnext.sql",
    ROOT / "mobile/database/migrations/006_feed_vertical_slice.sql",
]


def statements():
    result = []
    for path in SOURCES:
        source = path.read_text(encoding="utf-8")
        result.extend(
            part.strip() for part in source.split("-- statement")[1:] if part.strip()
        )
    return result


def old_v4_database(connection):
    connection.executescript(
        """
        PRAGMA foreign_keys = ON;
        CREATE TABLE state_snapshots (
          id TEXT PRIMARY KEY,
          schema_version INTEGER NOT NULL,
          payload_json TEXT NOT NULL,
          updated_at TEXT NOT NULL
        );
        CREATE TABLE quest_events (
          id TEXT PRIMARY KEY,
          event_type TEXT NOT NULL,
          quest_id TEXT NOT NULL,
          payload_json TEXT NOT NULL,
          created_at TEXT NOT NULL,
          synced INTEGER NOT NULL DEFAULT 0,
          sync_status TEXT NOT NULL DEFAULT 'pending',
          sync_attempts INTEGER NOT NULL DEFAULT 0,
          last_sync_error TEXT NOT NULL DEFAULT '',
          next_retry_at TEXT
        );
        CREATE TABLE quest_reflections (
          id TEXT PRIMARY KEY,
          quest_id TEXT NOT NULL,
          fear_score INTEGER NOT NULL,
          feel_after_score INTEGER NOT NULL,
          want_repeat INTEGER NOT NULL,
          note TEXT NOT NULL DEFAULT '',
          metadata_json TEXT NOT NULL,
          created_at TEXT NOT NULL
        );
        CREATE TABLE app_metadata (
          key TEXT PRIMARY KEY,
          value TEXT NOT NULL,
          updated_at TEXT NOT NULL
        );
        """
    )
    connection.execute(
        "INSERT INTO state_snapshots VALUES (?, ?, ?, ?)",
        (
            "current",
            4,
            json.dumps({"xp": {"charisma": 10, "boldness": 20, "networking": 30}}),
            "2026-07-13T00:00:00Z",
        ),
    )


def assert_schema(connection):
    names = {
        row[0]
        for row in connection.execute(
            "SELECT name FROM sqlite_master WHERE type = 'table'"
        )
    }
    required = {
        "user_identity",
        "content_item_revisions",
        "feed_batches",
        "feed_assignments",
        "challenge_attempts",
        "private_reflections",
        "event_log_v2",
        "projection_checkpoints",
        "event_quarantine",
        "feature_flags_cache",
        "media_cache_index",
    }
    assert required.issubset(names), required - names
    content_columns = {
        row[1] for row in connection.execute("PRAGMA table_info(content_item_revisions)")
    }
    assert "active" in content_columns

    base_event = (
        "event-1",
        "local-1",
        "install-1",
        1,
        2,
        "challenge_accepted",
        "2026-07-13T12:00:00Z",
        "Europe/Moscow",
        180,
        "{}",
        "pending",
    )
    connection.execute(
        """
        INSERT INTO event_log_v2 (
          event_id, local_user_id, installation_id, client_sequence,
          schema_version, event_type, occurred_at_utc, timezone_id,
          timezone_offset_minutes, payload_json, sync_status
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        """,
        base_event,
    )
    try:
        connection.execute(
            """
            INSERT INTO event_log_v2 (
              event_id, local_user_id, installation_id, client_sequence,
              schema_version, event_type, occurred_at_utc, timezone_id,
              timezone_offset_minutes, payload_json, sync_status
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """,
            ("event-2",) + base_event[1:],
        )
    except sqlite3.IntegrityError:
        pass
    else:
        raise AssertionError("Client sequence uniqueness was not enforced")

    connection.execute(
        """
        INSERT INTO challenge_attempts (
          attempt_id, assignment_id, content_id, content_revision, status,
          selected_route, accepted_at, timezone_id, reward_applied_local,
          sync_state, updated_at
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        """,
        (
            "attempt-1",
            "assignment-1",
            "challenge-1",
            1,
            "active",
            "normal",
            "2026-07-13T12:00:00Z",
            "Europe/Moscow",
            0,
            "pending",
            "2026-07-13T12:00:00Z",
        ),
    )
    try:
        connection.execute(
            """
            INSERT INTO challenge_attempts (
              attempt_id, assignment_id, content_id, content_revision, status,
              selected_route, accepted_at, timezone_id, reward_applied_local,
              sync_state, updated_at
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """,
            (
                "attempt-2",
                "assignment-1",
                "challenge-1",
                1,
                "abandoned",
                "normal",
                "2026-07-13T12:01:00Z",
                "Europe/Moscow",
                0,
                "pending",
                "2026-07-13T12:01:00Z",
            ),
        )
    except sqlite3.IntegrityError:
        pass
    else:
        raise AssertionError("Assignment attempt uniqueness was not enforced")


def run_case(with_v4):
    connection = sqlite3.connect(":memory:")
    connection.execute("PRAGMA foreign_keys = ON")
    if with_v4:
        old_v4_database(connection)
    with connection:
        for statement in statements():
            connection.execute(statement)
    assert_schema(connection)
    if with_v4:
        count = connection.execute("SELECT COUNT(*) FROM state_snapshots").fetchone()[0]
        assert count == 1, "v5 schema migration removed the v4 snapshot"
    connection.close()


def run_rollback_case():
    connection = sqlite3.connect(":memory:")
    old_v4_database(connection)
    connection.commit()
    connection.execute("BEGIN")
    try:
        for statement in statements()[:3]:
            connection.execute(statement)
        connection.execute("CREATE TABLE broken (")
    except sqlite3.OperationalError:
        connection.rollback()
    else:
        raise AssertionError("Expected the simulated migration to fail")

    tables = {
        row[0]
        for row in connection.execute(
            "SELECT name FROM sqlite_master WHERE type = 'table'"
        )
    }
    assert "user_identity" not in tables, "failed migration was not rolled back"
    count = connection.execute("SELECT COUNT(*) FROM state_snapshots").fetchone()[0]
    assert count == 1, "failed migration lost the legacy snapshot"
    connection.close()


run_case(with_v4=False)
run_case(with_v4=True)
run_rollback_case()
print("Verified mobile v6 schema on real SQLite: fresh, v4 upgrade and rollback")
