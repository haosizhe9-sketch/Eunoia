# 每日环球快讯 JSON 生成（运维）

## 安全

- **切勿**将 `DASHSCOPE_API_KEY` 提交到 Git。若在聊天、截图中泄露过密钥，请立即到阿里云百炼控制台**禁用/删除**该 Key 并新建。

## 在服务器上生成当日试卷

```bash
cd server/news-daily
export DASHSCOPE_API_KEY=你的密钥
# 若当日文件已存在则跳过（省 Token）
export SKIP_IF_EXISTS=1
export OUTPUT_DIR=/var/www/eunoia-news
node generate.mjs
```

将 `news_mock_daily_YYYY-MM-DD.json` 同步到网站可访问目录，例如：

- 本机构建 App 时增加：  
  `--dart-define=NEWS_MOCK_DAILY_BASE_URL=https://www.eunoia5.top/eunoia-news`  
  （路径与 Nginx 实际配置一致。）

## 与 App 内批改

同一 Key 通过编译参数注入客户端，用于模考提交后的阅读/写作/口语 AI 批改：

`--dart-define=DASHSCOPE_API_KEY=sk-xxxx`

生产环境更推荐由**你自己的后端**代理百炼，避免把 Key 打进安装包；当前工程为直连兼容模式，便于你联调。
