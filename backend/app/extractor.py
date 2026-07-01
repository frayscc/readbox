from __future__ import annotations

from dataclasses import dataclass, asdict
from html import escape, unescape
from typing import Iterable
from urllib.parse import urljoin
from urllib.request import Request, urlopen
import logging
import re


logger = logging.getLogger(__name__)
FETCH_TIMEOUT_SECONDS = 12
MAX_DOWNLOAD_BYTES = 8 * 1024 * 1024
USER_AGENT = (
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) "
    "AppleWebKit/537.36 (KHTML, like Gecko) "
    "Chrome/126.0 Safari/537.36 ReadBox/0.4"
)

CJK_RE = r"\u3400-\u4dbf\u4e00-\u9fff\uf900-\ufaff"


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

        downloaded = fetch_html(url)
        if not downloaded:
            return ArticleExtract()

        metadata = extract_metadata(downloaded, default_url=url)
        html = trafilatura.extract(
            downloaded,
            output_format="html",
            include_comments=False,
            include_tables=True,
            include_images=True,
            include_formatting=True,
            url=url,
        )
        text = trafilatura.extract(
            downloaded,
            output_format="txt",
            include_comments=False,
            include_tables=True,
            url=url,
        )

        if not html or not text:
            fallback_html, fallback_text = fallback_extract(downloaded)
            html = html or fallback_html
            text = text or fallback_text

        text = normalize_text(text)
        excerpt = make_excerpt(text)

        metadata_title = getattr(metadata, "title", None) if metadata else None
        metadata_site_name = getattr(metadata, "sitename", None) if metadata else None
        metadata_url = getattr(metadata, "url", None) if metadata else None
        metadata_image = getattr(metadata, "image", None) if metadata else None

        return ArticleExtract(
            title=clean_title(metadata_title or find_meta(downloaded, "og:title", "twitter:title") or find_title(downloaded)),
            content_html=html,
            content_text=text,
            excerpt=excerpt,
            site_name=clean_title(metadata_site_name or find_meta(downloaded, "og:site_name", "application-name")),
            author=getattr(metadata, "author", None) if metadata else None,
            canonical_url=absolute_url(url, metadata_url or find_canonical(downloaded)),
            cover_url=absolute_url(url, metadata_image or find_meta(downloaded, "og:image", "twitter:image")),
        )
    except Exception:
        logger.exception("Article extraction failed", extra={"url": url})
        return ArticleExtract()


def fetch_html(url: str) -> str | None:
    request = Request(
        url,
        headers={
            "User-Agent": USER_AGENT,
            "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
            "Accept-Language": "zh-CN,zh;q=0.9,en;q=0.7",
        },
    )
    with urlopen(request, timeout=FETCH_TIMEOUT_SECONDS) as response:
        raw = response.read(MAX_DOWNLOAD_BYTES + 1)
        if len(raw) > MAX_DOWNLOAD_BYTES:
            raw = raw[:MAX_DOWNLOAD_BYTES]
        content_type = response.headers.get("content-type", "")
    return decode_html(raw, content_type)


def decode_html(raw: bytes, content_type: str = "") -> str | None:
    if not raw:
        return None

    candidates = [
        find_charset(content_type),
        find_charset(raw[:4096].decode("ascii", errors="ignore")),
    ]

    try:
        from charset_normalizer import from_bytes

        detected = from_bytes(raw).best()
        if detected and detected.encoding:
            candidates.append(detected.encoding)
    except Exception:
        pass

    candidates.extend(["utf-8", "gb18030"])

    for encoding in dedupe(candidates):
        if not encoding:
            continue
        try:
            return raw.decode(encoding, errors="strict")
        except UnicodeDecodeError:
            continue
        except LookupError:
            continue

    return raw.decode("utf-8", errors="replace")


def find_charset(value: str | None) -> str | None:
    if not value:
        return None
    match = re.search(r"charset=[\"']?\s*([a-zA-Z0-9._-]+)", value, flags=re.I)
    if match:
        return normalize_charset(match.group(1))
    match = re.search(r"<meta[^>]+charset=[\"']?\s*([a-zA-Z0-9._-]+)", value, flags=re.I)
    if match:
        return normalize_charset(match.group(1))
    return None


def normalize_charset(charset: str) -> str:
    charset = charset.strip().lower()
    if charset in {"gbk", "gb2312", "gb-2312"}:
        return "gb18030"
    return charset


def normalize_text(text: str | None) -> str | None:
    if not text:
        return None
    text = text.replace("\u3000", " ")
    text = re.sub(rf"(?<=[{CJK_RE}])\s+(?=[{CJK_RE}])", "", text)
    text = re.sub(r"[ \t\r\f\v]+", " ", text)
    text = re.sub(r"\n{3,}", "\n\n", text)
    return text.strip() or None


def make_excerpt(text: str | None, limit: int = 320) -> str | None:
    if not text:
        return None
    compact = re.sub(r"\s+", " ", text).strip()
    return compact[:limit] if compact else None


def find_title(html: str) -> str | None:
    match = re.search(r"<title[^>]*>(.*?)</title>", html, flags=re.I | re.S)
    if not match:
        return None
    return clean_title(strip_tags(match.group(1)))


def find_meta(html: str, *names: str) -> str | None:
    for name in names:
        escaped_name = re.escape(name)
        patterns = [
            rf"<meta\b(?=[^>]*(?:property|name)=[\"']{escaped_name}[\"'])(?=[^>]*content=[\"']([^\"']+)[\"'])[^>]*>",
            rf"<meta\b(?=[^>]*content=[\"']([^\"']+)[\"'])(?=[^>]*(?:property|name)=[\"']{escaped_name}[\"'])[^>]*>",
        ]
        for pattern in patterns:
            match = re.search(pattern, html, flags=re.I | re.S)
            if match:
                return strip_tags(match.group(1)).strip()
    return None


def find_canonical(html: str) -> str | None:
    patterns = [
        r"<link\b(?=[^>]*rel=[\"'][^\"']*\bcanonical\b[^\"']*[\"'])(?=[^>]*href=[\"']([^\"']+)[\"'])[^>]*>",
        r"<link\b(?=[^>]*href=[\"']([^\"']+)[\"'])(?=[^>]*rel=[\"'][^\"']*\bcanonical\b[^\"']*[\"'])[^>]*>",
    ]
    for pattern in patterns:
        match = re.search(pattern, html, flags=re.I | re.S)
        if match:
            return match.group(1).strip()
    return None


def clean_title(title: str | None) -> str | None:
    if not title:
        return None
    title = re.sub(r"\s+", " ", title).strip()
    return title or None


def strip_tags(value: str) -> str:
    return unescape(re.sub(r"<[^>]+>", "", value))


def absolute_url(base_url: str, value: str | None) -> str | None:
    if not value:
        return None
    return urljoin(base_url, value.strip())


def fallback_extract(html: str) -> tuple[str | None, str | None]:
    try:
        from lxml import html as lxml_html

        document = lxml_html.fromstring(html)
        for node in document.xpath(
            "//script|//style|//noscript|//template|//svg|//canvas|//iframe|"
            "//nav|//header|//footer|//*[contains(@class, 'comment') or contains(@id, 'comment')]"
        ):
            parent = node.getparent()
            if parent is not None:
                parent.remove(node)

        candidates = document.xpath("//article|//main|//*[@id='article' or @id='content' or contains(@class, 'article') or contains(@class, 'content')]")
        candidate = max(candidates, key=lambda node: len(node.text_content()), default=document)

        blocks: list[str] = []
        text_blocks: list[str] = []
        for node in candidate.xpath(".//h1|.//h2|.//h3|.//p|.//li|.//blockquote|.//pre"):
            text = normalize_text(node.text_content())
            if not text or len(text) < 2:
                continue
            tag = node.tag.lower()
            if tag not in {"h1", "h2", "h3", "p", "li", "blockquote", "pre"}:
                tag = "p"
            blocks.append(f"<{tag}>{escape(text)}</{tag}>")
            text_blocks.append(text)

        if not text_blocks:
            text = normalize_text(candidate.text_content())
            return (f"<p>{escape(text)}</p>" if text else None, text)

        return "\n".join(blocks), "\n\n".join(text_blocks)
    except Exception:
        return None, None


def dedupe(values: Iterable[str | None]) -> list[str | None]:
    seen: set[str] = set()
    result: list[str | None] = []
    for value in values:
        key = value.lower() if value else ""
        if key in seen:
            continue
        seen.add(key)
        result.append(value)
    return result
