import React, { FormEvent, useEffect, useMemo, useState } from "react";
import { createRoot } from "react-dom/client";
import DOMPurify from "dompurify";
import {
  createItem,
  deleteItem,
  ListMode,
  listItems,
  ReadBoxItem,
  Settings,
  updateItem
} from "./api";
import "./styles.css";

const SETTINGS_KEY = "readbox.settings";

function loadSettings(): Settings {
  try {
    const value = localStorage.getItem(SETTINGS_KEY);
    return value ? JSON.parse(value) : { apiBaseUrl: "", apiToken: "" };
  } catch {
    return { apiBaseUrl: "", apiToken: "" };
  }
}

function SettingsView({ onSave }: { onSave: (settings: Settings) => void }) {
  const [settings, setSettings] = useState<Settings>(loadSettings());

  function submit(event: FormEvent) {
    event.preventDefault();
    localStorage.setItem(SETTINGS_KEY, JSON.stringify(settings));
    onSave(settings);
  }

  return (
    <main className="settings-shell">
      <form className="settings-panel" onSubmit={submit}>
        <h1>ReadBox</h1>
        <label>
          API Base URL
          <input
            placeholder="http://localhost:8000"
            value={settings.apiBaseUrl}
            onChange={(event) =>
              setSettings({ ...settings, apiBaseUrl: event.target.value })
            }
            required
          />
        </label>
        <label>
          API Token
          <input
            type="password"
            value={settings.apiToken}
            onChange={(event) =>
              setSettings({ ...settings, apiToken: event.target.value })
            }
            required
          />
        </label>
        <button type="submit">保存设置</button>
      </form>
    </main>
  );
}

function EmptyState({ mode }: { mode: ListMode }) {
  const text =
    mode === "search" ? "输入关键词搜索已保存文章" : "这里还没有文章";
  return <div className="empty">{text}</div>;
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
          <span className="item-title">{item.title || item.url}</span>
          {item.excerpt && <span className="item-excerpt">{item.excerpt}</span>}
          <span className="item-meta">
            {item.site_name || new URL(item.url).hostname}
            {item.is_favorite ? " / 收藏" : ""}
          </span>
        </button>
      ))}
    </div>
  );
}

function Reader({
  item,
  settings,
  onChanged
}: {
  item?: ReadBoxItem;
  settings: Settings;
  onChanged: (item?: ReadBoxItem) => void;
}) {
  const html = useMemo(() => {
    if (!item?.content_html) return "";
    return DOMPurify.sanitize(item.content_html);
  }, [item]);

  if (!item) {
    return <article className="reader empty-reader">选择一篇文章开始阅读</article>;
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
    <article className="reader">
      <div className="reader-actions">
        <a href={currentItem.canonical_url || currentItem.url} target="_blank" rel="noreferrer">
          原文
        </a>
        <button onClick={() => patch({ status: currentItem.status === "read" ? "unread" : "read" })}>
          {currentItem.status === "read" ? "恢复未读" : "标记已读"}
        </button>
        <button onClick={() => patch({ is_favorite: !currentItem.is_favorite })}>
          {currentItem.is_favorite ? "取消收藏" : "收藏"}
        </button>
        <button className="danger" onClick={remove}>
          删除
        </button>
      </div>
      <h1>{item.title || item.url}</h1>
      <div className="byline">
        {[item.site_name, item.author].filter(Boolean).join(" / ")}
      </div>
      {html ? (
        <div className="article-body" dangerouslySetInnerHTML={{ __html: html }} />
      ) : (
        <p className="fallback-text">
          暂无提取正文。可以打开原文链接阅读，保存记录已经保留。
        </p>
      )}
    </article>
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

  const configured = settings.apiBaseUrl && settings.apiToken;

  async function refresh(nextMode = mode) {
    if (!configured) return;
    setLoading(true);
    setMessage("");
    try {
      const data = await listItems(settings, nextMode, query);
      setItems(data);
      if (selected) {
        setSelected(data.find((item) => item.id === selected.id));
      }
    } catch (error) {
      setMessage(error instanceof Error ? error.message : "加载失败");
    } finally {
      setLoading(false);
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
      await refresh("unread");
      setMessage("已保存");
    } catch (error) {
      setMessage(error instanceof Error ? error.message : "保存失败");
    } finally {
      setLoading(false);
    }
  }

  function saveSettings(next: Settings) {
    setSettings(next);
    setMode("unread");
  }

  if (!configured) {
    return <SettingsView onSave={saveSettings} />;
  }

  return (
    <main className="app-shell">
      <aside className="sidebar">
        <div className="brand-row">
          <h1>ReadBox</h1>
          <button onClick={() => setSettings({ apiBaseUrl: "", apiToken: "" })}>
            设置
          </button>
        </div>

        <form className="add-form" onSubmit={addUrl}>
          <input
            type="url"
            placeholder="粘贴文章 URL"
            value={url}
            onChange={(event) => setUrl(event.target.value)}
            required
          />
          <button disabled={loading}>保存</button>
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
              className={mode === value ? "active" : ""}
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
              placeholder="搜索标题和正文"
              value={query}
              onChange={(event) => setQuery(event.target.value)}
            />
          </form>
        )}

        {message && <div className="message">{message}</div>}
        {items.length ? (
          <ArticleList items={items} selected={selected?.id} onSelect={setSelected} />
        ) : (
          <EmptyState mode={mode} />
        )}
      </aside>

      <Reader
        item={selected}
        settings={settings}
        onChanged={(item) => {
          setSelected(item);
          refresh();
        }}
      />
    </main>
  );
}

createRoot(document.getElementById("root")!).render(
  <React.StrictMode>
    <App />
  </React.StrictMode>
);
