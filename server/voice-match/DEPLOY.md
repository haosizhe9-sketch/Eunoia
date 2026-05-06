# 匿名语聊信令服务部署说明（腾讯云 Ubuntu）

本目录为 Node.js 服务：Socket.IO 排队配对（60 秒超时）、转发 WebRTC SDP/ICE；语音媒体为点对点直连（默认使用 Google 公共 STUN）。客户端构建时需传入 `VOICE_SIGNAL_URL`。

---

## 一、服务器准备（OrcaTerm / SSH）

1. 登录腾讯云控制台，打开 **OrcaTerm**（或本地 SSH）连接香港 Ubuntu 实例。
2. 安装 Node.js 18+（任选其一）：
   ```bash
   curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
   sudo apt-get install -y nodejs
   ```
   验证：`node -v` / `npm -v`。

---

## 二、上传代码（FileZilla）

1. 在本机用 **FileZilla Client** 连接服务器（SFTP：主机用户、`22` 端口、密钥或密码）。
2. 将本地仓库中的 **`server/voice-match/`** 整个目录上传到服务器，例如：`/home/ubuntu/eunoia-voice-match/`。
3. 在 OrcaTerm 中进入该目录：
   ```bash
   cd ~/eunoia-voice-match
   npm install --omit=dev
   ```

---

## 三、放行防火墙与安全组

1. **腾讯云安全组**：入站规则允许 TCP **3847**（或你改用的 `PORT`）来自 `0.0.0.0/0` 或仅你的办公/家庭网段。
2. 若使用 **ufw**：
   ```bash
   sudo ufw allow 3847/tcp
   sudo ufw reload
   ```

---

## 四、前台试跑

```bash
cd ~/eunoia-voice-match
PORT=3847 node index.js
```

应看到：`eunoia-voice-match listening on 0.0.0.0:3847`。

另开终端本机或手机（同网试机）用浏览器访问 `http://<公网IP>:3847/health` 应返回 `ok`。（本项目服务器示例：`http://43.155.24.58:3847/health`）

按 `Ctrl+C` 结束。

---

## 五、用 systemd 常驻（推荐）

```bash
sudo nano /etc/systemd/system/eunoia-voice.service
```

内容示例（把 `User` 与 `WorkingDirectory` 改成你的实际路径）：

```ini
[Unit]
Description=Eunoia voice match / WebRTC signaling
After=network.target

[Service]
Type=simple
User=ubuntu
WorkingDirectory=/home/ubuntu/eunoia-voice-match
Environment=PORT=3847
ExecStart=/usr/bin/node /home/ubuntu/eunoia-voice-match/index.js
Restart=on-failure
RestartSec=3

[Install]
WantedBy=multi-user.target
```

启用并启动：

```bash
sudo systemctl daemon-reload
sudo systemctl enable --now eunoia-voice.service
sudo systemctl status eunoia-voice.service
```

查看日志：`journalctl -u eunoia-voice.service -f`。

---

## 六、Flutter 客户端指向服务器

- **Android/iOS**：未配置时使用 `http://127.0.0.1:3847`（本机）。连接云主机示例：
  ```bash
  flutter build apk --dart-define=VOICE_SIGNAL_URL=http://43.155.24.58:3847
  ```
- **Flutter Web（HTTPS 站点）**：切勿让页面 `https://域名` 去连 `http://IP:3847`，浏览器会拦截（混合内容），出现 `TransportError / websocket error`。  
  **推荐**：在 Nginx 上按仓库内 **`nginx-socketio.example.conf`** 将 `/socket.io/` 反代到 `127.0.0.1:3847`，然后 **不必**再传 `VOICE_SIGNAL_URL`——客户端 Web 会自动使用 **当前页面同源**（`Uri.base.origin`）连接信令。  
  若仍需自定义地址：
  ```bash
  flutter build web --dart-define=VOICE_SIGNAL_URL=https://www.你的域名
  ```

---

## 七、联调与注意事项

1. **两台设备同时点「发射连接信号」** 才会配对成功；匹配最长等待 **60** 秒，超时客户端会自动退回上一页。
2. 语音依赖 **STUN**；部分对称 NAT 仅有 STUN 无法打通时需自建 **TURN**（如 coturn），并在客户端 `createPeerConnection` 的 `iceServers` 里追加（需改 Dart 代码）。
3. **麦克风**：移动端需在系统设置中授予麦克风权限；Web 需在安全上下文（HTTPS 或 localhost）下使用。
4. 更新服务端：FileZilla 覆盖上传 `index.js` / `package.json` 后执行 `sudo systemctl restart eunoia-voice.service`。
