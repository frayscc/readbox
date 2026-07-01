const form = document.querySelector("#settingsForm");
const apiBaseUrl = document.querySelector("#apiBaseUrl");
const apiToken = document.querySelector("#apiToken");
const statusBox = document.querySelector("#status");

function setStatus(message, type = "") {
  statusBox.textContent = message;
  statusBox.className = `status ${type}`;
}

async function loadSettings() {
  const settings = await ReadBox.getSettings();
  apiBaseUrl.value = settings.apiBaseUrl || "";
  apiToken.value = settings.apiToken || "";
}

form.addEventListener("submit", async (event) => {
  event.preventDefault();
  await chrome.storage.sync.set({
    apiBaseUrl: ReadBox.normalizeBaseUrl(apiBaseUrl.value),
    apiToken: apiToken.value.trim()
  });
  setStatus("已保存。", "success");
});

loadSettings().catch((error) => {
  setStatus(ReadBox.readableError(error), "error");
});
