export type ItemStatus = "unread" | "read" | "deleted";

export type ReadBoxItem = {
  id: number;
  url: string;
  canonical_url?: string | null;
  title?: string | null;
  author?: string | null;
  site_name?: string | null;
  excerpt?: string | null;
  content_html?: string | null;
  content_text?: string | null;
  cover_url?: string | null;
  status: ItemStatus;
  is_favorite: boolean;
  source?: string | null;
  created_at: string;
  updated_at: string;
  read_at?: string | null;
};

export type Settings = {
  apiBaseUrl: string;
  apiToken: string;
};

export type ListMode = "unread" | "read" | "favorite" | "search";

function normalizeBaseUrl(url: string): string {
  return url.replace(/\/+$/, "");
}

export async function request<T>(
  settings: Settings,
  path: string,
  init: RequestInit = {}
): Promise<T> {
  const response = await fetch(`${normalizeBaseUrl(settings.apiBaseUrl)}${path}`, {
    ...init,
    headers: {
      "Content-Type": "application/json",
      Authorization: `Bearer ${settings.apiToken}`,
      ...(init.headers ?? {})
    }
  });

  if (!response.ok) {
    const text = await response.text();
    throw new Error(text || `Request failed: ${response.status}`);
  }

  return response.json() as Promise<T>;
}

export async function listItems(
  settings: Settings,
  mode: ListMode,
  query: string
): Promise<ReadBoxItem[]> {
  if (mode === "search") {
    if (!query.trim()) return [];
    const data = await request<{ items: ReadBoxItem[] }>(
      settings,
      `/api/search?q=${encodeURIComponent(query.trim())}`
    );
    return data.items;
  }

  const params = new URLSearchParams();
  if (mode === "favorite") {
    params.set("status", "all");
    params.set("favorite", "true");
  } else {
    params.set("status", mode);
  }
  const data = await request<{ items: ReadBoxItem[] }>(settings, `/api/items?${params}`);
  return data.items;
}

export function getItem(settings: Settings, id: number) {
  return request<ReadBoxItem>(settings, `/api/items/${id}`);
}

export function createItem(settings: Settings, url: string, title?: string) {
  return request<ReadBoxItem>(settings, "/api/items", {
    method: "POST",
    body: JSON.stringify({ url, title: title || undefined, source: "web" })
  });
}

export function updateItem(
  settings: Settings,
  id: number,
  patch: Partial<Pick<ReadBoxItem, "status" | "is_favorite" | "title">>
) {
  return request<ReadBoxItem>(settings, `/api/items/${id}`, {
    method: "PATCH",
    body: JSON.stringify(patch)
  });
}

export function deleteItem(settings: Settings, id: number) {
  return request<ReadBoxItem>(settings, `/api/items/${id}`, {
    method: "DELETE"
  });
}
