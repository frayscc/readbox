from __future__ import annotations

from pathlib import Path

import pytest

from app import database


def test_init_db_records_applied_migrations(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    monkeypatch.setattr(database, "DB_PATH", tmp_path / "readbox.db")

    database.init_db()
    database.init_db()

    with database.db() as conn:
        migrations = conn.execute(
            "SELECT version, name FROM schema_migrations ORDER BY version"
        ).fetchall()
        item_columns = {
            row["name"] for row in conn.execute("PRAGMA table_info(items)").fetchall()
        }

    assert [(row["version"], row["name"]) for row in migrations] == [
        (1, "initial_items_schema")
    ]
    assert {"id", "url", "content_html", "content_text", "read_at"}.issubset(
        item_columns
    )
