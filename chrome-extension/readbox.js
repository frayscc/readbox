const SETTINGS_KEYS = ["apiBaseUrl", "apiToken"];

async function getSettings() {
  return chrome.storage.sync.get(SETTINGS_KEYS);
}

function normalizeBaseUrl(value) {
  return String(value || "").replace(/\/+$/, "");
}

function readableError(error) {
  if (error instanceof Error) return error.message;
  return "Unknown error";
}

async function saveToReadBox({ url, title, source = "chrome_extension" }) {
  const settings = await getSettings();
  const apiBaseUrl = normalizeBaseUrl(settings.apiBaseUrl);
  const apiToken = settings.apiToken;

  if (!apiBaseUrl || !apiToken) {
    throw new Error("ReadBox API is not configured.");
  }

  if (!url || !/^https?:\/\//i.test(url)) {
    throw new Error("This page URL cannot be saved.");
  }

  let response;
  try {
    response = await fetch(`${apiBaseUrl}/api/items`, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: `Bearer ${apiToken}`
      },
      body: JSON.stringify({
        url,
        title: title || url,
        source
      })
    });
  } catch {
    throw new Error("Network failed. Check the API URL and server status.");
  }

  if (response.status === 401) {
    throw new Error("Token is invalid.");
  }

  if (!response.ok) {
    const text = await response.text();
    throw new Error(text || `ReadBox returned HTTP ${response.status}.`);
  }

  return response.json();
}

globalThis.ReadBox = {
  getSettings,
  normalizeBaseUrl,
  readableError,
  saveToReadBox
};
