from __future__ import annotations

from pathlib import Path

import pytest
from fastapi.testclient import TestClient

from app import crud, database
from app.extractor import ArticleExtract
from app.main import app


@pytest.fixture()
def client(tmp_path: Path, monkeypatch: pytest.MonkeyPatch):
    monkeypatch.setenv("READBOX_TOKEN", "test-token")
    monkeypatch.setattr(database, "DB_PATH", tmp_path / "readbox.db")
    with TestClient(app) as test_client:
        yield test_client


def auth_headers() -> dict[str, str]:
    return {"Authorization": "Bearer test-token"}


def test_items_api_creates_in_background_and_returns_detail(
    client: TestClient, monkeypatch: pytest.MonkeyPatch
) -> None:
    monkeypatch.setattr(
        crud,
        "extract_article",
        lambda url: ArticleExtract(
            title="Extracted title",
            content_html="<p>正文</p>",
            content_text="正文",
            excerpt="正文",
        ),
    )

    response = client.post(
        "/api/items",
        headers=auth_headers(),
        json={"url": "https://example.com/article", "title": "Original"},
    )

    assert response.status_code == 200
    item_id = response.json()["id"]

    list_response = client.get("/api/items", headers=auth_headers())
    assert list_response.status_code == 200
    listed = list_response.json()["items"][0]
    assert listed["title"] == "Extracted title"
    assert "content_html" not in listed
    assert "content_text" not in listed

    detail_response = client.get(f"/api/items/{item_id}", headers=auth_headers())
    assert detail_response.status_code == 200
    detail = detail_response.json()
    assert detail["content_html"] == "<p>正文</p>"
    assert detail["content_text"] == "正文"


def test_api_requires_token(client: TestClient) -> None:
    response = client.get("/api/items")

    assert response.status_code == 401


def test_search_api_handles_special_characters(client: TestClient) -> None:
    response = client.get('/api/search?q=" OR @@@', headers=auth_headers())

    assert response.status_code == 200
    assert response.json()["items"] == []
