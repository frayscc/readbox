import os
import sqlite3
from contextlib import contextmanager
from pathlib import Path
from typing import Iterator


DATABASE_URL = os.getenv("DATABASE_URL", "sqlite:///./data/readbox.db")


def _database_path() -> Path:
    if not DATABASE_URL.startswith("sqlite:///"):
        raise RuntimeError("ReadBox MVP only supports sqlite:/// DATABASE_URL values")
    return Path(DATABASE_URL.removeprefix("sqlite:///"))


DB_PATH = _database_path()


def get_connection() -> sqlite3.Connection:
    DB_PATH.parent.mkdir(parents=True, exist_ok=True)
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    conn.execute("PRAGMA journal_mode=WAL")
    conn.execute("PRAGMA foreign_keys=ON")
    return conn


@contextmanager
def db() -> Iterator[sqlite3.Connection]:
    conn = get_connection()
    try:
        yield conn
        conn.commit()
    except Exception:
        conn.rollback()
        raise
    finally:
        conn.close()


def init_db() -> None:
    with db() as conn:
        conn.executescript(
            """
            CREATE TABLE IF NOT EXISTS items (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                url TEXT NOT NULL,
                canonical_url TEXT,
                title TEXT,
                author TEXT,
                site_name TEXT,
                excerpt TEXT,
                content_html TEXT,
                content_text TEXT,
                cover_url TEXT,
                status TEXT NOT NULL DEFAULT 'unread',
                is_favorite INTEGER NOT NULL DEFAULT 0,
                source TEXT,
                created_at TEXT NOT NULL,
                updated_at TEXT NOT NULL,
                read_at TEXT
            );

            CREATE VIRTUAL TABLE IF NOT EXISTS items_fts
            USING fts5(title, content_text, content='items', content_rowid='id');

            CREATE TRIGGER IF NOT EXISTS items_ai AFTER INSERT ON items BEGIN
                INSERT INTO items_fts(rowid, title, content_text)
                VALUES (new.id, new.title, new.content_text);
            END;

            CREATE TRIGGER IF NOT EXISTS items_ad AFTER DELETE ON items BEGIN
                INSERT INTO items_fts(items_fts, rowid, title, content_text)
                VALUES('delete', old.id, old.title, old.content_text);
            END;

            CREATE TRIGGER IF NOT EXISTS items_au AFTER UPDATE ON items BEGIN
                INSERT INTO items_fts(items_fts, rowid, title, content_text)
                VALUES('delete', old.id, old.title, old.content_text);
                INSERT INTO items_fts(rowid, title, content_text)
                VALUES (new.id, new.title, new.content_text);
            END;

            CREATE INDEX IF NOT EXISTS idx_items_status_created
            ON items(status, created_at DESC);

            CREATE INDEX IF NOT EXISTS idx_items_favorite_created
            ON items(is_favorite, created_at DESC);
            """
        )
