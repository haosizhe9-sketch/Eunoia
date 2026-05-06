/**
 * 在大陆服务器用 Node 生成「今日环球快讯」全员同卷 JSON。
 *
 * 环境变量：
 *   DASHSCOPE_API_KEY   必填，百炼 API Key（勿提交 Git）
 *   SKIP_IF_EXISTS=1    若当日文件已存在则跳过（省 Token）
 *   OUTPUT_DIR          输出目录，默认 ./out
 *   DASHSCOPE_MODEL     默认 qwen-plus
 *
 * 用法：
 *   export DASHSCOPE_API_KEY=sk-xxxx
 *   node generate.mjs
 *
 * 将生成的 news_mock_daily_YYYY-MM-DD.json 上传到站点静态目录，
 * App 使用 --dart-define=NEWS_MOCK_DAILY_BASE_URL=https://www.example.com/static
 */

import fs from 'fs';
import path from 'path';
import process from 'process';

const DASH_URL = 'https://dashscope.aliyuncs.com/compatible-mode/v1/chat/completions';

function chinaDateKey() {
  const china = new Date(Date.now() + 8 * 3600 * 1000);
  const y = china.getUTCFullYear();
  const m = String(china.getUTCMonth() + 1).padStart(2, '0');
  const d = String(china.getUTCDate()).padStart(2, '0');
  return `${y}-${m}-${d}`;
}

function extractJsonObject(raw) {
  let s = raw.trim();
  const fence = s.indexOf('```');
  if (fence !== -1) {
    const start = s.indexOf('{', fence);
    const end = s.lastIndexOf('}');
    if (start !== -1 && end > start) s = s.slice(start, end + 1);
  }
  const start = s.indexOf('{');
  const end = s.lastIndexOf('}');
  if (start === -1 || end <= start) return null;
  s = s.slice(start, end + 1);
  try {
    return JSON.parse(s);
  } catch {
    return null;
  }
}

function buildPrompt(dayStr) {
  return `请基于近几日国际新闻主题（科技、环境、教育、健康、经济民生等），合成一篇适合雅思 Academic Reading 难度的英文语料，长度约 650-900 词。
严禁涉及政治、军事、暴力恐怖、宗教冲突、敏感地缘话题；若材料疑似敏感则改写为中立科普/产业视角。

请仅输出一个 JSON 对象（不要 markdown），字段与要求如下：
{
  "paper_id": "字符串，可用日期+随机后缀",
  "title": "英文标题",
  "article_preview": "英文，截取正文前约 120 词，末尾用 …",
  "article_full": "完整英文正文",
  "reading": [
    {
      "question": "题干英文；若为 TFNG 第一行写 TRUE / FALSE / NOT GIVEN:",
      "options": ["选项英文…"],
      "option_tags": ["T","F","NG"] 或 null；四选一题用 null,
      "correct_index": 0,
      "explanation": "简短英文解析（一句）"
    }
  ],
  "writing_prompt": "英文 Task2 提示（讨论类）",
  "speaking_cue": "英文 Part2 主问题一句",
  "speaking_hints": "英文 bullet 提示（You should say …）",
  "generated_at": "${dayStr}"
}

要求 reading 数组恰好 5 题：其中第 1 题为 TRUE/FALSE/NOT GIVEN（3 选项）；其余 4 题为四选一（4 选项）。所有题目必须可根据 article_full 作答。`;
}

async function main() {
  const apiKey = process.env.DASHSCOPE_API_KEY || '';
  if (!apiKey.trim()) {
    console.error('缺少环境变量 DASHSCOPE_API_KEY');
    process.exit(1);
  }
  const model = process.env.DASHSCOPE_MODEL || 'qwen-plus';
  const outDir = process.env.OUTPUT_DIR || path.join(process.cwd(), 'out');
  const dateKey = chinaDateKey();
  const fileName = `news_mock_daily_${dateKey}.json`;
  const outPath = path.join(outDir, fileName);

  if (process.env.SKIP_IF_EXISTS === '1' && fs.existsSync(outPath)) {
    console.log(`已存在，跳过（SKIP_IF_EXISTS=1）：${outPath}`);
    process.exit(0);
  }

  fs.mkdirSync(outDir, { recursive: true });

  const userPrompt = buildPrompt(dateKey);
  const res = await fetch(DASH_URL, {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${apiKey}`,
      'Content-Type': 'application/json; charset=utf-8',
    },
    body: JSON.stringify({
      model,
      messages: [
        {
          role: 'system',
          content:
            'You are an IELTS content designer. Output MUST be valid JSON only, no markdown fences.',
        },
        { role: 'user', content: userPrompt },
      ],
      temperature: 0.35,
      max_tokens: 8192,
    }),
  });

  const text = await res.text();
  if (!res.ok) {
    console.error('DashScope HTTP', res.status, text);
    process.exit(1);
  }
  const decoded = JSON.parse(text);
  const content = decoded?.choices?.[0]?.message?.content;
  if (!content || typeof content !== 'string') {
    console.error('无有效 content', text.slice(0, 500));
    process.exit(1);
  }
  const json = extractJsonObject(content);
  if (!json || !json.article_full || !Array.isArray(json.reading) || json.reading.length !== 5) {
    console.error('JSON 结构不完整', content.slice(0, 800));
    process.exit(1);
  }

  fs.writeFileSync(outPath, JSON.stringify(json, null, 2), 'utf8');
  console.log('已写入', outPath);
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
