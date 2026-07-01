const pageTitle = document.querySelector("#pageTitle");
const pageUrl = document.querySelector("#pageUrl");
const saveButton = document.querySelector("#saveButton");
const statusBox = document.querySelector("#status");

let currentTab;

function setStatus(message, type = "") {
  statusBox.textContent = message;
  statusBox.className = `status ${type}`;
}

async function loadCurrentTab() {
  const [tab] = await chrome.tabs.query({ active: true, currentWindow: true });
  currentTab = tab;
  pageTitle.textContent = tab?.title || "Untitled page";
  pageUrl.textContent = tab?.url || "";

  if (!tab?.url || !/^https?:\/\//i.test(tab.url)) {
    saveButton.disabled = true;
    setStatus("当前页面不能保存。", "error");
  }
}

saveButton.addEventListener("click", async () => {
  if (!currentTab?.url) return;

  saveButton.disabled = true;
  setStatus("正在保存...", "");

  try {
    const item = await ReadBox.saveToReadBox({
      url: currentTab.url,
      title: currentTab.title
    });
    setStatus(`已保存：${item.title || item.url}`, "success");
  } catch (error) {
    setStatus(ReadBox.readableError(error), "error");
  } finally {
    saveButton.disabled = false;
  }
});

loadCurrentTab().catch((error) => {
  saveButton.disabled = true;
  setStatus(ReadBox.readableError(error), "error");
});
