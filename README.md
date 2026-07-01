# ReadBox

ReadBox 是一个轻量级、自部署、单用户的稍后阅读收件箱。当前 MVP 包含 backend、web、Chrome 插件和 iOS 基础源码，用来打通保存入口、后端解析、跨端阅读和标记已读。

## 当前功能

- FastAPI 后端，Bearer Token 鉴权
- SQLite 数据库存储，启动时开启 WAL
- SQLite FTS5 搜索标题和正文
- trafilatura + fallback 解析网页标题、正文、元信息和封面图
- 中文网页兼容：常见 GBK/GB2312 编码、中文空白规整、Open Graph/canonical fallback
- React + Vite 单页 Web
- Web 支持设置 API、添加 URL、未读/已读/收藏、搜索、阅读、删除
- Chrome Manifest V3 插件，支持 popup 保存当前页和右键菜单保存
- iOS SwiftUI App + Share Extension 基础源码
- Docker Compose 部署 backend + web

## 目录

```text
readbox/
├── backend/
│   ├── app/
│   │   ├── main.py
│   │   ├── database.py
│   │   ├── schemas.py
│   │   ├── crud.py
│   │   ├── extractor.py
│   │   ├── auth.py
│   │   └── routers/items.py
│   ├── requirements.txt
│   └── Dockerfile
├── web/
│   ├── src/
│   ├── package.json
│   └── Dockerfile
├── chrome-extension/
│   ├── manifest.json
│   ├── readbox.js
│   ├── popup.html
│   ├── popup.js
│   ├── options.html
│   ├── options.js
│   ├── background.js
│   └── styles.css
├── ios/
│   ├── Shared/
│   ├── ReadBox/
│   ├── ReadBoxShareExtension/
│   └── README.md
├── docker-compose.yml
├── .env.example
└── README.md
```

## 启动

```bash
cp .env.example .env
# 编辑 .env，把 READBOX_TOKEN 换成一个长随机字符串
docker compose up --build
```

访问 Web：

- Web: http://localhost:8080
- API: http://localhost:8000
- Health: http://localhost:8000/api/health

首次打开 Web 时填写：

- API Base URL: `http://localhost:8000`
- API Token: `.env` 里的 `READBOX_TOKEN`

## 本地开发

后端：

```bash
cd backend
python -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
READBOX_TOKEN=dev-token DATABASE_URL=sqlite:///../data/readbox.db uvicorn app.main:app --reload
```

后端测试：

```bash
cd backend
source .venv/bin/activate
pip install -r requirements-dev.txt
cd ..
python -m pytest
```

前端：

```bash
cd web
npm install
npm run dev
```

开发模式下访问 http://localhost:5173。

## Chrome 插件

加载未打包插件：

1. 打开 `chrome://extensions`
2. 开启 Developer mode
3. 点击 Load unpacked
4. 选择本仓库的 `chrome-extension` 目录
5. 打开插件 Options，填写 API Base URL 和 API Token

保存入口：

- 点击工具栏里的 ReadBox 图标，然后点击“保存当前页面”
- 在网页或链接上右键，点击 “Save to ReadBox”

插件会把当前页面的 `title` 和 `url` 发送到 `POST /api/items`，`source` 固定为 `chrome_extension`。如果未配置 API、Token 错误、网络失败或后端返回错误，popup 会显示对应提示；右键保存失败时会在扩展 service worker 控制台记录错误，并短暂显示 `ERR` badge。

## iOS App 和 Share Extension

iOS 源码位于 `ios/`，并包含可直接打开的 `ios/ReadBox.xcodeproj`：

- `ios/ReadBox`: SwiftUI 主 App
- `ios/ReadBoxShareExtension`: Share Extension
- `ios/Shared`: 主 App 和扩展共用的 settings、models、API client

主 App 支持：

- 设置 API Base URL 和 API Token
- 查看未读、已读、收藏列表
- 打开阅读页
- 标记已读 / 恢复未读
- 收藏 / 取消收藏
- 删除
- 手动粘贴 URL 保存

Share Extension 支持：

- 接收 `public.url`
- 接收 `public.plain-text`
- 从文本中提取第一个 `http/https` URL
- 调用后端 `POST /api/items`
- `source` 设置为 `ios_share`

使用方式：

1. 打开 `ios/ReadBox.xcodeproj`。
2. 修改 `ios/Shared/SettingsStore.swift` 里的 App Group。
3. 修改两个 entitlements 文件里的 App Group，并在 Xcode 为两个 target 启用相同 App Group。
4. 配置 bundle id、Team 和 signing。
5. 用 Xcode 构建，或打包后通过 AltStore 侧载。

更详细的 Xcode 和 AltStore 说明见 `ios/README.md`。

## API 示例

```bash
TOKEN=dev-token
API=http://localhost:8000

curl "$API/api/health"

curl -X POST "$API/api/items" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"url":"https://example.com","title":"Example","source":"web"}'

curl "$API/api/items?status=unread" \
  -H "Authorization: Bearer $TOKEN"

curl -X PATCH "$API/api/items/1" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"status":"read"}'

curl "$API/api/search?q=Example" \
  -H "Authorization: Bearer $TOKEN"
```

## 反向代理

推荐把 Web 和 API 放到同一域名下，例如：

- `https://readbox.example.com` 指向 web
- `https://readbox.example.com/api/` 反代到 backend 的 `8000` 端口

如果 API 和 Web 不同源，需要在 `.env` 中把 Web 地址加入 `CORS_ORIGINS`，多个地址用英文逗号分隔。

## 备份 SQLite

容器运行时数据库位于宿主机 `./data/readbox.db`。推荐用 SQLite 在线备份命令：

```bash
sqlite3 ./data/readbox.db ".backup './data/readbox-$(date +%Y%m%d-%H%M%S).db'"
```

也可以停止服务后直接复制 `./data` 目录。

## 正文解析

保存 URL 时，后端会先写入基础记录并立即返回，然后在后台抓取和解析正文，避免慢网页阻塞保存入口。列表和搜索接口只返回摘要字段；打开单篇文章时再读取完整正文。

解析层会使用浏览器风格请求头抓取页面，优先通过 trafilatura 提取正文；如果正文为空，会回退到 `article`、`main`、常见 `content/article` 容器提取段落。解析层会处理常见中文站点编码、Open Graph 元信息、canonical URL、封面图和中文正文空白。

## 后续轮次

第五轮再考虑 AI 摘要、Outline 同步、自动清理。

## 发布约定

从 `0.2.0` 开始，推送发布时使用语义化版本号：

- Git tag: `vX.Y.Z`
- Docker backend: `frayscc/readbox:backend-X.Y.Z`
- Docker web: `frayscc/readbox:web-X.Y.Z`
- 可同时更新 `backend-latest` 和 `web-latest`
