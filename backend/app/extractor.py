from __future__ import annotations

from dataclasses import dataclass, asdict


@dataclass
class ArticleExtract:
    title: str | None = None
    content_html: str | None = None
    content_text: str | None = None
    excerpt: str | None = None
    site_name: str | None = None
    author: str | None = None
    canonical_url: str | None = None
    cover_url: str | None = None

    def dict(self) -> dict[str, str | None]:
        return asdict(self)


def extract_article(url: str) -> ArticleExtract:
    """Best-effort extraction. Network or parser failures must not block saving."""
    try:
        import trafilatura
        from trafilatura.metadata import extract_metadata

        downloaded = trafilatura.fetch_url(url)
        if not downloaded:
            return ArticleExtract()

        metadata = extract_metadata(downloaded, default_url=url)
        html = trafilatura.extract(
            downloaded,
            output_format="html",
            include_comments=False,
            include_tables=True,
            url=url,
        )
        text = trafilatura.extract(
            downloaded,
            output_format="txt",
            include_comments=False,
            include_tables=True,
            url=url,
        )

        excerpt = None
        if text:
            excerpt = " ".join(text.split())[:320]

        return ArticleExtract(
            title=getattr(metadata, "title", None) if metadata else None,
            content_html=html,
            content_text=text,
            excerpt=excerpt,
            site_name=getattr(metadata, "sitename", None) if metadata else None,
            author=getattr(metadata, "author", None) if metadata else None,
            canonical_url=getattr(metadata, "url", None) if metadata else None,
            cover_url=getattr(metadata, "image", None) if metadata else None,
        )
    except Exception:
        return ArticleExtract()
