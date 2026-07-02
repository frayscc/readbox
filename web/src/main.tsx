import React, { FormEvent, useEffect, useMemo, useState } from "react";
import { createRoot } from "react-dom/client";
import DOMPurify from "dompurify";
import {
  createItem,
  deleteItem,
  getItem,
  ListMode,
  listItems,
  login,
  ReadBoxItem,
  Settings,
  updateItem
} from "./api";
import "./styles.css";

const SETTINGS_KEY = "readbox.settings";

function loadSettings(): Settings {
  try {
    const value = localStorage.getItem(SETTINGS_KEY);
    return value ? JSON.parse(value) : { apiBaseUrl: "", apiToken: "", username: "readbox" };
  } catch {
    return { apiBaseUrl: "", apiToken: "", username: "readbox" };
  }
}

function itemDomain(item: ReadBoxItem) {
  if (item.site_name) return item.site_name;
  try {
    return new URL(item.url).hostname;
  } catch {
    return "readbox.local";
  }
}

function BrandMark() {
  return (
    <span className="mark" aria-hidden="true">
      <svg viewBox="0 0 24 24" fill="none">
        <path
          d="M7 4.5h7.4L18 8.1v11.4H7V4.5Z"
          stroke="currentColor"
          strokeWidth="1.8"
        />
        <path d="M14 4.5v4h4" stroke="currentColor" strokeWidth="1.8" />
      </svg>
    </span>
  );
}

function SettingsForm({
  onSave,
  onCancel
}: {
  onSave: (settings: Settings) => void;
  onCancel?: () => void;
}) {
  const saved = loadSettings();
  const [apiBaseUrl, setApiBaseUrl] = useState(saved.apiBaseUrl);
  const [username, setUsername] = useState(saved.username || "readbox");
  const [password, setPassword] = useState("");
  const [message, setMessage] = useState("");
  const [submitting, setSubmitting] = useState(false);

  async function submit(event: FormEvent) {
    event.preventDefault();
    setSubmitting(true);
    setMessage("");
    try {
      const session = await login(apiBaseUrl, username, password);
      const nextSettings = {
        apiBaseUrl: apiBaseUrl.replace(/\/+$/, ""),
        apiToken: session.access_token,
        username: session.username
      };
      localStorage.setItem(SETTINGS_KEY, JSON.stringify(nextSettings));
      onSave(nextSettings);
    } catch (error) {
      setMessage(error instanceof Error ? error.message : "登录失败");
    } finally {
      setSubmitting(false);
    }
  }

  return (
    <form className="settings-panel" onSubmit={submit}>
      <div className="settings-title">
        <BrandMark />
        <div>
          <h1 id="settings-title">服务设置</h1>
          <p>登录你的自部署 ReadBox 服务。密码不会保存在本机。</p>
        </div>
      </div>

      <label>
        API Base URL
        <input
          placeholder="https://readbox.example.com"
          value={apiBaseUrl}
          onChange={(event) => setApiBaseUrl(event.target.value)}
          required
        />
      </label>

      <label>
        用户名
        <input
          value={username}
          onChange={(event) => setUsername(event.target.value)}
          autoComplete="username"
          required
        />
      </label>

      <label>
        密码
        <input
          type="password"
          value={password}
          onChange={(event) => setPassword(event.target.value)}
          autoComplete="current-password"
          required
        />
      </label>

      {message && (
        <div className="message error" role="alert">
          {message}
        </div>
      )}

      <div className="settings-actions">
        {onCancel && (
          <button className="text-btn" type="button" onClick={onCancel}>
            取消
          </button>
        )}
        <button className="primary" type="submit" disabled={submitting}>
          {submitting ? "正在登录..." : "登录并保存"}
        </button>
      </div>
    </form>
  );
}

function SettingsView({ onSave }: { onSave: (settings: Settings) => void }) {
  return (
    <main className="settings-shell">
      <SettingsForm onSave={onSave} />
    </main>
  );
}

function SettingsDialog({
  onSave,
  onClose
}: {
  onSave: (settings: Settings) => void;
  onClose: () => void;
}) {
  return (
    <div className="modal-backdrop" role="presentation" onMouseDown={onClose}>
      <div
        className="modal"
        role="dialog"
        aria-modal="true"
        aria-labelledby="settings-title"
        onMouseDown={(event) => event.stopPropagation()}
      >
        <SettingsForm onSave={onSave} onCancel={onClose} />
      </div>
    </div>
  );
}

function EmptyState({ mode }: { mode: ListMode }) {
  const title = mode === "search" ? "没有匹配文章" : "这里还没有文章";
  const hint =
    mode === "search"
      ? "换一个关键词，或先保存一个 URL。"
      : "从浏览器扩展、iOS 分享菜单或上方输入框保存第一个网页链接。";

  return (
    <div className="empty">
      <h3>{title}</h3>
      <p>{hint}</p>
    </div>
  );
}

function ArticleList({
  items,
  selected,
  onSelect
}: {
  items: ReadBoxItem[];
  selected?: number;
  onSelect: (item: ReadBoxItem) => void;
}) {
  return (
    <div className="list">
      {items.map((item) => (
        <button
          className={`list-item ${selected === item.id ? "active" : ""}`}
          key={item.id}
          onClick={() => onSelect(item)}
        >
          <span className="item-top">
            <span className="item-title">{item.title || item.url}</span>
            <span
              className={`dot ${
                item.status === "read" ? "read" : item.content_text ? "" : "warn"
              }`}
            />
          </span>
          {item.excerpt && <span className="item-excerpt">{item.excerpt}</span>}
          <span className="item-meta">
            {itemDomain(item)}
            {item.is_favorite ? " · 收藏" : ""}
            {item.status === "read" ? " · 已读" : ""}
          </span>
        </button>
      ))}
    </div>
  );
}

function Reader({
  item,
  settings,
  onChanged,
  onBack
}: {
  item?: ReadBoxItem;
  settings: Settings;
  onChanged: (item?: ReadBoxItem) => void;
  onBack: () => void;
}) {
  const html = useMemo(() => {
    if (!item?.content_html) return "";
    return DOMPurify.sanitize(item.content_html);
  }, [item]);
  const textParagraphs = useMemo(() => {
    if (!item?.content_text) return [];
    return item.content_text
      .split(/\n{2,}/)
      .map((paragraph) => paragraph.trim())
      .filter(Boolean);
  }, [item]);

  if (!item) {
    return (
      <main className="reader">
        <header className="reader-top">
          <span className="domain">readbox.local / empty</span>
        </header>
        <article className="article empty-reader">
          <div>
            <BrandMark />
            <h2>选择一篇文章开始阅读</h2>
            <p>ReadBox 会把正文放在安静的阅读面里，适合长时间阅读。</p>
          </div>
        </article>
      </main>
    );
  }

  const currentItem = item;

  async function patch(patchData: Partial<ReadBoxItem>) {
    const changed = await updateItem(settings, currentItem.id, patchData);
    onChanged(changed);
  }

  async function remove() {
    await deleteItem(settings, currentItem.id);
    onChanged(undefined);
  }

  return (
    <main className="reader">
      <header className="reader-top">
        <button className="text-btn mobile-back" onClick={onBack}>
          返回列表
        </button>
        <span className="domain">
          {itemDomain(currentItem).toLowerCase()} /{" "}
          {currentItem.content_html ? "parsed" : "saved"}
        </span>
        <div className="reader-actions">
          <a
            className="text-btn"
            href={currentItem.canonical_url || currentItem.url}
            target="_blank"
            rel="noreferrer"
          >
            原文
          </a>
          <button
            className="text-btn"
            onClick={() =>
              patch({ status: currentItem.status === "read" ? "unread" : "read" })
            }
          >
            {currentItem.status === "read" ? "恢复未读" : "标记已读"}
          </button>
          <button
            className="text-btn"
            onClick={() => patch({ is_favorite: !currentItem.is_favorite })}
          >
            {currentItem.is_favorite ? "取消收藏" : "收藏"}
          </button>
          <button className="text-btn danger" onClick={remove}>
            删除
          </button>
        </div>
      </header>

      <article className="article">
        <div className="article-inner">
          <h1>{item.title || item.url}</h1>
          <div className="byline">
            {[item.site_name, item.author].filter(Boolean).join(" / ") || "ReadBox"}
          </div>
          {html ? (
            <div className="article-body" dangerouslySetInnerHTML={{ __html: html }} />
          ) : textParagraphs.length ? (
            <div className="article-body plain-text">
              {textParagraphs.map((paragraph, index) => (
                <p key={index}>{paragraph}</p>
              ))}
            </div>
          ) : (
            <p className="fallback-text">
              暂无提取正文。可以打开原文链接阅读，保存记录已经保留。
            </p>
          )}
        </div>
      </article>
    </main>
  );
}

function App() {
  const [settings, setSettings] = useState<Settings>(loadSettings());
  const [mode, setMode] = useState<ListMode>("unread");
  const [items, setItems] = useState<ReadBoxItem[]>([]);
  const [selected, setSelected] = useState<ReadBoxItem | undefined>();
  const [url, setUrl] = useState("");
  const [query, setQuery] = useState("");
  const [loading, setLoading] = useState(false);
  const [message, setMessage] = useState("");
  const [settingsOpen, setSettingsOpen] = useState(false);
  const [mobilePane, setMobilePane] = useState<"list" | "reader">("list");

  const configured = settings.apiBaseUrl && settings.apiToken;

  async function refresh(nextMode = mode) {
    if (!configured) return;
    setLoading(true);
    setMessage("");
    try {
      const data = await listItems(settings, nextMode, query);
      setItems(data);
    } catch (error) {
      setMessage(error instanceof Error ? error.message : "加载失败");
    } finally {
      setLoading(false);
    }
  }

  async function selectItem(item: ReadBoxItem) {
    setSelected(item);
    setMobilePane("reader");
    setMessage("");
    try {
      setSelected(await getItem(settings, item.id));
    } catch (error) {
      setMessage(error instanceof Error ? error.message : "加载正文失败");
    }
  }

  useEffect(() => {
    refresh();
  }, [mode, configured]);

  async function addUrl(event: FormEvent) {
    event.preventDefault();
    if (!url.trim()) return;
    setLoading(true);
    setMessage("正在保存并解析...");
    try {
      const item = await createItem(settings, url.trim());
      setUrl("");
      setMode("unread");
      setSelected(item);
      setMobilePane("reader");
      await refresh("unread");
      setMessage("已保存，正在后台解析");
    } catch (error) {
      setMessage(error instanceof Error ? error.message : "保存失败");
    } finally {
      setLoading(false);
    }
  }

  function saveSettings(next: Settings) {
    setSettings(next);
    setMode("unread");
    setSettingsOpen(false);
  }

  if (!configured) {
    return <SettingsView onSave={saveSettings} />;
  }

  return (
    <main className={`app-shell ${mobilePane === "reader" ? "show-reader" : "show-list"}`}>
      <aside className="sidebar">
        <div className="side-head">
          <div className="brand-row">
            <div className="brand">
              <BrandMark />
              <h1>ReadBox</h1>
            </div>
            <button
              className="icon-btn"
              aria-label="设置"
              onClick={() => setSettingsOpen(true)}
            >
              <span aria-hidden="true">⌘</span>
            </button>
          </div>

          <form className="add-form" onSubmit={addUrl}>
            <input
              type="url"
              placeholder="粘贴 URL 保存到 ReadBox"
              value={url}
              onChange={(event) => setUrl(event.target.value)}
              required
            />
            <button className="primary" disabled={loading}>
              保存
            </button>
          </form>

          <div className="tabs">
            {[
              ["unread", "未读"],
              ["read", "已读"],
              ["favorite", "收藏"],
              ["search", "搜索"]
            ].map(([value, label]) => (
              <button
                key={value}
                className={`chip ${mode === value ? "active" : ""}`}
                onClick={() => setMode(value as ListMode)}
              >
                {label}
              </button>
            ))}
          </div>

          {mode === "search" && (
            <form
              className="search-form"
              onSubmit={(event) => {
                event.preventDefault();
                refresh("search");
              }}
            >
              <input
                placeholder="搜索标题、来源或摘要"
                value={query}
                onChange={(event) => setQuery(event.target.value)}
              />
            </form>
          )}
        </div>

        {message && (
          <div className="message" role="status">
            {message}
          </div>
        )}
        {loading && !items.length ? (
          <div className="list skeleton-list" aria-label="加载中">
            <span />
            <span />
            <span />
          </div>
        ) : items.length ? (
          <ArticleList items={items} selected={selected?.id} onSelect={selectItem} />
        ) : (
          <EmptyState mode={mode} />
        )}
      </aside>

      <Reader
        item={selected}
        settings={settings}
        onChanged={(item) => {
          setSelected(item);
          if (!item) {
            setMobilePane("list");
          }
          refresh();
        }}
        onBack={() => setMobilePane("list")}
      />

      {settingsOpen && (
        <SettingsDialog onSave={saveSettings} onClose={() => setSettingsOpen(false)} />
      )}
    </main>
  );
}

createRoot(document.getElementById("root")!).render(
  <React.StrictMode>
    <App />
  </React.StrictMode>
);
