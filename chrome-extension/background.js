importScripts("readbox.js");

chrome.runtime.onInstalled.addListener(() => {
  chrome.contextMenus.create({
    id: "save-to-readbox",
    title: "Save to ReadBox",
    contexts: ["page", "link"]
  });
});

async function setBadge(tabId, text, color) {
  if (!tabId) return;
  await chrome.action.setBadgeText({ text, tabId });
  if (color) {
    await chrome.action.setBadgeBackgroundColor({ color });
  }
}

chrome.contextMenus.onClicked.addListener(async (info, tab) => {
  if (info.menuItemId !== "save-to-readbox") return;

  const url = info.linkUrl || tab?.url;
  const title = tab?.title || url;

  try {
    await ReadBox.saveToReadBox({ url, title });
    await setBadge(tab?.id, "OK", "#2f6f63");
  } catch (error) {
    await setBadge(tab?.id, "ERR", "#9d2f2f");
    console.error("ReadBox save failed:", ReadBox.readableError(error));
  }

  if (tab?.id) {
    setTimeout(() => chrome.action.setBadgeText({ text: "", tabId: tab.id }), 2500);
  }
});
