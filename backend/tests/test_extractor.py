from app.extractor import (
    absolute_url,
    decode_html,
    fallback_extract,
    find_canonical,
    find_meta,
    find_title,
    make_excerpt,
    normalize_text,
    text_to_html,
)


def test_decode_html_handles_gbk_meta() -> None:
    html = '<html><head><meta charset="gb2312"><title>中文标题</title></head></html>'

    decoded = decode_html(html.encode("gbk"))

    assert decoded is not None
    assert "中文标题" in decoded


def test_decode_html_handles_gbk_without_declared_charset() -> None:
    html = "<html><head><title>中文标题</title></head><body>这是一段正文。</body></html>"

    decoded = decode_html(html.encode("gbk"))

    assert decoded is not None
    assert "中文标题" in decoded
    assert "这是一段正文" in decoded


def test_metadata_helpers_find_common_article_fields() -> None:
    html = """
    <html>
      <head>
        <title>备用标题 - 站点名</title>
        <meta property="og:title" content="OG 中文标题">
        <meta property="og:site_name" content="示例站点">
        <meta property="og:image" content="/cover.jpg">
        <link rel="canonical" href="/article/123">
      </head>
    </html>
    """

    assert find_title(html) == "备用标题 - 站点名"
    assert find_meta(html, "og:title") == "OG 中文标题"
    assert find_meta(html, "og:site_name") == "示例站点"
    assert find_canonical(html) == "/article/123"
    assert absolute_url("https://example.com/a/b", "/cover.jpg") == "https://example.com/cover.jpg"


def test_normalize_text_keeps_chinese_lines_natural() -> None:
    text = "这是\n一段\n中文。\n\n\nSecond   line"

    assert normalize_text(text) == "这是一段中文。\n\nSecond line"
    assert make_excerpt(text) == "这是 一段 中文。 Second line"


def test_fallback_extract_prefers_article_content() -> None:
    html = """
    <html>
      <body>
        <nav>首页 导航</nav>
        <article>
          <h1>标题</h1>
          <p>第一段中文内容。</p>
          <p>第二段中文内容。</p>
        </article>
      </body>
    </html>
    """

    content_html, content_text = fallback_extract(html)

    assert content_html is not None
    assert "<h1>标题</h1>" in content_html
    assert content_text == "标题\n\n第一段中文内容。\n\n第二段中文内容。"
    assert "首页 导航" not in content_text


def test_fallback_extract_handles_common_chinese_content_classes() -> None:
    html = """
    <html>
      <body>
        <div class="recommend">相关推荐 购买链接</div>
        <div id="js_content">
          <p>这是第一段正文，页面没有 article 标签。</p>
          <p>这是第二段正文，应该作为纯文本保存。</p>
        </div>
      </body>
    </html>
    """

    content_html, content_text = fallback_extract(html)

    assert content_html is not None
    assert content_text == "这是第一段正文，页面没有 article 标签。\n\n这是第二段正文，应该作为纯文本保存。"
    assert "相关推荐" not in content_text


def test_text_to_html_converts_plain_text_paragraphs() -> None:
    assert text_to_html("第一段\n\n第二段") == "<p>第一段</p>\n<p>第二段</p>"
