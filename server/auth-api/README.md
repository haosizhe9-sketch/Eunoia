# Eunoia 账号 API（JSON 文件）

在腾讯云 / 自建机上与 Flutter 客户端对接：账号与 **bcrypt 哈希** 存入 `data/users.json`，无 Supabase。

## 本地运行

```bash
cd server/auth-api
npm install
npm start
```

默认监听 **`127.0.0.1:3848`**。健康检查：`GET http://127.0.0.1:3848/health`。

## API

| 方法 | 路径 | 说明 |
|------|------|------|
| POST | `/register` | Body: `{ "account", "password", "displayName?" }`，账号与密码均为 6～12 位字母数字 |
| POST | `/login` | Body: `{ "account", "password" }` |

成功：`{ "user": { ... } }`（无 `password_hash`）。失败：`4xx` + `{ "error": "..." }`。

## 环境变量

| 变量 | 说明 |
|------|------|
| `PORT` | 监听端口，默认 `3848` |
| `AUTH_DATA_FILE` | 自定义 JSON 路径（默认 `data/users.json`） |

## Nginx（与站点同源 `/api/auth`）

Flutter Web 在未设置 `AUTH_API_BASE_URL` 时，会请求 **`https://你的域名/api/auth/register`** 与 **`.../login`**。将前缀反代到本服务：

```nginx
location /api/auth/ {
    proxy_pass http://127.0.0.1:3848/;
    proxy_http_version 1.1;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
}
```

注意：`proxy_pass` 末尾 **`/`** 会把 `/api/auth/login` 转成后端 `/login`。

## systemd（示例）

```ini
[Unit]
Description=Eunoia Auth API
After=network.target

[Service]
Type=simple
User=ubuntu
WorkingDirectory=/home/ubuntu/Eunoia/server/auth-api
ExecStart=/usr/bin/node index.js
Restart=on-failure
Environment=PORT=3848

[Install]
WantedBy=multi-user.target
```

部署后执行：`npm install` → `sudo systemctl enable --now eunoia-auth`（单元文件名自定）。

## Flutter 构建参数

- **自定义基址**：`--dart-define=AUTH_API_BASE_URL=https://www.example.com/api/auth`
- **Web 强制仅用本地账号（不调远端）**：`--dart-define=AUTH_LOCAL_ONLY=true`

## 说明

- 个人资料、E 点等**业务写入仍优先落在客户端本地** SharedPreferences；登录远端账号时会用服务端返回的用户快照覆盖本地同账号条目。**跨设备长期同步**需在后续增加「资料 / 进度同步 API」。
- 生产环境务必使用 **HTTPS**，并定期备份 `data/users.json`。
