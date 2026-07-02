const form = document.querySelector("#settingsForm");
const apiBaseUrl = document.querySelector("#apiBaseUrl");
const username = document.querySelector("#username");
const password = document.querySelector("#password");
const statusBox = document.querySelector("#status");

function setStatus(message, type = "") {
  statusBox.textContent = message;
  statusBox.className = `status ${type}`;
}

async function loadSettings() {
  const settings = await ReadBox.getSettings();
  apiBaseUrl.value = settings.apiBaseUrl || "";
  username.value = settings.username || "readbox";
}

form.addEventListener("submit", async (event) => {
  event.preventDefault();
  setStatus("正在登录...", "");
  try {
    await ReadBox.login({
      apiBaseUrl: apiBaseUrl.value,
      username: username.value.trim(),
      password: password.value
    });
    password.value = "";
    setStatus("已登录并保存。", "success");
  } catch (error) {
    setStatus(ReadBox.readableError(error), "error");
  }
});

loadSettings().catch((error) => {
  setStatus(ReadBox.readableError(error), "error");
});
