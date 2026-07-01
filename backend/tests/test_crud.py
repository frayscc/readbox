from __future__ import annotations

from pathlib import Path

import pytest

from app import crud, database
from app.extractor import ArticleExtract
from app.schemas import ItemCreate


@pytest.fixture()
def temp_db(tmp_path: Path, monkeypatch: pytest.MonkeyPatch):
    monkeypatch.setattr(database, "DB_PATH", tmp_path / "readbox.db")
    database.init_db()


def test_create_item_does_not_extract_synchronously(
    temp_db, monkeypatch: pytest.MonkeyPatch
) -> None:
    def fail_extract(url: str) -> ArticleExtract:
        raise AssertionError("create_item should not extract before returning")

    monkeypatch.setattr(crud, "extract_article", fail_extract)

    item = crud.create_item(
        ItemCreate(url="https://example.com/article", title="Saved title", source="web")
    )

    assert item["title"] == "Saved title"
    assert item["content_html"] is None
    assert item["content_text"] is None


def test_extract_item_content_updates_existing_item(
    temp_db, monkeypatch: pytest.MonkeyPatch
) -> None:
    item = crud.create_item(ItemCreate(url="https://example.com/article", source="web"))

    monkeypatch.setattr(
        crud,
        "extract_article",
        lambda url: ArticleExtract(
            title="Extracted title",
            content_html="<p>正文</p>",
            content_text="正文",
            excerpt="正文",
            site_name="Example",
            canonical_url="https://example.com/article",
        ),
    )

    crud.extract_item_content(item["id"])
    updated = crud.get_item(item["id"])

    assert updated is not None
    assert updated["title"] == "Extracted title"
    assert updated["content_html"] == "<p>正文</p>"
    assert updated["site_name"] == "Example"


def test_list_items_omits_full_article_body(temp_db) -> None:
    crud.create_item(ItemCreate(url="https://example.com/article", source="web"))

    items = crud.list_items()

    assert items
    assert "content_html" not in items[0]
    assert "content_text" not in items[0]


def test_search_sanitizes_special_characters(temp_db) -> None:
    assert crud.search_items('" OR NOT @@@') == []
