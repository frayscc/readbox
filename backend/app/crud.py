from __future__ import annotations

from datetime import datetime, timezone
import logging
import sqlite3
from typing import Any

from .database import db
from .extractor import extract_article
from .schemas import ItemCreate, ItemUpdate


logger = logging.getLogger(__name__)
SUMMARY_COLUMNS = """
    id, url, canonical_url, title, author, site_name, excerpt, cover_url,
    status, is_favorite, source, created_at, updated_at, read_at
"""
SUMMARY_COLUMNS_WITH_TABLE = """
    items.id, items.url, items.canonical_url, items.title, items.author,
    items.site_name, items.excerpt, items.cover_url, items.status,
    items.is_favorite, items.source, items.created_at, items.updated_at,
    items.read_at
"""


def now_iso() -> str:
    return datetime.now(timezone.utc).isoformat()


def row_to_item(row: Any) -> dict[str, Any]:
    item = dict(row)
    item["is_favorite"] = bool(item["is_favorite"])
    return item


def create_item(payload: ItemCreate) -> dict[str, Any]:
    title = payload.title or str(payload.url)
    created_at = now_iso()

    with db() as conn:
        cur = conn.execute(
            """
            INSERT INTO items (
                url, canonical_url, title, author, site_name, excerpt,
                content_html, content_text, cover_url, status, is_favorite,
                source, created_at, updated_at
            )
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, 'unread', 0, ?, ?, ?)
            """,
            (
                str(payload.url),
                None,
                title,
                None,
                None,
                None,
                None,
                None,
                None,
                payload.source,
                created_at,
                created_at,
            ),
        )
        row = conn.execute("SELECT * FROM items WHERE id = ?", (cur.lastrowid,)).fetchone()
        return row_to_item(row)


def extract_item_content(item_id: int) -> None:
    item = get_item(item_id)
    if not item:
        return

    url = item["url"]
    logger.info("Starting article extraction", extra={"item_id": item_id, "url": url})
    extracted = extract_article(url)
    data = extracted.dict()
    updated_at = now_iso()

    title = data.get("title") or item.get("title") or url

    with db() as conn:
        conn.execute(
            """
            UPDATE items
            SET canonical_url = COALESCE(?, canonical_url),
                title = ?,
                author = COALESCE(?, author),
                site_name = COALESCE(?, site_name),
                excerpt = COALESCE(?, excerpt),
                content_html = COALESCE(?, content_html),
                content_text = COALESCE(?, content_text),
                cover_url = COALESCE(?, cover_url),
                updated_at = ?
            WHERE id = ?
            """,
            (
                data.get("canonical_url"),
                title,
                data.get("author"),
                data.get("site_name"),
                data.get("excerpt"),
                data.get("content_html"),
                data.get("content_text"),
                data.get("cover_url"),
                updated_at,
                item_id,
            ),
        )
    logger.info("Finished article extraction", extra={"item_id": item_id, "url": url})


def list_items(
    status: str = "unread",
    favorite: bool | None = None,
    limit: int = 30,
    offset: int = 0,
) -> list[dict[str, Any]]:
    clauses: list[str] = []
    params: list[Any] = []

    if status == "all":
        clauses.append("status != 'deleted'")
    else:
        clauses.append("status = ?")
        params.append(status)

    if favorite is not None:
        clauses.append("is_favorite = ?")
        params.append(1 if favorite else 0)

    sql = f"""
        SELECT {SUMMARY_COLUMNS} FROM items
        WHERE {" AND ".join(clauses)}
        ORDER BY created_at DESC
        LIMIT ? OFFSET ?
    """
    params.extend([limit, offset])

    with db() as conn:
        rows = conn.execute(sql, params).fetchall()
        return [row_to_item(row) for row in rows]


def get_item(item_id: int) -> dict[str, Any] | None:
    with db() as conn:
        row = conn.execute("SELECT * FROM items WHERE id = ?", (item_id,)).fetchone()
        return row_to_item(row) if row else None


def update_item(item_id: int, payload: ItemUpdate) -> dict[str, Any] | None:
    current = get_item(item_id)
    if not current:
        return None

    updates: list[str] = []
    params: list[Any] = []
    if payload.status is not None:
        updates.append("status = ?")
        params.append(payload.status)
        if payload.status == "read" and current.get("read_at") is None:
            updates.append("read_at = ?")
            params.append(now_iso())
        if payload.status == "unread":
            updates.append("read_at = NULL")
    if payload.is_favorite is not None:
        updates.append("is_favorite = ?")
        params.append(1 if payload.is_favorite else 0)
    if payload.title is not None:
        updates.append("title = ?")
        params.append(payload.title)

    if not updates:
        return current

    updates.append("updated_at = ?")
    params.append(now_iso())
    params.append(item_id)

    with db() as conn:
        conn.execute(f"UPDATE items SET {', '.join(updates)} WHERE id = ?", params)
        row = conn.execute("SELECT * FROM items WHERE id = ?", (item_id,)).fetchone()
        return row_to_item(row)


def soft_delete_item(item_id: int) -> dict[str, Any] | None:
    return update_item(item_id, ItemUpdate(status="deleted"))


def search_items(query: str, limit: int = 30, offset: int = 0) -> list[dict[str, Any]]:
    fts_query = sanitize_fts_query(query)
    if not fts_query:
        return []

    with db() as conn:
        try:
            rows = conn.execute(
                f"""
                SELECT {SUMMARY_COLUMNS_WITH_TABLE}
                FROM items_fts
                JOIN items ON items.id = items_fts.rowid
                WHERE items_fts MATCH ? AND items.status != 'deleted'
                ORDER BY bm25(items_fts), items.created_at DESC
                LIMIT ? OFFSET ?
                """,
                (fts_query, limit, offset),
            ).fetchall()
        except sqlite3.OperationalError:
            logger.warning("Invalid FTS query", extra={"query": query, "fts_query": fts_query})
            return []
        return [row_to_item(row) for row in rows]


def sanitize_fts_query(query: str) -> str:
    import re

    tokens = re.findall(r"[\w\u3400-\u4dbf\u4e00-\u9fff\uf900-\ufaff]+", query, flags=re.UNICODE)
    return " ".join(f'"{token.replace(chr(34), chr(34) * 2)}"' for token in tokens[:12])
