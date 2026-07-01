# ReadBox

ReadBox 是一个轻量级、自部署、单用户的稍后阅读收件箱。第一轮 MVP 只包含 backend + web，用来打通保存入口、后端解析、跨端阅读和标记已读。

## 当前功能

- FastAPI 后端，Bearer Token 鉴权
- SQLite 数据库存储，启动时开启 WAL
- SQLite FTS5 搜索标题和正文
- trafilatura 最佳努力提取网页标题、正文和元信息
- React + Vite 单页 Web
- Web 支持设置 API、添加 URL、未读/已读/收藏、搜索、阅读、删除
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

前端：

```bash
cd web
npm install
npm run dev
```

开发模式下访问 http://localhost:5173。

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

## 后续轮次

第二轮建议只加 Chrome 插件，复用现有 `POST /api/items`。第三轮再加 iOS App + Share Extension。正文解析和中文网站兼容可以在第四轮集中优化，AI 摘要、Outline 同步、自动清理继续延后。
